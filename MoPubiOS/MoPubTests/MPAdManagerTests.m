#import <GHUnitIOS/GHUnit.h>
#import <OCMock/OCMock.h>

#import "MPAdManager.h"
#import "MPAdView.h"
#import "MPIAdAdapter.h"
#import "MPStore.h"
#import <objc/runtime.h>

@interface MPAdManagerTests : GHTestCase {
	MPAdView *testAdView;
	id mockConnect;
	id mockResponse;
	id mockWebview;
	NSMutableDictionary *headerFields;
}
@end

@implementation MPAdManagerTests

// Run before each test method
- (void)setUp { }

// Run after each test method
- (void)tearDown { }

// Run before the tests are run for this class
- (void)setUpClass {
	testAdView = [[MPAdView alloc] initWithAdUnitId:@"(adunitid)" size:CGSizeZero];
	mockConnect = [OCMockObject niceMockForClass:[NSURLConnection class]];
	mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];
	mockWebview = [OCMockObject niceMockForClass:[UIWebView class]];
	headerFields = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
					@"http://www.clickurl.com", kClickthroughHeaderKey,
					@"http://www.intercepturl.com", kLaunchpageHeaderKey,
					@"http://www.failurl.com", kFailUrlHeaderKey,
					@"http://www.imptracker.com", kImpressionTrackerHeaderKey,
					@"1", kInterceptLinksHeaderKey,
					@"1", kScrollableHeaderKey,
					@"", kWidthHeaderKey,
					@"", kHeightHeaderKey,
					@"20", kRefreshTimeHeaderKey,
					@"1", kAnimationHeaderKey,
					@"network_type", kNetworkTypeHeaderKey,
					@"ad_type", kAdTypeHeaderKey,
					nil];
}

- (void)tearDownClass {
}

- (void)testConnectionGeneration {
	testAdView.keywords = @"(keywords)";
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	NSString *testURL = [NSString stringWithFormat:@"http://ads.mopub.com/m/ad?v=4&udid=%@&q=(keywords)&id=(adunitid)&o=(orientation)&sc=(scalefactor)&z=(timezone)&ll=(location)",  
						 [[UIDevice currentDevice] hashedMoPubUDID]];

	[[[mockManager stub] andReturn:@"&o=(orientation)"] orientationQueryStringComponent];
	[[[mockManager stub] andReturn:@"&sc=(scalefactor)"] scaleFactorQueryStringComponent];
	[[[mockManager stub] andReturn:@"&z=(timezone)"] timeZoneQueryStringComponent];
	[[[mockManager stub] andReturn:@"&ll=(location)"] locationQueryStringComponent];
	
	[mockManager loadAdWithURL:nil];
	
	GHAssertEqualObjects(testURL, manager.URL.absoluteString, @"Incorrect URL generated");
}

-(void)testConnectionDelegate {	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
				
	[[mockManager expect] connection:mockConnect didFailWithError:OCMOCK_ANY];
	[[mockConnect expect] cancel];
	
	int code = 500;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	//[[[mockResponse expect] andReturn:OCMOCK_VALUE(yes)] isKindOfClass:[NSHTTPURLResponse class]];
	 
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	[mockManager verify];
	[mockConnect verify];
}

-(void)testHeaderConfiguration {
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
		
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	[mockManager connection:nil didReceiveResponse: mockResponse];

	GHAssertEqualObjects([headerFields objectForKey:kClickthroughHeaderKey], 
						 manager.clickURL.absoluteString, 
						 @"Click URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kLaunchpageHeaderKey], 
						 manager.interceptURL.absoluteString, 
						 @"Intercept URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kFailUrlHeaderKey], 
						 manager.failURL.absoluteString, 
						 @"Fail URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kImpressionTrackerHeaderKey], 
						 manager.impTrackerURL.absoluteString, 
						 @"Impression Tracker URLs are not equal");
	GHAssertEquals([[headerFields objectForKey:kInterceptLinksHeaderKey] boolValue], 
				   manager.adView.shouldInterceptLinks, 
				   @"shouldInterceptLinks are not equal");
	GHAssertEquals([[headerFields objectForKey:kScrollableHeaderKey] boolValue], 
				   manager.adView.scrollable, 
				   @"Scrollability is not equal");
	GHAssertEquals([[headerFields objectForKey:kWidthHeaderKey] floatValue], 
				   manager.adView.creativeSize.width, 
				   @"Creative widths are not equal");
	GHAssertEquals([[headerFields objectForKey:kHeightHeaderKey] floatValue],
				   manager.adView.creativeSize.height, 
				   @"Creative heights are not equal");
	GHAssertEquals([[headerFields objectForKey:kAnimationHeaderKey] intValue], 
				   manager.adView.animationType, 
				   @"Animation types are not equal");
	//TODO: Ignore networktypeheader
	//TODO: Ignoring adtypeheader
		
	[mockManager verify];
	[mockResponse verify];
}

