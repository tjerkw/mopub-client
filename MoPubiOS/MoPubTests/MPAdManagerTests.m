#import <GHUnitIOS/GHUnit.h>
#import <OCMock/OCMock.h>

#import "MPAdManager.h"
#import "MPAdView.h"
#import <objc/runtime.h>

@interface MPAdManagerTests : GHTestCase {
	id mockView;
	id mockDelegate;
}
@end

@implementation MPAdManagerTests

// Run before each test method
- (void)setUp { }

// Run after each test method
- (void)tearDown { }

// Run before the tests are run for this class
- (void)setUpClass {
}

- (void)tearDownClass {
}

- (void)testConnectionGeneration {
	MPAdView *testAdView = [[MPAdView alloc] initWithAdUnitId:@"(adunitid)" size:CGSizeZero];
	testAdView.keywords = @"(keywords)";
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	NSString *testURL = [NSString stringWithFormat:@"http://ads.mopub.com/m/ad?v=4&udid=%@&q=(keywords)&id=(adunitid)&o=(orientation)&sc=(scalefactor)&z=(timezone)&ll=(location)",  [[UIDevice currentDevice] hashedMoPubUDID]];

	[[[mockManager stub] andReturn:@"&o=(orientation)"] orientationQueryStringComponent];
	[[[mockManager stub] andReturn:@"&sc=(scalefactor)"] scaleFactorQueryStringComponent];
	[[[mockManager stub] andReturn:@"&z=(timezone)"] timeZoneQueryStringComponent];
	[[[mockManager stub] andReturn:@"&ll=(location)"] locationQueryStringComponent];
	
	[mockManager loadAdWithURL:nil];
	
	GHAssertEqualObjects(testURL, manager.URL.absoluteString, @"Incorrect URL generated");
}

-(void)testConnectionDelegate {
	MPAdView *testAdView = [[MPAdView alloc] initWithAdUnitId:@"(adunitid)" size:CGSizeZero];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	//NSURLConnection *testConnect = [[NSURLConnection alloc] initWithRequest:[[NSURLRequest alloc] init] delegate:manager];
	id mockConnect = [OCMockObject niceMockForClass:[NSURLConnection class]];//partialMockForObject:testConnect];
			
	[[mockManager expect] connection:mockConnect didFailWithError:OCMOCK_ANY];
	[[mockConnect expect] cancel];
	
	id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];
	int code = 500;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	//[[[mockResponse expect] andReturn:OCMOCK_VALUE(yes)] isKindOfClass:[NSHTTPURLResponse class]];
	 
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	[mockManager verify];
	[mockConnect verify];
}

-(void)testHeaderConfiguration {
	NSDictionary *headerFields = [[NSDictionary alloc] initWithObjectsAndKeys:
								  @"http://www.clickurl.com", kClickthroughHeaderKey,
								  @"http://www.intercepturl.com", kLaunchpageHeaderKey,
								  @"http://www.failurl.com", kFailUrlHeaderKey,
								  @"http://www.imptracker.com", kImpressionTrackerHeaderKey,
								  @"1", kInterceptLinksHeaderKey,
								  @"1", kScrollableHeaderKey,
								  @"320", kWidthHeaderKey,
								  @"50", kHeightHeaderKey,
								  @"20", kRefreshTimeHeaderKey,
								  @"1", kAnimationHeaderKey,
								  @"network_type", kNetworkTypeHeaderKey,
								  @"ad_type", kAdTypeHeaderKey,
								  nil];
	
	id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];	
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	MPAdView *testAdView = [[MPAdView alloc] initWithAdUnitId:@"(adunitid)" size:CGSizeZero];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	[mockManager connection:nil didReceiveResponse: mockResponse];

	GHAssertEqualObjects([headerFields objectForKey:kClickthroughHeaderKey], manager.clickURL.absoluteString, @"Click URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kLaunchpageHeaderKey], manager.interceptURL.absoluteString, @"Intercept URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kFailUrlHeaderKey], manager.failURL.absoluteString, @"Fail URLs are not equal");
	GHAssertEqualObjects([headerFields objectForKey:kImpressionTrackerHeaderKey], manager.impTrackerURL.absoluteString, @"Impression Tracker URLs are not equal");
	GHAssertEquals([[headerFields objectForKey:kInterceptLinksHeaderKey] boolValue], manager.delegate.shouldInterceptLinks, @"shouldInterceptLinks are not equal");
	GHAssertEquals([[headerFields objectForKey:kScrollableHeaderKey] boolValue], manager.delegate.scrollable, @"Scrollability is not equal");
	GHAssertEquals([[headerFields objectForKey:kWidthHeaderKey] floatValue], manager.delegate.creativeSize.width, @"Creative widths are not equal");
	GHAssertEquals([[headerFields objectForKey:kHeightHeaderKey] floatValue], manager.delegate.creativeSize.height, @"Creative heights are not equal");
	GHAssertEquals([[headerFields objectForKey:kAnimationHeaderKey] intValue], manager.delegate.animationType, @"Animation types are not equal");
	//TODO: Ignore networktypeheader
	//TODO: Ignoring adtypeheader
		
	[mockManager verify];
	[mockResponse verify];
}

