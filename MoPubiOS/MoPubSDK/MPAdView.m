//
//  MPAdView.m
//  MoPub
//
//  Created by Nafis Jamal on 1/19/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPAdView.h"
#import "MPBaseAdapter.h"
#import "MPAdapterMap.h"
#import "MPTimer.h"
#import "CJSONDeserializer.h"
#import <CommonCrypto/CommonDigest.h>
#import <stdlib.h>
#import <time.h>

@interface MPAdView (Internal)
- (void)registerForApplicationStateTransitionNotifications;
- (void)destroyWebviewPool;
- (void)scheduleAutorefreshTimer;
- (void)setScrollable:(BOOL)scrollable forView:(UIView *)view;
- (void)animateTransitionToAdView:(UIView *)view;
- (UIWebView *)makeAdWebViewWithFrame:(CGRect)frame;
- (void)adLinkClicked:(NSURL *)URL;
- (void)trackClick;
- (void)trackImpression;
- (NSDictionary *)dictionaryFromQueryString:(NSString *)query;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)customLinkClickedForSelectorString:(NSString *)selectorString 
							withDataString:(NSString *)dataString;
- (void)replaceCurrentAdapterWithAdapter:(MPBaseAdapter *)newAdapter;
- (NSURL *)serverRequestUrl;
- (NSString *)orientationQueryStringComponent;
- (NSString *)scaleFactorQueryStringComponent;
- (NSString *)timeZoneQueryStringComponent;
- (NSString *)locationQueryStringComponent;
- (NSURLRequest *)serverRequestObjectForUrl:(NSURL *)url;
- (NSString *)userAgentString;
@end

@interface MPAdView ()
@property (nonatomic, copy) NSURL *clickURL;
@property (nonatomic, copy) NSURL *interceptURL;
@property (nonatomic, copy) NSURL *failURL;
@property (nonatomic, copy) NSURL *impTrackerURL;
@property (nonatomic, retain) MPTimer *autorefreshTimer;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation MPAdView

@synthesize adContentView = _adContentView;
@synthesize delegate = _delegate;
@synthesize adUnitId = _adUnitId;
@synthesize URL = _URL;
@synthesize clickURL = _clickURL;
@synthesize interceptURL = _interceptURL;
@synthesize failURL = _failURL;
@synthesize impTrackerURL = _impTrackerURL;
@synthesize creativeSize = _creativeSize;
@synthesize keywords = _keywords;
@synthesize location = _location;
@synthesize shouldInterceptLinks = _shouldInterceptLinks;
@synthesize scrollable = _scrollable;
@synthesize autorefreshTimer = _autorefreshTimer;
@synthesize ignoresAutorefresh = _ignoresAutorefresh;
@synthesize stretchesWebContentToFill = _stretchesWebContentToFill;
@synthesize isLoading = _isLoading;
@synthesize animationType = _animationType;
@synthesize originalSize = _originalSize;

#pragma mark -
#pragma mark Lifecycle

+ (void)initialize
{
	srandom(time(NULL));
}

- (id)initWithAdUnitId:(NSString *)adUnitId size:(CGSize)size 
{   
	CGRect f = (CGRect){{0, 0}, size};
    if (self = [super initWithFrame:f]) 
	{
		self.backgroundColor = [UIColor clearColor];
		self.clipsToBounds = YES;
		_adUnitId = (adUnitId) ? [adUnitId copy] : DEFAULT_PUB_ID;
		_data = [[NSMutableData data] retain];
		_shouldInterceptLinks = YES;
		_scrollable = NO;
		_isLoading = NO;
		_ignoresAutorefresh = NO;
		_store = [MPStore sharedStore];
		_animationType = MPAdAnimationTypeNone;
		_originalSize = size;
		_webviewPool = [[NSMutableSet set] retain];
		[self registerForApplicationStateTransitionNotifications];
		_timerTarget = [[MPTimerTarget alloc] initWithNotificationName:kTimerNotificationName];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(forceRefreshAd)
													 name:kTimerNotificationName
												   object:_timerTarget];
    }
    return self;
}

