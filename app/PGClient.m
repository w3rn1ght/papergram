//
//  PGClient.m
//  Papergram
//

#import "PGClient.h"
#import "PGConfig.h"
#import "PGFormatters.h"

#import <td/telegram/td_json_client.h>
#import <td/telegram/td_log.h>

NSString *const PGAuthInfoCodeInfoKey = @"codeInfo";
NSString *const PGAuthInfoPasswordHintKey = @"passwordHint";
NSString *const PGAuthInfoLinkKey = @"link";

NSString *const PGClientChatListDidChangeNotification = @"PGClientChatListDidChange";
NSString *const PGClientConnectionDidChangeNotification = @"PGClientConnectionDidChange";
NSString *const PGClientMessageReceivedNotification = @"PGClientMessageReceived";
NSString *const PGClientMessageUpdatedNotification = @"PGClientMessageUpdated";
NSString *const PGClientMessageContentDidChangeNotification = @"PGClientMessageContentDidChange";
NSString *const PGClientMessagesDeletedNotification = @"PGClientMessagesDeleted";
NSString *const PGClientChatReadNotification = @"PGClientChatRead";
NSString *const PGClientSenderNamesDidChangeNotification = @"PGClientSenderNamesDidChange";

NSString *const PGMessageKey = @"message";
NSString *const PGOldMessageIDKey = @"oldMessageID";
NSString *const PGChatIDKey = @"chatID";
NSString *const PGMessageIDKey = @"messageID";
NSString *const PGMessageIDsKey = @"messageIDs";
NSString *const PGContentKey = @"content";

#pragma mark - JSON helpers

static NSString *PGJSONString(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSDictionary *PGJSONDictionary(id value)
{
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray *PGJSONArray(id value)
{
    return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static long long PGJSONInt(id value)
{
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
        return [value longLongValue];
    }
    return 0;
}

static NSArray<NSNumber *> *PGJSONIntegerArray(id value)
{
    NSMutableArray<NSNumber *> *result = [NSMutableArray array];
    for (id item in PGJSONArray(value)) {
        if ([item isKindOfClass:[NSNumber class]] || [item isKindOfClass:[NSString class]]) {
            [result addObject:@([item longLongValue])];
        }
    }
    return result;
}

@implementation PGClient {
    void *_client;
    NSThread *_receiveThread;
    volatile BOOL _stopping;
    volatile BOOL _receiveFinished;
    BOOL _started;
    BOOL _restartScheduled;

    NSMutableDictionary<NSString *, void (^)(NSDictionary *)> *_pending;
    NSUInteger _nextExtra;

    NSMutableDictionary<NSNumber *, PGChat *> *_chats;
    NSMutableDictionary<NSNumber *, NSString *> *_userNames;
    NSMutableDictionary<NSNumber *, NSString *> *_chatTitles;
    NSMutableSet<NSNumber *> *_requestedUsers;

    PGAuthState _authState;
    PGConnectionState _connectionState;
    NSString *_currentUserName;
}

+ (instancetype)shared
{
    static PGClient *client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [[PGClient alloc] init];
    });
    return client;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _pending = [NSMutableDictionary dictionary];
        _chats = [NSMutableDictionary dictionary];
        _userNames = [NSMutableDictionary dictionary];
        _chatTitles = [NSMutableDictionary dictionary];
        _requestedUsers = [NSMutableSet set];
        _authState = PGAuthStateUnknown;
        _connectionState = PGConnectionStateUnknown;
    }
    return self;
}

- (PGAuthState)authState
{
    return _authState;
}

- (PGConnectionState)connectionState
{
    return _connectionState;
}

- (NSString *)currentUserName
{
    return _currentUserName;
}

#pragma mark - Lifecycle

