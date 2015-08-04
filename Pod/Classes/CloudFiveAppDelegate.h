//
//

#import <Foundation/Foundation.h>

@interface CloudFiveAppDelegate : NSObject

+ (id)sharedInstance;
- (void)register:(NSString *)userIdentifier;

@end