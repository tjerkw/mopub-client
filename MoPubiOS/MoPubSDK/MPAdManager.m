//
//  MPAdRequest.m
//  MoPubTests
//
//  Created by Haydn Dufrene on 6/15/11.
//  Copyright 2011 The Falco Initiative. All rights reserved.
//

#import "MPAdManager.h"
#import "MPConstants.h"
#import "MPGlobal.h"
#import "MPAdView.h"
#import "MPTimer.h"
#import "MPBaseAdapter.h"
#import "MPAdapterMap.h"
#import "CJSONDeserializer.h"
#import "MPAdView+MPAdManagerPrivate.h"

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

@interface MPAdManager (Internal)
- (void)loadAdWithURL:(NSURL *)URL;
- (void)forceRefreshAd;
- (void)registerForApplicationStateTransitionNotifications;
- (void)destroyWebviewPool;
- (NSString *)orientationQueryStringComponent;
- (NSString *)scaleFactorQueryStringComponent;
- (NSString *)timeZoneQueryStringComponent;
- (NSString *)locationQueryStringComponent;
- (NSURLRequest *)serverRequestObjectForUrl:(NSURL *)URL;
- (void)replaceCurrentAdapterWithAdapter:(MPBaseAdapter *)newAdapter;
- (void)scheduleAutorefreshTimer;
- (NSURL *)serverRequestUrl;
- (UIWebView *)makeAdWebViewWithFrame:(CGRect)frame;
- (void)trackClick;
- (void)trackImpression;
- (NSDictionary *)dictionaryFromQueryString:(NSString *)query;
- (void)customLinkClickedForSelectorString:(NSString *)selectorString 
							withDataString:(NSString *)dataString;
@end

@interface MPAdManager ()

@property (nonatomic, assign) MPAdView *adView;
@property (nonatomic, copy) NSString *adUnitId;
@property (nonatomic, retain) CLLocation *location;
@property (nonatomic, copy) NSString *keywords;
@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, copy) NSURL *clickURL;
@property (nonatomic, copy) NSURL *interceptURL;
@property (nonatomic, copy) NSURL *failURL;
@property (nonatomic, copy) NSURL *impTrackerURL;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL ignoresAutorefresh;
@property (nonatomic, assign) BOOL adActionInProgress;
@property (nonatomic, assign) BOOL autorefreshTimerNeedsScheduling;	
@property (nonatomic, retain) MPTimer *autorefreshTimer;
@property (nonatomic, retain) MPStore *store;
@property (nonatomic, retain) NSMutableData *data;
@property (nonatomic, retain) NSMutableSet *webviewPool;
@property (nonatomic, retain) MPBaseAdapter *currentAdapter;

@end

@implementation MPAdManager

@synthesize adView = _adView;
@synthesize adUnitId = _adUnitId;
@synthesize location = _location;
@synthesize keywords = _keywords;
@synthesize URL = _URL;
@synthesize clickURL = _clickURL;
@synthesize interceptURL = _interceptURL;
@synthesize failURL = _failURL;
@synthesize impTrackerURL = _impTrackerURL;
@synthesize autorefreshTimer = _autorefreshTimer;
@synthesize isLoading = _isLoading;
@synthesize adActionInProgress = _adActionInProgress;
@synthesize ignoresAutorefresh = _ignoresAutorefresh;
@synthesize autorefreshTimerNeedsScheduling = _autorefreshTimerNeedsScheduling;
@synthesize store = _store;
@synthesize data = _data;
@synthesize webviewPool = _webviewPool;
@synthesize currentAdapter = _currentAdapter;

-(id)initWithAdView:(MPAdView *)adView {
	if (self = [super init]) {
		_adView = adView;
		_data = [[NSMutableData data] retain];
		_webviewPool = [[NSMutableSet set] retain];
		_isLoading = NO;
		_ignoresAutorefresh = NO;
		_store = [MPStore sharedStore];
		_timerTarget = [[MPTimerTarget alloc] initWithNotificationName:kTimerNotificationName];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(forceRefreshAd)
													 name:kTimerNotificationName
												   object:_timerTarget];		
		[self registerForApplicationStateTransitionNotifications];
	}
	return self;
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
		
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
	
	_adView = nil;
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

