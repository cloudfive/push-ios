//
//

#import <Foundation/Foundation.h>

@interface CloudFivePush : NSObject

+ (void)register;
+ (void)unregister;
+ (void)registerWithUserIdentifier:(NSString *)userIdentifier;
+ (id)sharedInstance;
+ (SEL)origSelector:(SEL)selector;
- (void)register:(NSString *)userIdentifier;
- (void)unregister:(NSString *)userIdentifier;
- (void)notifyCloudFiveWithToken:(NSString *)apsToken;
- (BOOL)appDidImplementSelector:(SEL)selector;

@end
