//
//  MPAdView+MPAdManagerPrivate.h
//  MoPubTests
//
//  Created by Haydn Dufrene on 6/22/11.
//  Copyright 2011 Mopub/Stanford. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPAdManager.h"
#import "MPAdView.h"

@interface MPAdView (MPAdManagerPrivate)
static NSString * userAgentString;
@property (nonatomic, retain) MPAdManager *adManager;
@property (nonatomic, retain) UIView *adContentView;
@property (nonatomic, assign) CGSize originalSize;
@end

@interface MPAdManager (MPAdViewPrivate)
@property (nonatomic, copy) NSString *adUnitId;
@property (nonatomic, copy) NSString *keywords;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, copy) NSURL *failURL;

@property (nonatomic, retain) NSMutableSet *webviewPool;
@property (nonatomic, retain) MPBaseAdapter *currentAdapter;

- (id)initWithAdView:(MPAdView *)adView;
- (void)loadAdWithURL:(NSURL *)URL;
- (void)refreshAd;
- (void)forceRefreshAd;
- (void)trackImpression;
@end