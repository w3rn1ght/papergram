//
//  PGQRCode.c
//  Papergram
//
//  Small QR encoder. Byte mode only, error correction level M, versions 1-10.
//  That is enough for a Telegram login link (well under 100 bytes) while
//  keeping the implementation auditable.
//

#include "PGQRCode.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define QR_MAX_VERSION 10
#define QR_MAX_SIZE (17 + 4 * QR_MAX_VERSION)
#define QR_MAX_BLOCKS 8

/* Total codewords, ECC codewords per block and block structure for level M. */
static const int kTotalCodewords[QR_MAX_VERSION + 1] = {
    0, 26, 44, 70, 100, 134, 172, 196, 242, 292, 346,
};
static const int kEccPerBlock[QR_MAX_VERSION + 1] = {
    0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26,
};
static const int kGroup1Blocks[QR_MAX_VERSION + 1] = {
    0, 1, 1, 1, 2, 2, 4, 4, 2, 3, 4,
};
static const int kGroup1Data[QR_MAX_VERSION + 1] = {
    0, 16, 28, 44, 32, 43, 27, 31, 38, 36, 43,
};
static const int kGroup2Blocks[QR_MAX_VERSION + 1] = {
    0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 1,
};
static const int kGroup2Data[QR_MAX_VERSION + 1] = {
    0, 0, 0, 0, 0, 0, 0, 0, 39, 37, 44,
};

static const int kAlignmentCount[QR_MAX_VERSION + 1] = {
    0, 0, 2, 2, 2, 2, 2, 3, 3, 3, 3,
};
static const int kAlignmentPositions[QR_MAX_VERSION + 1][3] = {
    {0, 0, 0},
    {0, 0, 0},
    {6, 18, 0},
    {6, 22, 0},
    {6, 26, 0},
    {6, 30, 0},
    {6, 34, 0},
    {6, 22, 38},
    {6, 24, 42},
    {6, 26, 46},
    {6, 28, 50},
};

static uint8_t gf_exp[512];
static uint8_t gf_log[256];
static int gf_ready = 0;

static void gf_init(void)
{
    if (gf_ready) {
        return;
    }

    int x = 1;
    for (int i = 0; i < 255; i++) {
        gf_exp[i] = (uint8_t)x;
        gf_log[x] = (uint8_t)i;
        x <<= 1;
        if (x & 0x100) {
            x ^= 0x11D;
        }
    }
    for (int i = 255; i < 512; i++) {
        gf_exp[i] = gf_exp[i - 255];
    }
    gf_ready = 1;
}

static uint8_t gf_mul(uint8_t a, uint8_t b)
{
    if (a == 0 || b == 0) {
        return 0;
    }
    return gf_exp[(int)gf_log[a] + (int)gf_log[b]];
}

static int bch_remainder(int value, int generator, int degree)
{
    int remainder = value;
    for (int bit = 31; bit >= degree; bit--) {
        if (remainder & (1 << bit)) {
            remainder ^= generator << (bit - degree);
        }
    }
    return remainder & ((1 << degree) - 1);
}

static int data_codewords_for_version(int version)
{
    return kGroup1Blocks[version] * kGroup1Data[version] +
           kGroup2Blocks[version] * kGroup2Data[version];
}

static int capacity_bytes(int version)
{
    int dataCodewords = data_codewords_for_version(version);
    int headerBits = 4 + (version <= 9 ? 8 : 16);
    return (dataCodewords * 8 - headerBits) / 8;
}

static void put_bits(uint8_t *buffer, int *bitCount, int value, int count)
{
    for (int shift = count - 1; shift >= 0; shift--) {
        if ((value >> shift) & 1) {
            int index = *bitCount;
            buffer[index >> 3] |= (uint8_t)(0x80 >> (index & 7));
        }
        (*bitCount)++;
    }
}

