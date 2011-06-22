//
//  MPAdRequest.h
//  MoPubTests
//
//  Created by Haydn Dufrene on 6/15/11.
//  Copyright 2011 The Falco Initiative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPBaseAdapter.h"
#import "MPStore.h"

@protocol MPAdapterDelegate;
@class MPAdView, MPTimer, MPTimerTarget, MPBaseAdapter;

@interface MPAdManager : NSObject <MPAdapterDelegate, UIWebViewDelegate> {
	// URL for initial MoPub ad request.
	NSURL *_URL;

	// Whether this ad view is currently loading an ad.
	BOOL _isLoading;
	
	// Whether the ad is currently in the middle of a user-triggered action.
	BOOL _adActionInProgress;

	NSURLConnection *_conn;
	
	// Connection data object for ad request.
	NSMutableData *_data;	
	
	// Pool of webviews being used as HTML ads.
	NSMutableSet *_webviewPool;
	
	MPAdView *_adView;
	
	// Current adapter being used for serving native ads.
	MPBaseAdapter *_currentAdapter;
	
	// Previous adapter.
	MPBaseAdapter *_previousAdapter;	
	
	// Click-tracking URL.
	NSURL *_clickURL;
	
	// We often need to intercept ad navigation that is not the result of a
	// click. This represents a URL prefix for links we'd like to intercept.
	NSURL *_interceptURL;
	
	// Fall-back URL if an ad request fails.
	NSURL *_failURL;
	
	// Impression-tracking URL.
	NSURL *_impTrackerURL;
	
	// Timer that sends a -forceRefreshAd message upon firing, with a time interval handed
	// down from the server. You can set the desired interval for any ad unit using 
	// the MoPub web interface.
	MPTimer *_autorefreshTimer;
	
	// Used as the target object for the MPTimer, in order to avoid a retain cycle (see MPTimer.h).
	MPTimerTarget *_timerTarget;
	
	// Whether this ad view ignores autorefresh values sent down from the server. If YES,
	// the ad view will never create an autorefresh timer.
	BOOL _ignoresAutorefresh;	
	
	// Whether the autorefresh timer needs to be scheduled. Use case: during a user-triggered ad 
	// action, we must postpone any attempted timer scheduling until the action ends. This flag 
	// allows the "action-ended" callbacks to decide whether the timer needs to be re-scheduled.
	BOOL _autorefreshTimerNeedsScheduling;	
	
	// Handle to the shared store object that manages in-app purchases from ads.
	MPStore *_store;
}

@property (nonatomic, retain) MPStore *store;
@property (nonatomic, retain) NSMutableData *data;
@property (nonatomic, retain) NSMutableSet *webviewPool;
@property(nonatomic, copy) NSURL *URL;
@property(nonatomic, retain) NSURLConnection *conn;
@property(nonatomic, assign) MPAdView *adView;
@property (nonatomic, copy) NSURL *clickURL;
@property (nonatomic, copy) NSURL *interceptURL;
@property (nonatomic, copy) NSURL *failURL;
@property (nonatomic, copy) NSURL *impTrackerURL;
@property (nonatomic, retain) MPTimer *autorefreshTimer;
@property (nonatomic, retain) MPTimerTarget *timerTarget;
@property (nonatomic, assign) BOOL ignoresAutorefresh;
@property (nonatomic, assign) BOOL isLoading;


-(id)initWithAdView:(MPAdView *)adView;

/*
 * Loads a new ad using the specified URL.
 */
- (void)loadAdWithURL:(NSURL *)URL;

/*
 * Signals to the ad view that a custom event has resulted in a failed load.
 * You must call this method if you implement custom events.
 */
- (void)customEventDidFailToLoadAd;




@end
