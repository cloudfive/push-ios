//
//  CloudFivePush.m
//  cloudfivepush
//
//  Created by Brian Samson on 3/30/15.
//  Copyright (c) 2015 Brian Samson. All rights reserved.
//

#import "CloudFivePush.h"
#import "CloudFiveAppDelegate.h"

@interface CloudFivePush ()
{

}
@end

@implementation CloudFivePush;

+(void)configure
{
    [CloudFiveAppDelegate sharedInstance];
}

+ (void)register
{
    [self registerWithUserIdentifier:nil];
}

+ (void)registerWithUserIdentifier:(NSString *)userIdentifier
{
    [[CloudFiveAppDelegate sharedInstance] register: userIdentifier];
}


+(void)notifyCloudFiveWithToken:(NSString*)apsToken uniqueIdentifier:(NSString*)uniqueIdentifier
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.cloudfiveapp.com/push/register"]];
    request.HTTPMethod = @"POST";
    UIDevice *dev = [UIDevice currentDevice];
    NSString *postData = [NSString stringWithFormat:@"bundle_identifier=%@&device_token=%@&device_platform=ios&device_name=%@&device_model=%@&device_version=%@&app_version=%@",
                          [[NSBundle mainBundle] bundleIdentifier],
                          apsToken,
                          dev.name,
                          dev.model,
                          dev.systemVersion,
                          [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]

                          ];
    if (uniqueIdentifier != nil) {
        postData = [postData stringByAppendingFormat:@"&user_identifier=%@", uniqueIdentifier];
    }

    request.HTTPBody = [postData dataUsingEncoding:NSUTF8StringEncoding];
    NSURLConnection *conn = [NSURLConnection connectionWithRequest:request delegate:self];
    [conn start];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"Error talking to cloudfive");
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    if ([httpResponse statusCode] == 200) {
        NSLog(@"Successfully registered!");
    } else {
        NSLog(@"Couldn't register with cloudfive");
    }
}

// Accept self signed certificates
//- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
//    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
//}
//
//- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
//    NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
//    [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
//}
@end
