//
//  PGClient.h
//  Papergram
//

#import <Foundation/Foundation.h>
#import "PGModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PGAuthState) {
    PGAuthStateUnknown = 0,
    /// TDLib is waiting for API credentials; the app shows the setup screen.
    PGAuthStateNeedsCredentials,
    PGAuthStateWaitParameters,
    PGAuthStateWaitEncryptionKey,
    PGAuthStateWaitPhoneNumber,
    PGAuthStateWaitCode,
    PGAuthStateWaitPassword,
    PGAuthStateWaitRegistration,
    PGAuthStateWaitOtherDevice,
    PGAuthStateUnsupported,
    PGAuthStateReady,
    PGAuthStateLoggingOut,
    PGAuthStateClosed,
};

typedef NS_ENUM(NSInteger, PGConnectionState) {
    PGConnectionStateUnknown = 0,
    PGConnectionStateWaitingForNetwork,
    PGConnectionStateConnecting,
    PGConnectionStateReady,
    PGConnectionStateUpdating,
};

extern NSString *const PGAuthInfoCodeInfoKey;       // NSDictionary (authenticationCodeInfo)
extern NSString *const PGAuthInfoPasswordHintKey;   // NSString
extern NSString *const PGAuthInfoLinkKey;           // NSString
extern NSString *const PGAuthInfoStateTypeKey;      // NSString

extern NSString *const PGClientChatListDidChangeNotification;
extern NSString *const PGClientConnectionDidChangeNotification;
extern NSString *const PGClientMessageReceivedNotification;
extern NSString *const PGClientMessageUpdatedNotification;
extern NSString *const PGClientMessageContentDidChangeNotification;
extern NSString *const PGClientMessagesDeletedNotification;
extern NSString *const PGClientChatReadNotification;
extern NSString *const PGClientSenderNamesDidChangeNotification;

extern NSString *const PGMessageKey;        // PGMessage
extern NSString *const PGOldMessageIDKey;   // NSNumber (int64)
extern NSString *const PGChatIDKey;         // NSNumber (int64)
extern NSString *const PGMessageIDKey;      // NSNumber (int64)
extern NSString *const PGMessageIDsKey;     // NSArray<NSNumber *>
extern NSString *const PGContentKey;        // NSDictionary

@protocol PGClientDelegate <NSObject>
@optional
- (void)clientDidChangeAuthorizationState:(PGAuthState)state info:(NSDictionary *)info;
- (void)clientDidChangeConnectionState:(PGConnectionState)state;
- (void)clientDidReceiveError:(NSString *)message;
@end

/// Thin Objective-C wrapper around the TDLib JSON interface.
///
/// All public methods must be called from the main thread. Delegate callbacks
/// and notifications are delivered on the main thread as well.
@interface PGClient : NSObject

+ (instancetype)shared;

@property (nonatomic, weak, nullable) id<PGClientDelegate> delegate;
@property (nonatomic, readonly) PGAuthState authState;
@property (nonatomic, readonly) PGConnectionState connectionState;
@property (nonatomic, readonly, nullable) NSString *currentUserName;

/// Starts TDLib. Safe to call more than once.
- (void)start;

/// Re-sends TDLib parameters after the user has entered API credentials.
- (void)retryWithCredentials;

- (void)setPhoneNumber:(NSString *)phoneNumber;
/// Switches to QR-code login. Valid while TDLib waits for a phone number.
- (void)beginQRLogin;
/// Aborts QR login and returns to the phone number screen.
- (void)cancelQRLogin;
- (void)submitCode:(NSString *)code;
- (void)submitPassword:(NSString *)password;
- (void)registerFirstName:(NSString *)firstName lastName:(NSString *)lastName;
- (void)resendCode;
- (void)logout;

/// Chats ordered by last activity.
- (NSArray<PGChat *> *)chats;
- (nullable PGChat *)chatWithID:(long long)chatID;
- (void)loadChats;

- (void)requestHistoryForChat:(long long)chatID
                  fromMessage:(long long)fromMessageID
                        limit:(NSInteger)limit
                   completion:(void (^)(NSArray<PGMessage *> *messages, NSString *_Nullable errorMessage))completion;

- (void)sendText:(NSString *)text
          toChat:(long long)chatID
      completion:(void (^_Nullable)(PGMessage *_Nullable message, NSString *_Nullable errorMessage))completion;

- (void)markChatRead:(long long)chatID upToMessageID:(long long)messageID;
- (void)openChat:(long long)chatID;
- (void)closeChat:(long long)chatID;

@end

NS_ASSUME_NONNULL_END
