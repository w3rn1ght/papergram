//
//  PGPlaceholderViewController.m
//  Papergram
//

#import "PGPlaceholderViewController.h"
#import "PGTheme.h"

@implementation PGPlaceholderViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [PGTheme background];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = @"Select a chat";
    title.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
    title.textColor = [PGTheme secondaryText];
    title.textAlignment = NSTextAlignmentCenter;
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:title];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitle.text = @"Your conversations will appear here.";
    subtitle.font = [UIFont systemFontOfSize:14.0];
    subtitle.textColor = [PGTheme tertiaryText];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:subtitle];

    title.tag = 100;
    subtitle.tag = 101;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    UIView *title = [self.view viewWithTag:100];
    UIView *subtitle = [self.view viewWithTag:101];
    title.frame = CGRectMake(24, CGRectGetMidY(bounds) - 26, CGRectGetWidth(bounds) - 48, 26);
    subtitle.frame = CGRectMake(24, CGRectGetMidY(bounds) + 4, CGRectGetWidth(bounds) - 48, 20);
}

@end
