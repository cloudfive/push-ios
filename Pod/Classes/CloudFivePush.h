//
//

#import <Foundation/Foundation.h>

@interface CloudFivePush : NSObject

+ (void)register;
+ (void)registerWithUserIdentifier:(NSString *)userIdentifier;
+ (void)unregister;
+ (void)unregisterWithUserIdentifier:(NSString *)userIdentifier;
+ (id)sharedInstance;
+ (SEL)origSelector:(SEL)selector;
- (void)register:(NSString *)userIdentifier;
- (void)notifyCloudFiveWithToken:(NSString *)apsToken;
- (BOOL)appDidImplementSelector:(SEL)selector;

@end
