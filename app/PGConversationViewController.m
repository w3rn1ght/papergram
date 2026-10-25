//
//  PGConversationViewController.m
//  Papergram
//

#import "PGConversationViewController.h"
#import "PGClient.h"
#import "PGComposerView.h"
#import "PGMessageCell.h"
#import "PGModels.h"
#import "PGTheme.h"

static NSString *const PGMessageCellIdentifier = @"PGMessageCell";
static const NSInteger PGHistoryPageSize = 40;
static const NSInteger PGHistoryLimit = 400;

@interface PGConversationViewController () <UITableViewDataSource, UITableViewDelegate, PGComposerViewDelegate>
@end

@implementation PGConversationViewController {
    long long _chatID;
    PGChat *_chat;

    UITableView *_tableView;
    PGComposerView *_composer;
    UILabel *_emptyLabel;
    UIRefreshControl *_refreshControl;

    NSMutableArray<PGMessage *> *_messages;
    BOOL _loadingInitial;
    BOOL _loadingOlder;
    BOOL _hasMore;
    BOOL _didInitialLoad;
    NSString *_loadError;

    CGFloat _keyboardHeight;
}

- (instancetype)initWithChatID:(long long)chatID
{
    self = [super init];
    if (self) {
        _chatID = chatID;
        _messages = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [PGTheme background];
    _chat = [[PGClient shared] chatWithID:_chatID];
    self.title = _chat.title.length > 0 ? _chat.title : @"Chat";

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [PGTheme background];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _tableView.allowsSelection = NO;
    [_tableView registerClass:[PGMessageCell class] forCellReuseIdentifier:PGMessageCellIdentifier];
    [self.view addSubview:_tableView];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(loadInitialHistory) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    _emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _emptyLabel.text = @"No messages yet";
    _emptyLabel.font = [UIFont systemFontOfSize:15.0];
    _emptyLabel.textColor = [PGTheme tertiaryText];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.userInteractionEnabled = NO;
    _emptyLabel.hidden = YES;

    _composer = [[PGComposerView alloc] initWithFrame:CGRectZero];
    _composer.delegate = self;
    [self.view addSubview:_composer];
    [self.view addSubview:_emptyLabel];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(keyboardWillChangeFrame:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(messageReceived:)
                   name:PGClientMessageReceivedNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(messageUpdated:)
                   name:PGClientMessageUpdatedNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(messageContentChanged:)
                   name:PGClientMessageContentDidChangeNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(messagesDeleted:)
                   name:PGClientMessagesDeletedNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(senderNamesChanged:)
                   name:PGClientSenderNamesDidChangeNotification
                 object:nil];

    [self loadInitialHistory];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[PGClient shared] openChat:_chatID];
    if (_didInitialLoad) {
        [self markChatRead];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[PGClient shared] closeChat:_chatID];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutContent];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    __weak typeof(self) weakSelf = self;
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [weakSelf layoutContent];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) {
            return;
        }
        [self->_tableView reloadData];
        [self scrollToBottomAnimated:NO];
    }];
}

- (void)layoutContent
{
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;

    CGFloat composerHeight = 52.0 + (_keyboardHeight > 0.0 ? 0.0 : safeBottom);
    _composer.contentBottomInset = (_keyboardHeight > 0.0 ? 0.0 : safeBottom);
    _composer.frame = CGRectMake(0, height - _keyboardHeight - composerHeight, width, composerHeight);

    CGFloat tableHeight = MAX(0.0, CGRectGetMinY(_composer.frame));
    _tableView.frame = CGRectMake(0, 0, width, tableHeight);

    _emptyLabel.frame = CGRectMake(24, (tableHeight - 80.0) / 2.0, width - 48.0, 80.0);
}

#pragma mark - History

- (void)loadInitialHistory
{
    if (_loadingInitial) {
        [_refreshControl endRefreshing];
        return;
    }
    _loadingInitial = YES;

    __weak typeof(self) weakSelf = self;
    [[PGClient shared] requestHistoryForChat:_chatID
                                 fromMessage:0
                                       limit:PGHistoryPageSize
                                  completion:^(NSArray<PGMessage *> *messages, NSString *errorMessage) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) {
            return;
        }

        self->_loadingInitial = NO;
        [self->_refreshControl endRefreshing];

        if (errorMessage.length > 0) {
            self->_loadError = errorMessage;
            [self updateEmptyState];
            return;
        }

        self->_loadError = nil;
        NSMutableArray<PGMessage *> *sorted = [NSMutableArray array];
        for (PGMessage *message in [messages reverseObjectEnumerator]) {
            [sorted addObject:message];
        }
        self->_messages = sorted;
        self->_hasMore = messages.count >= PGHistoryPageSize;
        self->_didInitialLoad = YES;

        [self->_tableView reloadData];
        [self updateEmptyState];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToBottomAnimated:NO];
        });
        [self markChatRead];
    }];
}

