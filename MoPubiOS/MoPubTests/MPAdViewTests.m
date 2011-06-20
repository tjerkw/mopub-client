#import <GHUnitIOS/GHUnit.h>
#import <OCMock/OCMock.h>

#import "MPAdView.h"
#import <objc/runtime.h>

@interface MPAdViewTests : GHTestCase {
	MPAdView *adView;
	id mockView;
	id mockDelegate;
}
@end

@implementation MPAdViewTests

// Run before each test method
- (void)setUp { }

// Run after each test method
- (void)tearDown { }

// Run before the tests are run for this class
- (void)setUpClass {
	adView = [[MPAdView alloc] init];
	mockView = [OCMockObject partialMockForObject:adView];
	mockDelegate = [OCMockObject mockForProtocol:@protocol(MPAdViewDelegate)];
}

- (void)tearDownClass {
}

- (void)testSimplePass {
	
}

@end