- (void)dealloc 
{
	_delegate = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
	
	// If our content has a delegate, set its delegate to nil.
	if ([_adContentView respondsToSelector:@selector(setDelegate:)])
		[_adContentView performSelector:@selector(setDelegate:) withObject:nil];
	[_adContentView release];
	
	[self destroyWebviewPool];
	
	[_currentAdapter unregisterDelegate];
	[_currentAdapter release];
	[_previousAdapter unregisterDelegate];
	[_previousAdapter release];
	[_adUnitId release];
	[_conn cancel];
	[_conn release];
	[_data release];
	[_URL release];
	[_clickURL release];
	[_interceptURL release];
	[_failURL release];
	[_impTrackerURL release];
	[_keywords release];
	[_location release];
	[_autorefreshTimer invalidate];
	[_autorefreshTimer release];
	[_timerTarget release];
    [super dealloc];
}

- (void)destroyWebviewPool
{
	for (UIWebView *webview in _webviewPool)
	{
		[webview setDelegate:nil];
		[webview stopLoading];
	}
	[_webviewPool release];
}

#pragma mark -

- (void)setAdContentView:(UIView *)view
{
	if (!view) return;
	[view retain];
	
	if (_stretchesWebContentToFill && [view isKindOfClass:[UIWebView class]])
	{
		// Avoids a race condition: 
		// 1) a webview is initialized with the ad view's bounds
		// 2) ad view resizes its frame before webview gets set as the content view
		view.frame = self.bounds;
	}
	
	self.hidden = NO;
	
	// We don't necessarily know where this view came from, so make sure its scrollability
	// corresponds to our value of self.scrollable.
	[self setScrollable:self.scrollable forView:view];
	
	[self animateTransitionToAdView:view];
}

