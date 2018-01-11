#import <dlfcn.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <substrate.h>
#import <CommonCrypto/CommonCrypto.h>

#define NSLogn(...)

static NSString* md5String(NSString* stringSt) 
{
	const char* str = [stringSt UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5(str, strlen(str), result);
	NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
	for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
		[ret appendFormat:@"%02x",result[i]];
	}
	return ret;
}



enum {
  closeConnection               = 0,
  stopMedia                     = 1, 
  playMedia                     = 2,
  pauseMedia                    = 3,
  connectConnection             = 4,
};



#import <Security/Security.h>
#include "ioSock.c"

#include "ScanLAN.m"
#include "SimplePing.m"
#include "SimplePingHelper.m"

static NSString* serverURLWithURL(NSURL* mediaURL)
{
	NSMutableDictionary* cachedUrls = [[[NSDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Media/mCastCache.plist"]?:@{} mutableCopy];
	NSString* nowPlayingSt = [NSString stringWithFormat:@"%@", [mediaURL absoluteString]];
	NSString* urlMediaMD5 = md5String(nowPlayingSt);
	cachedUrls[urlMediaMD5] = nowPlayingSt;
	[cachedUrls writeToFile:@"/private/var/mobile/Media/mCastCache.plist" atomically:YES];
	return [NSString stringWithFormat:@"http://%@:86/%@", [[[ScanLAN alloc] init] localIPAddress], urlMediaMD5];
}

static const char * reqCONNECT ="\x00\x00\x00\x58\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x0A\x72\x65\x63\x65\x69\x76\x65\x72\x2D\x30\x22\x28\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x74\x70\x2E\x63\x6F\x6E\x6E\x65\x63\x74\x69\x6F\x6E\x28\x00\x32\x12""{\"type\":\"CONNECT\"}";
static const char * reqLAUNCH ="\x00\x00\x00\x73\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x0A\x72\x65\x63\x65\x69\x76\x65\x72\x2D\x30\x22\x23\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x72\x65\x63\x65\x69\x76\x65\x72\x28\x00\x32\x32""{\"type\":\"LAUNCH\",\"appId\":\"CC1AD845\",\"requestId\":0}";
static const char * reqGET_STATUS ="\x00\x00\x00\x64\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x0A\x72\x65\x63\x65\x69\x76\x65\x72\x2D\x30\x22\x23\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x72\x65\x63\x65\x69\x76\x65\x72\x28\x00\x32\x23""{\"type\":\"GET_STATUS\",\"requestId\":0}";



static void sendMessage(SSLContextRef context, const char* message, int messageLen, BOOL waitResponse, NSString** session)
{
	if(!context) {
		return;
	}
	size_t processed = 0;
	OSStatus result;
	result = SSLWrite(context, message, messageLen, &processed);
	if(result) {
		printf("Error SSLWrite\n");
		return;
	}	
	if(waitResponse) {
		size_t processedRead = 0;
		char buffer[2000];
		result = SSLRead(context, buffer, 2000, &processedRead);
		if(result) {
			printf("Error SSLRead\n");
			return;
		}
		char *b = buffer;
		if(processedRead > 0) {
			NSString* receivedData = [[[NSString alloc] initWithData:[[NSData alloc] initWithBytes:(const void *)b length:processedRead]?:[NSData data] encoding:NSASCIIStringEncoding] copy];
			NSRegularExpression *regexp_filedowncount = [NSRegularExpression regularExpressionWithPattern:@"com.google.cast.media\"\\}\\],\"sessionId\":\"(.*?)\",\"" options:NSRegularExpressionCaseInsensitive error:NULL];
			NSTextCheckingResult *match_filedowncount = [regexp_filedowncount firstMatchInString:receivedData options:0 range:NSMakeRange(0, receivedData.length)];
			if(match_filedowncount) {
				NSRange  Range_filedowncount = [match_filedowncount rangeAtIndex:1];
				if ([receivedData rangeOfString:@"CC1AD845"].location != NSNotFound) {
					*session = [[receivedData substringWithRange:Range_filedowncount] copy];
				}				
			}
		}
	}
}


static void startConnection(NSString* ipCastSt, SSLContextRef* context)
{
	if(!ipCastSt) {
		return;
	}
	otSocket socket;
	OSStatus result;
	PeerSpec peer;
	
	result = MakeServerConnection(ipCastSt.UTF8String, 8009, &socket, &peer);
	if (result)
	{
		printf("Error creating server connection\n");
		return;
	}
	*context = SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType);
	result = SSLSetIOFuncs(*context, SocketRead, SocketWrite);
	if (result)
	{
		printf("Error setting SSL context callback functions\n");
		return;
	}
	result = SSLSetConnection(*context, socket);
	if (result)
	{
		printf("Error setting the SSL context connection\n");
		return;
	}
	result = SSLSetPeerDomainName(*context, ipCastSt.UTF8String, ipCastSt.length);
	if (result)
	{
		printf("Error setting the server domain name\n");
		return;
	}
	
	SSLSetClientSideAuthenticate(*context, kTryAuthenticate);	
	SSLSetSessionOption(*context, kSSLSessionOptionBreakOnCertRequested, true);
	SSLSetSessionOption(*context, kSSLSessionOptionBreakOnServerAuth, true);
	SSLSetSessionOption(*context, kSSLSessionOptionBreakOnClientAuth, true);
	
	do {result = SSLHandshake(*context);} while(result == errSSLWouldBlock);
}

static int startChromecastMedia(NSString* ipCastSt, NSDictionary* metadata)
{
	@try {
	if(!ipCastSt || !metadata) {
		return 0;
	}
	
	int mediaType = 1;
	if(id mediaTypeID = metadata[@"mediaType"]) {
		mediaType = [mediaTypeID intValue];
	}
	
	NSString* urlMedia = metadata[@"mediaURL"];
	NSString* urlArtMedia = metadata[@"artURL"];
	NSString* titleMedia = metadata[@"titleMedia"];
	NSString* subtitleMedia = metadata[@"subtitleMedia"];
	
	if(urlMedia.length > 82) {
		printf("Error unsupported Buffer URL\n");
		return 0;
	}
	
	SSLContextRef context;
	startConnection(ipCastSt, &context);	
	if(!context) {
		return 0;
	}
	
	sendMessage(context, reqCONNECT, 92, NO, NULL);	
	sendMessage(context, reqLAUNCH, 119, NO, NULL);
	
	NSString* kSessionId = nil;
	int trying = 0;
	do {
		sendMessage(context, reqCONNECT, 92, YES, &kSessionId);
		trying++;
	} while(trying<10 && kSessionId == nil);

	if(!kSessionId) {
		return 0;
	}
	NSMutableData *data = [NSMutableData data];
	[data appendBytes:"\x00\x00\x00\x72\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x24" length:18];
	[data appendBytes:kSessionId.UTF8String length:36];
	[data appendBytes:"\x22\x28\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x74\x70\x2E\x63\x6F\x6E\x6E\x65\x63\x74\x69\x6F\x6E\x28\x00\x32\x12" length:46];
	[data appendBytes:"{\"type\":\"CONNECT\"}" length:18];
	sendMessage(context, (const char*)data.bytes, data.length, NO, NULL);
	
	
	const char* baseURL =  (const char*)(malloc(83)); // max length 82
	memset ((void *)baseURL,'?',82);
	((char*)baseURL)[83] = 0;
	if(urlMedia) {
		urlMedia = [urlMedia stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		urlMedia = [urlMedia stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
		memcpy((void*)baseURL, urlMedia.UTF8String, urlMedia.length);
	}
	
	const char* baseArtURL =  (const char*)(malloc(266)); // max length 265
	memset ((void *)baseArtURL,'?',265);
	((char*)baseArtURL)[266] = 0;
	if(urlArtMedia) {
		urlArtMedia = [urlArtMedia stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		urlArtMedia = [urlArtMedia stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
		memcpy((void*)baseArtURL, urlArtMedia.UTF8String, urlArtMedia.length);
	}
	
	const char* baseTitle =  (const char*)(malloc(162)); // max length 161
	memset ((void *)baseTitle,' ',161);
	((char*)baseTitle)[162] = 0;
	if(titleMedia) {
		titleMedia = [NSString stringWithFormat:@"%@", @{@"":titleMedia}];
		titleMedia = [titleMedia substringToIndex:[titleMedia length]-3];
		titleMedia = [titleMedia substringFromIndex:11];
		if([titleMedia hasPrefix:@"\""] && [titleMedia hasSuffix:@"\""]) {
			titleMedia = [titleMedia substringToIndex:[titleMedia length]-1];
			titleMedia = [titleMedia substringFromIndex:1];
		}
		titleMedia = [titleMedia stringByReplacingOccurrencesOfString: @"\\U" withString:@"\\u"];
		memcpy((void*)baseTitle, titleMedia.UTF8String, titleMedia.length);
	}
	
	const char* baseSubtitle =  (const char*)(malloc(165)); // max length 164
	memset ((void *)baseSubtitle,' ',164);
	((char*)baseSubtitle)[165] = 0;
	if(subtitleMedia) {
		subtitleMedia = [NSString stringWithFormat:@"%@", @{@"":subtitleMedia}];
		subtitleMedia = [subtitleMedia substringToIndex:[subtitleMedia length]-3];
		subtitleMedia = [subtitleMedia substringFromIndex:11];
		if([subtitleMedia hasPrefix:@"\""] && [subtitleMedia hasSuffix:@"\""]) {
			subtitleMedia = [subtitleMedia substringToIndex:[subtitleMedia length]-1];
			subtitleMedia = [subtitleMedia substringFromIndex:1];
		}
		subtitleMedia = [subtitleMedia stringByReplacingOccurrencesOfString: @"\\U" withString:@"\\u"];
		memcpy((void*)baseSubtitle, subtitleMedia.UTF8String, subtitleMedia.length);
	}
	
	data = [NSMutableData data];
	[data appendBytes:"\x00\x00\x03\xEC\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x24" length:18];
	[data appendBytes:kSessionId.UTF8String length:36];
	[data appendBytes:"\x22\x20\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x6D\x65\x64\x69\x61\x28\x00\x32\x93\x07" length:39];
	[data appendBytes:"{\"type\":\"LOAD\",\"media\":{\"metadata\":{\"title\":\"" length:45];
	[data appendBytes:baseTitle length:161];
	[data appendBytes:"\",\"subtitle\":\"" length:14];
	[data appendBytes:baseSubtitle length:164];
	[data appendBytes:"\",\"images\":[{\"url\":\"" length:20];
	[data appendBytes:baseArtURL length:265];
	[data appendBytes:"\",\"width\":600,\"height\":600}],\"metadataType\":0},\"contentId\":\"" length:60];
	[data appendBytes:baseURL length:82];
	[data appendBytes:"\",\"streamType\":\"BUFFERED\",\"contentType\":\"" length:41];
	[data appendBytes:mediaType==0?"image/xxx":mediaType==1?"audio/xxx":"video/xxx" length:9];
	[data appendBytes:"\"},\"autoplay\":1,\"currentTime\":0,\"requestId\":921489134}" length:54];
	
	sendMessage(context, (const char*)data.bytes, data.length, NO, NULL);
	
	SSLClose(context);
	} @catch (NSException* e) {
		
	}
	return 0;
}

static void actionChromecast(NSString* ipCastSt, NSDictionary* info)
{
	@try {
	if(!ipCastSt || !info) {
		return;
	}
	
	int actionType = 0;
	if(id actionTypeID = info[@"actionType"]) {
		actionType = [actionTypeID intValue];
	}
	
	SSLContextRef context;
	startConnection(ipCastSt, &context);
	
	if(!context) {
		return;
	}
	
	sendMessage(context, reqCONNECT, 92, NO, NULL);
	
	NSString* kSessionId = nil;
	int trying = 0;
	do {
		sendMessage(context, reqGET_STATUS, 104, YES, &kSessionId);
		trying++;
	} while(trying<10 && kSessionId == nil);
	
	if(kSessionId) {
		NSMutableData *data = [NSMutableData data];
		[data appendBytes:"\x00\x00\x00\x72\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x24" length:18];
		[data appendBytes:kSessionId.UTF8String length:36];
		[data appendBytes:"\x22\x28\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x74\x70\x2E\x63\x6F\x6E\x6E\x65\x63\x74\x69\x6F\x6E\x28\x00\x32\x12" length:46];
		[data appendBytes:"{\"type\":\"CONNECT\"}" length:18];
		sendMessage(context, (const char*)data.bytes, data.length, NO, NULL);
		if(actionType == closeConnection) {			
			data = [NSMutableData data];
			[data appendBytes:"\x00\x00\x00\x70\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x24" length:18];
			[data appendBytes:kSessionId.UTF8String length:36];
			[data appendBytes:"\x22\x28\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x74\x70\x2E\x63\x6F\x6E\x6E\x65\x63\x74\x69\x6F\x6E\x28\x00\x32\x10" length:46];
			[data appendBytes:"{\"type\":\"CLOSE\"}" length:16];
			sendMessage(context, (const char*)data.bytes, data.length, NO, NULL);
		} else if(actionType == connectConnection) {
			
		} else if(actionType == pauseMedia) {
			data = [NSMutableData data];
			[data appendBytes:"\x00\x00\x00\x8B\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x24" length:18];
			[data appendBytes:kSessionId.UTF8String length:36];
			[data appendBytes:"\x22\x20\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x6D\x65\x64\x69\x61\x28\x00\x32\x33" length:38];
			[data appendBytes:"{\"type\":\"PAUSE\", \"mediaSessionId\":1, \"requestId\":1}" length:51];
			sendMessage(context, (const char*)data.bytes, data.length, NO, NULL);
		} else if(actionType == playMedia) {
			data = [NSMutableData data];
			[data appendBytes:"\x00\x00\x00\x8A\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x24" length:18];
			[data appendBytes:kSessionId.UTF8String length:36];
			[data appendBytes:"\x22\x20\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x6D\x65\x64\x69\x61\x28\x00\x32\x32" length:38];
			[data appendBytes:"{\"type\":\"PLAY\", \"mediaSessionId\":1, \"requestId\":1}" length:50];
			sendMessage(context, (const char*)data.bytes, data.length, NO, NULL);
		} else if(actionType == stopMedia) {
			data = [NSMutableData data];
			[data appendBytes:"\x00\x00\x00\x8A\x08\x00\x12\x08\x73\x65\x6E\x64\x65\x72\x2D\x30\x1A\x24" length:18];
			[data appendBytes:kSessionId.UTF8String length:36];
			[data appendBytes:"\x22\x20\x75\x72\x6E\x3A\x78\x2D\x63\x61\x73\x74\x3A\x63\x6F\x6D\x2E\x67\x6F\x6F\x67\x6C\x65\x2E\x63\x61\x73\x74\x2E\x6D\x65\x64\x69\x61\x28\x00\x32\x32" length:38];
			[data appendBytes:"{\"type\":\"STOP\", \"mediaSessionId\":1, \"requestId\":1}" length:50];
			sendMessage(context, (const char*)data.bytes, data.length, NO, NULL);
		}
	}
	
	SSLClose(context);
	} @catch (NSException* e) {
	}
}

static BOOL isPortOpen(const char* ip, int port)
{
    otSocket socket;
	PeerSpec peer;
	return (MakeServerConnection(ip, port, &socket, &peer) == 0);
}

#import <Foundation/Foundation.h>


@interface UIProgressHUD : UIView
- (void)hide;
- (void)setText:(id)arg1;
- (void)showInView:(id)arg1;
@end

@interface MusicNowPlayingControlsViewController: UIViewController
+ (NSDictionary*)nowPlayingInfo;
@end

@interface mCastSearchServiceViewController : UITableViewController <ScanLANDelegate>

@property(strong, nonatomic) NSMutableDictionary* services;
@property(strong, nonatomic) ScanLAN * lanScanner;
@property(strong, nonatomic) NSTimer* timer;
@property(strong, nonatomic) NSMutableArray *connctedDevices;

+ (mCastSearchServiceViewController*) shared;
@end

@implementation mCastSearchServiceViewController
@synthesize services, lanScanner, timer, connctedDevices;

+ (mCastSearchServiceViewController*) shared
{
	static __strong mCastSearchServiceViewController *mCastSearchServiceC;
	if (!mCastSearchServiceC) {
		mCastSearchServiceC = [[self alloc] init];
	}
	return mCastSearchServiceC;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.services allKeys] count];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (BOOL)isChomecastSelected:(NSDictionary*)dicCast
{
	@autoreleasepool {
		if(NSDictionary* cachedDevice = [[NSDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Media/mCastDevice.plist"]) {
			if(NSString* ipChd = cachedDevice[@"ip"]) {
				if([ipChd isEqualToString:dicCast[@"ip"]]) {
					if(NSString* nameChd = cachedDevice[@"name"]) {
						if([nameChd isEqualToString:dicCast[@"name"]]) {
							return YES;
						}
					}
				}
			}
		}
	}
	return NO;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static __strong NSString *CellIdentifier = @"CellSearchService";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell) {
		cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.imageView.image = nil;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	NSDictionary* castDicRow = [self.services objectForKey:[[self.services allKeys] objectAtIndex:indexPath.row]];
	
	if([self isChomecastSelected:castDicRow]) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	
	cell.textLabel.text = [castDicRow objectForKey:@"name"];
	cell.detailTextLabel.text = [castDicRow objectForKey:@"ip"];
	if(UIImage* cellmg = [castDicRow objectForKey:@"image"]) {
		cell.imageView.image = cellmg;
	}
	
	return cell;
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(NSDictionary*myCast = [self.services objectForKey:[[self.services allKeys] objectAtIndex:indexPath.row]]) {
		if([self isChomecastSelected:myCast]) {
			[@{} writeToFile:@"/private/var/mobile/Media/mCastDevice.plist" atomically:YES];
			__block UIProgressHUD* hud = [[UIProgressHUD alloc] init];
			[hud setText:@"Diconnecting..."];
			[hud showInView:((UIViewController*)self).view];
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				actionChromecast(myCast[@"ip"], @{@"actionType": @(closeConnection)});
				dispatch_async(dispatch_get_main_queue(), ^{
					[hud hide];
					hud = nil;
				});	
			});
		} else {
			NSMutableDictionary* myCastMut = [myCast mutableCopy];
			[myCastMut removeObjectForKey:@"image"];
			[myCastMut writeToFile:@"/private/var/mobile/Media/mCastDevice.plist" atomically:YES];
			__block UIProgressHUD* hud = [[UIProgressHUD alloc] init];
			[hud setText:@"Connecting..."];
			[hud showInView:((UIViewController*)self).view];
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				actionChromecast(myCast[@"ip"], @{@"actionType": @(connectConnection)});
				dispatch_async(dispatch_get_main_queue(), ^{
					[hud hide];
					hud = nil;
				});	
			});
		}
		[self.tableView reloadData];
	}
	return nil;
}
- (void)startScanningLAN
{
	self.title = @"Searching for Chromecast...";
	self.services = [[NSMutableDictionary alloc]init];
	[self.tableView reloadData];
	UIActivityIndicatorView* activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	activityIndicator.frame = CGRectMake(0, 0, 20, 20);
	UIBarButtonItem * barButton = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
	[self navigationItem].rightBarButtonItem = barButton;
    [activityIndicator startAnimating];
	
    [self.lanScanner stopScan];
    self.lanScanner = [[ScanLAN alloc] initWithDelegate:self];
    self.connctedDevices = [[NSMutableArray alloc] init];
    [self.lanScanner startScan];
}
- (void)refreshView:(UIRefreshControl *)refresh
{
	[self startScanningLAN];
	[refresh endRefreshing];
}
- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
    [self startScanningLAN];
}
- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    [self.lanScanner stopScan];
}
- (void)scanLANDidFindNewAdrress:(NSString *)address havingHostName:(NSString *)hostName
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if(address) {
			if(isPortOpen(address.UTF8String, 8009)) {
				[self.services setObject:@{@"ip": address, @"name": hostName?:address,} forKey:address];
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.tableView reloadData];
				});
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
					NSData*data = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@:8008/setup/eureka_info?params=name", address]]];
					NSError *error = nil;
					NSDictionary* response = [NSJSONSerialization JSONObjectWithData:data?:[NSData data] options:0 error:&error];
					if(!error && response) {
						if([response isKindOfClass:[NSDictionary class]]) {
							if(NSString* name = response[@"name"]) {
								if(NSDictionary* adrDic = self.services[address]) {
									NSMutableDictionary* adrDicMut = [adrDic mutableCopy];
									adrDicMut[@"name"] = name;
									[self.services setObject:adrDicMut forKey:address];
									dispatch_async(dispatch_get_main_queue(), ^{
										[self.tableView reloadData];
									});
								}
							}
						}
					}					
				});
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
					UIImage *im = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@:8008/setup/icon.png", address]]]];
					if(im) {
						if(NSDictionary* adrDic = self.services[address]) {
							NSMutableDictionary* adrDicMut = [adrDic mutableCopy];
							adrDicMut[@"image"] = im;
							[self.services setObject:adrDicMut forKey:address];
							dispatch_async(dispatch_get_main_queue(), ^{
								[self.tableView reloadData];
							});
						}
					}
				});
			}
		}	
    });
}
- (void)scanLANDidFinishScanning
{
	self.title = @"Choose Chromecast";
	UIBarButtonItem* refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(startScanningLAN)];
    [self navigationItem].rightBarButtonItem = refresh;
}
@end