- (void)start
{
    if (_started) {
        return;
    }
    _started = YES;

    NSString *directory = [PGConfig dataDirectory];
    NSString *logPath = [directory stringByAppendingPathComponent:@"tdlib.log"];
    td_set_log_file_path(logPath.UTF8String);
    td_set_log_max_file_size(2 * 1024 * 1024);
    td_set_log_verbosity_level((int)[PGConfig logVerbosity]);

    _client = td_json_client_create();
    if (_client == NULL) {
        [self deliverError:@"Failed to initialize the Telegram library."];
        return;
    }

    _receiveThread = [[NSThread alloc] initWithTarget:self selector:@selector(receiveLoop) object:nil];
    _receiveThread.name = @"papergram.tdlib.receive";
    _receiveThread.qualityOfService = NSQualityOfServiceUtility;
    [_receiveThread start];

    [self sendRequest:@{@"@type": @"getAuthorizationState"} completion:nil];
}

- (void)receiveLoop
{
    while (!_stopping) {
        @autoreleasepool {
            if (_client == NULL) {
                [NSThread sleepForTimeInterval:0.2];
                continue;
            }

            const char *response = td_json_client_receive(_client, 0.5);
            if (response == NULL) {
                continue;
            }

            NSString *json = [[NSString alloc] initWithUTF8String:response];
            if (json.length == 0) {
                continue;
            }

            NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
            id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
            if (![object isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self handleObject:object];
            });
        }
    }
    _receiveFinished = YES;
}

#pragma mark - Requests

