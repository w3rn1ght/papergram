//
//  PGModels.h
//  Papergram
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// A chat as shown in the chat list.
@interface PGChat : NSObject

@property (nonatomic) long long identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSInteger unreadCount;
@property (nonatomic) NSInteger mentionCount;
@property (nonatomic) BOOL markedAsUnread;
@property (nonatomic) BOOL isGroup;
@property (nonatomic) NSInteger lastMessageDate;
@property (nonatomic, copy) NSString *lastMessagePreview;
@property (nonatomic) BOOL lastMessageOutgoing;

- (void)applyChatObject:(NSDictionary *)object;
- (void)applyLastMessageObject:(nullable NSDictionary *)message;

@end

/// Precomputed bubble geometry. Computed once per width and reused by the
/// cell, so scrolling never triggers text measurement.
typedef struct {
    CGRect bubble;
    CGRect text;
    CGRect sender;
    CGRect time;
    CGFloat rowHeight;
} PGMessageLayout;

/// A single message. Layout metrics are computed once per width and cached,
/// which keeps scrolling cheap on older hardware.
@interface PGMessage : NSObject

@property (nonatomic) long long identifier;
@property (nonatomic) long long chatID;
@property (nonatomic) NSInteger date;
@property (nonatomic) NSInteger editDate;
@property (nonatomic) BOOL outgoing;
@property (nonatomic) BOOL failed;
@property (nonatomic) BOOL service;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *senderName;
@property (nonatomic, copy, nullable) NSString *failureReason;

- (instancetype)initWithMessageObject:(NSDictionary *)object;
- (void)applyMessageObject:(NSDictionary *)object;

/// Total row height, including the gap below the bubble.
- (CGFloat)heightForWidth:(CGFloat)width;

/// Precomputed geometry for the given table width.
- (PGMessageLayout)layoutForWidth:(CGFloat)width;

/// Height of the bubble itself (row height minus the gap).
- (CGFloat)bubbleHeightForWidth:(CGFloat)width;

- (void)applyContentObject:(NSDictionary *)content;

@end

NS_ASSUME_NONNULL_END
