//
//  MPGlobal.m
//  MoPub
//
//  Created by Andrew He on 5/5/11.
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "MPGlobal.h"
#import <CommonCrypto/CommonDigest.h>

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


NSString *MPHashedUDID()
{
	static NSString *hashedUDID = nil;
	
    if (!hashedUDID) {
        NSString *result = nil;
        NSString *udid = [NSString stringWithFormat:@"mopub-%@", 
                          [[UIDevice currentDevice] uniqueIdentifier]];

        if (udid) 
        {
            unsigned char digest[16];
            NSData *data = [udid dataUsingEncoding:NSASCIIStringEncoding];
            CC_MD5([data bytes], [data length], digest);
            
            result = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                      digest[0], digest[1], 
                      digest[2], digest[3],
                      digest[4], digest[5],
                      digest[6], digest[7],
                      digest[8], digest[9],
                      digest[10], digest[11],
                      digest[12], digest[13],
                      digest[14], digest[15]];
            result = [result uppercaseString];
        }
        hashedUDID = [NSString stringWithFormat:@"md5:%@", result];
        [hashedUDID retain];
    }
    return hashedUDID;
}

NSString *MPUserAgentString()
{
	static NSString *userAgent = nil;
	
    if (!userAgent) {
        UIWebView *webview = [[UIWebView alloc] init];
        userAgent = [[webview stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"] copy];  
        [webview release];
    }
    return userAgent;
}

@implementation NSString (MPAdditions)

- (NSString *)URLEncodedString
{
	NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
																		   (CFStringRef)self,
																		   NULL,
																		   (CFStringRef)@"!*'();:@&=+$,/?%#[]<>",
																		   kCFStringEncodingUTF8);
	return [result autorelease];
}

@end
