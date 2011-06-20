//
//  MPCustomEventAdapter.m
//  MoPub
//
//  Created by Andrew He on 2/9/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPCustomEventAdapter.h"
#import "MPAdManager.h"
#import "MPLogging.h"

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
	if ([self.adManager.viewDelegate respondsToSelector:selector])
	{
		[self.adManager.viewDelegate performSelector:selector];
	}
	// Then, try calling the selector passing in the ad view.
	else 
	{
		NSString *selectorWithObjectString = [NSString stringWithFormat:@"%@:", selectorString];
		SEL selectorWithObject = NSSelectorFromString(selectorWithObjectString);
		
		if ([self.adManager.viewDelegate respondsToSelector:selectorWithObject])
		{
			[self.adManager.viewDelegate performSelector:selectorWithObject withObject:self.adManager.delegate];
		}
		else
		{
			MPLogError(@"Ad view delegate does not implement custom event selectors %@ or %@.",
				  selectorString,
				  selectorWithObjectString);
			[self.adManager.viewDelegate customEventDidFailToLoadAd];
		}
	}

}

@end
