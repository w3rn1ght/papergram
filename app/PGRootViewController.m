//
//  PGRootViewController.m
//  Papergram
//

#import "PGRootViewController.h"
#import "PGAuthViewController.h"
#import "PGSplitViewController.h"
#import "PGClient.h"
#import "PGTheme.h"

@interface PGRootViewController () <PGClientDelegate>
@end

@implementation PGRootViewController {
    UIViewController *_content;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [PGTheme background];

    PGClient *client = [PGClient shared];
    client.delegate = self;
    [client start];

    PGAuthState state = client.authState;
    if (state == PGAuthStateReady) {
        [self showChats];
    } else {
        [self showAuthWithState:state info:@{}];
    }
}

- (void)showAuthWithState:(PGAuthState)state info:(NSDictionary *)info
{
    if ([_content isKindOfClass:[PGAuthViewController class]]) {
        [(PGAuthViewController *)_content applyAuthState:state info:info];
        return;
    }

    PGAuthViewController *auth = [[PGAuthViewController alloc] init];
    [self setContentViewController:auth];
    [auth applyAuthState:state info:info];
}

- (void)showChats
{
    if ([_content isKindOfClass:[PGSplitViewController class]]) {
        return;
    }
    [self setContentViewController:[[PGSplitViewController alloc] init]];
}

- (void)setContentViewController:(UIViewController *)viewController
{
    if (_content == viewController) {
        return;
    }

    if (_content != nil) {
        [_content willMoveToParentViewController:nil];
        [_content.view removeFromSuperview];
        [_content removeFromParentViewController];
    }

    _content = viewController;

    if (viewController != nil) {
        [self addChildViewController:viewController];
        viewController.view.frame = self.view.bounds;
        viewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:viewController.view];
        [viewController didMoveToParentViewController:self];
    }
}

#pragma mark - PGClientDelegate

- (void)clientDidChangeAuthorizationState:(PGAuthState)state info:(NSDictionary *)info
{
    if (state == PGAuthStateReady) {
        if ([_content isKindOfClass:[PGAuthViewController class]]) {
            [(PGAuthViewController *)_content resignAllFirstResponders];
        }
        [self showChats];
    } else {
        [self showAuthWithState:state info:info];
    }
}

- (void)clientDidReceiveError:(NSString *)message
{
    if ([_content isKindOfClass:[PGAuthViewController class]]) {
        [(PGAuthViewController *)_content showError:message];
    }
}

@end
