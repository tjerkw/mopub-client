//
//  MPAdManager+MPBaseAdapterFriend.h
//  MoPub
//
//  Created by Haydn Dufrene on 6/22/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPAdManager.h"

@interface MPAdManager (MPBaseAdapterFriend)

@property (nonatomic, retain) MPAdView *adView;

- (void)setAdContentView:(UIView *)view;
- (CGSize)adContentViewSize;
- (void)customEventDidFailToLoadAd;
- (UIViewController *)viewControllerForPresentingModalView;

@end