- (void)sendRequest:(NSDictionary *)request completion:(void (^)(NSDictionary *))completion
{
    if (_client == NULL || request == nil) {
        return;
    }

    NSMutableDictionary *payload = [request mutableCopy];
    NSString *extra = nil;
    if (completion != nil) {
        extra = [NSString stringWithFormat:@"%lu", (unsigned long)(++_nextExtra)];
        payload[@"@extra"] = extra;
        _pending[extra] = [completion copy];
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    if (data == nil) {
        if (extra != nil) {
            [_pending removeObjectForKey:extra];
        }
        return;
    }

    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    td_json_client_send(_client, json.UTF8String);
}

- (void)handleObject:(NSDictionary *)object
{
    NSString *type = PGJSONString(object[@"@type"]);
    if (type.length == 0) {
        return;
    }

    NSString *extra = nil;
    id extraValue = object[@"@extra"];
    if ([extraValue isKindOfClass:[NSString class]]) {
        extra = extraValue;
    }

    void (^completion)(NSDictionary *) = nil;
    if (extra.length > 0) {
        completion = _pending[extra];
        if (completion != nil) {
            [_pending removeObjectForKey:extra];
        }
    }

    if ([type isEqualToString:@"error"]) {
        if (completion == nil) {
            [self deliverError:[self friendlyErrorForObject:object]];
        }
        if (completion != nil) {
            completion(object);
        }
        return;
    }

    if (completion != nil) {
        completion(object);
        return;
    }

    if ([type isEqualToString:@"updateAuthorizationState"]) {
        [self applyAuthorizationState:PGJSONDictionary(object[@"authorization_state"])];
    } else if ([type isEqualToString:@"updateConnectionState"]) {
        [self applyConnectionState:PGJSONDictionary(object[@"state"])];
    } else if ([type isEqualToString:@"updateNewChat"]) {
        [self applyChatObject:PGJSONDictionary(object[@"chat"])];
    } else if ([type isEqualToString:@"updateChatLastMessage"]) {
        [self handleChatLastMessage:object];
    } else if ([type isEqualToString:@"updateChatTitle"]) {
        [self handleChatTitle:object];
    } else if ([type isEqualToString:@"updateChatReadInbox"]) {
        [self handleChatReadInbox:object];
    } else if ([type isEqualToString:@"updateChatUnreadMentionCount"]) {
        [self handleChatUnreadMentionCount:object];
    } else if ([type isEqualToString:@"updateChatPosition"]) {
        [self handleChatPosition:object];
    } else if ([type isEqualToString:@"updateNewMessage"]) {
        [self handleNewMessage:object];
    } else if ([type isEqualToString:@"updateMessageSendSucceeded"]) {
        [self handleMessageSendSucceeded:object];
    } else if ([type isEqualToString:@"updateMessageSendFailed"]) {
        [self handleMessageSendFailed:object];
    } else if ([type isEqualToString:@"updateMessageContent"]) {
        [self handleMessageContent:object];
    } else if ([type isEqualToString:@"updateDeleteMessages"]) {
        [self handleDeleteMessages:object];
    } else if ([type isEqualToString:@"updateUser"]) {
        [self storeUserObject:PGJSONDictionary(object[@"user"])];
    }
}

#pragma mark - Authorization

- (void)applyAuthorizationState:(NSDictionary *)state
{
    NSString *type = PGJSONString(state[@"@type"]);
    PGAuthState newState = PGAuthStateUnknown;
    NSMutableDictionary *info = [NSMutableDictionary dictionary];

    if ([type isEqualToString:@"authorizationStateWaitTdlibParameters"]) {
        if ([PGConfig hasCredentials]) {
            [self sendTdlibParameters];
            newState = PGAuthStateWaitParameters;
        } else {
            newState = PGAuthStateNeedsCredentials;
        }
    } else if ([type isEqualToString:@"authorizationStateWaitEncryptionKey"]) {
        [self sendRequest:@{@"@type": @"checkDatabaseEncryptionKey",
                            @"encryption_key": @""}
               completion:nil];
        newState = PGAuthStateWaitEncryptionKey;
    } else if ([type isEqualToString:@"authorizationStateWaitPhoneNumber"]) {
        [self resetAccountCaches];
        newState = PGAuthStateWaitPhoneNumber;
    } else if ([type isEqualToString:@"authorizationStateWaitCode"]) {
        NSDictionary *codeInfo = PGJSONDictionary(state[@"code_info"]);
        if (codeInfo != nil) {
            info[PGAuthInfoCodeInfoKey] = codeInfo;
        }
        newState = PGAuthStateWaitCode;
    } else if ([type isEqualToString:@"authorizationStateWaitPassword"]) {
        info[PGAuthInfoPasswordHintKey] = PGJSONString(state[@"password_hint"]);
        newState = PGAuthStateWaitPassword;
    } else if ([type isEqualToString:@"authorizationStateWaitRegistration"]) {
        newState = PGAuthStateWaitRegistration;
    } else if ([type isEqualToString:@"authorizationStateWaitOtherDeviceConfirmation"]) {
        info[PGAuthInfoLinkKey] = PGJSONString(state[@"link"]);
        newState = PGAuthStateWaitOtherDevice;
    } else if ([type isEqualToString:@"authorizationStateReady"]) {
        newState = PGAuthStateReady;
    } else if ([type isEqualToString:@"authorizationStateLoggingOut"]) {
        newState = PGAuthStateLoggingOut;
    } else if ([type isEqualToString:@"authorizationStateClosed"]) {
        newState = PGAuthStateClosed;
    }

    _authState = newState;

    if (newState == PGAuthStateReady) {
        [self loadChats];
        [self loadCurrentUser];
    } else if (newState == PGAuthStateClosed) {
        [self scheduleRestartAfterClose];
    }

    if ([self.delegate respondsToSelector:@selector(clientDidChangeAuthorizationState:info:)]) {
        [self.delegate clientDidChangeAuthorizationState:newState info:info];
    }
}

- (void)retryWithCredentials
{
    if (_authState != PGAuthStateNeedsCredentials) {
        return;
    }
    [self sendTdlibParameters];
    _authState = PGAuthStateWaitParameters;
    if ([self.delegate respondsToSelector:@selector(clientDidChangeAuthorizationState:info:)]) {
        [self.delegate clientDidChangeAuthorizationState:_authState info:@{}];
    }
}

/// TDLib cannot be reused after authorizationStateClosed (for example after
/// an explicit logout). The old instance is torn down and a fresh one is
/// created so that the user can sign in again without relaunching the app.
- (void)scheduleRestartAfterClose
{
    if (_restartScheduled) {
        return;
    }
    _restartScheduled = YES;
    _stopping = YES;
    [self waitForReceiverAndRestart:0];
}

- (void)waitForReceiverAndRestart:(NSInteger)attempt
{
    if (!_receiveFinished && attempt < 50) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf waitForReceiverAndRestart:attempt + 1];
        });
        return;
    }

    if (_client != NULL) {
        td_json_client_destroy(_client);
        _client = NULL;
    }
    [_pending removeAllObjects];

    _restartScheduled = NO;
    _stopping = NO;
    _receiveFinished = NO;

    _client = td_json_client_create();
    if (_client == NULL) {
        [self deliverError:@"Failed to restart the Telegram library."];
        return;
    }

    _receiveThread = [[NSThread alloc] initWithTarget:self selector:@selector(receiveLoop) object:nil];
    _receiveThread.name = @"papergram.tdlib.receive";
    _receiveThread.qualityOfService = NSQualityOfServiceUtility;
    [_receiveThread start];

    [self sendRequest:@{@"@type": @"getAuthorizationState"} completion:nil];
}