- (void)registerForApplicationStateTransitionNotifications
{
	// iOS version > 4.0: Register for relevant application state transition notifications.
	if (&UIApplicationDidEnterBackgroundNotification != nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(applicationDidEnterBackground) 
													 name:UIApplicationDidEnterBackgroundNotification 
												   object:[UIApplication sharedApplication]];
	}		
	if (&UIApplicationWillEnterForegroundNotification !=  nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(applicationWillEnterForeground)
													 name:UIApplicationWillEnterForegroundNotification 
												   object:[UIApplication sharedApplication]];
	}
}

- (void)refreshAd
{
	[self.autorefreshTimer invalidate];
	[self loadAdWithURL:nil];
}

- (void)forceRefreshAd
{
	// Cancel any existing request to the ad server.
	[_conn cancel];
	
	_isLoading = NO;
	[self.autorefreshTimer invalidate];
	[self loadAdWithURL:nil];
}

- (void)loadAdWithURL:(NSURL *)URL
{
	if (_isLoading) 
	{
		MPLogWarn(@"Ad view (%p) already loading an ad. Wait for previous load to finish.", self.adView);
		return;
	}
	
	self.URL = (URL) ? URL : [self serverRequestUrl];
	MPLogDebug(@"Ad view (%p) loading ad with MoPub server URL: %@", self.adView, self.URL);
	
	NSURLRequest *request = [self serverRequestObjectForUrl:self.URL];
	[_conn release];
	_conn = [[NSURLConnection connectionWithRequest:request delegate:self] retain];
	_isLoading = YES;
	
	MPLogInfo(@"Ad manager (%p) fired initial ad request.", self);
}

-(NSURL *)serverRequestUrl {
	NSString *urlString = [NSString stringWithFormat:@"http://%@/m/ad?v=4&udid=%@&q=%@&id=%@", 
						   HOSTNAME,
						   hashedMoPubUDID(),
						   [_keywords stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
						   [_adUnitId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
						   ];
	
	urlString = [urlString stringByAppendingString:[self orientationQueryStringComponent]];
	urlString = [urlString stringByAppendingString:[self scaleFactorQueryStringComponent]];
	urlString = [urlString stringByAppendingString:[self timeZoneQueryStringComponent]];
	urlString = [urlString stringByAppendingString:[self locationQueryStringComponent]];
	
	return [NSURL URLWithString:urlString];
}

- (NSString *)orientationQueryStringComponent
{
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	NSString *orientString = UIInterfaceOrientationIsPortrait(orientation) ?
	kMoPubInterfaceOrientationPortraitId : kMoPubInterfaceOrientationLandscapeId;
	return [NSString stringWithFormat:@"&o=%@", orientString];
}

- (NSString *)scaleFactorQueryStringComponent
{
	return [NSString stringWithFormat:@"&sc=%.1f", MPDeviceScaleFactor()];
}

- (NSString *)timeZoneQueryStringComponent
{
	static NSDateFormatter *formatter;
	@synchronized(self)
	{
		if (!formatter) formatter = [[NSDateFormatter alloc] init];
	}
	[formatter setDateFormat:@"Z"];
	NSDate *today = [NSDate date];
	return [NSString stringWithFormat:@"&z=%@", [formatter stringFromDate:today]];
}

- (NSString *)locationQueryStringComponent
{
	NSString *result = @"";
	if (_location)
	{
		result = [result stringByAppendingFormat:
				  @"&ll=%f,%f",
				  _location.coordinate.latitude,
				  _location.coordinate.longitude];
	}
	return result;
}

- (NSURLRequest *)serverRequestObjectForUrl:(NSURL *)URL {
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] 
									 initWithURL:URL
									 cachePolicy:NSURLRequestUseProtocolCachePolicy 
									 timeoutInterval:kMoPubRequestTimeoutInterval] autorelease];
	
	// Set the user agent so that we know where the request is coming from (for targeting).
	[request setValue:userAgentString forHTTPHeaderField:@"User-Agent"];			
	
	return request;
}

