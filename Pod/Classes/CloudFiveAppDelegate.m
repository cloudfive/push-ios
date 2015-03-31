//
//  AppDelegate+notification.m
//  pushtest
//
//  Created by Robert Easterday on 10/26/12.
//
//

#import "CloudFiveAppDelegate.h"
#import "CloudFivePush.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface CloudFiveAppDelegate () {
    Method originalDidReceiveRemoteNotification;
    Method originalDidRegisterForRemoteNotificationsWithDeviceToken;
    Method originalDidFailToRegisterForRemoteNotificationsWithError;
    NSString *_uniqueIdentifier;
}

@end

@implementation CloudFiveAppDelegate : NSObject

+ (id) sharedInstance
{
    static CloudFiveAppDelegate *cfad = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cfad = [[CloudFiveAppDelegate alloc] init];
    });
    return cfad;
}

+ (void)load {
    //instantiate the singleton which will swizzle a bunch of AppDelegate methods
    [CloudFiveAppDelegate sharedInstance];
}

// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
- (id)init
{
    _uniqueIdentifier = nil;
   
    [self replaceSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)];
    [self replaceSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)];
//    [self replaceSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)];
    [self replaceSelector:@selector(application:didReceiveRemoteNotification:)];
    
    return self;
}

// Replace a selector on AppDelegate with the same named selector here
- (Method) replaceSelector:(SEL)selector
{
    Class appDelegate = NSClassFromString(@"AppDelegate");
    
    Method originalMethod = class_getInstanceMethod(appDelegate, selector);
    Method swizzledMethod = class_getInstanceMethod(self.class, selector);
    BOOL didAddMethod = class_addMethod(appDelegate,
                    selector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(self.class,
                            selector,
                            method_getImplementation(class_getInstanceMethod(self.class, @selector(noop))),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    return originalMethod;
}

-(void)noop
{
    NSLog(@"NOOP");
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"Got token: %@", deviceToken);
    NSString* apsToken = [[[[deviceToken description] stringByReplacingOccurrencesOfString:@"<"  withString:@""]
                  stringByReplacingOccurrencesOfString:@">"  withString:@""]
                 stringByReplacingOccurrencesOfString: @" " withString:@""];
    [CloudFivePush notifyCloudFiveWithToken: apsToken uniqueIdentifier:@"test"];
    
    [[CloudFiveAppDelegate sharedInstance] application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

-(void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"Error registering for push");
    //    [self sendResult:@{@"event": @"registration", @"success": @NO, @"error": [error localizedDescription]} ];
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSLog(@"didReceiveNotification");
    
    // Get application state for iOS4.x+ devices, otherwise assume active
    UIApplicationState appState = UIApplicationStateActive;
    if ([application respondsToSelector:@selector(applicationState)]) {
        appState = application.applicationState;
    }
    NSDictionary *payload = [userInfo objectForKey:@"aps"];
    NSNumber *badge = [payload objectForKey:@"badge"];
    if (badge) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[badge longValue]];
    } else {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }
    
    if (appState == UIApplicationStateActive) {
        // This method is swizzled so self is AppDelegate
        [[CloudFiveAppDelegate sharedInstance] handleForegroundNotification:userInfo];
    } else {
        //save it for later
        //[self handleBackgroundNotification:userInfo];
    }
    //TODO call original method if present
    
}

-(void)handleForegroundNotification:(NSDictionary *)userInfo
{
    
    NSDictionary *payload = [userInfo objectForKey:@"aps"];
    NSString *message = [userInfo objectForKey:@"message"];
    NSString *alert = [payload objectForKey:@"alert"];
    NSDictionary *customData = [userInfo objectForKey:@"data"];
    
    NSString *title = alert;
    NSString *detailButton = nil;
    if (customData) {
        detailButton = @"Details";
    }
    
    if (message == nil) {
        title = [[[NSBundle mainBundle] infoDictionary]  objectForKey:@"CFBundleName"];
        message = alert;
    }
    
    if (alert) {
//        self.alertUserInfo = userInfo;
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:detailButton, nil];
        [alertView show];
    }
    
//    if (customData) {
//        [self sendResult:@{@"event": @"message", @"payload": userInfo} ];
//    }
}

//- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
//    if (buttonIndex == 1) {
//        [self sendResult:@{@"event": @"interaction", @"payload": self.alertUserInfo} ];
//        self.alertUserInfo = nil;
//    }
//}

- (void) register: (NSString*)userIdentifier
{
    _uniqueIdentifier = userIdentifier;
    UIApplication *application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings
                                                settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound
                                                categories:nil];

        [application registerUserNotificationSettings:settings ];
        [application registerForRemoteNotifications];
    } else {
        [application registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
    }
}

@end