include theos/makefiles/common.mk

TWEAK_NAME = mcast
mcast_FILES = /mnt/d/codes/mcast/Tweak.xm

mcast_FILES += /mnt/d/codes/mcast/CyDWebServer/CyDWebServer.m /mnt/d/codes/mcast/CyDWebServer/CyDWebServerConnection.m /mnt/d/codes/mcast/CyDWebServer/CyDWebServerDataResponse.m 
mcast_FILES += /mnt/d/codes/mcast/CyDWebServer/CyDWebServerFileRequest.m /mnt/d/codes/mcast/CyDWebServer/CyDWebServerFileResponse.m /mnt/d/codes/mcast/CyDWebServer/CyDWebServerFunctions.m 
mcast_FILES += /mnt/d/codes/mcast/CyDWebServer/CyDWebServerRequest.m /mnt/d/codes/mcast/CyDWebServer/CyDWebServerResponse.m /mnt/d/codes/mcast/CyDWebServer/CyDWebServerStreamedResponse.m 
mcast_FILES += /mnt/d/codes/mcast/CyDWebServer/CyDWebServerURLEncodedFormRequest.m /mnt/d/codes/mcast/CyDWebServer/CyDWebServerMultiPartFormRequest.m 
mcast_FILES += /mnt/d/codes/mcast/CyDWebServer/CyDWebServerDataRequest.m /mnt/d/codes/mcast/CyDWebServer/CyDWebServerErrorResponse.m
mcast_FILES += /mnt/d/codes/mcast/CyDWebServer/CyDWebUploader.m

mcast_FRAMEWORKS = CydiaSubstrate Foundation UIKit CoreGraphics Security CFNetwork SystemConfiguration MobileCoreServices NetworkExtension
mcast_CFLAGS = -fno-objc-arc
mcast_LDFLAGS = -Wl,-segalign,4000 -lz

mcast_ARCHS = armv7 arm64
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk
	