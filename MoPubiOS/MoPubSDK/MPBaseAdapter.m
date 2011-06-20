//
//  MPBaseAdapter.m
//  MoPub
//
//  Created by Nafis Jamal on 1/19/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPBaseAdapter.h"
#import "MPAdManager.h"
#import "MPLogging.h"

@implementation MPBaseAdapter

@synthesize adManager = _adManager;

- (id)initWithAdManager:(MPAdManager *)adManager
{
	if (self = [super init])
		
		_adManager = adManager;
	return self;
}

- (void)dealloc
{
	_adManager = nil;
	[super dealloc];
}

- (void)unregisterDelegate
{
	_adManager = nil;
}

- (void)getAd
{
	[self getAdWithParams:nil];
}

- (void)getAdWithParams:(NSDictionary *)params
{
	// To be implemented by subclasses.
	[self doesNotRecognizeSelector:_cmd];
}

- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation
{
	// Do nothing by default. Subclasses can override.
	MPLogDebug(@"rotateToOrientation %d called for adapter %@ (%p)",
		  newOrientation, NSStringFromClass([self class]), self);
}

@end