- (void)animateTransitionToAdView:(UIView *)view
{
	MPAdAnimationType type = (_animationType == MPAdAnimationTypeRandom) ? 
		(random() % (MPAdAnimationTypeCount - 2)) + 2 : _animationType;
	
	// Special case: if there's currently no ad content view, certain transitions will
	// look strange (e.g. CurlUp / CurlDown). We'll just omit the transition.
	if (!_adContentView) type = MPAdAnimationTypeNone;
	
	if (type == MPAdAnimationTypeFade) view.alpha = 0.0;
	
	MPLogDebug(@"Ad view (%p) is using animationType: %d", self, type);
	
	[UIView beginAnimations:kAdAnimationId context:view];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	[UIView setAnimationDuration:1.0];
	
	switch (type)
	{
		case MPAdAnimationTypeFlipFromLeft:
			[self addSubview:view];
			[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft 
								   forView:self 
									 cache:YES];
			break;
		case MPAdAnimationTypeFlipFromRight:
			[self addSubview:view];
			[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight
								   forView:self 
									 cache:YES];
			break;
		case MPAdAnimationTypeCurlUp:
			[self addSubview:view];
			[UIView setAnimationTransition:UIViewAnimationTransitionCurlUp
								   forView:self 
									 cache:YES];
			break;
		case MPAdAnimationTypeCurlDown:
			[self addSubview:view];
			[UIView setAnimationTransition:UIViewAnimationTransitionCurlDown
								   forView:self 
									 cache:YES];
			break;
		case MPAdAnimationTypeFade:
			[UIView setAnimationCurve:UIViewAnimationCurveLinear];
			[self addSubview:view];
			view.alpha = 1.0;
			break;
		default:
			[self addSubview:view];
			break;
	}
	
	[UIView commitAnimations];
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished 
				 context:(void *)context
{
	if ([animationID isEqualToString:kAdAnimationId])
	{
		UIView *viewAddedToHierarchy = (UIView *)context;
		
		// Remove the old ad content view from the view hierarchy, but first confirm that it's
		// not the same as the new view; otherwise, we'll be left with no content view.
		if (_adContentView != viewAddedToHierarchy)
		{
			[_adContentView removeFromSuperview];
			
			// Additionally, do webview-related cleanup if the old _adContentView was a webview.
			if ([_adContentView isKindOfClass:[UIWebView class]])
			{
				[(UIWebView *)_adContentView setDelegate:nil];
				[(UIWebView *)_adContentView stopLoading];
				[_webviewPool removeObject:_adContentView];
			}
		}
		
		// Release _adContentView, since -setAdContentView: retained it.
		[_adContentView release];
		
		_adContentView = viewAddedToHierarchy;
	}
}

- (CGSize)adContentViewSize
{
	return (!_adContentView) ? _originalSize : _adContentView.bounds.size;
}

- (void)setIgnoresAutorefresh:(BOOL)ignoresAutorefresh
{
	_ignoresAutorefresh = ignoresAutorefresh;
	
	if (_ignoresAutorefresh) 
	{
		MPLogInfo(@"Ad view (%p) is now ignoring autorefresh.", self);
		if ([self.autorefreshTimer isScheduled]) [self.autorefreshTimer pause];
	}
	else 
	{
		MPLogInfo(@"Ad view (%p) is no longer ignoring autorefresh.", self);
		if ([self.autorefreshTimer isScheduled]) [self.autorefreshTimer resume];
	}
}

- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation
{
	// Pass along this notification to the adapter, so that it can handle the orientation change.
	[_currentAdapter rotateToOrientation:newOrientation];
}

- (void)loadAd
{
	[self loadAdWithURL:nil];
}

- (void)didCloseAd:(id)sender
{
	if ([_adContentView isKindOfClass:[UIWebView class]])
		[(UIWebView *)_adContentView stringByEvaluatingJavaScriptFromString:@"webviewDidClose();"];
	
	if ([self.delegate respondsToSelector:@selector(adViewShouldClose:)])
		[self.delegate adViewShouldClose:self];
}

- (void)adViewDidAppear
{
	if ([_adContentView isKindOfClass:[UIWebView class]])
		[(UIWebView *)_adContentView stringByEvaluatingJavaScriptFromString:@"webviewDidAppear();"];
}

# pragma mark -
# pragma mark Custom Events

- (void)customEventDidLoadAd
{
	_isLoading = NO;
	[self trackImpression];
}

- (void)customEventDidFailToLoadAd
{
	_isLoading = NO;
	[self loadAdWithURL:self.failURL];
}

#pragma mark -
#pragma mark MPAdapterDelegate

- (void)adapterDidFinishLoadingAd:(MPBaseAdapter *)adapter shouldTrackImpression:(BOOL)shouldTrack
{	
	_isLoading = NO;
	
	if (shouldTrack) [self trackImpression];
	[self scheduleAutorefreshTimer];
	
	if ([self.delegate respondsToSelector:@selector(adViewDidLoadAd:)])
		[self.delegate adViewDidLoadAd:self];
}

- (void)adapter:(MPBaseAdapter *)adapter didFailToLoadAdWithError:(NSError *)error
{
	// Ignore fail messages from the previous adapter.
	if (_previousAdapter && adapter == _previousAdapter) return;
	
	_isLoading = NO;
	MPLogError(@"Adapter (%p) failed to load ad. Error: %@", adapter, error);
	
	// Dispose of the current adapter, because we don't want it to try loading again.
	[_currentAdapter unregisterDelegate];
	[_currentAdapter release];
	_currentAdapter = nil;
	
	// An adapter will sometimes send this message during a user action (example: user taps on an 
	// iAd; iAd then does an internal refresh and fails). In this case, we schedule a new request
	// to occur after the action ends. Otherwise, just start a new request using the fall-back URL.
	if (_adActionInProgress) [self scheduleAutorefreshTimer];
	else [self loadAdWithURL:self.failURL];
}

- (void)userActionWillBeginForAdapter:(MPBaseAdapter *)adapter
{
	_adActionInProgress = YES;
	[self trackClick];
	
	if ([self.autorefreshTimer isScheduled])
		[self.autorefreshTimer pause];
	
	// Notify delegate that the ad will present a modal view / disrupt the app.
	if ([self.delegate respondsToSelector:@selector(willPresentModalViewForAd:)])
		[self.delegate willPresentModalViewForAd:self];
}

- (void)userActionDidEndForAdapter:(MPBaseAdapter *)adapter
{
	_adActionInProgress = NO;
	
	if (_autorefreshTimerNeedsScheduling)
	{
		[self.autorefreshTimer scheduleNow];
		_autorefreshTimerNeedsScheduling = NO;
	}
	else if ([self.autorefreshTimer isScheduled])
		[self.autorefreshTimer resume];
	
	// Notify delegate that the ad's modal view was dismissed, returning focus to the app.
	if ([self.delegate respondsToSelector:@selector(didDismissModalViewForAd:)])
		[self.delegate didDismissModalViewForAd:self];
}

- (void)userWillLeaveApplicationFromAdapter:(MPBaseAdapter *)adapter
{
	// TODO: Implement.
}

#pragma mark -
#pragma mark Internal

- (void)setScrollable:(BOOL)scrollable forView:(UIView *)view
{
	// For webviews, find all subviews that are UIScrollViews or subclasses
	// and set their scrolling and bounce.
	if ([view isKindOfClass:[UIWebView class]])
	{
		UIScrollView *scrollView = nil;
		for (UIView *v in view.subviews)
		{
			if ([v isKindOfClass:[UIScrollView class]])
			{
				scrollView = (UIScrollView *)v;
				scrollView.scrollEnabled = scrollable;
				scrollView.bounces = scrollable;
			}
		}
	}
	// For normal UIScrollView subclasses, use the provided setter.
	else if ([view isKindOfClass:[UIScrollView class]])
	{
		[(UIScrollView *)view setScrollEnabled:scrollable];
	}
}

- (void)backFillWithNothing
{
	// Make the ad view disappear.
	self.backgroundColor = [UIColor clearColor];
	self.hidden = YES;
	
	// Notify delegate that the ad has failed to load.
	if ([self.delegate respondsToSelector:@selector(adViewDidFailToLoadAd:)])
		[self.delegate adViewDidFailToLoadAd:self];
}

- (void)trackClick
{
	NSURLRequest *clickURLRequest = [NSURLRequest requestWithURL:self.clickURL];
	[NSURLConnection connectionWithRequest:clickURLRequest delegate:nil];
	MPLogDebug(@"Ad view (%p) tracking click %@", self, self.clickURL);
}

- (void)trackImpression
{
	NSURLRequest *impTrackerURLRequest = [NSURLRequest requestWithURL:self.impTrackerURL];
	[NSURLConnection connectionWithRequest:impTrackerURLRequest delegate:nil];
	MPLogDebug(@"Ad view (%p) tracking impression %@", self, self.impTrackerURL);
}

@end

#pragma mark -
#pragma mark Categories

@implementation UIDevice (MPAdditions)

- (NSString *)hashedMoPubUDID 
{
	NSString *result = nil;
	NSString *udid = [NSString stringWithFormat:@"mopub-%@", 
					  [[UIDevice currentDevice] uniqueIdentifier]];
	
	if (udid) 
	{
		unsigned char digest[16];
		NSData *data = [udid dataUsingEncoding:NSASCIIStringEncoding];
		CC_MD5([data bytes], [data length], digest);
		
		result = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				  digest[0], digest[1], 
				  digest[2], digest[3],
				  digest[4], digest[5],
				  digest[6], digest[7],
				  digest[8], digest[9],
				  digest[10], digest[11],
				  digest[12], digest[13],
				  digest[14], digest[15]];
		result = [result uppercaseString];
	}
	return [NSString stringWithFormat:@"md5:%@", result];
}

@end

@implementation NSString (MPAdditions)

- (NSString *)URLEncodedString
{
	NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(
															NULL,
															(CFStringRef)self,
															NULL,
															(CFStringRef)@"!*'();:@&=+$,/?%#[]<>",
															kCFStringEncodingUTF8);
	return result;
}

@end

