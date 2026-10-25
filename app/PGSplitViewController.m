//
//  PGSplitViewController.m
//  Papergram
//

#import "PGSplitViewController.h"
#import "PGChatListViewController.h"
#import "PGConversationViewController.h"
#import "PGPlaceholderViewController.h"
#import "PGTheme.h"

@interface PGSplitViewController () <PGChatListViewControllerDelegate>
@end

@implementation PGSplitViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        PGChatListViewController *list = [[PGChatListViewController alloc] init];
        list.delegate = self;
        UINavigationController *master = [[UINavigationController alloc] initWithRootViewController:list];

        PGPlaceholderViewController *placeholder = [[PGPlaceholderViewController alloc] init];
        UINavigationController *detail = [[UINavigationController alloc] initWithRootViewController:placeholder];

        self.viewControllers = @[master, detail];
        self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
        self.preferredPrimaryColumnWidthFraction = 0.34;
        self.minimumPrimaryColumnWidth = 280.0;
        self.maximumPrimaryColumnWidth = 380.0;
    }
    return self;
}

#pragma mark - PGChatListViewControllerDelegate

- (void)chatListViewController:(PGChatListViewController *)controller didSelectChat:(PGChat *)chat
{
    PGConversationViewController *conversation =
        [[PGConversationViewController alloc] initWithChatID:chat.identifier];
    UINavigationController *detail = [[UINavigationController alloc] initWithRootViewController:conversation];
    [self showDetailViewController:detail sender:self];
}

@end
