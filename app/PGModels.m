//
//  PGModels.m
//  Papergram
//

#import "PGModels.h"
#import "PGFormatters.h"
#import "PGTheme.h"

#include <math.h>

#pragma mark - Layout constants

static const CGFloat PGMessageMargin = 16.0;
static const CGFloat PGMessagePaddingX = 10.0;
static const CGFloat PGMessagePaddingTop = 7.0;
static const CGFloat PGMessagePaddingBottom = 7.0;
static const CGFloat PGMessageTimeHeight = 14.0;
static const CGFloat PGMessageSenderHeight = 16.0;
static const CGFloat PGMessageTextTimeGap = 2.0;
static const CGFloat PGMessageRowGap = 8.0;
static const CGFloat PGMessageMinBubbleWidth = 64.0;
static const CGFloat PGMessageMaxBubbleWidth = 560.0;
static const CGFloat PGServiceMessageHeight = 30.0;

@implementation PGChat

- (void)applyChatObject:(NSDictionary *)object
{
    if (![object isKindOfClass:[NSDictionary class]]) {
        return;
    }

    id identifier = object[@"id"];
    if ([identifier respondsToSelector:@selector(longLongValue)]) {
        self.identifier = [identifier longLongValue];
    }

    NSString *title = object[@"title"];
    if ([title isKindOfClass:[NSString class]]) {
        self.title = title;
    }

    NSDictionary *type = object[@"type"];
    NSString *typeName = [type isKindOfClass:[NSDictionary class]] ? type[@"@type"] : nil;
    if ([typeName isKindOfClass:[NSString class]]) {
        self.isGroup = ![typeName isEqualToString:@"chatTypePrivate"] &&
                      ![typeName isEqualToString:@"chatTypeSecret"];
    }

    self.unreadCount = [object[@"unread_count"] integerValue];
    self.mentionCount = [object[@"unread_mention_count"] integerValue];
    self.markedAsUnread = [object[@"is_marked_as_unread"] boolValue];

    id lastMessage = object[@"last_message"];
    [self applyLastMessageObject:[lastMessage isKindOfClass:[NSDictionary class]] ? lastMessage : nil];
}

- (void)applyLastMessageObject:(NSDictionary *)message
{
    if (![message isKindOfClass:[NSDictionary class]]) {
        self.lastMessageDate = 0;
        self.lastMessagePreview = @"";
        self.lastMessageOutgoing = NO;
        return;
    }

    self.lastMessageDate = [message[@"date"] integerValue];
    self.lastMessageOutgoing = [message[@"is_outgoing"] boolValue];

    id content = message[@"content"];
    self.lastMessagePreview = PGPreviewForContent([content isKindOfClass:[NSDictionary class]] ? content : nil);
}

@end

@implementation PGMessage {
    CGFloat _layoutWidth;
    PGMessageLayout _layout;
    BOOL _layoutValid;
}

- (instancetype)initWithMessageObject:(NSDictionary *)object
{
    self = [super init];
    if (self) {
        [self applyMessageObject:object];
    }
    return self;
}

- (void)applyMessageObject:(NSDictionary *)object
{
    if (![object isKindOfClass:[NSDictionary class]]) {
        return;
    }

    id identifier = object[@"id"];
    if ([identifier respondsToSelector:@selector(longLongValue)]) {
        self.identifier = [identifier longLongValue];
    }

    id chatID = object[@"chat_id"];
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        self.chatID = [chatID longLongValue];
    }

    self.date = [object[@"date"] integerValue];
    self.editDate = [object[@"edit_date"] integerValue];
    self.outgoing = [object[@"is_outgoing"] boolValue];

    id content = object[@"content"];
    NSDictionary *contentObject = [content isKindOfClass:[NSDictionary class]] ? content : nil;
    self.service = PGContentIsService(contentObject);
    self.text = PGDisplayTextForMessage(object);

    self.failed = NO;
    self.failureReason = nil;
    id sendingState = object[@"sending_state"];
    if ([sendingState isKindOfClass:[NSDictionary class]]) {
        NSString *stateType = sendingState[@"@type"];
        if ([stateType isEqualToString:@"messageSendingStateFailed"]) {
            self.failed = YES;
            NSString *reason = sendingState[@"error_message"];
            self.failureReason = [reason isKindOfClass:[NSString class]] ? reason : @"Not delivered";
        }
    }

    _layoutValid = NO;
}