- (void)loadOlderHistory
{
    if (_loadingOlder || !_hasMore || _messages.count == 0) {
        return;
    }
    if (_messages.count >= PGHistoryLimit) {
        _hasMore = NO;
        return;
    }

    _loadingOlder = YES;
    long long oldestID = _messages.firstObject.identifier;
    CGSize sizeBefore = _tableView.contentSize;
    CGFloat offsetBefore = _tableView.contentOffset.y;

    __weak typeof(self) weakSelf = self;
    [[PGClient shared] requestHistoryForChat:_chatID
                                 fromMessage:oldestID
                                       limit:PGHistoryPageSize
                                  completion:^(NSArray<PGMessage *> *messages, NSString *errorMessage) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) {
            return;
        }

        self->_loadingOlder = NO;
        if (errorMessage.length > 0) {
            return;
        }

        NSMutableArray<PGMessage *> *older = [NSMutableArray array];
        for (PGMessage *message in [messages reverseObjectEnumerator]) {
            if ([self indexOfMessage:message.identifier] == NSNotFound) {
                [older addObject:message];
            }
        }

        if (older.count == 0) {
            self->_hasMore = NO;
            return;
        }

        [self->_messages insertObjects:older
                             atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, older.count)]];
        [self->_tableView reloadData];
        [self->_tableView layoutIfNeeded];

        CGFloat delta = self->_tableView.contentSize.height - sizeBefore.height;
        if (delta > 0.0) {
            self->_tableView.contentOffset = CGPointMake(0, offsetBefore + delta);
        }
        self->_hasMore = messages.count >= PGHistoryPageSize;
    }];
}

- (void)updateEmptyState
{
    if (_messages.count > 0) {
        _emptyLabel.hidden = YES;
        return;
    }

    _emptyLabel.hidden = NO;
    if (_loadError.length > 0) {
        _emptyLabel.text = [NSString stringWithFormat:@"Couldn't load messages.\n%@\n\nPull down to retry.", _loadError];
    } else if (_didInitialLoad) {
        _emptyLabel.text = @"No messages yet";
    } else {
        _emptyLabel.text = @"Loading…";
    }
}

#pragma mark - Sending

- (void)composerView:(PGComposerView *)composer didSubmitText:(NSString *)text
{
    [composer clearText];

    __weak typeof(self) weakSelf = self;
    [[PGClient shared] sendText:text toChat:_chatID completion:^(PGMessage *message, NSString *errorMessage) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) {
            return;
        }

        if (errorMessage.length > 0) {
            [composer setDraftText:text];
            [self presentSendError:errorMessage];
            return;
        }
        if (message != nil) {
            [self appendMessage:message];
        }
    }];
}

- (void)presentSendError:(NSString *)message
{
    if (self.presentedViewController != nil) {
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Message not sent"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)appendMessage:(PGMessage *)message
{
    if (message == nil || message.chatID != _chatID) {
        return;
    }
    if ([self indexOfMessage:message.identifier] != NSNotFound) {
        return;
    }

    BOOL wasAtBottom = [self isNearBottom];
    [_messages addObject:message];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)_messages.count - 1 inSection:0];
    [_tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];

    if (wasAtBottom || message.outgoing) {
        [self scrollToBottomAnimated:YES];
    }
    [self updateEmptyState];
}

#pragma mark - Notifications

- (void)messageReceived:(NSNotification *)notification
{
    PGMessage *message = notification.userInfo[PGMessageKey];
    if (![message isKindOfClass:[PGMessage class]] || message.chatID != _chatID) {
        return;
    }

    [self appendMessage:message];

    if (self.view.window != nil) {
        [self markChatRead];
    }
}

- (void)messageUpdated:(NSNotification *)notification
{
    PGMessage *message = notification.userInfo[PGMessageKey];
    if (![message isKindOfClass:[PGMessage class]] || message.chatID != _chatID) {
        return;
    }

    long long oldID = [notification.userInfo[PGOldMessageIDKey] longLongValue];
    NSUInteger index = [self indexOfMessage:oldID];
    if (index == NSNotFound) {
        index = [self indexOfMessage:message.identifier];
    }

    if (index == NSNotFound) {
        [self appendMessage:message];
        return;
    }

    BOOL wasAtBottom = [self isNearBottom];
    _messages[index] = message;
    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:(NSInteger)index inSection:0]]
                      withRowAnimation:UITableViewRowAnimationNone];
    if (wasAtBottom) {
        [self scrollToBottomAnimated:NO];
    }
}

