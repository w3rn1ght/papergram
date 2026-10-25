//
//  PGUIKit.h
//  Papergram
//
//  Small, dependency-free UI primitives shared by the screens.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// UITextField with configurable insets and a built-in rounded background.
@interface PGTextField : UITextField

@property (nonatomic) UIEdgeInsets textInsets;

@end

/// Filled call-to-action button.
@interface PGPrimaryButton : UIButton

@end

/// 1px separator that matches the theme.
@interface PGSeparatorView : UIView

@end

/// Two-line navigation title ("Papergram" / "Connecting…").
@interface PGTitleView : UIView

- (void)setTitle:(NSString *)title subtitle:(nullable NSString *)subtitle;

@end

NS_ASSUME_NONNULL_END
