//
//  PGFormatters.h
//  Papergram
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Returns the text or caption of a TDLib message content object, if any.
NSString * _Nullable PGTextFromContent(NSDictionary * _Nullable content);

/// Human readable name for a content type, e.g. "Photo", "Voice message".
NSString *PGPlaceholderForContent(NSDictionary * _Nullable content);

/// One line preview used in the chat list.
NSString *PGPreviewForContent(NSDictionary * _Nullable content);

/// What should be rendered inside a message bubble.
NSString *PGDisplayTextForMessage(NSDictionary * _Nullable message);

BOOL PGContentIsService(NSDictionary * _Nullable content);

/// "14:32" (locale aware).
NSString *PGTimeString(NSInteger timestamp);

/// Chat list timestamp: time today, "Yesterday", weekday, or a short date.
NSString *PGChatDateString(NSInteger timestamp);

/// "14:32" for message bubbles, empty for zero timestamps.
NSString *PGMessageTimeString(NSInteger timestamp);

NS_ASSUME_NONNULL_END
