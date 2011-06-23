#import <GHUnitIOS/GHUnit.h>
#import <OCMock/OCMock.h>

#import "MPAdManager.h"
#import "MPAdView.h"
#import "MPBaseAdapter.h"
#import "MPIAdAdapter.h"
#import "MPStore.h"
#import "MPGlobal.h"
#import "MPAdManager+MPAdView+TestsPrivate.h"
#import <objc/runtime.h>

@interface MPAdManagerTests : GHTestCase {
	MPAdView *testAdView;
	id mockManager;
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
	mockManager = [OCMockObject partialMockForObject:testAdView.adManager];
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

-(BOOL)shouldRunOnMainThread {
	return YES;
}

- (void)tearDownClass {
}

#pragma mark -
#pragma mark Initialization Tests

- (void)testConnectionGeneration {
	testAdView.keywords = @"(keywords)";
		
	NSString *testURL = [NSString stringWithFormat:@"http://ads.mopub.com/m/ad?v=4&udid=%@&q=(keywords)&id=(adunitid)&o=(orientation)&sc=(scalefactor)&z=(timezone)&ll=(location)",  
						 hashedMoPubUDID()];

	[[[mockManager stub] andReturn:@"&o=(orientation)"] orientationQueryStringComponent];
	[[[mockManager stub] andReturn:@"&sc=(scalefactor)"] scaleFactorQueryStringComponent];
	[[[mockManager stub] andReturn:@"&z=(timezone)"] timeZoneQueryStringComponent];
	[[[mockManager stub] andReturn:@"&ll=(location)"] locationQueryStringComponent];
	
	[mockManager loadAdWithURL:nil];
	
	GHAssertEqualObjects(testURL, testAdView.adManager.URL.absoluteString, @"Incorrect URL generated");
}

-(void)testConnectionDelegate {					
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
			
	[mockManager connection:nil didReceiveResponse: mockResponse];

	GHAssertEqualObjects([headerFields objectForKey:kClickthroughHeaderKey], 
						 testAdView.adManager.clickURL.absoluteString, 
						 @"Click URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kLaunchpageHeaderKey], 
						 testAdView.adManager.interceptURL.absoluteString, 
						 @"Intercept URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kFailUrlHeaderKey], 
						 testAdView.adManager.failURL.absoluteString, 
						 @"Fail URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kImpressionTrackerHeaderKey], 
						 testAdView.adManager.impTrackerURL.absoluteString, 
						 @"Impression Tracker URLs are not equal");
	GHAssertEquals([[headerFields objectForKey:kInterceptLinksHeaderKey] boolValue], 
				   testAdView.shouldInterceptLinks, 
				   @"shouldInterceptLinks are not equal");
	GHAssertEquals([[headerFields objectForKey:kScrollableHeaderKey] boolValue], 
				   testAdView.scrollable, 
				   @"Scrollability is not equal");
	GHAssertEquals([[headerFields objectForKey:kWidthHeaderKey] floatValue], 
				   testAdView.creativeSize.width, 
				   @"Creative widths are not equal");
	GHAssertEquals([[headerFields objectForKey:kHeightHeaderKey] floatValue],
				   testAdView.creativeSize.height, 
				   @"Creative heights are not equal");
	GHAssertEquals([[headerFields objectForKey:kAnimationHeaderKey] intValue], 
				   testAdView.animationType, 
				   @"Animation types are not equal");
		
	[mockManager verify];
	[mockResponse verify];
}

- (void)testHeaderInitialization {
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
			
	[mockManager connection:nil didReceiveResponse:mockResponse];

	GHAssertEquals(testAdView.creativeSize, 
				   testAdView.originalSize, 
				   @"Creative size should be equal to original size, since no size headers were passed.");
	GHAssertNotNil(testAdView.adManager.autorefreshTimer, 
				   @"Autorefresh timer should not be nil.");
		
	[mockManager verify];
}

#pragma mark -
#pragma mark Adapter Tests

-(void)testNilOrHTMLAdapterInitialization {
	[headerFields setValue:@"html" forKey:kAdTypeHeaderKey]; 

	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
		
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
		
	[[mockManager expect] replaceCurrentAdapterWithAdapter:nil];

	[[mockAdView expect] backFillWithNothing];
	[[mockManager expect] scheduleAutorefreshTimer];
	[[mockConnect expect] cancel];
	
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	
	GHAssertFalse(testAdView.adManager.isLoading, 
				  @"isLoading value should be false.");
	[mockManager verify];
	[mockConnect verify];
}

-(void)testMissingAdapterInitialization {
	[headerFields setValue:@"error" forKey:kAdTypeHeaderKey]; 

	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
		
	[[mockManager expect] replaceCurrentAdapterWithAdapter:nil];
	[[mockConnect expect] cancel];
	[[mockManager expect] loadAdWithURL:[NSURL URLWithString:@"http://www.failurl.com"]];
	
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	
	GHAssertFalse(testAdView.adManager.isLoading, 
				  @"isLoading value should be false.");
	[mockManager verify];
	[mockConnect verify];
}	

-(void)testAllOtherAdapterInitialization {
	[headerFields setValue:@"iAd" forKey:kAdTypeHeaderKey]; 
	
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	id mockView = [OCMockObject partialMockForObject:testAdView];
	
	[[[mockManager expect] andForwardToRealObject] replaceCurrentAdapterWithAdapter:[OCMArg any]];
	[[mockConnect expect] cancel];
	
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	
	[mockManager verify];
	[mockConnect verify];
	[mockView verify];
}

-(void)testAdapterDidFinishLoading {
	[[mockManager expect] trackImpression];
	[[mockManager expect] scheduleAutorefreshTimer];
	
	[mockManager adapterDidFinishLoadingAd:nil shouldTrackImpression:YES];
	GHAssertFalse(testAdView.adManager.isLoading, 
				  @"isLoading value should be false.");
	[mockManager verify];
}
/*
//TODO: Fix release stuff
-(void)testAdapterDidFailToLoadWithError {
	MPBaseAdapter *testAdapter = [[MPBaseAdapter alloc] initWithAdManager:testAdView.adManager];
	id mockAdapter = [OCMockObject partialMockForObject:testAdapter];
	
	[[mockAdapter expect] unregisterDelegate];
	[[mockAdapter reject] release];
	[[mockManager expect] loadAdWithURL:testAdView.adManager.failURL];
	
	[mockManager adapter:testAdapter didFailToLoadAdWithError:nil];
	
	GHAssertNil(testAdapter, @"Adapter should be nil.");
	[mockManager verify];
	[mockAdapter verify];
}*/

-(void)testUserActionWillBeginForAdapter {
	[[mockManager expect] trackClick];
	
	[mockManager userActionWillBeginForAdapter: nil];
	
	GHAssertTrue(testAdView.adManager.adActionInProgress, 
				 @"adActionInProgress value should be true.");
	[mockManager verify];
}

-(void)testUserActionDidEndForAdapter {
	[mockManager userActionDidEndForAdapter:nil];
	
	GHAssertFalse(testAdView.adManager.adActionInProgress, 
				  @"adActionInProgress value should be false.");
	GHAssertFalse(testAdView.adManager.autorefreshTimerNeedsScheduling, 
				  @"autorefreshTimerNeedsScheduling value should be false");
	[mockManager verify];
}


#pragma mark -
#pragma mark Connection Tests

-(void)testConnectionDidFail {
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	id mockView = [OCMockObject partialMockForObject:testAdView];

	[[mockManager expect] scheduleAutorefreshTimer];
	[[mockView expect] backFillWithNothing];
	
	[mockManager connection:mockConnect didFailWithError:nil];
	
	GHAssertFalse(testAdView.adManager.isLoading, 
				  @"isLoading value should be false.");
	GHAssertNotNil(testAdView.adManager.autorefreshTimer, 
				   @"Autorefresh timer should not be nil.");
	[mockManager verify];
}

-(void)testConnectionDidFinishLoading {	
	testAdView.creativeSize = CGSizeMake(320, 250);
		
	unsigned poolSize = testAdView.adManager.webviewPool.count;
	
	[[[mockManager expect] andForwardToRealObject] 
		makeAdWebViewWithFrame:(CGRect){{0, 0}, testAdView.creativeSize}];

	[mockManager connectionDidFinishLoading:mockConnect];
	
	NSEnumerator *enumerator = [testAdView.adManager.webviewPool objectEnumerator];
	UIWebView *webview;
	while ((webview = [enumerator nextObject])) {
		GHAssertEquals(webview.frame.size, 
					   testAdView.creativeSize, 
					   @"Webview size does not match creative size");
	}
	
	GHAssertEquals(testAdView.adManager.webviewPool.count, 
				   poolSize + 1, 
				   @"Webview pool has incorrect count.");
	[mockManager verify];
}

-(void)testConnectionDidReceiveData {	
	
	NSMutableData *newData = [[NSMutableData alloc] initWithLength:4];
	id mockData = [OCMockObject mockForClass:[NSMutableData class]];
	testAdView.adManager.data = mockData;
	
	[[mockData expect] appendData:newData];
	[mockManager connection:mockConnect didReceiveData:newData];
	
	[mockData verify];
}

#pragma mark -
#pragma mark Webview Tests

-(void)testWebviewOnClose {
	id mockView = [OCMockObject partialMockForObject:testAdView];
	
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
	
	BOOL yes = YES;
	[[[mockDelegate stub] andReturnValue:OCMOCK_VALUE(yes)] respondsToSelector:
															@selector(adViewDidLoadAd:)];
	
	[[mockView expect] setAdContentView:mockWebview];
	[[mockManager expect] scheduleAutorefreshTimer];
	[[mockDelegate expect] adViewDidLoadAd:testAdView];
	
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
												  [NSURL URLWithString:@"mopub://finishLoad"]];
	
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];	
	
	GHAssertFalse(testAdView.adManager.isLoading, 
				  @"isLoading value should be false.");
	[mockView verify];
	[mockManager verify];
	[mockDelegate verify];
}

