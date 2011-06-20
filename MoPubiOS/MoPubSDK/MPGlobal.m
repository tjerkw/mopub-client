//
//  MPGlobal.m
//  MoPub
//
//  Created by Andrew He on 5/5/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPGlobal.h"

CGRect MPScreenBounds()
{
	CGRect bounds = [UIScreen mainScreen].bounds;
	
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsLandscape(orientation))
	{
		CGFloat width = bounds.size.width;
		bounds.size.width = bounds.size.height;
		bounds.size.height = width;
	}
	
	return bounds;
}

CGFloat MPDeviceScaleFactor()
{
	if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
		[[UIScreen mainScreen] respondsToSelector:@selector(scale)])
	{
		return [[UIScreen mainScreen] scale];
	}
	else return 1.0;
}


NSString *userAgentString()
{
	NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
	NSString *systemName = [[UIDevice currentDevice] systemName];
	NSString *model = [[UIDevice currentDevice] model];
	NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
	NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	return [NSString stringWithFormat:
			@"%@/%@ (%@; U; CPU %@ %@ like Mac OS X; %@)",
			bundleName, 
			appVersion, 
			model,
			systemName, 
			systemVersion, 
			[[NSLocale currentLocale] localeIdentifier]
			];
}