- (void)applyContentObject:(NSDictionary *)content
{
    self.service = PGContentIsService(content);
    self.text = PGDisplayTextForMessage(@{@"content": content ?: @{}});
    _layoutValid = NO;
}

- (PGMessageLayout)layoutForWidth:(CGFloat)width
{
    if (_layoutValid && fabs(_layoutWidth - width) < 0.5) {
        return _layout;
    }

    PGMessageLayout layout = {0};
    if (self.service) {
        layout.rowHeight = PGServiceMessageHeight;
        _layout = layout;
        _layoutWidth = width;
        _layoutValid = YES;
        return layout;
    }

    CGFloat maxBubbleWidth = MIN(width - 2.0 * PGMessageMargin,
                                 MIN(width * 0.78, PGMessageMaxBubbleWidth));
    CGFloat contentMaxWidth = MAX(32.0, maxBubbleWidth - 2.0 * PGMessagePaddingX);

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attributes = @{
        NSFontAttributeName: [PGTheme messageFont],
        NSParagraphStyleAttributeName: paragraph,
    };

    NSString *text = self.text.length > 0 ? self.text : @" ";
    CGRect textRect = [text boundingRectWithSize:CGSizeMake(contentMaxWidth, CGFLOAT_MAX)
                                         options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                      attributes:attributes
                                         context:nil];
    CGFloat textWidth = ceil(textRect.size.width);
    CGFloat textHeight = ceil(textRect.size.height);
    if (textHeight <= 0.0) {
        textHeight = ceil([PGTheme messageFont].lineHeight);
    }

    CGFloat bubbleWidth = MIN(maxBubbleWidth, MAX(textWidth + 2.0 * PGMessagePaddingX, PGMessageMinBubbleWidth));
    CGFloat senderHeight = (self.senderName.length > 0 && !self.outgoing) ? PGMessageSenderHeight : 0.0;
    CGFloat bubbleHeight = PGMessagePaddingTop + senderHeight + textHeight +
                           PGMessageTextTimeGap + PGMessageTimeHeight + PGMessagePaddingBottom;

    CGFloat originX = self.outgoing ? (width - PGMessageMargin - bubbleWidth) : PGMessageMargin;
    layout.bubble = CGRectMake(originX, 0.0, bubbleWidth, bubbleHeight);
    layout.sender = CGRectMake(originX + PGMessagePaddingX,
                               PGMessagePaddingTop,
                               bubbleWidth - 2.0 * PGMessagePaddingX,
                               senderHeight);
    layout.text = CGRectMake(originX + PGMessagePaddingX,
                             PGMessagePaddingTop + senderHeight,
                             bubbleWidth - 2.0 * PGMessagePaddingX,
                             textHeight);
    layout.time = CGRectMake(originX + PGMessagePaddingX,
                             PGMessagePaddingTop + senderHeight + textHeight + PGMessageTextTimeGap,
                             bubbleWidth - 2.0 * PGMessagePaddingX,
                             PGMessageTimeHeight);
    layout.rowHeight = bubbleHeight + PGMessageRowGap;

    _layout = layout;
    _layoutWidth = width;
    _layoutValid = YES;
    return layout;
}

- (CGFloat)heightForWidth:(CGFloat)width
{
    return [self layoutForWidth:width].rowHeight;
}

- (CGFloat)bubbleHeightForWidth:(CGFloat)width
{
    return [self layoutForWidth:width].bubble.size.height;
}

@end
