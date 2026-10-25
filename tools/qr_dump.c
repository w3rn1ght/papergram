/*
 * Test harness for the QR encoder. Reads "mask<TAB>payload" lines from stdin
 * and prints the resulting matrices. Used by tools/verify_qr.py.
 */

#include "PGQRCode.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void)
{
    char line[8192];
    while (fgets(line, sizeof(line), stdin) != NULL) {
        char *tab = strchr(line, '\t');
        if (tab == NULL) {
            continue;
        }
        *tab = '\0';

        int mask = atoi(line);
        char *payload = tab + 1;
        size_t length = strlen(payload);
        while (length > 0 && (payload[length - 1] == '\n' || payload[length - 1] == '\r')) {
            payload[--length] = '\0';
        }

        PGQRCode qr;
        if (!pg_qr_encode_mask((const unsigned char *)payload, (int)length, mask, &qr)) {
            printf("FAIL\n");
            continue;
        }

        printf("BEGIN %d %d\n", qr.size, mask);
        for (int row = 0; row < qr.size; row++) {
            for (int column = 0; column < qr.size; column++) {
                putchar(qr.modules[row * qr.size + column] ? '1' : '0');
            }
            putchar('\n');
        }
        printf("END\n");
        pg_qr_free(&qr);
    }
    return 0;
}
