/*
 * Prints the interleaved data + ECC codewords for a payload and version.
 * Used to debug the encoder against python-qrcode.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int pg_qr_debug_codewords(const unsigned char *data, int length, int version,
                                 unsigned char *output, int capacity);

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s <version> <payload>\n", argv[0]);
        return 1;
    }

    int version = atoi(argv[1]);
    const char *payload = argv[2];
    unsigned char output[4096];
    int length = pg_qr_debug_codewords((const unsigned char *)payload,
                                       (int)strlen(payload), version, output, (int)sizeof(output));
    if (length <= 0) {
        printf("FAIL\n");
        return 1;
    }

    for (int i = 0; i < length; i++) {
        printf("%02x", output[i]);
    }
    printf("\n");
    return 0;
}
