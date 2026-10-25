//
//  PGChatListViewController.m
//  Papergram
//

#import "PGChatListViewController.h"
#import "PGChatCell.h"
#import "PGClient.h"
#import "PGSettingsViewController.h"
#import "PGTheme.h"
#import "PGUIKit.h"

static NSString *const PGChatCellIdentifier = @"PGChatCell";

@interface PGChatListViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation PGChatListViewController {
    UITableView *_tableView;
    NSArray<PGChat *> *_chats;
    PGTitleView *_titleView;
    UIRefreshControl *_refreshControl;
    UILabel *_emptyLabel;
    BOOL _reloadScheduled;
}- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [PGTheme background];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 68.0;
    _tableView.backgroundColor = [PGTheme cardBackground];
    _tableView.separatorInset = UIEdgeInsetsMake(0, 76, 0, 0);
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_tableView registerClass:[PGChatCell class] forCellReuseIdentifier:PGChatCellIdentifier];
    [self.view addSubview:_tableView];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(refreshChats) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    _emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _emptyLabel.text = @"No chats yet\n\nPull down to refresh.";
    _emptyLabel.font = [UIFont systemFontOfSize:15.0];
    _emptyLabel.textColor = [PGTheme tertiaryText];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.userInteractionEnabled = NO;
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    _titleView = [[PGTitleView alloc] initWithFrame:CGRectMake(0, 0, 170, 44)];
    self.navigationItem.titleView = _titleView;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Settings"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(openSettings)];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(chatListDidChange:)
                   name:PGClientChatListDidChangeNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(connectionDidChange:)
                   name:PGClientConnectionDidChangeNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationDidBecomeActive:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];

    [self reloadChats];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadChats];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _tableView.frame = self.view.bounds;
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    _emptyLabel.frame = CGRectMake(24, (height - 90.0) / 2.0, width - 48.0, 90.0);
}

#pragma mark - Data

- (void)reloadChats
{
    _chats = [[PGClient shared] chats];
    [_tableView reloadData];
    _emptyLabel.hidden = (_chats.count > 0);
    [self updateTitle];
}

- (void)updateTitle
{
    NSString *subtitle = @"";
    switch ([PGClient shared].connectionState) {
        case PGConnectionStateConnecting:
            subtitle = @"Connecting…";
            break;
        case PGConnectionStateWaitingForNetwork:
            subtitle = @"Waiting for network…";
            break;
        case PGConnectionStateUpdating:
            subtitle = @"Updating…";
            break;
        default:
            subtitle = @"";
            break;
    }
    [_titleView setTitle:@"Papergram" subtitle:subtitle];
}

- (void)scheduleReload
{
    if (_reloadScheduled) {
        return;
    }
    _reloadScheduled = YES;

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) {
            return;
        }
        self->_reloadScheduled = NO;
        [self reloadChats];
    });
}

#pragma mark - Actions

- (void)refreshChats
{
    [[PGClient shared] loadChats];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf->_refreshControl endRefreshing];
    });
}

- (void)openSettings
{
    PGSettingsViewController *settings = [[PGSettingsViewController alloc] init];
    UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:settings];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navigation animated:YES completion:nil];
}

#pragma mark - Notifications

- (void)chatListDidChange:(NSNotification *)notification
{
    [self scheduleReload];
}

- (void)connectionDidChange:(NSNotification *)notification
{
    [self updateTitle];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self scheduleReload];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)_chats.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PGChatCell *cell = [tableView dequeueReusableCellWithIdentifier:PGChatCellIdentifier
                                                      forIndexPath:indexPath];
    [cell configureWithChat:_chats[(NSUInteger)indexPath.row]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ((NSUInteger)indexPath.row >= _chats.count) {
        return;
    }
    [self.delegate chatListViewController:self didSelectChat:_chats[(NSUInteger)indexPath.row]];
}

@end
