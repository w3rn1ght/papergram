#!/usr/bin/env python3
"""Verifies app/PGQRCode.c against python-qrcode and zbar.

For every mask the resulting matrix must be identical to the reference
encoder. The automatic mask selection is verified by actually decoding the
generated symbol with zbar.

Dependencies: clang, python-qrcode, pillow, pyzbar (and libzbar).
Usage: python3 tools/verify_qr.py
"""

import subprocess
import sys

import qrcode
from PIL import Image
from pyzbar.pyzbar import decode

CASES = [
    "tg://login?token=A",
    "tg://login?token=AbCdEfGhIjKlMnOpQrStUvWxYz0123456789",
    "tg://login?token=" + "x" * 32,
    "tg://login?token=" + "y" * 60,
    "tg://login?token=" + "z" * 100,
    "Hello, Papergram!",
]


def build_dump():
    subprocess.run(
        ["clang", "-O2", "-std=c11", "-Iapp", "-o", "qr_dump",
         "app/PGQRCode.c", "tools/qr_dump.c"],
        check=True,
    )


def run_dump(lines):
    result = subprocess.run(
        ["./qr_dump"],
        input="\n".join(lines) + "\n",
        capture_output=True,
        text=True,
        check=True,
    )
    blocks = []
    current = None
    for line in result.stdout.splitlines():
        if line.startswith("BEGIN "):
            parts = line.split()
            current = {"size": int(parts[1]), "mask": int(parts[2]), "rows": []}
        elif line == "END":
            blocks.append(current)
            current = None
        elif current is not None:
            current["rows"].append(line)
    return blocks


def reference(payload, mask):
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        mask_pattern=mask,
        border=0,
    )
    qr.add_data(payload)
    qr.make(fit=True)
    return ["".join("1" if cell else "0" for cell in row) for row in qr.get_matrix()]


def decode_matrix(rows, scale=6, border=4):
    count = len(rows)
    total = (count + border * 2) * scale
    image = Image.new("L", (total, total), 255)
    pixels = image.load()
    for row in range(count):
        for column in range(count):
            if rows[row][column] == "1":
                for dy in range(scale):
                    for dx in range(scale):
                        pixels[(column + border) * scale + dx,
                               (row + border) * scale + dy] = 0
    results = decode(image)
    return results[0].data.decode("utf-8") if results else None


def main():
    build_dump()

    requests = []
    expected = []
    for payload in CASES:
        for mask in range(8):
            requests.append(f"{mask}\t{payload}")
            expected.append((payload, mask, reference(payload, mask)))

    blocks = run_dump(requests)
    if len(blocks) != len(expected):
        print(f"block count mismatch: {len(blocks)} != {len(expected)}")
        return 1

    failures = 0
    for block, (payload, mask, rows) in zip(blocks, expected):
        if block is None:
            print(f"FAIL mask={mask} len={len(payload)}: encoder returned nothing")
            failures += 1
            continue
        if block["rows"] != rows:
            print(f"FAIL mask={mask} len={len(payload)}: matrix mismatch")
            failures += 1

    auto_blocks = run_dump([f"-1\t{payload}" for payload in CASES])
    for payload, block in zip(CASES, auto_blocks):
        decoded = decode_matrix(block["rows"]) if block else None
        if decoded != payload:
            print(f"FAIL auto len={len(payload)}: decoded {decoded!r}")
            failures += 1

    if failures == 0:
        print(f"OK: {len(blocks)} matrices match python-qrcode, "
              f"{len(auto_blocks)} symbols decode")
        return 0
    print(f"{failures} failures")
    return 1


if __name__ == "__main__":
    sys.exit(main())