- (void)sendTdlibParameters
{
    NSString *root = [PGConfig dataDirectory];
    NSString *database = [root stringByAppendingPathComponent:@"database"];
    NSString *files = [root stringByAppendingPathComponent:@"files"];

    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:database withIntermediateDirectories:YES attributes:nil error:NULL];
    [manager createDirectoryAtPath:files withIntermediateDirectories:YES attributes:nil error:NULL];

    NSDictionary *parameters = @{
        @"use_test_dc": @NO,
        @"database_directory": database,
        @"files_directory": files,
        @"use_file_database": @NO,
        @"use_chat_info_database": @YES,
        @"use_message_database": @YES,
        @"use_secret_chats": @NO,
        @"api_id": @([PGConfig apiID]),
        @"api_hash": [PGConfig apiHash],
        @"system_language_code": @"en",
        @"device_model": [PGConfig deviceModel],
        @"system_version": [PGConfig systemVersion],
        @"application_version": [PGConfig applicationVersion],
        @"enable_storage_optimizer": @YES,
        @"ignore_file_names": @NO,
    };

    [self sendRequest:@{@"@type": @"setTdlibParameters", @"parameters": parameters} completion:nil];
}

- (void)resetAccountCaches
{
    [_chats removeAllObjects];
    [_userNames removeAllObjects];
    [_chatTitles removeAllObjects];
    [_requestedUsers removeAllObjects];
    _currentUserName = nil;
    [self postChatListChange];
}

- (void)setPhoneNumber:(NSString *)phoneNumber
{
    NSDictionary *request = @{
        @"@type": @"setAuthenticationPhoneNumber",
        @"phone_number": phoneNumber ?: @"",
        @"settings": [NSNull null],
    };
    [self sendRequest:request completion:nil];
}

- (void)submitCode:(NSString *)code
{
    [self sendRequest:@{@"@type": @"checkAuthenticationCode", @"code": code ?: @""} completion:nil];
}

- (void)submitPassword:(NSString *)password
{
    [self sendRequest:@{@"@type": @"checkAuthenticationPassword", @"password": password ?: @""} completion:nil];
}

- (void)registerFirstName:(NSString *)firstName lastName:(NSString *)lastName
{
    NSDictionary *request = @{
        @"@type": @"registerUser",
        @"first_name": firstName ?: @"",
        @"last_name": lastName ?: @"",
    };
    [self sendRequest:request completion:nil];
}

- (void)resendCode
{
    [self sendRequest:@{@"@type": @"resendAuthenticationCode"} completion:nil];
}

- (void)logout
{
    [self sendRequest:@{@"@type": @"logOut"} completion:nil];
}

#pragma mark - Connection state

- (void)applyConnectionState:(NSDictionary *)state
{
    NSString *type = PGJSONString(state[@"@type"]);
    PGConnectionState newState = PGConnectionStateUnknown;

    if ([type isEqualToString:@"connectionStateReady"]) {
        newState = PGConnectionStateReady;
    } else if ([type isEqualToString:@"connectionStateWaitingForNetwork"]) {
        newState = PGConnectionStateWaitingForNetwork;
    } else if ([type isEqualToString:@"connectionStateConnecting"] ||
               [type isEqualToString:@"connectionStateConnectingToProxy"]) {
        newState = PGConnectionStateConnecting;
    } else if ([type isEqualToString:@"connectionStateUpdating"]) {
        newState = PGConnectionStateUpdating;
    }

    _connectionState = newState;
    if ([self.delegate respondsToSelector:@selector(clientDidChangeConnectionState:)]) {
        [self.delegate clientDidChangeConnectionState:newState];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientConnectionDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"state": @(newState)}];
}

