//
//  PGAppDelegate.m
//  Papergram
//

#import "PGAppDelegate.h"
#import "PGRootViewController.h"
#import "PGTheme.h"

@implementation PGAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [PGTheme background];
    self.window.rootViewController = [[PGRootViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