- (void)testHeaderInitialization {
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
		
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	[mockManager connection:nil didReceiveResponse:mockResponse];

	GHAssertEquals(manager.adView.creativeSize, 
				   manager.adView.originalSize, 
				   @"Creative size should be equal to original size, since no size headers were passed.");
	GHAssertNotNil(manager.autorefreshTimer, 
				   @"Autorefresh timer should not be nil.");
		
	[mockManager verify];
}

-(void)testNilOrHTMLAdapterInitialization {
	[headerFields setValue:@"html" forKey:kAdTypeHeaderKey]; 

	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	[[mockManager expect] replaceCurrentAdapterWithAdapter:nil];
	[mockManager connection:nil didReceiveResponse:mockResponse];

	[mockManager verify];
}

-(void)testClearAdapterInitialization {
	[headerFields setValue:@"clear" forKey:kAdTypeHeaderKey]; 

	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	id mockAdView = [OCMockObject partialMockForObject:testAdView];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
		
	[[mockManager expect] replaceCurrentAdapterWithAdapter:nil];

	[[mockAdView expect] backFillWithNothing];
	[[mockManager expect] scheduleAutorefreshTimer];
	[[mockConnect expect] cancel];
	
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	
	GHAssertFalse(manager.isLoading, 
				  @"isLoading value should be false.");
	[mockManager verify];
	[mockConnect verify];
}

-(void)testMissingAdapterInitialization {
	[headerFields setValue:@"error" forKey:kAdTypeHeaderKey]; 

	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
		
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
		
	[[mockManager expect] replaceCurrentAdapterWithAdapter:nil];
	[[mockConnect expect] cancel];
	[[mockManager expect] loadAdWithURL:[NSURL URLWithString:@"http://www.failurl.com"]];
	
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	
	GHAssertFalse(manager.isLoading, 
				  @"isLoading value should be false.");
	[mockManager verify];
	[mockConnect verify];
}	

-(void)testAllOtherAdapterInitialization {
	[headerFields setValue:@"iAd" forKey:kAdTypeHeaderKey]; 
	
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	id mockView = [OCMockObject partialMockForObject:testAdView];
	
	[[[mockManager expect] andForwardToRealObject] replaceCurrentAdapterWithAdapter:[OCMArg any]];
	[[mockConnect expect] cancel];
	//TODO: Figure out how to test for certain calls
	//[[[mockManager expect] andForwardToRealObject] adapterDidFinishLoadingAd:[OCMArg any] shouldTrackImpression:NO];
	//[[mockView expect] setAdContentView:[OCMArg any]];
	
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	
	[mockManager verify];
	[mockConnect verify];
	[mockView verify];
}

-(void)testConnectionDidFail {
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	id mockView = [OCMockObject partialMockForObject:testAdView];
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:mockView];
	id mockManager = [OCMockObject partialMockForObject:manager];

	[[mockManager expect] scheduleAutorefreshTimer];
	[[mockView expect] backFillWithNothing];
	
	[mockManager connection:mockConnect didFailWithError:nil];
	
	GHAssertFalse(manager.isLoading, 
				  @"isLoading value should be false.");
	GHAssertNotNil(manager.autorefreshTimer, 
				   @"Autorefresh timer should not be nil.");
	[mockManager verify];
}

-(void)testConnectionDidFinishLoading {	
	id mockView = [OCMockObject partialMockForObject:testAdView];
	testAdView.creativeSize = CGSizeMake(320, 250);
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:mockView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	unsigned poolSize = manager.webviewPool.count;
	
	[[[mockManager expect] andForwardToRealObject] 
		makeAdWebViewWithFrame:(CGRect){{0, 0}, testAdView.creativeSize}];

	[mockManager connectionDidFinishLoading:mockConnect];
	
	NSEnumerator *enumerator = [manager.webviewPool objectEnumerator];
	UIWebView *webview;
	while ((webview = [enumerator nextObject])) {
		GHAssertEquals(webview.frame.size, 
					   testAdView.creativeSize, 
					   @"Webview size does not match creative size");
	}
	
	GHAssertEquals(manager.webviewPool.count, 
				   poolSize + 1, 
				   @"Webview pool has incorrect count.");
	[mockManager verify];
}

