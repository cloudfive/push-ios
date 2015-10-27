#import "CloudFivePush.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface CloudFivePush () {
	NSString *_uniqueIdentifier;
    NSDictionary *appImplementedSelectors;
}

@end

@implementation CloudFivePush : NSObject

+ (id)sharedInstance
{
	static CloudFivePush *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[CloudFivePush alloc] init];
	});
	return instance;
}

+ (void)register
{
    [[CloudFivePush sharedInstance] register: nil];
}

+ (void)registerWithUserIdentifier:(NSString *)userIdentifier
{
    [[CloudFivePush sharedInstance] register: userIdentifier];
}

// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
- (id)init
{
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
- (BOOL)replaceSelector:(SEL)selector
{
    NSLog(@"Replacing selector %@", NSStringFromSelector(selector));
    UIApplication *app = [UIApplication sharedApplication];
    id delegate = [app delegate];
    Class appDelegate = [delegate class];

	Method originalMethod = class_getInstanceMethod(appDelegate, selector);
    BOOL appDidImplementMethod = YES;
    if (originalMethod == NULL) {
        NSLog(@"Creating method on appDelegate as noop instead");
        appDidImplementMethod = NO;
        // they didn't declare the method so create it with our noop implementation
        void (^noopBlock)(id) = ^(id _self)
        {
            NSLog(@"noop block");
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
        NSLog(@"Something went terribly wrong, we couldn't add a method with a crazy name");
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
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"Got token: %@", deviceToken);
    NSString *apsToken = [[[[deviceToken description] stringByReplacingOccurrencesOfString:@"<" withString:@""]
                                                      stringByReplacingOccurrencesOfString:@">" withString:@""]
                                                      stringByReplacingOccurrencesOfString:@" " withString:@""];


    [[CloudFivePush sharedInstance] notifyCloudFiveWithToken:apsToken];

    SEL orig = [CloudFivePush origSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector: orig withObject: application withObject: deviceToken];
    #pragma clang diagnostic pop
    return;
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
	NSLog(@"Error registering for push: %@", [error localizedDescription]);
    // TODO show an error message or something?
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{

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

    // If we're in the foreground and the app dev didn't implement the receiveRemoteNotificaiton method,
    // We show an alert by default so the notification isn't swallowed.
    BOOL appImpl = [[CloudFivePush sharedInstance] appDidImplementSelector:@selector(application:didReceiveRemoteNotification:)];
    if (appState == UIApplicationStateActive && !appImpl) {
        [[CloudFivePush sharedInstance] handleForegroundNotification:userInfo];
	}

	SEL orig = [CloudFivePush origSelector:@selector(application:didReceiveRemoteNotification:)];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector: orig withObject: application withObject: userInfo];
    #pragma clang diagnostic pop
}

- (void)handleForegroundNotification:(NSDictionary *)userInfo
{
	NSDictionary *payload = [userInfo objectForKey:@"aps"];
	NSString *message = [userInfo objectForKey:@"message"];
	NSString *alert = [payload objectForKey:@"alert"];
    if (!alert) {
        return;
    }
	NSString *title = alert;

	if (message == nil) {
		title = [[[NSBundle mainBundle] infoDictionary]  objectForKey:@"CFBundleName"];
		message = alert;
	}


    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)register:(NSString *)userIdentifier
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

#pragma mark -
- (void)notifyCloudFiveWithToken:(NSString *)apsToken
{
    NSLog(@"notifying cloud five %@ has token %@", _uniqueIdentifier, apsToken);
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
    if (_uniqueIdentifier != nil) {
        postData = [postData stringByAppendingFormat:@"&user_identifier=%@", _uniqueIdentifier];
    }

    request.HTTPBody = [postData dataUsingEncoding:NSUTF8StringEncoding];
    NSURLConnection *conn = [NSURLConnection connectionWithRequest:request delegate:self];
    [conn start];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"Error talking to cloudfive");
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    if ([httpResponse statusCode] == 200) {
        NSLog(@"Successfully registered!");
    } else {
        NSLog(@"Couldn't register with cloudfive");
    }
}

@end