- (void)messageContentChanged:(NSNotification *)notification
{
    if ([notification.userInfo[PGChatIDKey] longLongValue] != _chatID) {
        return;
    }

    long long messageID = [notification.userInfo[PGMessageIDKey] longLongValue];
    NSDictionary *content = notification.userInfo[PGContentKey];
    NSUInteger index = [self indexOfMessage:messageID];
    if (index == NSNotFound || ![content isKindOfClass:[NSDictionary class]]) {
        return;
    }

    [_messages[index] applyContentObject:content];
    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:(NSInteger)index inSection:0]]
                      withRowAnimation:UITableViewRowAnimationNone];
}

- (void)messagesDeleted:(NSNotification *)notification
{
    if ([notification.userInfo[PGChatIDKey] longLongValue] != _chatID) {
        return;
    }

    NSArray<NSNumber *> *identifiers = notification.userInfo[PGMessageIDsKey];
    if (![identifiers isKindOfClass:[NSArray class]] || identifiers.count == 0) {
        return;
    }

    BOOL wasAtBottom = [self isNearBottom];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    for (NSNumber *identifier in identifiers) {
        NSUInteger index = [self indexOfMessage:identifier.longLongValue];
        if (index != NSNotFound) {
            [indexes addIndex:index];
        }
    }
    if (indexes.count == 0) {
        return;
    }

    [_messages removeObjectsAtIndexes:indexes];
    [_tableView reloadData];
    [self updateEmptyState];
    if (wasAtBottom) {
        [self scrollToBottomAnimated:NO];
    }
}

- (void)senderNamesChanged:(NSNotification *)notification
{
    if (!_chat.isGroup || self.view.window == nil) {
        return;
    }
    NSArray<NSIndexPath *> *indexPaths = _tableView.indexPathsForVisibleRows;
    if (indexPaths.count > 0) {
        [_tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - Keyboard

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    CGRect frame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect converted = [self.view convertRect:frame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(converted));
    overlap = MIN(overlap, CGRectGetHeight(self.view.bounds));

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    _keyboardHeight = overlap;

    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        [self layoutContent];
    } completion:^(BOOL finished) {
        if (overlap > 0.0) {
            [self scrollToBottomAnimated:NO];
        }
    }];
}

#pragma mark - Scrolling

- (BOOL)isNearBottom
{
    if (_tableView.contentSize.height <= 0.0) {
        return YES;
    }
    CGFloat bottom = _tableView.contentOffset.y + CGRectGetHeight(_tableView.bounds);
    return (_tableView.contentSize.height - bottom) < 140.0;
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
    if (_tableView.contentSize.height <= 0.0) {
        return;
    }

    CGFloat minimum = -_tableView.contentInset.top;
    CGFloat target = _tableView.contentSize.height - CGRectGetHeight(_tableView.bounds) + _tableView.contentInset.bottom;
    if (target < minimum) {
        target = minimum;
    }
    [_tableView setContentOffset:CGPointMake(0, target) animated:animated];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != _tableView || !scrollView.isDragging) {
        return;
    }
    CGFloat top = -_tableView.contentInset.top;
    if (_tableView.contentOffset.y < top + 60.0) {
        [self loadOlderHistory];
    }
}

#pragma mark - Helpers

- (void)markChatRead
{
    long long latestID = 0;
    for (PGMessage *message in [_messages reverseObjectEnumerator]) {
        if (message.identifier > 0) {
            latestID = message.identifier;
            break;
        }
    }
    [[PGClient shared] markChatRead:_chatID upToMessageID:latestID];
}

- (NSUInteger)indexOfMessage:(long long)identifier
{
    if (identifier == 0) {
        return NSNotFound;
    }
    for (NSUInteger index = 0; index < _messages.count; index++) {
        if (_messages[index].identifier == identifier) {
            return index;
        }
    }
    return NSNotFound;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)_messages.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PGMessage *message = _messages[(NSUInteger)indexPath.row];
    return [message heightForWidth:CGRectGetWidth(tableView.bounds)];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PGMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:PGMessageCellIdentifier
                                                         forIndexPath:indexPath];
    [cell configureWithMessage:_messages[(NSUInteger)indexPath.row]];
    return cell;
}

@end
