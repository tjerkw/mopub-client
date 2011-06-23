//
//  MPAdManager+MPAdView+TestsPrivate.h
//  MoPubTests
//
//  Created by Haydn Dufrene on 6/22/11.
//  Copyright 2011 Mopub/Stanford. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPAdManager.h"
#import "MPAdView.h"

@interface MPAdView (MPAdTestsPrivate)
@property (nonatomic, retain) MPAdManager *adManager;
@property (nonatomic, assign) CGSize originalSize;
@end

@interface MPAdManager (MPAdTestsPrivate)
static NSString * const kTimerNotificationName		= @"Autorefresh";
static NSString * const kErrorDomain				= @"mopub.com";
static NSString * const kMoPubUrlScheme				= @"mopub";
static NSString * const kMoPubCloseHost				= @"close";
static NSString * const kMoPubFinishLoadHost		= @"finishLoad";
static NSString * const kMoPubFailLoadHost			= @"failLoad";
static NSString * const kMoPubInAppHost				= @"inapp";
static NSString * const kMoPubCustomHost			= @"custom";
static NSString * const kMoPubInterfaceOrientationPortraitId	= @"p";
static NSString * const kMoPubInterfaceOrientationLandscapeId	= @"l";
static const CGFloat kMoPubRequestTimeoutInterval	= 10.0;
static const CGFloat kMoPubRequestRetryInterval     = 60.0;

// Ad header key/value constants.
static NSString * const kClickthroughHeaderKey		= @"X-Clickthrough";
static NSString * const kLaunchpageHeaderKey		= @"X-Launchpage";
static NSString * const kFailUrlHeaderKey			= @"X-Failurl";
static NSString * const kImpressionTrackerHeaderKey	= @"X-Imptracker";
static NSString * const kInterceptLinksHeaderKey	= @"X-Interceptlinks";
static NSString * const kScrollableHeaderKey		= @"X-Scrollable";
static NSString * const kWidthHeaderKey				= @"X-Width";
static NSString * const kHeightHeaderKey			= @"X-Height";
static NSString * const kRefreshTimeHeaderKey		= @"X-Refreshtime";
static NSString * const kAnimationHeaderKey			= @"X-Animation";
static NSString * const kAdTypeHeaderKey			= @"X-Adtype";
static NSString * const kNetworkTypeHeaderKey		= @"X-Networktype";
static NSString * const kAdTypeHtml					= @"html";
static NSString * const kAdTypeClear				= @"clear";

@property(nonatomic, copy) NSURL *URL;
@property (nonatomic, copy) NSURL *clickURL;
@property (nonatomic, copy) NSURL *interceptURL;
@property (nonatomic, copy) NSURL *failURL;
@property (nonatomic, copy) NSURL *impTrackerURL;
@property (nonatomic, retain) MPTimer *autorefreshTimer;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL adActionInProgress;
@property (nonatomic, assign) BOOL autorefreshTimerNeedsScheduling;	
@property (nonatomic, retain) NSMutableSet *webviewPool;
@property (nonatomic, retain) NSMutableData *data;
@property (nonatomic, retain) MPStore *store;
@property (nonatomic, retain) MPBaseAdapter *currentAdapter;

- (NSString *)orientationQueryStringComponent;
- (NSString *)scaleFactorQueryStringComponent;
- (NSString *)timeZoneQueryStringComponent;
- (NSString *)locationQueryStringComponent;
- (void)replaceCurrentAdapterWithAdapter:(MPBaseAdapter *)newAdapter;
- (void)scheduleAutorefreshTimer;
- (UIWebView *)makeAdWebViewWithFrame:(CGRect)frame;
- (void)trackClick;
- (void)trackImpression;
- (void)adLinkClicked:(NSURL *)URL;
- (void)customLinkClickedForSelectorString:(NSString *)selectorString 
							withDataString:(NSString *)dataString;
@end