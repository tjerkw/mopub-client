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

@interface MPAdManager ()
- (void)registerForApplicationStateTransitionNotifications;
- (NSString *)orientationQueryStringComponent;
- (NSString *)scaleFactorQueryStringComponent;
- (NSString *)timeZoneQueryStringComponent;
- (NSString *)locationQueryStringComponent;
- (NSURLRequest *)serverRequestObjectForUrl:(NSURL *)URL;
- (void)replaceCurrentAdapterWithAdapter:(MPBaseAdapter *)newAdapter;
- (void)scheduleAutorefreshTimer;
- (NSURL *)serverRequestUrl;

@end

@implementation MPAdManager

@synthesize URL = _URL;
@synthesize conn = _conn;
@synthesize delegate = _delegate;
@synthesize viewDelegate = _viewDelegate;
@synthesize clickURL = _clickURL;
@synthesize interceptURL = _interceptURL;
@synthesize failURL = _failURL;
@synthesize impTrackerURL = _impTrackerURL;
@synthesize autorefreshTimer = _autorefreshTimer;
@synthesize timerTarget = _timerTarget;
@synthesize ignoresAutorefresh = _ignoresAutorefresh;
@synthesize isLoading = _isLoading;

-(id)initWithAdView:(MPAdView *)adView {
	if (self = [super init]) {
		_delegate = adView;
		[self registerForApplicationStateTransitionNotifications];
	}
	return self;
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

- (void)loadAdWithURL:(NSURL *)URL
{
	if (_isLoading) 
	{
		MPLogWarn(@"Ad view (%p) already loading an ad. Wait for previous load to finish.", self.delegate);
		return;
	}
	
	self.URL = (URL) ? URL : [self serverRequestUrl];
	MPLogDebug(@"Ad view (%p) loading ad with MoPub server URL: %@", self.delegate, self.URL);
	
	NSURLRequest *request = [self serverRequestObjectForUrl:self.URL];
	[_conn release];
	_conn = [[NSURLConnection connectionWithRequest:request delegate:self] retain];
	_isLoading = YES;
	
	MPLogInfo(@"Ad manager (%p) fired initial ad request.", self);
}

-(NSURL *)serverRequestUrl {
	NSString *urlString = [NSString stringWithFormat:@"http://%@/m/ad?v=4&udid=%@&q=%@&id=%@", 
						   HOSTNAME,
						   [[UIDevice currentDevice] hashedMoPubUDID],
						   [_delegate.keywords stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
						   [_delegate.adUnitId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
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
	if (_delegate.location)
	{
		result = [result stringByAppendingFormat:
				  @"&ll=%f,%f",
				  _delegate.location.coordinate.latitude,
				  _delegate.location.coordinate.longitude];
	}
	return result;
}

- (NSURLRequest *)serverRequestObjectForUrl:(NSURL *)URL {
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] 
									 initWithURL:URL
									 cachePolicy:NSURLRequestUseProtocolCachePolicy 
									 timeoutInterval:kMoPubRequestTimeoutInterval] autorelease];
	
	// Set the user agent so that we know where the request is coming from (for targeting).
	[request setValue:userAgentString() forHTTPHeaderField:@"User-Agent"];			
	
	return request;
}

- (void)customEventDidFailToLoadAd
{
	_isLoading = NO;
	[self loadAdWithURL:self.failURL];
}

# pragma mark -
# pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response 
{
	NSLog(@"%@", userAgentString());

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
		self.delegate.shouldInterceptLinks = [shouldInterceptLinksString boolValue];
	
	NSString *scrollableString = [headers objectForKey:kScrollableHeaderKey];
	if (scrollableString)
		self.delegate.scrollable = [scrollableString boolValue];
	
	NSString *widthString = [headers objectForKey:kWidthHeaderKey];
	NSString *heightString = [headers objectForKey:kHeightHeaderKey];
	
	// Try to get the creative size from the server or otherwise use the original container's size.
	if (widthString && heightString)
		self.delegate.creativeSize = CGSizeMake([widthString floatValue], [heightString floatValue]);
	else
		self.delegate.creativeSize = self.delegate.originalSize;
	
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
		self.delegate.animationType = [animationString intValue];
	
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
		[_delegate backFillWithNothing];
		[self scheduleAutorefreshTimer];
		return;
	}
	
	// Obtain adapter for specified ad type.
	NSString *classString = [[MPAdapterMap sharedAdapterMap] classStringForAdapterType:typeHeader];
	Class cls = NSClassFromString(classString);
	if (cls != nil)
	{
		MPBaseAdapter *newAdapter = (MPBaseAdapter *)[[cls alloc] initWithAdView:self];
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
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
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

@end