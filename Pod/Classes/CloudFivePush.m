#import "CloudFivePush.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface CloudFivePush () {
    NSString *_uniqueIdentifier;
    NSDictionary *appImplementedSelectors;
}

@end

@implementation CloudFivePush : NSObject

+ (id)sharedInstance {
    static CloudFivePush *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CloudFivePush alloc] init];
    });
    return instance;
}

+ (void)register {
    [[CloudFivePush sharedInstance] register:nil];
}

+ (void)registerWithUserIdentifier:(NSString *)userIdentifier {
    [[CloudFivePush sharedInstance] register:userIdentifier];
}

+ (void)unregister {
    [[CloudFivePush sharedInstance] unregister:nil];
}

+ (void)unregisterWithUserIdentifier:(NSString *)userIdentifier {
    [[CloudFivePush sharedInstance] unregister:userIdentifier];
}

// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
- (id)init {
    _uniqueIdentifier = nil;
    appImplementedSelectors = [[NSMutableDictionary alloc] init];

    [self replaceSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)];
    [self replaceSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)];
    [self replaceSelector:@selector(application:didReceiveRemoteNotification:)];

    return self;
}

// Replace a selector on appDelegate with the equivalently named selector here, and put the original
// in a method called cloudfive_orig_{selector}
// Returns true if the app already implemented the method, false if we added it.
- (BOOL)replaceSelector:(SEL)selector {
    NSLog(@"Cloudfive: Replacing selector %@", NSStringFromSelector(selector));
    UIApplication *app = [UIApplication sharedApplication];
    id delegate = [app delegate];
    Class appDelegate = [delegate class];

    Method originalMethod = class_getInstanceMethod(appDelegate, selector);
    BOOL appDidImplementMethod = YES;
    if (originalMethod == NULL) {
        NSLog(@"Cloudfive: Creating method on appDelegate as noop instead");
        appDidImplementMethod = NO;
        // they didn't declare the method so create it with our noop implementation
        void (^noopBlock)(id) = ^(id _self)
        {
            NSLog(@"Cloudfive: noop block");
            return;
        };
        IMP noop_imp = imp_implementationWithBlock(noopBlock);
        class_addMethod(appDelegate, selector, noop_imp , @encode(void));
        originalMethod = class_getInstanceMethod(appDelegate, selector);
    }
    [appImplementedSelectors setValue:[NSNumber numberWithBool:appDidImplementMethod] forKey:NSStringFromSelector(selector)];

    SEL origSelector = [CloudFivePush origSelector:selector];
    Method swizzledMethod = class_getInstanceMethod(self.class, selector);
    BOOL didAddMethod = class_addMethod(appDelegate,
                                        origSelector,
                                        method_getImplementation(originalMethod),
                                        method_getTypeEncoding(originalMethod));

    if (didAddMethod) {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    } else {
        NSLog(@"Cloudfive: Something went terribly wrong, we couldn't add a method with a crazy name");
    }

    return appDidImplementMethod;
}

- (BOOL)appDidImplementSelector:(SEL)selector {
    return [[appImplementedSelectors valueForKey:NSStringFromSelector(selector)] boolValue];
}

+ (SEL)origSelector:(SEL)selector {
    return NSSelectorFromString([@"cloudfive_orig_" stringByAppendingString:NSStringFromSelector(selector)]);
}

#pragma mark appDelegate methods

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSUInteger length = deviceToken.length * 2;
    if (length == 0) {
        NSLog(@"Cloudfive: Device token is empty");
        return;
    }
    NSLog(@"Cloudfive: Got token: %@", deviceToken);
    const unsigned char *buffer = deviceToken.bytes;
    NSMutableString *apsToken = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < deviceToken.length; i++) {
        [apsToken appendFormat:@"%02x", buffer[i]];
    }

    [[CloudFivePush sharedInstance] notifyCloudFiveWithToken:[apsToken copy]];

    SEL orig = [CloudFivePush origSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector: orig withObject: application withObject: deviceToken];
#pragma clang diagnostic pop
    return;
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Cloudfive: Error registering for push: %@", [error localizedDescription]);
    // TODO show an error message or something?
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
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

    // If we're in the foreground and the app dev didn't implement the receiveRemoteNotificaiton method
    BOOL appImpl = [[CloudFivePush sharedInstance] appDidImplementSelector:@selector(application:didReceiveRemoteNotification:)];
    if (!appImpl) {
         NSLog(@"Cloudfive: Push received but didReceiveRemoteNotification was not implemented.");
    }

    SEL orig = [CloudFivePush origSelector:@selector(application:didReceiveRemoteNotification:)];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector: orig withObject: application withObject: userInfo];
#pragma clang diagnostic pop
}

- (void)register:(NSString *)userIdentifier {
    _uniqueIdentifier = userIdentifier;
    UIApplication *application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings
                                                settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound
                                                categories:nil];

        [application registerUserNotificationSettings:settings];
        [application registerForRemoteNotifications];
    } else {
        [application registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
    }
}

#pragma mark -

- (void)notifyCloudFiveWithToken:(NSString *)apsToken {
    NSLog(@"Cloudfive: notifying cloud five %@ has token %@", _uniqueIdentifier, apsToken);

    NSBundle *bundle = [NSBundle mainBundle];
    UIDevice *device = [UIDevice currentDevice];
    NSString *postData = [NSString stringWithFormat:@"bundle_identifier=%@&device_token=%@&device_platform=ios&device_name=%@&device_model=%@&device_version=%@&app_version=%@&device_identifier=%@",
                          bundle.bundleIdentifier,
                          apsToken,
                          device.name,
                          device.model,
                          device.systemVersion,
                          [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey],
                          device.identifierForVendor.UUIDString];

    if (_uniqueIdentifier != nil) {
        postData = [postData stringByAppendingFormat:@"&user_identifier=%@", _uniqueIdentifier];
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://push.cloudfiveapp.com/push/register"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [[postData stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] dataUsingEncoding:NSUTF8StringEncoding];
    NSURLConnection *conn = [NSURLConnection connectionWithRequest:request delegate:self];
    [conn start];
}

- (void)unregister:(NSString *)userIdentifier {
    NSLog(@"Cloudfive: unregistering device");

    NSBundle *bundle = [NSBundle mainBundle];
    UIDevice *device = [UIDevice currentDevice];
    NSString *postData = [NSString stringWithFormat:@"bundle_identifier=%@&device_platform=ios&device_identifier=%@", bundle.bundleIdentifier, device.identifierForVendor.UUIDString];
    if (userIdentifier != nil) {
        postData = [postData stringByAppendingFormat:@"&user_identifier=%@", userIdentifier];
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://push.cloudfiveapp.com/push/unregister"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [[postData stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] dataUsingEncoding:NSUTF8StringEncoding];
    NSURLConnection *conn = [NSURLConnection connectionWithRequest:request delegate:self];
    [conn start];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Cloudfive: Error talking to cloudfive");
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ([httpResponse statusCode] == 200) {
        NSLog(@"Cloudfive: Successfully registered!");
    } else {
        NSLog(@"Cloudfive: Couldn't register with cloudfive");
    }
}

@end