- (void)testHeaderInitialization {
	NSDictionary *headerFields = [[NSDictionary alloc] initWithObjectsAndKeys:
								  @"20", kRefreshTimeHeaderKey,
								  @"network_type", kNetworkTypeHeaderKey,
								  @"html", kAdTypeHeaderKey,
								  nil];

	id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];	
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	MPAdView *testAdView = [[MPAdView alloc] initWithAdUnitId:@"(adunitid)" size:CGSizeZero];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	[mockManager connection:nil didReceiveResponse:mockResponse];

	GHAssertEquals(manager.delegate.creativeSize, manager.delegate.originalSize, @"Creative size should be equal to original size, since no size headers were passed.");
	GHAssertNotNil(manager.autorefreshTimer, @"Autorefresh timer should not be nil.");
		
	[mockManager verify];
}

-(void)testNilOrHTMLAdapterInitialization {
	NSDictionary *headerFields = [[NSDictionary alloc] initWithObjectsAndKeys:
								  @"20", kRefreshTimeHeaderKey,
								  @"network_type", kNetworkTypeHeaderKey,
								  @"html", kAdTypeHeaderKey,
								  nil];
	id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];	
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	MPAdView *testAdView = [[MPAdView alloc] initWithAdUnitId:@"(adunitid)" size:CGSizeZero];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	[[mockManager expect] replaceCurrentAdapterWithAdapter:nil];
	[mockManager connection:nil didReceiveResponse:mockResponse];

	[mockManager verify];
}

-(void)testClearAdapterInitialization {
	NSDictionary *headerFields = [[NSDictionary alloc] initWithObjectsAndKeys:
								  @"20", kRefreshTimeHeaderKey,
								  @"network_type", kNetworkTypeHeaderKey,
								  @"clear", kAdTypeHeaderKey,
								  nil];	
	id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];	
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	MPAdView *testAdView = [[MPAdView alloc] initWithAdUnitId:@"(adunitid)" size:CGSizeZero];
	id mockAdView = [OCMockObject partialMockForObject:testAdView];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	id mockConnect = [OCMockObject mockForClass:[NSURLConnection class]];
	
	[[mockManager expect] replaceCurrentAdapterWithAdapter:nil];

	[[mockAdView expect] backFillWithNothing];
	[[mockManager expect] scheduleAutorefreshTimer];
	[[mockConnect expect] cancel];
	
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	
	GHAssertFalse(manager.isLoading, @"isLoading value should be false.");
	[mockManager verify];
	[mockConnect verify];
}

-(void)testMissingAdapterInitialization {
	NSDictionary *headerFields = [[NSDictionary alloc] initWithObjectsAndKeys:
								  @"http://www.failurl.com", kFailUrlHeaderKey,
								  @"error", kAdTypeHeaderKey,
								  nil];	
	id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];	
	[[[mockResponse expect] andReturn:headerFields] allHeaderFields];
	int code = 200;
	[[[mockResponse expect] andReturnValue:OCMOCK_VALUE(code)] statusCode];
	
	MPAdView *testAdView = [[MPAdView alloc] initWithAdUnitId:@"(adunitid)" size:CGSizeZero];
	
	MPAdManager *manager = [[MPAdManager alloc] initWithAdView:testAdView];
	id mockManager = [OCMockObject partialMockForObject:manager];
	
	id mockConnect = [OCMockObject mockForClass:[NSURLConnection class]];
	
	[[mockManager expect] replaceCurrentAdapterWithAdapter:nil];
	[[mockConnect expect] cancel];
	[[mockManager expect] loadAdWithURL:[NSURL URLWithString:@"http://www.failurl.com"]];
	
	[mockManager connection:mockConnect didReceiveResponse:mockResponse];
	
	GHAssertFalse(manager.isLoading, @"isLoading value should be false.");
	[mockManager verify];
	[mockConnect verify];
}	

-(void)testAllOtherAdapterInitialization {
	
}

@end