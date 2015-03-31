//
//

#import <Foundation/Foundation.h>

@interface CloudFiveAppDelegate : NSObject 

+ (id) sharedInstance;
//- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
//- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
//- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;

- (void) register: (NSString*)userIdentifier;
//@property (nonatomic, retain) NSDictionary  *launchNotification;
@end