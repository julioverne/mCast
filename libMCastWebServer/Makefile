include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libMCastWebServer

libMCastWebServer_FILES = /mnt/d/codes/mcast/libMCastWebServer/CyDWebServer.m /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerConnection.m /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerDataResponse.m 
libMCastWebServer_FILES += /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerFileRequest.m /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerFileResponse.m /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerFunctions.m 
libMCastWebServer_FILES += /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerRequest.m /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerResponse.m /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerStreamedResponse.m 
libMCastWebServer_FILES += /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerURLEncodedFormRequest.m /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerMultiPartFormRequest.m 
libMCastWebServer_FILES += /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerDataRequest.m /mnt/d/codes/mcast/libMCastWebServer/CyDWebServerErrorResponse.m
libMCastWebServer_FILES += /mnt/d/codes/mcast/libMCastWebServer/CyDWebUploader.m

libMCastWebServer_INSTALL_PATH = /usr/lib

libMCastWebServer_FRAMEWORKS = UIKit Foundation CoreFoundation CFNetwork MobileCoreServices
libMCastWebServer_CFLAGS = -fno-objc-arc -std=c++11
libMCastWebServer_LDFLAGS = -lz -Wl,-segalign,4000

libMCastWebServer_ARCHS = armv7 arm64 arm64e
export ARCHS = armv7 arm64 arm64e

include $(THEOS_MAKE_PATH)/library.mk
	