- (NSDictionary *)dictionaryFromQueryString:(NSString *)query
{
	NSMutableDictionary *queryDict = [[NSMutableDictionary alloc] initWithCapacity:1];
	NSArray *queryElements = [query componentsSeparatedByString:@"&"];
	for (NSString *element in queryElements) {
		NSArray *keyVal = [element componentsSeparatedByString:@"="];
		NSString *key = [keyVal objectAtIndex:0];
		NSString *value = [keyVal lastObject];
		[queryDict setObject:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] 
					  forKey:key];
	}
	return [queryDict autorelease];
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

- (void)setAdContentView:(UIView *)view
{
	[_adView setAdContentView:view];
}

- (void)customEventDidFailToLoadAd {
	[_adView customEventDidFailToLoadAd];
}

- (UIViewController *)viewControllerForPresentingModalView {
	return [_adView.delegate viewControllerForPresentingModalView];
}

- (void)customLinkClickedForSelectorString:(NSString *)selectorString 
							withDataString:(NSString *)dataString
{
	if (!selectorString)
	{
		MPLogError(@"Custom selector requested, but no custom selector string was provided.",
				   selectorString);
	}
	
	SEL selector = NSSelectorFromString(selectorString);
	
	// First, try calling the no-object selector.
	if ([_adView.delegate respondsToSelector:selector])
	{
		[_adView.delegate performSelector:selector];
	}
	// Then, try calling the selector passing in the ad view.
	else 
	{
		NSString *selectorWithObjectString = [NSString stringWithFormat:@"%@:", selectorString];
		SEL selectorWithObject = NSSelectorFromString(selectorWithObjectString);
		
		if ([_adView.delegate respondsToSelector:selectorWithObject])
		{
			NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
			NSDictionary *dataDictionary = [[CJSONDeserializer deserializer] deserializeAsDictionary:data
																							   error:NULL];
			[_adView.delegate performSelector:selectorWithObject withObject:dataDictionary];
		}
		else
		{
			MPLogError(@"Ad view delegate does not implement custom selectors %@ or %@.",
					   selectorString,
					   selectorWithObjectString);
		}
	}
}

- (void)adLinkClicked:(NSURL *)URL
{
	_adActionInProgress = YES;
	
	// Construct the URL that we want to load in the ad browser, using the click-tracking URL.
	NSString *redirectURLString = [[URL absoluteString] URLEncodedString];	
	NSURL *desiredURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@&r=%@",
											  _clickURL,
											  redirectURLString]];
	
	// Notify delegate that the ad browser is about to open.
	if ([_adView.delegate respondsToSelector:@selector(willPresentModalViewForAd:)])
		[_adView.delegate willPresentModalViewForAd:_adView];
	
	if ([self.autorefreshTimer isScheduled])
		[self.autorefreshTimer pause];
	
	// Present ad browser.
	MPAdBrowserController *browserController = [[MPAdBrowserController alloc] initWithURL:desiredURL 
																				 delegate:self];
	[[_adView.delegate viewControllerForPresentingModalView] presentModalViewController:browserController 			
																			animated:YES];
	[browserController release];
}

#pragma mark -
#pragma mark MPAdBrowserControllerDelegate

- (void)dismissBrowserController:(MPAdBrowserController *)browserController{
	[self dismissBrowserController:browserController animated:YES];
}

- (void)dismissBrowserController:(MPAdBrowserController *)browserController animated:(BOOL)animated
{
	_adActionInProgress = NO;
	[[_adView.delegate viewControllerForPresentingModalView] dismissModalViewControllerAnimated:animated];
	
	if ([_adView.delegate respondsToSelector:@selector(didDismissModalViewForAd:)])
		[_adView.delegate didDismissModalViewForAd:_adView];
	
	if (_autorefreshTimerNeedsScheduling)
	{
		[self.autorefreshTimer scheduleNow];
		_autorefreshTimerNeedsScheduling = NO;
	}
	else if ([self.autorefreshTimer isScheduled])
		[self.autorefreshTimer resume];
}

