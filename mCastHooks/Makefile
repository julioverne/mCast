include $(THEOS)/makefiles/common.mk

TWEAK_NAME = mcast
mcast_FILES = /mnt/d/codes/mcast/mCastHooks/Tweak.xm


mcast_FRAMEWORKS = CydiaSubstrate Foundation UIKit CoreGraphics Security CFNetwork SystemConfiguration MobileCoreServices
mcast_CFLAGS = -fno-objc-arc
mcast_LDFLAGS = -Wl,-segalign,4000 -lz

mcast_ARCHS = armv7 arm64 arm64e
export ARCHS = armv7 arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk
	