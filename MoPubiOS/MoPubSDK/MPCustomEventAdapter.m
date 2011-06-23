//
//  MPCustomEventAdapter.m
//  MoPub
//
//  Created by Andrew He on 2/9/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPCustomEventAdapter.h"
#import "MPAdManager.h"
#import "MPAdView.h"
#import "MPLogging.h"
#import "MPAdManager+MPAdaptersPrivate.h"

@implementation MPCustomEventAdapter

- (void)getAdWithParams:(NSDictionary *)params
{
	NSString *selectorString = [params objectForKey:@"X-Customselector"];
	if (!selectorString)
	{
		MPLogError(@"Custom event requested, but no custom selector was provided.",
			  selectorString);
		[self.adManager customEventDidFailToLoadAd];
	}

	SEL selector = NSSelectorFromString(selectorString);
	
	// First, try calling the no-object selector.
	
	if ([self.adManager.adView.delegate respondsToSelector:selector])
	{
		[self.adManager.adView.delegate performSelector:selector];
	}
	// Then, try calling the selector passing in the ad view.
	else 
	{
		NSString *selectorWithObjectString = [NSString stringWithFormat:@"%@:", selectorString];
		SEL selectorWithObject = NSSelectorFromString(selectorWithObjectString);
		
		if ([self.adManager.adView.delegate respondsToSelector:selectorWithObject])
		{
			[self.adManager.adView.delegate performSelector:selectorWithObject withObject:self.adManager.adView];
		}
		else
		{
			MPLogError(@"Ad view delegate does not implement custom event selectors %@ or %@.",
				  selectorString,
				  selectorWithObjectString);
			[self.adManager customEventDidFailToLoadAd];
		}
	}

}

@end
