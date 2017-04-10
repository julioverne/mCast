#import "mCastSB.h"

#import "../libMCastWebServer/CyDWebServer.h"
#import "../libMCastWebServer/CyDWebServerFileResponse.h"
#import "../libMCastWebServer/CyDWebServerDataResponse.h"

#define PORT_SERVER 86
#define kMaxIdleTimeSeconds 1

__strong CyDWebServer* _webServer;
__strong NSTimer *timerCheckMImport;

const char* mCast_running = "/private/var/mobile/Media/mcast_running";

@interface SpringBoard : NSObject
- (void)mCastAllocServer;
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
    %orig;
	unlink(mCast_running);
	if(!timerCheckMImport) {
		timerCheckMImport = [NSTimer scheduledTimerWithTimeInterval:kMaxIdleTimeSeconds target:self selector:@selector(mCastChecker) userInfo:nil repeats:YES];
	}
}
%new
- (void)mCastAllocServer
{
	if(_webServer) {
		return;
	}
	dlopen("/usr/lib/libMCastWebServer.dylib", RTLD_LAZY | RTLD_GLOBAL);
	_webServer = [[objc_getClass("CyDWebServer") alloc] init];
	[_webServer addDefaultHandlerForMethod:@"GET" requestClass:objc_getClass("CyDWebServerRequest") processBlock:^CyDWebServerResponse *(CyDWebServerRequest* request) {
		NSURL* url = request.URL;
		NSDictionary* cachedUrls = [[NSDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Media/mCastCache.plist"]?:@{};
		if(NSString * urlFromMD5St = cachedUrls[[url lastPathComponent]]) {
			if(NSURL* urlFromMD5 = [NSURL URLWithString:urlFromMD5St]) {
				if([urlFromMD5 isFileURL]) {
					NSString* fileR = [urlFromMD5 path];
					if(fileR && [[NSFileManager defaultManager] fileExistsAtPath:fileR]) {
						return [objc_getClass("CyDWebServerFileResponse") responseWithFile:fileR byteRange:request.byteRange];
					}
				} else {
					return [objc_getClass("CyDWebServerResponse") responseWithRedirect:urlFromMD5 permanent:NO];
				}
			}
		}
		return [objc_getClass("CyDWebServerDataResponse") responseWithData:[NSData data] contentType:@"data"];
	}];
}
%new
- (void)mCastChecker
{
	@autoreleasepool {
		if(access(mCast_running, F_OK) == 0) {
			if(!_webServer) {
				[self mCastAllocServer];
			}
			if(_webServer != nil && !_webServer.running) {
				[_webServer startWithPort:PORT_SERVER bonjourName:nil];
			}			
		} else {
			if(_webServer != nil && _webServer.running) {
				[_webServer stop];
			}
		}
	}
}
%end


static void lockScreenState(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		unlink(mCast_running);
	}
}

__attribute__((constructor)) static void initialize_mimportCenter()
{
	@autoreleasepool {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, lockScreenState, CFSTR("com.apple.springboard.lockstate"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
		unlink(mCast_running);
	}
}


