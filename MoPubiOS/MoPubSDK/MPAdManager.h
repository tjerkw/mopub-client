//
//  MPAdRequest.h
//  MoPubTests
//
//  Created by Haydn Dufrene on 6/15/11.
//  Copyright 2011 The Falco Initiative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "MPBaseAdapter.h"
#import "MPStore.h"
#import "MPAdBrowserController.h"

@protocol MPAdapterDelegate;
@class MPAdView, MPTimer, MPTimerTarget, MPBaseAdapter;

@interface MPAdManager : NSObject <MPAdapterDelegate, MPAdBrowserControllerDelegate, UIWebViewDelegate> {
	MPAdView *_adView;

	// Ad unit identifier for the ad view.
	NSString *_adUnitId;
	
	// Targeting parameters.
	NSString *_keywords;
	CLLocation *_location;
	
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

@end
