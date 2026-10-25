//
//  PGComposerView.m
//  Papergram
//

#import "PGComposerView.h"
#import "PGTheme.h"
#import "PGUIKit.h"

/// Small vector send button. Cheaper than shipping and decoding an image.
@interface PGSendButton : UIButton
@end

@implementation PGSendButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.enabled = NO;
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    [self setNeedsDisplay];
    self.alpha = enabled ? 1.0 : 0.35;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.65 : (self.enabled ? 1.0 : 0.35);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL) {
        return;
    }

    [[PGTheme accent] setFill];
    CGContextFillEllipseInRect(context, self.bounds);

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGPoint start = CGPointMake(width * 0.30, height * 0.50);
    CGPoint tip = CGPointMake(width * 0.70, height * 0.50);
    CGPoint top = CGPointMake(width * 0.56, height * 0.36);
    CGPoint bottom = CGPointMake(width * 0.56, height * 0.64);

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:start];
    [path addLineToPoint:tip];
    [path moveToPoint:top];
    [path addLineToPoint:tip];
    [path addLineToPoint:bottom];
    path.lineWidth = 2.0;
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;
    [[UIColor whiteColor] setStroke];
    [path stroke];
}

@end

@interface PGComposerView () <UITextFieldDelegate>
@end

@implementation PGComposerView {
    PGTextField *_field;
    PGSendButton *_sendButton;
    UIView *_separator;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [PGTheme cardBackground];

        _separator = [[UIView alloc] initWithFrame:CGRectZero];
        _separator.backgroundColor = [PGTheme separator];
        _separator.userInteractionEnabled = NO;
        [self addSubview:_separator];

        _field = [[PGTextField alloc] initWithFrame:CGRectZero];
        _field.layer.cornerRadius = 18.0;
        _field.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.94 alpha:1.0];
        _field.placeholder = @"Message";
        _field.returnKeyType = UIReturnKeySend;
        _field.enablesReturnKeyAutomatically = YES;
        _field.delegate = self;
        _field.textContentType = nil;
        [_field addTarget:self
                   action:@selector(textDidChange:)
         forControlEvents:UIControlEventEditingChanged];
        [self addSubview:_field];

        _sendButton = [[PGSendButton alloc] initWithFrame:CGRectZero];
        [_sendButton addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_sendButton];
    }
    return self;
}

- (void)setContentBottomInset:(CGFloat)contentBottomInset
{
    _contentBottomInset = contentBottomInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    _separator.frame = CGRectMake(0, 0, width, 0.5);

    CGFloat sendSize = 36.0;
    CGFloat sendX = width - 12.0 - sendSize;
    _sendButton.frame = CGRectMake(sendX, 8.0, sendSize, sendSize);

    CGFloat fieldWidth = sendX - 8.0 - 12.0;
    if (fieldWidth < 60.0) {
        fieldWidth = 60.0;
    }
    _field.frame = CGRectMake(12.0, 8.0, fieldWidth, 36.0);
}

- (void)clearText
{
    _field.text = @"";
    _sendButton.enabled = NO;
}

- (void)setDraftText:(NSString *)text
{
    _field.text = text ?: @"";
    _sendButton.enabled = _field.text.length > 0;
}

- (void)focusInput
{
    [_field becomeFirstResponder];
}

- (void)textDidChange:(UITextField *)field
{
    NSString *trimmed = [field.text stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    _sendButton.enabled = trimmed.length > 0;
}

- (void)send
{
    NSString *text = _field.text;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return;
    }
    [self.delegate composerView:self didSubmitText:text];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self send];
    return YES;
}

@end