/// Builds the interleaved data + ECC codewords for one version.
static int build_codewords(const unsigned char *data, int length, int version,
                           uint8_t *output, int outputCapacity)
{
    int totalCodewords = kTotalCodewords[version];
    int dataCodewords = data_codewords_for_version(version);
    int eccLength = kEccPerBlock[version];

    if (outputCapacity < totalCodewords) {
        return 0;
    }

    uint8_t *dataBytes = (uint8_t *)calloc((size_t)dataCodewords, 1);
    if (dataBytes == NULL) {
        return 0;
    }

    int bitCount = 0;
    put_bits(dataBytes, &bitCount, 0x4, 4); /* byte mode */
    put_bits(dataBytes, &bitCount, length, version <= 9 ? 8 : 16);
    for (int i = 0; i < length; i++) {
        put_bits(dataBytes, &bitCount, data[i], 8);
    }

    int totalBits = dataCodewords * 8;
    int terminator = totalBits - bitCount;
    if (terminator > 4) {
        terminator = 4;
    }
    if (terminator > 0) {
        bitCount += terminator; /* zero bits, the buffer is already zeroed */
    }
    while ((bitCount % 8) != 0) {
        bitCount++;
    }

    int padIndex = bitCount / 8;
    int padValue = 0xEC;
    while (padIndex < dataCodewords) {
        dataBytes[padIndex++] = (uint8_t)padValue;
        padValue = (padValue == 0xEC) ? 0x11 : 0xEC;
    }

    int blockCount = kGroup1Blocks[version] + kGroup2Blocks[version];
    int maxBlockData = kGroup1Data[version] > kGroup2Data[version]
        ? kGroup1Data[version]
        : kGroup2Data[version];

    uint8_t *blockData = (uint8_t *)calloc((size_t)blockCount * (size_t)maxBlockData, 1);
    uint8_t *blockEcc = (uint8_t *)calloc((size_t)blockCount * (size_t)eccLength, 1);
    int *blockLength = (int *)calloc((size_t)blockCount, sizeof(int));
    uint8_t generator[QR_MAX_SIZE];
    memset(generator, 0, sizeof(generator));

    if (blockData == NULL || blockEcc == NULL || blockLength == NULL) {
        free(dataBytes);
        free(blockData);
        free(blockEcc);
        free(blockLength);
        return 0;
    }

    /* Generator polynomial for the ECC degree, lowest coefficient first. */
    generator[0] = 1;
    int degree = 0;
    for (int i = 0; i < eccLength; i++) {
        uint8_t alpha = gf_exp[i];
        for (int k = degree + 1; k >= 0; k--) {
            uint8_t value = 0;
            if (k >= 1) {
                value ^= generator[k - 1];
            }
            if (k <= degree) {
                value ^= gf_mul(generator[k], alpha);
            }
            generator[k] = value;
        }
        degree++;
    }

    int offset = 0;
    for (int block = 0; block < blockCount; block++) {
        int isFirst = block < kGroup1Blocks[version];
        int blockDataLength = isFirst ? kGroup1Data[version] : kGroup2Data[version];
        blockLength[block] = blockDataLength;
        memcpy(blockData + block * maxBlockData, dataBytes + offset, (size_t)blockDataLength);
        offset += blockDataLength;

        uint8_t *remainder = blockEcc + block * eccLength;
        memset(remainder, 0, (size_t)eccLength);
        for (int i = 0; i < blockDataLength; i++) {
            uint8_t factor = blockData[block * maxBlockData + i] ^ remainder[0];
            memmove(remainder, remainder + 1, (size_t)(eccLength - 1));
            remainder[eccLength - 1] = 0;
            for (int j = 0; j < eccLength; j++) {
                remainder[j] ^= gf_mul(generator[eccLength - 1 - j], factor);
            }
        }
    }

    int outIndex = 0;
    for (int i = 0; i < maxBlockData; i++) {
        for (int block = 0; block < blockCount; block++) {
            if (i < blockLength[block]) {
                output[outIndex++] = blockData[block * maxBlockData + i];
            }
        }
    }
    for (int i = 0; i < eccLength; i++) {
        for (int block = 0; block < blockCount; block++) {
            output[outIndex++] = blockEcc[block * eccLength + i];
        }
    }

    free(dataBytes);
    free(blockData);
    free(blockEcc);
    free(blockLength);

    return outIndex == totalCodewords;
}