# pragma mark -
# pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response 
{
	if ([response respondsToSelector:@selector(statusCode)])
	{
		int statusCode = [((NSHTTPURLResponse *)response) statusCode];
		if (statusCode >= 400)
		{
			[connection cancel];
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:
																		  NSLocalizedString(@"Server returned status code %d",@""),
																		  statusCode]
																  forKey:NSLocalizedDescriptionKey];
			NSError *statusError = [NSError errorWithDomain:@"mopub.com"
													   code:statusCode
												   userInfo:errorInfo];
			[self connection:connection didFailWithError:statusError];
			return;
		}
	}
	
	// Parse response headers, set relevant URLs and booleans.
	NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
	NSString *urlString = nil;
	
	urlString = [headers objectForKey:kClickthroughHeaderKey];
	self.clickURL = urlString ? [NSURL URLWithString:urlString] : nil;
	
	urlString = [headers objectForKey:kLaunchpageHeaderKey];
	self.interceptURL = urlString ? [NSURL URLWithString:urlString] : nil;
	
	urlString = [headers objectForKey:kFailUrlHeaderKey];
	self.failURL = urlString ? [NSURL URLWithString:urlString] : nil;
	
	urlString = [headers objectForKey:kImpressionTrackerHeaderKey];
	self.impTrackerURL = urlString ? [NSURL URLWithString:urlString] : nil;
	
	NSString *shouldInterceptLinksString = [headers objectForKey:kInterceptLinksHeaderKey];
	if (shouldInterceptLinksString)
		self.adView.shouldInterceptLinks = [shouldInterceptLinksString boolValue];
	
	NSString *scrollableString = [headers objectForKey:kScrollableHeaderKey];
	if (scrollableString)
		self.adView.scrollable = [scrollableString boolValue];
	
	NSString *widthString = [headers objectForKey:kWidthHeaderKey];
	NSString *heightString = [headers objectForKey:kHeightHeaderKey];
	
	// Try to get the creative size from the server or otherwise use the original container's size.
	if (widthString && heightString)
		self.adView.creativeSize = CGSizeMake([widthString floatValue], [heightString floatValue]);
	else
		self.adView.creativeSize = self.adView.originalSize;
	
	// Create the autorefresh timer, which will be scheduled either when the ad appears,
	// or if it fails to load.
	NSString *refreshString = [headers objectForKey:kRefreshTimeHeaderKey];
	if (refreshString && !self.ignoresAutorefresh)
	{
		NSTimeInterval interval = [refreshString doubleValue];
		interval = (interval >= MINIMUM_REFRESH_INTERVAL) ? interval : MINIMUM_REFRESH_INTERVAL;
		self.autorefreshTimer = [MPTimer timerWithTimeInterval:interval
													  target:_timerTarget 
													  selector:@selector(postNotification) 
													  userInfo:nil 
													  repeats:NO];
	}
	
	NSString *animationString = [headers objectForKey:kAnimationHeaderKey];
	if (animationString)
		self.adView.animationType = [animationString intValue];
	
	// Log if the ad is from an ad network
	NSString *networkTypeHeader = [[(NSHTTPURLResponse *)response allHeaderFields] 
								   objectForKey:kNetworkTypeHeaderKey];
	if (networkTypeHeader && ![networkTypeHeader isEqualToString:@""])
	{
		MPLogInfo(@"Fetching Ad Network Type: %@",networkTypeHeader);
	}
	
	// Determine ad type.
	NSString *typeHeader = [headers	objectForKey:kAdTypeHeaderKey];
	
	if (!typeHeader || [typeHeader isEqualToString:kAdTypeHtml]) {
		[self replaceCurrentAdapterWithAdapter:nil];
		
		// HTML ad, so just return. connectionDidFinishLoading: will take care of the rest.
		return;
	}	else if ([typeHeader isEqualToString:kAdTypeClear]) {
		[self replaceCurrentAdapterWithAdapter:nil];
		
		// Show a blank.
		MPLogInfo(@"*** CLEAR ***");
		[connection cancel];
		_isLoading = NO;
		[_adView backFillWithNothing];
		[self scheduleAutorefreshTimer];
		return;
	}
	
	// Obtain adapter for specified ad type.
	NSString *classString = [[MPAdapterMap sharedAdapterMap] classStringForAdapterType:typeHeader];
	Class cls = NSClassFromString(classString);
	if (cls != nil)
	{
		MPBaseAdapter *newAdapter = (MPBaseAdapter *)[[cls alloc] initWithAdManager:self];
		[self replaceCurrentAdapterWithAdapter:newAdapter];
		
		[connection cancel];
		
		// Tell adapter to fire off ad request.
		NSDictionary *params = [(NSHTTPURLResponse *)response allHeaderFields];
		[_currentAdapter getAdWithParams:params];
	}
	// Else: no adapter for the specified ad type, so just fail over.
	else 
	{
		[self replaceCurrentAdapterWithAdapter:nil];
		
		[connection cancel];
		_isLoading = NO;
		
		[self loadAdWithURL:self.failURL];
	}	
}