-(void)testWebviewOnFailLoad {		
	[testAdView.adManager.webviewPool addObject:mockWebview];
	unsigned poolSize = testAdView.adManager.webviewPool.count;

	[[mockManager expect] loadAdWithURL:testAdView.adManager.failURL];
	[[mockWebview expect] stopLoading];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
							 [NSURL URLWithString:@"mopub://failLoad"]];
		
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];	
	
	GHAssertFalse(testAdView.adManager.isLoading, 
				  @"isLoading value should be false.");
	GHAssertEquals(testAdView.adManager.webviewPool.count, 
				   poolSize - 1, 
				   @"Webview pool has incorrect count.");
	
	[mockManager verify];
	[mockWebview verify];
}

-(void)testWebviewOnInAppPurchase {
	id mockStore = [OCMockObject mockForClass:[MPStore class]];
	testAdView.adManager.store = mockStore;
	
	[[mockManager expect] trackClick];
	[[mockStore expect] initiatePurchaseForProductIdentifier:@"(id)" quantity:1];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
							 [NSURL URLWithString:@"mopub://inapp?id=(id)&num=1"]];
	
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];
	
	[mockManager verify];
	[mockStore verify];
}

-(void)testWebviewOnCustomHost {	
	[[mockManager expect] trackClick];
	[[[mockManager expect] andForwardToRealObject] customLinkClickedForSelectorString:@"(fnc)" withDataString:@"(data)"];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:
							 [NSURL URLWithString:@"mopub://custom?fnc=(fnc)&data=(data)"]];
	
	[mockManager webView:mockWebview shouldStartLoadWithRequest:request navigationType:0];
	
	[mockManager verify];
}

-(void)testMakeWebViewWithFrame {
	CGRect frame = CGRectMake(10, 10, 10, 10);
	UIWebView *webView = [mockManager makeAdWebViewWithFrame:frame];
	
	GHAssertEqualObjects(webView.backgroundColor, [UIColor clearColor],
						 @"Webview background color should be clear");
	GHAssertFalse(webView.opaque, @"Webview should be opaque");
	GHAssertEquals(webView.frame, frame,
						 @"Webview frame is not initialized property");
}

@end