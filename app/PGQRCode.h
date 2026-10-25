//
//  PGQRCode.h
//  Papergram
//
//  Minimal QR Code encoder (byte mode, error correction level M,
//  versions 1-10). Pure C so it can be unit-tested off-device.
//

#ifndef PGQRCode_h
#define PGQRCode_h

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int size;
    unsigned char *modules; /* row-major, 1 = dark */
} PGQRCode;

/// Encodes `length` bytes. Returns 1 on success, 0 when the data does not fit.
int pg_qr_encode(const unsigned char *data, int length, PGQRCode *out);

/// Same, but with a forced mask (0-7) for tests. Pass -1 for automatic selection.
int pg_qr_encode_mask(const unsigned char *data, int length, int mask, PGQRCode *out);

void pg_qr_free(PGQRCode *code);

#ifdef __cplusplus
}
#endif

#endif /* PGQRCode_h */