- (void)replaceCurrentAdapterWithAdapter:(MPBaseAdapter *)newAdapter
{
	// Dispose of the last adapter stored in _previousAdapter.
	[_previousAdapter unregisterDelegate];
	[_previousAdapter release];
	
	_previousAdapter = _currentAdapter;
	_currentAdapter = newAdapter;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)d
{
	[_data appendData:d];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	MPLogError(@"Ad view (%p) failed to get a valid response from MoPub server. Error: %@", 
			   self, error);
	
	// If the initial request to MoPub fails, replace the current ad content with a blank.
	_isLoading = NO;
	[_adView backFillWithNothing];
	
	// Retry in 60 seconds.
	if (!self.autorefreshTimer || ![self.autorefreshTimer isValid])
	{
		self.autorefreshTimer = [MPTimer timerWithTimeInterval:kMoPubRequestRetryInterval 
														target:_timerTarget 
													  selector:@selector(postNotification) 
													  userInfo:nil 
													   repeats:NO];
	}
	
	[self scheduleAutorefreshTimer];	
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	// Generate a new webview to contain the HTML and add it to the webview pool.
	UIWebView *webview = [self makeAdWebViewWithFrame:(CGRect){{0, 0}, self.adView.creativeSize}];
	webview.delegate = self;
	[_webviewPool addObject:webview];
	[webview loadData:_data MIMEType:@"text/html" textEncodingName:@"utf-8" baseURL:self.URL];
	
	// Print out the response, for debugging.
	if (MPLogGetLevel() <= MPLogLevelTrace)
	{
		NSString *response = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
		MPLogTrace(@"Ad view (%p) loaded HTML content: %@", self, response);
		[response release];
	}
}

- (void)scheduleAutorefreshTimer
{
	if (_adActionInProgress)
	{
		MPLogDebug(@"Ad action in progress: MPTimer will be scheduled after action ends.");
		_autorefreshTimerNeedsScheduling = YES;
	}
	else if ([self.autorefreshTimer isScheduled])
	{
		MPLogDebug(@"Tried to schedule the autorefresh timer, but it was already scheduled.");
	}
	else if (self.autorefreshTimer == nil)
	{
		MPLogDebug(@"Tried to schedule the autorefresh timer, but it was nil.");
	}
	else
	{
		[self.autorefreshTimer scheduleNow];
	}
}

#pragma mark -
#pragma mark MPAdapterDelegate

