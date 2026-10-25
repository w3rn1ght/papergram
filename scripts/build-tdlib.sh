#!/usr/bin/env bash
#
# Builds a static TDLib (tdjson) for iOS arm64 and prepares an include/lib
# directory that Theos can link against.
#
# Environment:
#   TDLIB_VERSION    TDLib git tag (default: v1.8.0)
#   OPENSSL_VERSION  OpenSSL git tag (default: OpenSSL_1_1_1w)
#   IOS_MIN          deployment target (default: 12.0)
#   TDLIB_ROOT       output prefix (default: ./.tdlib)
#   TDLIB_WORK       build directory (default: ./.tdlib-build)
#   JOBS             parallel jobs (default: number of CPUs)
#
# The output layout is:
#   $TDLIB_ROOT/include/td/telegram/*.h
#   $TDLIB_ROOT/lib/libtdjson_all.a

set -euo pipefail

TDLIB_VERSION="${TDLIB_VERSION:-v1.8.0}"
OPENSSL_VERSION="${OPENSSL_VERSION:-OpenSSL_1_1_1w}"
IOS_MIN="${IOS_MIN:-12.0}"
TDLIB_ROOT="${TDLIB_ROOT:-$PWD/.tdlib}"
TDLIB_WORK="${TDLIB_WORK:-$PWD/.tdlib-build}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 3)}"

TD_SRC="$TDLIB_WORK/td"
OPENSSL_SRC="$TDLIB_WORK/openssl-src"
OPENSSL_PREFIX="$TDLIB_WORK/openssl-ios"
NATIVE_BUILD="$TDLIB_WORK/native-build"
IOS_BUILD="$TDLIB_WORK/ios-build"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

log() {
    echo "==> $*"
}

if [ -f "$TDLIB_ROOT/lib/libtdjson_all.a" ]; then
    log "TDLib is already built at $TDLIB_ROOT"
    exit 0
fi

mkdir -p "$TDLIB_ROOT/lib" "$TDLIB_ROOT/include/td/telegram" "$TDLIB_WORK"

if [ ! -d "$TD_SRC/.git" ]; then
    log "Cloning TDLib $TDLIB_VERSION"
    git clone --recursive --depth 1 --branch "$TDLIB_VERSION" \
        https://github.com/tdlib/td.git "$TD_SRC"
fi

# TDLib v1.8.0 ships a toolchain file that still uses exec_program(), which
# CMake 4 rejects (CMP0153). The two calls are pure information queries, so
# replacing them with execute_process() preserves the behaviour.
log "Patching iOS.cmake for CMake 4 compatibility"
python3 - "$TD_SRC/CMake/iOS.cmake" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    text = handle.read()

replacements = {
    "exec_program(uname ARGS -r OUTPUT_VARIABLE CMAKE_HOST_SYSTEM_VERSION)":
        "execute_process(COMMAND uname -r OUTPUT_VARIABLE CMAKE_HOST_SYSTEM_VERSION "
        "OUTPUT_STRIP_TRAILING_WHITESPACE)",
    "exec_program(/usr/bin/xcode-select ARGS -print-path OUTPUT_VARIABLE CMAKE_XCODE_DEVELOPER_DIR)":
        "execute_process(COMMAND /usr/bin/xcode-select -print-path "
        "OUTPUT_VARIABLE CMAKE_XCODE_DEVELOPER_DIR OUTPUT_STRIP_TRAILING_WHITESPACE)",
}

for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)

with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
PY

# ---------------------------------------------------------------------------
# 1. Generate the TL source files on the host. The iOS build is a
#    cross-compilation and therefore cannot run the generators itself.
# ---------------------------------------------------------------------------
log "Generating TL sources (host build)"
cmake -S "$TD_SRC" -B "$NATIVE_BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build "$NATIVE_BUILD" -j"$JOBS" --target prepare_cross_compiling

# ---------------------------------------------------------------------------
# 2. Build OpenSSL for iOS arm64. Only libcrypto is needed by TDLib, but the
#    static libssl is built as well because it costs almost nothing.
# ---------------------------------------------------------------------------
if [ ! -f "$OPENSSL_PREFIX/lib/libcrypto.a" ]; then
    if [ ! -d "$OPENSSL_SRC/.git" ]; then
        log "Cloning OpenSSL $OPENSSL_VERSION"
        git clone --depth 1 --branch "$OPENSSL_VERSION" \
            https://github.com/openssl/openssl "$OPENSSL_SRC"
    fi

    log "Building OpenSSL for iOS arm64"
    export CROSS_COMPILE="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/"
    export CROSS_TOP="$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer"
    export CROSS_SDK="iPhoneOS.sdk"

    (
        cd "$OPENSSL_SRC"
        ./Configure ios64-cross no-shared no-tests \
            --prefix="$OPENSSL_PREFIX" \
            -mios-version-min="$IOS_MIN"
        make -j"$JOBS" build_libs
        make install_sw
    )
fi

# ---------------------------------------------------------------------------
# 3. Cross-compile TDLib for iOS arm64.
# ---------------------------------------------------------------------------
log "Configuring TDLib for iOS arm64 (deployment target $IOS_MIN)"
cmake -S "$TD_SRC" -B "$IOS_BUILD" \
    -DCMAKE_TOOLCHAIN_FILE="$TD_SRC/CMake/iOS.cmake" \
    -DCMAKE_MAKE_PROGRAM="$(xcrun --find make)" \
    -DIOS_PLATFORM=OS \
    -DIOS_ARCH=arm64 \
    -DIOS_DEPLOYMENT_TARGET="$IOS_MIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DOPENSSL_FOUND=1 \
    -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_PREFIX/lib/libcrypto.a" \
    -DOPENSSL_SSL_LIBRARY="$OPENSSL_PREFIX/lib/libssl.a" \
    -DOPENSSL_INCLUDE_DIR="$OPENSSL_PREFIX/include" \
    -DOPENSSL_LIBRARIES="$OPENSSL_PREFIX/lib/libcrypto.a;$OPENSSL_PREFIX/lib/libssl.a" \
    -DCMAKE_INSTALL_PREFIX="$TDLIB_ROOT"

log "Building TDLib (this takes a while)"
cmake --build "$IOS_BUILD" -j"$JOBS" --target tdjson_static

# ---------------------------------------------------------------------------
# 4. Merge every static library into one archive so the app only has to link
#    a single file, regardless of internal target layout.
# ---------------------------------------------------------------------------
log "Merging static libraries"
ARCHIVES=$(find "$IOS_BUILD" -name '*.a' ! -name 'libtdjson_all.a' ! -path '*/CMakeFiles/*' | sort)
if [ -z "$ARCHIVES" ]; then
    echo "No static libraries were produced by the TDLib build" >&2
    exit 1
fi
# shellcheck disable=SC2086
libtool -static -o "$TDLIB_ROOT/lib/libtdjson_all.a" $ARCHIVES \
    "$OPENSSL_PREFIX/lib/libcrypto.a" \
    "$OPENSSL_PREFIX/lib/libssl.a"

log "Copying headers"
cp "$TD_SRC/td/telegram/td_json_client.h" "$TDLIB_ROOT/include/td/telegram/"
cp "$TD_SRC/td/telegram/td_log.h" "$TDLIB_ROOT/include/td/telegram/"
if [ -f "$IOS_BUILD/td/telegram/tdjson_export.h" ]; then
    cp "$IOS_BUILD/td/telegram/tdjson_export.h" "$TDLIB_ROOT/include/td/telegram/"
fi

log "Done: $TDLIB_ROOT/lib/libtdjson_all.a"
