//
//  PGAuthViewController.h
//  Papergram
//

#import <UIKit/UIKit.h>
#import "PGClient.h"

@interface PGAuthViewController : UIViewController

- (void)applyAuthState:(PGAuthState)state info:(NSDictionary *)info;
- (void)showError:(NSString *)message;
- (void)resignAllFirstResponders;

@end