- (void)loadCurrentUser
{
    [self sendRequest:@{@"@type": @"getMe"} completion:^(NSDictionary *result) {
        if (![PGJSONString(result[@"@type"]) isEqualToString:@"user"]) {
            return;
        }
        self->_currentUserName = [self displayNameForUserObject:result];
    }];
}

#pragma mark - Chats

- (NSArray<PGChat *> *)chats
{
    NSArray<PGChat *> *values = [_chats allValues];
    return [values sortedArrayUsingComparator:^NSComparisonResult(PGChat *left, PGChat *right) {
        if (left.lastMessageDate != right.lastMessageDate) {
            return left.lastMessageDate > right.lastMessageDate ? NSOrderedAscending : NSOrderedDescending;
        }
        return [left.title localizedCaseInsensitiveCompare:right.title];
    }];
}

- (PGChat *)chatWithID:(long long)chatID
{
    return _chats[@(chatID)];
}

- (void)loadChats
{
    NSDictionary *request = @{
        @"@type": @"getChats",
        @"chat_list": @{@"@type": @"chatListMain"},
        @"limit": @100,
    };
    [self sendRequest:request completion:^(NSDictionary *result) {
        for (NSNumber *chatID in PGJSONIntegerArray(result[@"chat_ids"])) {
            if (self->_chats[chatID] == nil) {
                [self requestChat:chatID.longLongValue];
            }
        }
    }];
}

- (void)requestChat:(long long)chatID
{
    if (chatID == 0) {
        return;
    }
    [self sendRequest:@{@"@type": @"getChat", @"chat_id": @(chatID)} completion:^(NSDictionary *result) {
        if ([PGJSONString(result[@"@type"]) isEqualToString:@"chat"]) {
            [self applyChatObject:result];
        }
    }];
}

- (void)applyChatObject:(NSDictionary *)object
{
    long long chatID = PGJSONInt(object[@"id"]);
    if (chatID == 0) {
        return;
    }

    PGChat *chat = _chats[@(chatID)];
    if (chat == nil) {
        chat = [[PGChat alloc] init];
        _chats[@(chatID)] = chat;
    }
    [chat applyChatObject:object];

    if (chat.title.length > 0) {
        _chatTitles[@(chatID)] = chat.title;
    }

    [self postChatListChange];
}

- (void)handleChatLastMessage:(NSDictionary *)object
{
    long long chatID = PGJSONInt(object[@"chat_id"]);
    PGChat *chat = _chats[@(chatID)];
    if (chat == nil) {
        return;
    }

    id lastMessage = object[@"last_message"];
    NSDictionary *message = [lastMessage isKindOfClass:[NSDictionary class]] ? lastMessage : nil;
    [chat applyLastMessageObject:message];
    [self postChatListChange];
}

- (void)handleChatTitle:(NSDictionary *)object
{
    long long chatID = PGJSONInt(object[@"chat_id"]);
    PGChat *chat = _chats[@(chatID)];
    if (chat == nil) {
        return;
    }
    NSString *title = PGJSONString(object[@"title"]);
    chat.title = title;
    _chatTitles[@(chatID)] = title;
    [self postChatListChange];
}

- (void)handleChatReadInbox:(NSDictionary *)object
{
    long long chatID = PGJSONInt(object[@"chat_id"]);
    PGChat *chat = _chats[@(chatID)];
    if (chat == nil) {
        return;
    }
    chat.unreadCount = (NSInteger)PGJSONInt(object[@"unread_count"]);
    [self postChatListChange];

    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientChatReadNotification
                                                        object:self
                                                      userInfo:@{PGChatIDKey: @(chatID)}];
}

