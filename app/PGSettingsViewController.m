//
//  PGSettingsViewController.m
//  Papergram
//

#import "PGSettingsViewController.h"
#import "PGClient.h"
#import "PGConfig.h"
#import "PGTheme.h"

static NSString *const PGRepositoryURL = @"https://github.com/w3rn1ght/papergram";
static NSString *const PGIssuesURL = @"https://github.com/w3rn1ght/papergram/issues";

@implementation PGSettingsViewController

- (instancetype)init
{
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Settings";
    self.view.backgroundColor = [PGTheme background];
    self.tableView.backgroundColor = [PGTheme background];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(done)];
}

- (void)done
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return 2;
        case 1:
            return 2;
        default:
            return 2;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"Account";
        case 1:
            return @"About";
        default:
            return @"Links";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section != 2) {
        return nil;
    }
    return @"Papergram is an independent, open-source client. It is not affiliated with Telegram Messenger LLP.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const valueCell = @"PGValueCell";
    static NSString *const actionCell = @"PGActionCell";

    BOOL isValueRow = (indexPath.section == 0 && indexPath.row == 0) ||
                      indexPath.section == 1;
    NSString *identifier = isValueRow ? valueCell : actionCell;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        UITableViewCellStyle style = isValueRow ? UITableViewCellStyleValue1 : UITableViewCellStyleDefault;
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
        cell.backgroundColor = [PGTheme cardBackground];
    }

    cell.textLabel.textColor = [PGTheme primaryText];
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.detailTextLabel.textColor = [PGTheme secondaryText];
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"Signed in as";
        NSString *name = [PGClient shared].currentUserName;
        cell.detailTextLabel.text = name.length > 0 ? name : @"…";
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        cell.textLabel.text = @"Log out";
        cell.textLabel.textColor = [PGTheme danger];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        cell.textLabel.text = @"Version";
        cell.detailTextLabel.text = [PGConfig applicationVersion];
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        cell.textLabel.text = @"TDLib";
        cell.detailTextLabel.text = @"1.8.0";
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        cell.textLabel.text = @"Source code";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text = @"Report an issue";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.row == 0) {
        return nil;
    }
    if (indexPath.section == 1) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 1) {
        [self confirmLogout];
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        [self openURLString:PGRepositoryURL];
    } else if (indexPath.section == 2 && indexPath.row == 1) {
        [self openURLString:PGIssuesURL];
    }
}

- (void)confirmLogout
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Log out?"
                                                                   message:@"The session will be removed from this device. You can sign in again with a code."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Log out"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) {
            return;
        }
        [[PGClient shared] logout];
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openURLString:(NSString *)string
{
    NSURL *url = [NSURL URLWithString:string];
    if (url == nil) {
        return;
    }
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
