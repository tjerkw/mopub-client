//
//  MPAdView.m
//  MoPub
//
//  Created by Nafis Jamal on 1/19/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPAdView.h"
#import <stdlib.h>
#import <time.h>
#import "MPAdView+MPAdManagerPrivate.h"

static NSString * const kAdAnimationId = @"MPAdTransition";

@interface MPAdView (Internal)
static NSString * userAgentString;
- (void)setScrollable:(BOOL)scrollable forView:(UIView *)view;
- (void)animateTransitionToAdView:(UIView *)view;
- (NSString *)userAgentString;
@end

@interface MPAdView ()
@property (nonatomic, retain) MPAdManager *adManager;
@property (nonatomic, retain) UIView *adContentView;
@property (nonatomic, assign) CGSize originalSize;
@end


@implementation MPAdView

@synthesize adManager = _adManager;
@synthesize keywords = _keywords;
@synthesize delegate = _delegate;
@synthesize adContentView = _adContentView;
@synthesize creativeSize = _creativeSize;
@synthesize originalSize = _originalSize;
@synthesize shouldInterceptLinks = _shouldInterceptLinks;
@synthesize scrollable = _scrollable;
@synthesize stretchesWebContentToFill = _stretchesWebContentToFill;
@synthesize animationType = _animationType;

#pragma mark -
#pragma mark Lifecycle

+ (void)initialize
{
	UIWebView *webview = [[UIWebView alloc] init];
	userAgentString = [webview stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
	[webview release];
	srandom(time(NULL));
}

- (id)initWithAdUnitId:(NSString *)adUnitId size:(CGSize)size 
{   
	CGRect f = (CGRect){{0, 0}, size};
    if (self = [super initWithFrame:f]) 
	{	
		self.backgroundColor = [UIColor clearColor];
		self.clipsToBounds = YES;
		_shouldInterceptLinks = YES;
		_scrollable = NO;
		_animationType = MPAdAnimationTypeNone;
		_originalSize = size;
		_adManager = [[MPAdManager alloc] initWithAdView:self];
		_adManager.adUnitId = (adUnitId) ? [adUnitId copy] : DEFAULT_PUB_ID;
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
	[_adManager release];
    [super dealloc];
}

#pragma mark -

-(void)setKeywords:(NSString *)keyword{
	_adManager.keywords = keyword; 
}

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
				[_adManager.webviewPool removeObject:_adContentView];
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

- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation
{
	// Pass along this notification to the adapter, so that it can handle the orientation change.
	[_adManager.currentAdapter rotateToOrientation:newOrientation];
}

- (void)loadAd
{
	[_adManager loadAdWithURL:nil];
}

- (void)refreshAd
{
	[_adManager refreshAd];
}

- (void)forceRefreshAd
{
	[_adManager forceRefreshAd];
}

- (void)loadAdWithURL:(NSURL *)URL
{
	[_adManager loadAdWithURL:URL];
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
	_adManager.isLoading = NO;
	[_adManager trackImpression];
}

- (void)customEventDidFailToLoadAd
{
	_adManager.isLoading = NO;
	[_adManager loadAdWithURL:_adManager.failURL];
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

@end