static void set_function(int8_t *modules, uint8_t *function, int size, int row, int column, int dark)
{
    if (row < 0 || column < 0 || row >= size || column >= size) {
        return;
    }
    modules[row * size + column] = (int8_t)(dark ? 1 : 0);
    function[row * size + column] = 1;
}

static void draw_finder(int8_t *modules, uint8_t *function, int size, int row, int column)
{
    for (int r = -1; r <= 7; r++) {
        for (int c = -1; c <= 7; c++) {
            int dark = 0;
            if (r >= 0 && r <= 6 && c >= 0 && c <= 6) {
                if (r == 0 || r == 6 || c == 0 || c == 6) {
                    dark = 1;
                } else if (r >= 2 && r <= 4 && c >= 2 && c <= 4) {
                    dark = 1;
                }
            }
            set_function(modules, function, size, row + r, column + c, dark);
        }
    }
}

static void draw_alignment(int8_t *modules, uint8_t *function, int size, int row, int column)
{
    for (int r = -2; r <= 2; r++) {
        for (int c = -2; c <= 2; c++) {
            int dark = (r == -2 || r == 2 || c == -2 || c == 2 || (r == 0 && c == 0));
            set_function(modules, function, size, row + r, column + c, dark);
        }
    }
}

static void draw_format(int8_t *modules, int size, int mask)
{
    /* Error correction level M is 0b00. */
    int data = mask;
    int remainder = bch_remainder(data << 10, 0x537, 10);
    int bits = ((data << 10) | remainder) ^ 0x5412;

    /* First copy: the vertical strip in column 8, then row 8 to the left. */
    for (int i = 0; i < 15; i++) {
        int bit = (bits >> i) & 1;

        if (i <= 5) {
            modules[i * size + 8] = (int8_t)bit;
        } else if (i == 6) {
            modules[7 * size + 8] = (int8_t)bit;
        } else if (i == 7) {
            modules[8 * size + 8] = (int8_t)bit;
        } else if (i == 8) {
            modules[8 * size + 7] = (int8_t)bit;
        } else {
            modules[8 * size + (14 - i)] = (int8_t)bit;
        }

        if (i < 8) {
            modules[8 * size + (size - 1 - i)] = (int8_t)bit;
        } else {
            modules[(size - 15 + i) * size + 8] = (int8_t)bit;
        }
    }

    modules[(size - 8) * size + 8] = 1;
}

static void draw_version(int8_t *modules, int size, int version)
{
    int remainder = bch_remainder(version << 12, 0x1F25, 12);
    int bits = (version << 12) | remainder;

    for (int i = 0; i < 18; i++) {
        int bit = (bits >> i) & 1;
        modules[(size - 11 + (i % 3)) * size + (i / 3)] = (int8_t)bit;
        modules[(i / 3) * size + (size - 11 + (i % 3))] = (int8_t)bit;
    }
}

static int mask_bit(int mask, int row, int column)
{
    switch (mask) {
        case 0:
            return ((row + column) % 2) == 0;
        case 1:
            return (row % 2) == 0;
        case 2:
            return (column % 3) == 0;
        case 3:
            return ((row + column) % 3) == 0;
        case 4:
            return ((row / 2 + column / 3) % 2) == 0;
        case 5:
            return (((row * column) % 2) + ((row * column) % 3)) == 0;
        case 6:
            return ((((row * column) % 2) + ((row * column) % 3)) % 2) == 0;
        default:
            return ((((row + column) % 2) + ((row * column) % 3)) % 2) == 0;
    }
}

