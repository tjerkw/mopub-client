//
//  MPGoogleAdMobAdapter.m
//  MoPub
//
//  Created by Andrew He on 5/1/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPGoogleAdMobAdapter.h"
#import "MPAdManager.h"
#import "MPAdManager+MPBaseAdapterFriend.h"
#import "MPLogging.h"
#import "CJSONDeserializer.h"

@implementation MPGoogleAdMobAdapter

- (id)initWithAdView:(MPAdManager *)adManager
{
	if (self = [super initWithAdManager:adManager])
	{
		CGRect frame = CGRectMake(0.0, 0.0, GAD_SIZE_320x50.width, GAD_SIZE_320x50.height);
		_adBannerView = [[GADBannerView alloc] initWithFrame:frame];
		_adBannerView.delegate = self;
	}
	return self;
}

- (void)dealloc
{
	_adBannerView.delegate = nil;
	[_adBannerView release];
	[super dealloc];
}

- (void)getAdWithParams:(NSDictionary *)params
{
	NSData *hdrData = [(NSString *)[params objectForKey:@"X-Nativeparams"] 
					   dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *hdrParams = [[CJSONDeserializer deserializer] deserializeAsDictionary:hdrData
																				  error:NULL];
	
	_adBannerView.adUnitID = [hdrParams objectForKey:@"adUnitID"];
	_adBannerView.rootViewController = [self.adManager viewControllerForPresentingModalView];
	
	GADRequest *request = [GADRequest request];
	// Here, you can specify a list of devices that will receive test ads.
	// See: http://code.google.com/mobile/ads/docs/ios/intermediate.html#testdevices
	request.testDevices = [NSArray arrayWithObjects:
						   // GAD_SIMULATOR_ID, 
						   // more UDIDs here,
						   nil];
	
	[_adBannerView loadRequest:request];
}

- (void)adViewDidReceiveAd:(GADBannerView *)bannerView
{
	[self.adManager setAdContentView:bannerView];
	[self.adManager adapterDidFinishLoadingAd:self shouldTrackImpression:YES];
}

- (void)adView:(GADBannerView *)bannerView
		didFailToReceiveAdWithError:(GADRequestError *)error
{
	[self.adManager adapter:self didFailToLoadAdWithError:nil];
}

- (void)adViewWillPresentScreen:(GADBannerView *)bannerView
{
	[self.adManager userActionWillBeginForAdapter:self];
}

- (void)adViewDidDismissScreen:(GADBannerView *)bannerView
{
	[self.adManager userActionDidEndForAdapter:self];
}

- (void)adViewWillLeaveApplication:(GADBannerView *)bannerView
{
	[self.adManager userWillLeaveApplicationFromAdapter:self];
}

@end
