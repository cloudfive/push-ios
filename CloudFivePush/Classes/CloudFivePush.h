//
//  CloudFivePush.h
//  cloudfivepush
//
//  Created by Brian Samson on 3/30/15.
//  Copyright (c) 2015 Brian Samson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CloudFivePush : NSObject <NSURLConnectionDataDelegate, UIAlertViewDelegate>
+(void)configure;

+(void)register:(NSString*)userIdentifier;
+(void)notifyCloudFiveWithToken:(NSString*)apsToken uniqueIdentifier:(NSString*)uniqueIdentifier;
//-(void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)token;
//-(void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
//-(void)didReceiveRemoteNotification:(NSDictionary *)userInfo;



@property NSString* uniqueIdentifier;
@property NSString* apsToken;
@property NSDictionary* alertUserInfo;
@end
