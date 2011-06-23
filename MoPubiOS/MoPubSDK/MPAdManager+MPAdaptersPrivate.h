//
//  MPAdManager+MPAdaptersPrivate.h
//  MoPubTests
//
//  Created by Haydn Dufrene on 6/22/11.
//  Copyright 2011 Mopub/Stanford. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPAdManager.h"

@interface MPAdManager (MPAdaptersPrivate)
@property (nonatomic, retain) MPAdView *adView;
- (void)setAdContentView:(UIView *)view;
- (void)customEventDidFailToLoadAd;
- (UIViewController *)viewControllerForPresentingModalView;
@end