- (void)adapterDidFinishLoadingAd:(MPBaseAdapter *)adapter shouldTrackImpression:(BOOL)shouldTrack
{
	_isLoading = NO;
	
	if (shouldTrack) [self trackImpression];
	[self scheduleAutorefreshTimer];
	
	if ([_adView.delegate respondsToSelector:@selector(adViewDidLoadAd:)])
		[_adView.delegate adViewDidLoadAd:_adView];	
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
	if ([_adView.delegate respondsToSelector:@selector(willPresentModalViewForAd:)])
		[_adView.delegate willPresentModalViewForAd:_adView];	
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
	if ([_adView.delegate respondsToSelector:@selector(didDismissModalViewForAd:)])
		[_adView.delegate didDismissModalViewForAd:_adView];	
}

- (void)userWillLeaveApplicationFromAdapter:(MPBaseAdapter *)adapter
{
	// TODO: Implement.
}

#pragma mark -
#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request 
 navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *URL = [request URL];
	
	// Handle the custom mopub:// scheme.
	if ([[URL scheme] isEqualToString:kMoPubUrlScheme])
	{
		NSString *host = [URL host];
		if ([host isEqualToString:kMoPubCloseHost])
		{
			[self.adView didCloseAd:nil];
		}
		else if ([host isEqualToString:kMoPubFinishLoadHost])
		{
			_isLoading = NO;
			
			[self.adView setAdContentView:webView];
			[self scheduleAutorefreshTimer];
			
			// Notify delegate that an ad has been loaded.
			if ([self.adView.delegate respondsToSelector:@selector(adViewDidLoadAd:)]) 
				[self.adView.delegate adViewDidLoadAd:_adView];
		}
		else if ([host isEqualToString:kMoPubFailLoadHost])
		{
			_isLoading = NO;
			
			// Deallocate this webview by removing it from the pool.
			webView.delegate = nil;
			[webView stopLoading];
			[_webviewPool removeObject:webView];
			
			// Start a new request using the fall-back URL.
			[self loadAdWithURL:self.failURL];
		}
	    else if ([host isEqualToString:kMoPubInAppHost])
		{
			[self trackClick];
			NSDictionary *queryDict = [self dictionaryFromQueryString:[URL query]];
			[_store initiatePurchaseForProductIdentifier:[queryDict objectForKey:@"id"] 
												quantity:[[queryDict objectForKey:@"num"] intValue]];
		}
	    else if ([host isEqualToString:kMoPubCustomHost])
		{
			[self trackClick];
			NSDictionary *queryDict = [self dictionaryFromQueryString:[URL query]];
			[self customLinkClickedForSelectorString:[queryDict objectForKey:@"fnc"]
									  withDataString:[queryDict objectForKey:@"data"]];
		}
		
		return NO;
	}
	
	// Intercept non-click forms of navigation (e.g. "window.location = ...") if the target URL
	// has the interceptURL prefix. Launch the ad browser.
	if (navigationType == UIWebViewNavigationTypeOther && 
		_adView.shouldInterceptLinks && 
		self.interceptURL &&
		[[URL absoluteString] hasPrefix:[self.interceptURL absoluteString]])
	{
		[self adLinkClicked:URL];
		return NO;
	}
	
	// Launch the ad browser for all clicks (if shouldInterceptLinks is YES).
	if (navigationType == UIWebViewNavigationTypeLinkClicked && _adView.shouldInterceptLinks)
	{
		[self adLinkClicked:URL];
		return NO;
	}
	
	// Other stuff (e.g. JavaScript) should load as usual.
	return YES;	
}

- (UIWebView *)makeAdWebViewWithFrame:(CGRect)frame
{
	UIWebView *webView = [[UIWebView alloc] initWithFrame:frame];
	if (self.adView.stretchesWebContentToFill)
		webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	webView.backgroundColor = [UIColor clearColor];
	webView.opaque = NO;
	return [webView autorelease];
}

# pragma mark -
# pragma UIApplicationNotification responders

- (void)applicationDidEnterBackground
{
	[self.autorefreshTimer pause];
}

- (void)applicationWillEnterForeground
{
	_autorefreshTimerNeedsScheduling = NO;
	if (_ignoresAutorefresh == NO) [self forceRefreshAd];
}

@end