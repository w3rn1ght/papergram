//
//  PGChatListViewController.h
//  Papergram
//

#import <UIKit/UIKit.h>
#import "PGModels.h"

@class PGChatListViewController;

@protocol PGChatListViewControllerDelegate <NSObject>
- (void)chatListViewController:(PGChatListViewController *)controller didSelectChat:(PGChat *)chat;
@end

@interface PGChatListViewController : UIViewController

@property (nonatomic, weak) id<PGChatListViewControllerDelegate> delegate;

@end