static int penalty_score(const int8_t *modules, int size)
{
    int score = 0;
    int total = size * size;

    /* Rule 1: runs of five or more modules of the same colour. */
    for (int row = 0; row < size; row++) {
        int run = 1;
        for (int column = 1; column < size; column++) {
            if (modules[row * size + column] == modules[row * size + column - 1]) {
                run++;
            } else {
                if (run >= 5) {
                    score += 3 + (run - 5);
                }
                run = 1;
            }
        }
        if (run >= 5) {
            score += 3 + (run - 5);
        }
    }
    for (int column = 0; column < size; column++) {
        int run = 1;
        for (int row = 1; row < size; row++) {
            if (modules[row * size + column] == modules[(row - 1) * size + column]) {
                run++;
            } else {
                if (run >= 5) {
                    score += 3 + (run - 5);
                }
                run = 1;
            }
        }
        if (run >= 5) {
            score += 3 + (run - 5);
        }
    }

    /* Rule 2: 2x2 blocks of the same colour. */
    for (int row = 0; row < size - 1; row++) {
        for (int column = 0; column < size - 1; column++) {
            int8_t value = modules[row * size + column];
            if (modules[row * size + column + 1] == value &&
                modules[(row + 1) * size + column] == value &&
                modules[(row + 1) * size + column + 1] == value) {
                score += 3;
            }
        }
    }

    /* Rule 3: finder-like 1011101 patterns with four light modules. */
    static const int pattern1[11] = {1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0};
    static const int pattern2[11] = {0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1};

    for (int row = 0; row < size; row++) {
        for (int column = 0; column <= size - 11; column++) {
            int match1 = 1;
            int match2 = 1;
            for (int k = 0; k < 11; k++) {
                int value = modules[row * size + column + k];
                if (value != pattern1[k]) {
                    match1 = 0;
                }
                if (value != pattern2[k]) {
                    match2 = 0;
                }
            }
            if (match1) {
                score += 40;
            }
            if (match2) {
                score += 40;
            }
        }
    }
    for (int column = 0; column < size; column++) {
        for (int row = 0; row <= size - 11; row++) {
            int match1 = 1;
            int match2 = 1;
            for (int k = 0; k < 11; k++) {
                int value = modules[(row + k) * size + column];
                if (value != pattern1[k]) {
                    match1 = 0;
                }
                if (value != pattern2[k]) {
                    match2 = 0;
                }
            }
            if (match1) {
                score += 40;
            }
            if (match2) {
                score += 40;
            }
        }
    }

    /* Rule 4: balance of dark and light modules. */
    int dark = 0;
    for (int i = 0; i < total; i++) {
        dark += modules[i] ? 1 : 0;
    }
    int percent = (dark * 100) / total;
    int deviation = percent > 50 ? percent - 50 : 50 - percent;
    score += 10 * (deviation / 5);

    return score;
}