- (void)handleChatUnreadMentionCount:(NSDictionary *)object
{
    long long chatID = PGJSONInt(object[@"chat_id"]);
    PGChat *chat = _chats[@(chatID)];
    if (chat == nil) {
        return;
    }
    chat.mentionCount = (NSInteger)PGJSONInt(object[@"unread_mention_count"]);
    [self postChatListChange];
}

- (void)handleChatPosition:(NSDictionary *)object
{
    long long chatID = PGJSONInt(object[@"chat_id"]);
    NSDictionary *position = PGJSONDictionary(object[@"position"]);
    NSDictionary *list = PGJSONDictionary(position[@"list"]);
    NSString *listType = PGJSONString(list[@"@type"]);

    if (![listType isEqualToString:@"chatListMain"]) {
        return;
    }

    if (PGJSONInt(position[@"order"]) == 0) {
        if (_chats[@(chatID)] != nil) {
            [_chats removeObjectForKey:@(chatID)];
            [self postChatListChange];
        }
    }
}

#pragma mark - Messages

- (void)handleNewMessage:(NSDictionary *)object
{
    NSDictionary *messageObject = PGJSONDictionary(object[@"message"]);
    PGMessage *message = [self messageFromObject:messageObject];
    if (message == nil) {
        return;
    }

    PGChat *chat = _chats[@(message.chatID)];
    if (chat != nil && message.date >= chat.lastMessageDate) {
        [chat applyLastMessageObject:messageObject];
        [self postChatListChange];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientMessageReceivedNotification
                                                        object:self
                                                      userInfo:@{PGMessageKey: message}];
}

