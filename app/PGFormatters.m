//
//  PGFormatters.m
//  Papergram
//

#import "PGFormatters.h"

static NSString *PGStringValue(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSDictionary *PGDictionaryValue(id value)
{
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

NSString *PGTextFromContent(NSDictionary *content)
{
    if (![content isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *text = PGDictionaryValue(content[@"text"]);
    NSString *value = PGStringValue(text[@"text"]);
    if (value.length > 0) {
        return value;
    }

    NSDictionary *caption = PGDictionaryValue(content[@"caption"]);
    value = PGStringValue(caption[@"text"]);
    return value.length > 0 ? value : nil;
}

NSString *PGPlaceholderForContent(NSDictionary *content)
{
    NSString *type = PGStringValue(content[@"@type"]);
    if (type.length == 0) {
        return @"Message";
    }

    static NSDictionary<NSString *, NSString *> *overrides = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        overrides = @{
            @"messageText": @"Message",
            @"messagePhoto": @"Photo",
            @"messageVideo": @"Video",
            @"messageVideoNote": @"Video message",
            @"messageVoiceNote": @"Voice message",
            @"messageSticker": @"Sticker",
            @"messageAnimation": @"GIF",
            @"messageDocument": @"Document",
            @"messageAudio": @"Audio",
            @"messageLocation": @"Location",
            @"messageVenue": @"Venue",
            @"messageContact": @"Contact",
            @"messagePoll": @"Poll",
            @"messageCall": @"Call",
            @"messageDice": @"Dice",
            @"messageGame": @"Game",
            @"messageInvoice": @"Invoice",
            @"messageUnsupported": @"Unsupported message",
        };
    });

    NSString *override = overrides[type];
    if (override.length > 0) {
        return override;
    }

    NSString *name = type;
    if ([name hasPrefix:@"message"]) {
        name = [name substringFromIndex:@"message".length];
    }
    if (name.length == 0) {
        return @"Message";
    }

    NSMutableString *humanized = [NSMutableString string];
    for (NSUInteger index = 0; index < name.length; index++) {
        unichar character = [name characterAtIndex:index];
        if (index > 0 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:character]) {
            [humanized appendString:@" "];
        }
        [humanized appendFormat:@"%C", character];
    }
    return humanized;
}

NSString *PGPreviewForContent(NSDictionary *content)
{
    NSString *text = PGTextFromContent(content);
    NSString *preview = text.length > 0 ? text : PGPlaceholderForContent(content);

    preview = [preview stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    preview = [preview stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    preview = [preview stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (preview.length > 160) {
        preview = [[preview substringToIndex:160] stringByAppendingString:@"…"];
    }
    return preview;
}

NSString *PGDisplayTextForMessage(NSDictionary *message)
{
    NSDictionary *content = PGDictionaryValue(message[@"content"]);
    NSString *text = PGTextFromContent(content);
    if (text.length > 0) {
        return text;
    }
    return PGPlaceholderForContent(content);
}

BOOL PGContentIsService(NSDictionary *content)
{
    NSString *type = PGStringValue(content[@"@type"]);
    if (type.length == 0) {
        return NO;
    }

    static NSSet<NSString *> *exact = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        exact = [NSSet setWithArray:@[
            @"messagePinMessage",
            @"messageGameScore",
            @"messagePaymentSuccessful",
            @"messagePaymentSuccessfulBot",
            @"messageCustomServiceAction",
            @"messageChatSetMessageAutoDeleteTime",
            @"messageChatSetTheme",
            @"messageChatSetBackground",
        ]];
    });

    return [type hasPrefix:@"messageChat"] ||
           [type hasPrefix:@"messageBasicGroup"] ||
           [type hasPrefix:@"messageSupergroup"] ||
           [exact containsObject:type];
}

static NSString *PGLocalizedTime(NSDate *date)
{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterNoStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
    });
    return [formatter stringFromDate:date];
}

NSString *PGTimeString(NSInteger timestamp)
{
    if (timestamp <= 0) {
        return @"";
    }
    return PGLocalizedTime([NSDate dateWithTimeIntervalSince1970:timestamp]);
}

NSString *PGMessageTimeString(NSInteger timestamp)
{
    return PGTimeString(timestamp);
}

NSString *PGChatDateString(NSInteger timestamp)
{
    if (timestamp <= 0) {
        return @"";
    }

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSCalendar *calendar = [NSCalendar currentCalendar];

    if ([calendar isDateInToday:date]) {
        return PGLocalizedTime(date);
    }
    if ([calendar isDateInYesterday:date]) {
        return @"Yesterday";
    }

    NSDateComponents *components = [calendar components:NSCalendarUnitDay
                                               fromDate:date
                                                 toDate:[NSDate date]
                                                options:0];
    if (components.day < 6) {
        static NSDateFormatter *weekday = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            weekday = [[NSDateFormatter alloc] init];
            weekday.dateFormat = @"EEE";
        });
        return [weekday stringFromDate:date];
    }

    static NSDateFormatter *shortDate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shortDate = [[NSDateFormatter alloc] init];
        shortDate.dateStyle = NSDateFormatterShortStyle;
        shortDate.timeStyle = NSDateFormatterNoStyle;
    });
    return [shortDate stringFromDate:date];
}