int pg_qr_encode_mask(const unsigned char *data, int length, int forcedMask, PGQRCode *out)
{
    if (out == NULL) {
        return 0;
    }
    out->size = 0;
    out->modules = NULL;

    if (data == NULL && length > 0) {
        return 0;
    }
    if (length < 0) {
        return 0;
    }
    if (forcedMask < -1 || forcedMask > 7) {
        return 0;
    }

    gf_init();

    int version = 0;
    for (int candidate = 1; candidate <= QR_MAX_VERSION; candidate++) {
        if (capacity_bytes(candidate) >= length) {
            version = candidate;
            break;
        }
    }
    if (version == 0) {
        return 0;
    }

    int totalCodewords = kTotalCodewords[version];
    uint8_t *codewords = (uint8_t *)calloc((size_t)totalCodewords, 1);
    if (codewords == NULL) {
        return 0;
    }
    if (!build_codewords(data, length, version, codewords, totalCodewords)) {
        free(codewords);
        return 0;
    }

    int size = 17 + 4 * version;
    int8_t *modules = (int8_t *)malloc((size_t)(size * size));
    uint8_t *function = (uint8_t *)calloc((size_t)(size * size), 1);
    if (modules == NULL || function == NULL) {
        free(codewords);
        free(modules);
        free(function);
        return 0;
    }
    memset(modules, -1, (size_t)(size * size));

    draw_finder(modules, function, size, 0, 0);
    draw_finder(modules, function, size, 0, size - 7);
    draw_finder(modules, function, size, size - 7, 0);

    for (int i = 8; i <= size - 9; i++) {
        int dark = (i % 2) == 0;
        set_function(modules, function, size, 6, i, dark);
        set_function(modules, function, size, i, 6, dark);
    }

    for (int i = 0; i < kAlignmentCount[version]; i++) {
        for (int j = 0; j < kAlignmentCount[version]; j++) {
            int row = kAlignmentPositions[version][i];
            int column = kAlignmentPositions[version][j];
            if ((row == 6 && column == 6) ||
                (row == 6 && column == size - 7) ||
                (row == size - 7 && column == 6)) {
                continue;
            }
            draw_alignment(modules, function, size, row, column);
        }
    }

    /* Reserve the format information areas. */
    for (int i = 0; i <= 8; i++) {
        if (i != 6) {
            function[8 * size + i] = 1;
            function[i * size + 8] = 1;
        }
    }
    for (int i = 0; i < 8; i++) {
        function[(size - 1 - i) * size + 8] = 1;
        function[8 * size + (size - 1 - i)] = 1;
    }

    if (version >= 7) {
        for (int i = 0; i < 18; i++) {
            function[(size - 11 + (i % 3)) * size + (i / 3)] = 1;
            function[(i / 3) * size + (size - 11 + (i % 3))] = 1;
        }
    }

    /* Place the data bits in the zig-zag pattern. */
    int bit = 0;
    int totalDataBits = totalCodewords * 8;
    for (int right = size - 1; right >= 1; right -= 2) {
        if (right == 6) {
            right = 5;
        }
        for (int vertical = 0; vertical < size; vertical++) {
            for (int j = 0; j < 2; j++) {
                int column = right - j;
                int upward = ((right + 1) & 2) == 0;
                int row = upward ? (size - 1 - vertical) : vertical;
                if (function[row * size + column]) {
                    continue;
                }
                int dark = 0;
                if (bit < totalDataBits) {
                    dark = (codewords[bit >> 3] >> (7 - (bit & 7))) & 1;
                    bit++;
                }
                modules[row * size + column] = (int8_t)dark;
            }
        }
    }

    int8_t *candidate = (int8_t *)malloc((size_t)(size * size));
    int8_t *best = (int8_t *)malloc((size_t)(size * size));
    if (candidate == NULL || best == NULL) {
        free(codewords);
        free(modules);
        free(function);
        free(candidate);
        free(best);
        return 0;
    }

    int bestMask = -1;
    int bestScore = 0;

    for (int mask = 0; mask < 8; mask++) {
        if (forcedMask >= 0 && mask != forcedMask) {
            continue;
        }

        memcpy(candidate, modules, (size_t)(size * size));
        for (int row = 0; row < size; row++) {
            for (int column = 0; column < size; column++) {
                if (function[row * size + column]) {
                    continue;
                }
                if (mask_bit(mask, row, column)) {
                    candidate[row * size + column] ^= 1;
                }
            }
        }
        draw_format(candidate, size, mask);
        if (version >= 7) {
            draw_version(candidate, size, version);
        }

        int score = penalty_score(candidate, size);
        if (bestMask < 0 || score < bestScore) {
            bestMask = mask;
            bestScore = score;
            memcpy(best, candidate, (size_t)(size * size));
        }
    }

    free(codewords);
    free(modules);
    free(function);
    free(candidate);

    if (bestMask < 0) {
        free(best);
        return 0;
    }

    unsigned char *output = (unsigned char *)malloc((size_t)(size * size));
    if (output == NULL) {
        free(best);
        return 0;
    }
    for (int i = 0; i < size * size; i++) {
        output[i] = best[i] ? 1 : 0;
    }
    free(best);

    out->size = size;
    out->modules = output;
    return 1;
}

int pg_qr_encode(const unsigned char *data, int length, PGQRCode *out)
{
    return pg_qr_encode_mask(data, length, -1, out);
}

void pg_qr_free(PGQRCode *code)
{
    if (code == NULL) {
        return;
    }
    free(code->modules);
    code->modules = NULL;
    code->size = 0;
}

#ifdef PG_QR_TEST
int pg_qr_debug_codewords(const unsigned char *data, int length, int version,
                          unsigned char *output, int capacity)
{
    gf_init();
    if (version < 1 || version > QR_MAX_VERSION) {
        return 0;
    }
    if (!build_codewords(data, length, version, output, capacity)) {
        return 0;
    }
    return kTotalCodewords[version];
}
#endif