- (void)handleMessageSendSucceeded:(NSDictionary *)object
{
    NSDictionary *messageObject = PGJSONDictionary(object[@"message"]);
    PGMessage *message = [self messageFromObject:messageObject];
    if (message == nil) {
        return;
    }

    long long oldMessageID = PGJSONInt(object[@"old_message_id"]);
    PGChat *chat = _chats[@(message.chatID)];
    if (chat != nil && message.date >= chat.lastMessageDate) {
        [chat applyLastMessageObject:messageObject];
        [self postChatListChange];
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[PGMessageKey] = message;
    userInfo[PGOldMessageIDKey] = @(oldMessageID);
    userInfo[PGChatIDKey] = @(message.chatID);
    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientMessageUpdatedNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)handleMessageSendFailed:(NSDictionary *)object
{
    NSDictionary *messageObject = PGJSONDictionary(object[@"message"]);
    PGMessage *message = [self messageFromObject:messageObject];
    if (message == nil) {
        return;
    }

    message.failed = YES;
    message.failureReason = PGJSONString(object[@"error_message"]);
    long long oldMessageID = PGJSONInt(object[@"old_message_id"]);

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[PGMessageKey] = message;
    userInfo[PGOldMessageIDKey] = @(oldMessageID);
    userInfo[PGChatIDKey] = @(message.chatID);
    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientMessageUpdatedNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)handleMessageContent:(NSDictionary *)object
{
    long long chatID = PGJSONInt(object[@"chat_id"]);
    long long messageID = PGJSONInt(object[@"message_id"]);
    NSDictionary *content = PGJSONDictionary(object[@"new_content"]);
    if (content == nil) {
        return;
    }

    NSDictionary *userInfo = @{
        PGChatIDKey: @(chatID),
        PGMessageIDKey: @(messageID),
        PGContentKey: content,
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientMessageContentDidChangeNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)handleDeleteMessages:(NSDictionary *)object
{
    long long chatID = PGJSONInt(object[@"chat_id"]);
    NSArray<NSNumber *> *messageIDs = PGJSONIntegerArray(object[@"message_ids"]);
    if (messageIDs.count == 0) {
        return;
    }

    NSDictionary *userInfo = @{PGChatIDKey: @(chatID), PGMessageIDsKey: messageIDs};
    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientMessagesDeletedNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (PGMessage *)messageFromObject:(NSDictionary *)object
{
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    PGMessage *message = [[PGMessage alloc] initWithMessageObject:object];
    if (message.identifier == 0) {
        return nil;
    }

    PGChat *chat = _chats[@(message.chatID)];
    if (chat.isGroup && !message.outgoing && !message.service) {
        message.senderName = [self senderNameForSender:PGJSONDictionary(object[@"sender_id"])];
    }
    return message;
}

- (void)requestHistoryForChat:(long long)chatID
                  fromMessage:(long long)fromMessageID
                        limit:(NSInteger)limit
                   completion:(void (^)(NSArray<PGMessage *> *, NSString *))completion
{
    NSDictionary *request = @{
        @"@type": @"getChatHistory",
        @"chat_id": @(chatID),
        @"from_message_id": @(fromMessageID),
        @"offset": @0,
        @"limit": @(limit),
        @"only_local": @NO,
    };

    [self sendRequest:request completion:^(NSDictionary *result) {
        NSString *resultType = PGJSONString(result[@"@type"]);
        if ([resultType isEqualToString:@"error"]) {
            if (completion != nil) {
                completion(@[], [self friendlyErrorForObject:result]);
            }
            return;
        }

        NSMutableArray<PGMessage *> *messages = [NSMutableArray array];
        for (id item in PGJSONArray(result[@"messages"])) {
            PGMessage *message = [self messageFromObject:PGJSONDictionary(item)];
            if (message != nil) {
                [messages addObject:message];
            }
        }
        if (completion != nil) {
            completion(messages, nil);
        }
    }];
}

- (void)sendText:(NSString *)text
          toChat:(long long)chatID
      completion:(void (^)(PGMessage *, NSString *))completion
{
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        if (completion != nil) {
            completion(nil, @"The message is empty.");
        }
        return;
    }

    NSDictionary *request = @{
        @"@type": @"sendMessage",
        @"chat_id": @(chatID),
        @"message_thread_id": @0,
        @"reply_to_message_id": @0,
        @"options": @{
            @"disable_notification": @NO,
            @"from_background": @NO,
            @"scheduling_state": [NSNull null],
        },
        @"reply_markup": [NSNull null],
        @"input_message_content": @{
            @"@type": @"inputMessageText",
            @"text": @{
                @"text": text,
                @"entities": @[],
            },
            @"disable_web_page_preview": @NO,
            @"clear_draft": @NO,
        },
    };

    [self sendRequest:request completion:^(NSDictionary *result) {
        if ([PGJSONString(result[@"@type"]) isEqualToString:@"error"]) {
            if (completion != nil) {
                completion(nil, [self friendlyErrorForObject:result]);
            }
            return;
        }

        PGMessage *message = [[PGMessage alloc] initWithMessageObject:result];
        message.chatID = chatID;

        PGChat *chat = self->_chats[@(chatID)];
        if (chat != nil) {
            [chat applyLastMessageObject:result];
            [self postChatListChange];
        }

        if (completion != nil) {
            completion(message, nil);
        }
    }];
}

- (void)markChatRead:(long long)chatID
{
    PGChat *chat = _chats[@(chatID)];
    chat.unreadCount = 0;
    chat.markedAsUnread = NO;
    [self postChatListChange];

    NSDictionary *request = @{
        @"@type": @"viewMessages",
        @"chat_id": @(chatID),
        @"message_thread_id": @0,
        @"message_ids": @[],
        @"force_read": @YES,
    };
    [self sendRequest:request completion:nil];
}

- (void)openChat:(long long)chatID
{
    [self sendRequest:@{@"@type": @"openChat", @"chat_id": @(chatID)} completion:nil];
}

- (void)closeChat:(long long)chatID
{
    [self sendRequest:@{@"@type": @"closeChat", @"chat_id": @(chatID)} completion:nil];
}

#pragma mark - Sender names

- (NSString *)displayNameForUserObject:(NSDictionary *)user
{
    NSString *firstName = PGJSONString(user[@"first_name"]);
    NSString *lastName = PGJSONString(user[@"last_name"]);
    NSString *name = [[firstName stringByAppendingFormat:@" %@", lastName]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (name.length > 0) {
        return name;
    }
    NSString *username = PGJSONString(user[@"username"]);
    if (username.length > 0) {
        return [@"@" stringByAppendingString:username];
    }
    return @"Unknown";
}

- (void)storeUserObject:(NSDictionary *)user
{
    long long userID = PGJSONInt(user[@"id"]);
    if (userID == 0) {
        return;
    }

    NSString *name = [self displayNameForUserObject:user];
    if (name.length == 0) {
        return;
    }
    _userNames[@(userID)] = name;

    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientSenderNamesDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"userID": @(userID)}];
}

- (NSString *)senderNameForSender:(NSDictionary *)sender
{
    NSString *type = PGJSONString(sender[@"@type"]);
    if ([type isEqualToString:@"messageSenderUser"]) {
        long long userID = PGJSONInt(sender[@"user_id"]);
        NSString *name = _userNames[@(userID)];
        if (name.length == 0) {
            [self requestUserIfNeeded:userID];
            return @"";
        }
        return name;
    }
    if ([type isEqualToString:@"messageSenderChat"]) {
        long long chatID = PGJSONInt(sender[@"chat_id"]);
        return _chatTitles[@(chatID)] ?: @"";
    }
    return @"";
}

- (void)requestUserIfNeeded:(long long)userID
{
    if (userID == 0) {
        return;
    }
    NSNumber *key = @(userID);
    if ([_requestedUsers containsObject:key]) {
        return;
    }
    [_requestedUsers addObject:key];

    [self sendRequest:@{@"@type": @"getUser", @"user_id": key} completion:^(NSDictionary *result) {
        if ([PGJSONString(result[@"@type"]) isEqualToString:@"user"]) {
            [self storeUserObject:result];
        } else {
            [self->_requestedUsers removeObject:key];
        }
    }];
}

#pragma mark - Errors

- (NSString *)friendlyErrorForObject:(NSDictionary *)object
{
    NSString *message = PGJSONString(object[@"message"]);
    NSInteger code = (NSInteger)PGJSONInt(object[@"code"]);

    if ([message hasPrefix:@"FLOOD_WAIT_"]) {
        NSString *suffix = [message substringFromIndex:@"FLOOD_WAIT_".length];
        return [NSString stringWithFormat:@"Too many attempts. Try again in %ld seconds.", (long)suffix.integerValue];
    }

    static NSDictionary<NSString *, NSString *> *messages = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        messages = @{
            @"PHONE_NUMBER_INVALID": @"That phone number doesn't look right.",
            @"PHONE_NUMBER_BANNED": @"This phone number is banned from Telegram.",
            @"PHONE_NUMBER_FLOOD": @"Too many attempts with this phone number.",
            @"PHONE_NUMBER_OCCUPIED": @"This phone number is already in use.",
            @"PHONE_CODE_INVALID": @"The code is incorrect.",
            @"PHONE_CODE_EMPTY": @"Please enter the code.",
            @"PHONE_CODE_EXPIRED": @"The code has expired. Request a new one.",
            @"PASSWORD_HASH_INVALID": @"The password is incorrect.",
            @"PHONE_PASSWORD_FLOOD": @"Too many attempts. Try again later.",
            @"AUTH_KEY_UNREGISTERED": @"The session has expired. Please sign in again.",
        };
    });

    NSString *friendly = messages[message];
    if (friendly.length > 0) {
        return friendly;
    }

    if (code == 420) {
        return @"Too many attempts. Please wait and try again.";
    }
    if (code == 500) {
        return @"Telegram servers are having trouble. Try again later.";
    }
    return message.length > 0 ? message : @"Unknown error.";
}

- (void)deliverError:(NSString *)message
{
    if ([self.delegate respondsToSelector:@selector(clientDidReceiveError:)]) {
        [self.delegate clientDidReceiveError:message];
    }
}

- (void)postChatListChange
{
    [[NSNotificationCenter defaultCenter] postNotificationName:PGClientChatListDidChangeNotification
                                                        object:self];
}

@end
