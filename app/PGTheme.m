//
//  PGTheme.m
//  Papergram
//

#import "PGTheme.h"

@implementation PGTheme

+ (UIColor *)colorWithHex:(NSUInteger)hex
{
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

+ (UIColor *)background { return [self colorWithHex:0xF4F4F2]; }
+ (UIColor *)cardBackground { return [UIColor whiteColor]; }
+ (UIColor *)separator { return [self colorWithHex:0xE2E2DE]; }
+ (UIColor *)primaryText { return [self colorWithHex:0x1B1D21]; }
+ (UIColor *)secondaryText { return [self colorWithHex:0x6E7378]; }
+ (UIColor *)tertiaryText { return [self colorWithHex:0x9AA0A6]; }
+ (UIColor *)accent { return [self colorWithHex:0x2F6FED]; }
+ (UIColor *)danger { return [self colorWithHex:0xD94A3D]; }
+ (UIColor *)bubbleIncoming { return [UIColor whiteColor]; }
+ (UIColor *)bubbleOutgoing { return [self colorWithHex:0xDCEBFF]; }
+ (UIColor *)bubbleBorder { return [self colorWithHex:0xE7E7E3]; }
+ (UIColor *)badge { return [self colorWithHex:0xE0533F]; }

+ (UIFont *)chatTitleFont { return [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold]; }
+ (UIFont *)chatPreviewFont { return [UIFont systemFontOfSize:14.0]; }
+ (UIFont *)chatDateFont { return [UIFont systemFontOfSize:12.0]; }
+ (UIFont *)badgeFont { return [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold]; }
+ (UIFont *)messageFont { return [UIFont systemFontOfSize:16.0]; }
+ (UIFont *)messageSenderFont { return [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold]; }
+ (UIFont *)messageTimeFont { return [UIFont systemFontOfSize:11.0]; }

+ (UIColor *)avatarColorForIdentifier:(long long)identifier
{
    static NSArray<UIColor *> *palette = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        palette = @[
            [self colorWithHex:0x5B8DEF],
            [self colorWithHex:0xE48A5B],
            [self colorWithHex:0x4FA88C],
            [self colorWithHex:0xB07CD6],
            [self colorWithHex:0xD46A7C],
            [self colorWithHex:0x6E9E4F],
            [self colorWithHex:0x4E9EC9],
            [self colorWithHex:0xC79545],
        ];
    });
    unsigned long long value = (unsigned long long)identifier;
    return palette[(NSUInteger)(value % palette.count)];
}

+ (NSString *)initialsForTitle:(NSString *)title
{
    NSArray<NSString *> *words = [title componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet whitespaceCharacterSet]];
    NSMutableString *initials = [NSMutableString string];
    for (NSString *word in words) {
        if (word.length == 0) {
            continue;
        }
        unichar first = [word characterAtIndex:0];
        [initials appendFormat:@"%C", first];
        if (initials.length == 2) {
            break;
        }
    }
    return [initials uppercaseStringWithLocale:nil];
}

@end
