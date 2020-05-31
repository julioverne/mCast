include $(THEOS)/makefiles/common.mk

TWEAK_NAME = mCastSB

mCastSB_FILES = /mnt/d/codes/mcast/mCastSB/mCastSB.xm

mCastSB_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate
mCastSB_CFLAGS = -fobjc-arc -std=c++11
mCastSB_LDFLAGS = -Wl,-segalign,4000

export ARCHS = armv7 arm64 arm64e
mCastSB_ARCHS = armv7 arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk

	