@interface mCastPlayerViewController : UITableViewController <ScanLANDelegate>

@property(strong, nonatomic) NSMutableDictionary* services;
@property(strong, nonatomic) NSTimer* timer;
@property(strong, nonatomic) NSMutableArray *connctedDevices;

+ (mCastPlayerViewController*) shared;
@end

@implementation mCastPlayerViewController
@synthesize services, timer, connctedDevices;

+ (mCastPlayerViewController*) shared
{
	static __strong mCastPlayerViewController *mCastSearchServiceC;
	if (!mCastSearchServiceC) {
		mCastSearchServiceC = [[self alloc] initWithStyle:UITableViewStyleGrouped];
	}
	return mCastSearchServiceC;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = @"mCast";
	
	UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closePopUp)];
	[self navigationItem].leftBarButtonItems = @[kBTClose];
	
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
}
- (void)closePopUp
{
	[self dismissModalViewControllerAnimated:YES];
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(section == 2) {
		return 4;
	}
    return 1;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static __strong NSString *CellIdentifier = @"CellSearchService";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell) {
		cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.imageView.image = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if(indexPath.section==0 && indexPath.row==0) {
		cell.textLabel.text = @"Choose Chromecast";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		if(NSDictionary* cachedDevice = [[NSDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Media/mCastDevice.plist"]) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", cachedDevice[@"name"], cachedDevice[@"ip"]];
		}
	}
	
	if(indexPath.section==1 && indexPath.row==0) {
		cell.textLabel.text = @"Start Cast Current Media";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	
	if(indexPath.section==2 && indexPath.row==0) {
		cell.textLabel.text = @"Play";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	if(indexPath.section==2 && indexPath.row==1) {
		cell.textLabel.text = @"Pause";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	if(indexPath.section==2 && indexPath.row==2) {
		cell.textLabel.text = @"Stop";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	if(indexPath.section==2 && indexPath.row==3) {
		cell.textLabel.text = @"Close";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	
	return cell;
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 0) {
		@try {
			[self.navigationController pushViewController:[mCastSearchServiceViewController shared] animated:YES];
		} @catch (NSException * e) {
		}
		return nil;
	}
	__block UIProgressHUD* hud = [[UIProgressHUD alloc] init];
	[hud setText:@"Loading..."];
	[hud showInView:((UIViewController*)self).view];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if(NSDictionary* nowPlayingInfo = [%c(MusicNowPlayingControlsViewController) nowPlayingInfo]) {
			
			NSDictionary* cachedDevice = [[NSDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Media/mCastDevice.plist"];
			if(cachedDevice && cachedDevice[@"ip"]!=nil) {
				if(indexPath.section == 1 && indexPath.row == 0) {
					dispatch_async(dispatch_get_main_queue(), ^{
						[hud setText:@"Starting..."];
					});
					
					NSString* mediaURL = serverURLWithURL(nowPlayingInfo[@"mediaURL"]);
					NSString* artURL = serverURLWithURL(nowPlayingInfo[@"artURL"]);
					
					NSString* subtitleSt = [[nowPlayingInfo[@"artistName"]?:@"" stringByAppendingString:@" – "]stringByAppendingString:nowPlayingInfo[@"albumName"]?:@""];
					
					startChromecastMedia(cachedDevice[@"ip"], @{
						@"mediaURL": mediaURL,
						@"mediaType": nowPlayingInfo[@"mediaType"]?:@(1),
						@"artURL": artURL,
						@"titleMedia": nowPlayingInfo[@"title"]?:@"",
						@"subtitleMedia": subtitleSt.length>3?subtitleSt:@"",
					});
				}
				if(indexPath.section == 2 && indexPath.row == 0) {
					dispatch_async(dispatch_get_main_queue(), ^{
						[hud setText:@"Playing..."];
					});
					actionChromecast(cachedDevice[@"ip"], @{@"actionType": @(playMedia)});
				}
				if(indexPath.section == 2 && indexPath.row == 1) {
					dispatch_async(dispatch_get_main_queue(), ^{
						[hud setText:@"Pause..."];
					});
					actionChromecast(cachedDevice[@"ip"], @{@"actionType": @(pauseMedia)});
				}
				if(indexPath.section == 2 && indexPath.row == 2) {
					dispatch_async(dispatch_get_main_queue(), ^{
						[hud setText:@"Stop..."];
					});
					actionChromecast(cachedDevice[@"ip"], @{@"actionType": @(stopMedia)});
				}
				if(indexPath.section == 2 && indexPath.row == 3) {
					dispatch_async(dispatch_get_main_queue(), ^{
						[hud setText:@"Close..."];
					});
					actionChromecast(cachedDevice[@"ip"], @{@"actionType": @(closeConnection)});
				}
			} else {
				dispatch_async(dispatch_get_main_queue(), ^{
					@try {
						[self.navigationController pushViewController:[mCastSearchServiceViewController shared] animated:YES];
					} @catch (NSException * e) {
					}
				});
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[hud hide];
			hud = nil;
		});
	});	
	return nil;
}
- (void)refreshView:(UIRefreshControl *)refresh
{
	[self.tableView reloadData];
	[refresh endRefreshing];
}
- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}
- (void)viewWillDisappear:(BOOL)animated
{
	[self.tableView reloadData];
	[super viewWillDisappear:animated];
}
@end

@interface NSObject ()
@property(strong, nonatomic) NSObject* artworkView;
@property(strong, nonatomic) NSObject* player;
- (id)currentItem;
@property(strong, nonatomic) NSObject* avItem;
@property(strong, nonatomic) NSObject* asset;
@property(nonatomic, readonly) NSURL* URL;
@property(strong, nonatomic) NSObject* artworkCatalog;
@property(strong, nonatomic) NSObject* bestImageFromDisk;
@property(strong, nonatomic) NSObject* artworkCatalogBackingFileURL;
@property(strong, nonatomic) NSObject* albumName;
@property(strong, nonatomic) NSObject* artistName;
- (int)type;
@end

@interface AVItem : NSObject
- (int)type;
@end


const char* mcast_running = "/private/var/mobile/Media/mcast_running";

static MusicNowPlayingControlsViewController* sharedMusicNowPlayingControlsViewController;
%hook MusicNowPlayingControlsViewController
- (id)init
{
	id ret = %orig;
	sharedMusicNowPlayingControlsViewController = ret;
	return ret;
}
- (void)viewDidAppear:(BOOL)arg1
{
	%orig;
	sharedMusicNowPlayingControlsViewController = self;
	
	UIButton *mCast = nil;
	if(!mCast) {
		mCast = [UIButton buttonWithType:UIButtonTypeRoundedRect];
		[mCast setTitle:@"Chromecast" forState:UIControlStateNormal];
		mCast.titleLabel.adjustsFontSizeToFitWidth = YES;
		mCast.frame = CGRectMake(5, 3, 70, 30);
		[mCast addTarget:self action:@selector(popMCast) forControlEvents:UIControlEventTouchDown];
		mCast.tag = 8654;
	}	
	if(UIView* cV = self.view) {
		if(UIView* rem = [cV viewWithTag:8654]) {
			[rem removeFromSuperview];
		}
		[cV addSubview:mCast];
	}
}
%new
- (void)popMCast
{
	@try {
		
		if (access(mcast_running, F_OK) != 0) {
			if(open(mcast_running, O_CREAT)) {
			}
			usleep(1500000); //wait server start again.
		}
		
		UINavigationController* navCon; 
		if(!navCon) {
			navCon = [[UINavigationController alloc] initWithNavigationBarClass:[UINavigationBar class] toolbarClass:[UIToolbar class]];
		}
		[navCon setViewControllers:@[[mCastPlayerViewController shared]] animated:NO];
		[self presentViewController:navCon animated:YES completion:nil];
	} @catch (NSException * e) {
	}
}
%new
+ (NSDictionary*)nowPlayingInfo
{
	@try {
		NSMutableDictionary* ret = [NSMutableDictionary dictionary];
		if(sharedMusicNowPlayingControlsViewController) {
			if(id artwork = [sharedMusicNowPlayingControlsViewController artworkView]) {
				if(id player = [artwork player]) {
					if(id currentItem = [player currentItem]) {
						if(id albumName = [currentItem albumName]) {
							ret[@"albumName"] = albumName;
						}
						if(id title = [currentItem title]) {
							ret[@"title"] = title;
						}
						if(id artistName = [currentItem artistName]) {
							ret[@"artistName"] = artistName;
						}
						if(AVItem* avItem = (AVItem*)[currentItem avItem]) {
							if(id asset = [avItem asset]) {
								if(id URL = [asset URL]) {
									ret[@"mediaURL"] = URL;
								}
							}
							ret[@"mediaType"] = @([avItem type]);
						}						
						if(id artworkCatalog = [currentItem artworkCatalog]) {
							if(id bestImageFromDisk = [artworkCatalog bestImageFromDisk]) {
								if(id URL = [bestImageFromDisk artworkCatalogBackingFileURL]) {
									ret[@"artURL"] = URL;
								}
							}
						}
					}
				}
			}
		}
		
		return ret;
	} @catch (NSException* e) {
	}
}
%end

__attribute__((constructor)) static void initialize_mcast()
{
	@autoreleasepool {
		%init;
	}
}

__attribute__((destructor)) static void finalize_mcast()
{
	@autoreleasepool {
		unlink(mcast_running);
	}
}