-(void)testConnectionDidReceiveData {	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	NSMutableData *newData = [[NSMutableData alloc] initWithLength:4];
	id mockData = [OCMockObject mockForClass:[NSMutableData class]];
	manager.data = mockData;
	
	[[mockData expect] appendData:newData];
	[mockManager connection:mockConnect didReceiveData:newData];
	
	[mockData verify];
}
/*
 
 return NO;
 }
 
 // Intercept non-click forms of navigation (e.g. "window.location = ...") if the target URL
 // has the interceptURL prefix. Launch the ad browser.
 if (navigationType == UIWebViewNavigationTypeOther && 
 self.shouldInterceptLinks && 
 self.interceptURL &&
 [[URL absoluteString] hasPrefix:[self.interceptURL absoluteString]])
 {
 [self adLinkClicked:URL];
 return NO;
 }
 
 // Launch the ad browser for all clicks (if shouldInterceptLinks is YES).
 if (navigationType == UIWebViewNavigationTypeLinkClicked && self.shouldInterceptLinks)
 {
 [self adLinkClicked:URL];
 return NO;
 }
 
 // Other stuff (e.g. JavaScript) should load as usual.
 return YES;
*/ 
-(void)testWebviewOnClose {
	id mockView = [OCMockObject partialMockForObject:testAdView];
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:mockView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	[[[mockView expect] andForwardToRealObject] didCloseAd:nil];
	
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
												  [NSURL URLWithString:@"mopub://close"]];
	
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];
	
	[mockView verify];
}

-(void)testWebviewOnFinishLoad {
	id mockDelegate = [OCMockObject mockForProtocol:@protocol(MPAdViewDelegate)];
	testAdView.delegate = mockDelegate;
	id mockView = [OCMockObject partialMockForObject:testAdView];
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:mockView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	BOOL yes = YES;
	[[[mockDelegate stub] andReturnValue:OCMOCK_VALUE(yes)] respondsToSelector:
															@selector(adViewDidLoadAd:)];
	
	[[mockView expect] setAdContentView:mockWebview];
	[[mockManager expect] scheduleAutorefreshTimer];
	[[mockDelegate expect] adViewDidLoadAd:mockView];
	
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
												  [NSURL URLWithString:@"mopub://finishLoad"]];
	
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];	
	
	GHAssertFalse(manager.isLoading, 
				  @"isLoading value should be false.");
	[mockView verify];
	[mockManager verify];
	[mockDelegate verify];
}

-(void)testWebviewOnFailLoad {		
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
		
	[manager.webviewPool addObject:mockWebview];
	unsigned poolSize = manager.webviewPool.count;

	[[mockManager expect] loadAdWithURL:manager.failURL];
	[[mockWebview expect] stopLoading];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
							 [NSURL URLWithString:@"mopub://failLoad"]];
		
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];	
	
	GHAssertFalse(manager.isLoading, 
				  @"isLoading value should be false.");
	GHAssertEquals(manager.webviewPool.count, 
				   poolSize - 1, 
				   @"Webview pool has incorrect count.");
	
	[mockManager verify];
	[mockWebview verify];
}

-(void)testWebviewOnInAppPurchase {
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	id mockStore = [OCMockObject mockForClass:[MPStore class]];
	manager.store = mockStore;
	
	[[mockManager expect] trackClick];
	[[mockStore expect] initiatePurchaseForProductIdentifier:@"(id)" quantity:1];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
							 [NSURL URLWithString:@"mopub://inapp?id=(id)&num=1"]];
	
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];
	
	[mockManager verify];
	[mockStore verify];
}

-(void)testWebviewOnCustomHost {
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	[[mockManager expect] trackClick];
	[[[mockManager expect] andForwardToRealObject] customLinkClickedForSelectorString:@"(fnc)" withDataString:@"(data)"];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
							 [NSURL URLWithString:@"mopub://custom?fnc=(fnc)&data=(data)"]];
	
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];
	
	[mockManager verify];
}

@end