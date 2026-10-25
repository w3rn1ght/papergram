//
//  PGTheme.h
//  Papergram
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PGTheme : NSObject

+ (UIColor *)background;
+ (UIColor *)cardBackground;
+ (UIColor *)separator;
+ (UIColor *)primaryText;
+ (UIColor *)secondaryText;
+ (UIColor *)tertiaryText;
+ (UIColor *)accent;
+ (UIColor *)danger;
+ (UIColor *)bubbleIncoming;
+ (UIColor *)bubbleOutgoing;
+ (UIColor *)bubbleBorder;
+ (UIColor *)badge;

+ (UIFont *)chatTitleFont;
+ (UIFont *)chatPreviewFont;
+ (UIFont *)chatDateFont;
+ (UIFont *)badgeFont;
+ (UIFont *)messageFont;
+ (UIFont *)messageSenderFont;
+ (UIFont *)messageTimeFont;

+ (UIColor *)avatarColorForIdentifier:(long long)identifier;
+ (NSString *)initialsForTitle:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
