//
//  PGUIKit.m
//  Papergram
//

#import "PGUIKit.h"
#import "PGTheme.h"

@implementation PGTextField

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.textInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        self.borderStyle = UITextBorderStyleNone;
        self.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.94 alpha:1.0];
        self.layer.cornerRadius = 10.0;
        self.font = [UIFont systemFontOfSize:16.0];
        self.textColor = [PGTheme primaryText];
        self.tintColor = [PGTheme accent];
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.clearButtonMode = UITextFieldViewModeWhileEditing;
    }
    return self;
}

- (CGRect)textRectForBounds:(CGRect)bounds
{
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds
{
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

- (CGRect)clearButtonRectForBounds:(CGRect)bounds
{
    CGRect rect = [super clearButtonRectForBounds:bounds];
    rect.origin.x -= 4.0;
    return rect;
}

@end

@implementation PGPrimaryButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [PGTheme accent];
        self.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.layer.cornerRadius = 10.0;
        self.adjustsImageWhenHighlighted = NO;
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    self.alpha = enabled ? 1.0 : 0.45;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.8 : (self.enabled ? 1.0 : 0.45);
}

@end

@implementation PGSeparatorView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [PGTheme separator];
        self.userInteractionEnabled = NO;
    }
    return self;
}

@end

@implementation PGTitleView {
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:CGRectMake(0, 0, 170, 44)];
    if (self) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [PGTheme primaryText];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:11.0];
        _subtitleLabel.textColor = [PGTheme secondaryText];
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_subtitleLabel];
    }
    return self;
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    _titleLabel.text = title;
    _subtitleLabel.text = subtitle;
    _subtitleLabel.hidden = subtitle.length == 0;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    if (_subtitleLabel.hidden) {
        _titleLabel.frame = CGRectMake(0, 0, CGRectGetWidth(bounds), CGRectGetHeight(bounds));
        _subtitleLabel.frame = CGRectZero;
    } else {
        _titleLabel.frame = CGRectMake(0, 5, CGRectGetWidth(bounds), 20);
        _subtitleLabel.frame = CGRectMake(0, 23, CGRectGetWidth(bounds), 14);
    }
}

@end
