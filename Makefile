TARGET := iphone:clang:latest:12.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := Papergram

# Directory produced by scripts/build-tdlib.sh (or a CI cache).
TDLIB_ROOT ?= $(CURDIR)/.tdlib

Papergram_FILES := $(wildcard app/*.m)
Papergram_FRAMEWORKS := UIKit Foundation CoreGraphics QuartzCore
Papergram_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Iapp -I$(TDLIB_ROOT)/include
Papergram_LDFLAGS := -Wl,-force_load,$(TDLIB_ROOT)/lib/libtdjson_all.a \
	-Wl,-dead_strip -lc++ -lz -framework CoreFoundation
Papergram_INSTALL_PATH := /Applications

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 Papergram || true"
