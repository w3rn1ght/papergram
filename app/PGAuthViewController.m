//
//  PGAuthViewController.m
//  Papergram
//

#import "PGAuthViewController.h"
#import "PGConfig.h"
#import "PGLogoView.h"
#import "PGTheme.h"
#import "PGUIKit.h"

static NSString *PGNormalizePhone(NSString *input)
{
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![trimmed hasPrefix:@"+"]) {
        return @"";
    }

    NSMutableString *digits = [NSMutableString stringWithString:@"+"];
    for (NSUInteger index = 1; index < trimmed.length; index++) {
        unichar character = [trimmed characterAtIndex:index];
        if (character >= '0' && character <= '9') {
            [digits appendFormat:@"%C", character];
        }
    }
    return digits.length > 1 ? digits : @"";
}

static NSString *PGCompactCode(NSString *input)
{
    NSArray<NSString *> *parts = [input componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [parts componentsJoinedByString:@""];
}

@interface PGAuthViewController () <UITextFieldDelegate>
@end

@implementation PGAuthViewController {
    UIScrollView *_scrollView;
    UIView *_contentView;
    UIView *_card;
    UILabel *_errorLabel;

    NSMutableArray<UIView *> *_items;
    PGAuthState _state;
    NSDictionary *_info;
    NSString *_phoneNumber;
    NSString *_errorText;
    BOOL _busy;

    PGTextField *_apiIDField;
    PGTextField *_apiHashField;
    PGTextField *_phoneField;
    PGTextField *_codeField;
    PGTextField *_passwordField;
    PGTextField *_firstNameField;
    PGTextField *_lastNameField;
    PGPrimaryButton *_primaryButton;
    UIButton *_resendButton;
    UIButton *_changeNumberButton;
    UITextField *_activeField;

    NSTimer *_resendTimer;
    NSInteger _resendSeconds;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _state = PGAuthStateUnknown;
        _info = @{};
        _items = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    [_resendTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [PGTheme background];

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_scrollView];

    _contentView = [[UIView alloc] initWithFrame:CGRectZero];
    [_scrollView addSubview:_contentView];

    _card = [[UIView alloc] initWithFrame:CGRectZero];
    _card.backgroundColor = [PGTheme cardBackground];
    _card.layer.cornerRadius = 18.0;
    _card.layer.borderWidth = 0.5;
    _card.layer.borderColor = [PGTheme separator].CGColor;
    [_contentView addSubview:_card];

    _errorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _errorLabel.font = [UIFont systemFontOfSize:13.0];
    _errorLabel.textColor = [PGTheme danger];
    _errorLabel.textAlignment = NSTextAlignmentCenter;
    _errorLabel.numberOfLines = 0;
    _errorLabel.hidden = YES;
    [_card addSubview:_errorLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];

    [self rebuild];
}

#pragma mark - Public

- (void)applyAuthState:(PGAuthState)state info:(NSDictionary *)info
{
    BOOL changed = (state != _state);
    _state = state;
    _info = [info isKindOfClass:[NSDictionary class]] ? info : @{};

    if (changed) {
        _errorText = nil;
        _errorLabel.text = nil;
        _errorLabel.hidden = YES;
        _busy = NO;
        if (self.isViewLoaded) {
            [self.view endEditing:YES];
            [self rebuild];
        }
    }
}

- (void)showError:(NSString *)message
{
    _busy = NO;
    _errorText = message.length > 0 ? message : nil;
    _errorLabel.text = _errorText;
    _errorLabel.hidden = _errorText.length == 0;
    _primaryButton.enabled = !_busy;
    [self.view setNeedsLayout];
}

- (void)resignAllFirstResponders
{
    [self.view endEditing:YES];
}

#pragma mark - Form building

- (void)rebuild
{
    for (UIView *item in _items) {
        [item removeFromSuperview];
    }
    [_items removeAllObjects];

    _apiIDField = nil;
    _apiHashField = nil;
    _phoneField = nil;
    _codeField = nil;
    _passwordField = nil;
    _firstNameField = nil;
    _lastNameField = nil;
    _primaryButton = nil;
    _resendButton = nil;
    _changeNumberButton = nil;
    _activeField = nil;

    switch (_state) {
        case PGAuthStateNeedsCredentials:
            [self buildCredentialsForm];
            break;
        case PGAuthStateWaitPhoneNumber:
            [self buildPhoneForm];
            break;
        case PGAuthStateWaitCode:
            [self buildCodeForm];
            break;
        case PGAuthStateWaitPassword:
            [self buildPasswordForm];
            break;
        case PGAuthStateWaitRegistration:
            [self buildRegistrationForm];
            break;
        case PGAuthStateWaitOtherDevice:
            [self buildOtherDeviceForm];
            break;
        case PGAuthStateWaitParameters:
        case PGAuthStateWaitEncryptionKey:
            [self buildBusyView:@"Preparing your session…"];
            break;
        case PGAuthStateLoggingOut:
            [self buildBusyView:@"Signing out…"];
            break;
        case PGAuthStateClosed:
            [self buildBusyView:@"Session closed. Reconnecting…"];
            break;
        case PGAuthStateReady:
            [self buildBusyView:@"Signed in"];
            break;
        case PGAuthStateUnknown:
        default:
            [self buildBusyView:@"Connecting to Telegram…"];
            break;
    }

    [self.view setNeedsLayout];
}

- (void)buildHeaderWithTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 0)];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:25.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = [PGTheme primaryText];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    [self addItem:titleLabel];

    [self addItem:[self spacerWithHeight:2.0]];

    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 0)];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont systemFontOfSize:14.0];
    subtitleLabel.textColor = [PGTheme secondaryText];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    [self addItem:subtitleLabel];

    [self addItem:[self spacerWithHeight:6.0]];
}

- (void)buildLogo
{
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 68)];
    PGLogoView *logo = [[PGLogoView alloc] initWithFrame:CGRectMake(0, 2, 64, 64)];
    logo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [box addSubview:logo];
    [self addItem:box];
    [self addItem:[self spacerWithHeight:2.0]];
}

- (void)buildCredentialsForm
{
    [self buildLogo];
    [self buildHeaderWithTitle:@"Developer setup"
                     subtitle:@"Papergram is an independent client. Create your own Telegram application and paste its credentials below."];

    _apiIDField = [self makeFieldWithPlaceholder:@"API ID" keyboard:UIKeyboardTypeNumberPad secure:NO];
    _apiIDField.textContentType = nil;
    [self addItem:_apiIDField];

    _apiHashField = [self makeFieldWithPlaceholder:@"API hash" keyboard:UIKeyboardTypeASCIICapable secure:NO];
    _apiHashField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [self addItem:_apiHashField];

    PGPrimaryButton *button = [self makePrimaryButtonWithTitle:@"Save and connect" action:@selector(saveCredentials)];
    _primaryButton = button;
    [self addItem:button];

    [self addItem:[self footnoteWithText:@"my.telegram.org → API development tools"]];
}

- (void)buildPhoneForm
{
    [self buildLogo];
    [self buildHeaderWithTitle:@"Sign in to Telegram"
                     subtitle:@"Enter your phone number in international format. Telegram will send you a login code."];

    _phoneField = [self makeFieldWithPlaceholder:@"+1 555 0100" keyboard:UIKeyboardTypePhonePad secure:NO];
    _phoneField.textContentType = UITextContentTypeTelephoneNumber;
    [self addItem:_phoneField];

    PGPrimaryButton *button = [self makePrimaryButtonWithTitle:@"Continue" action:@selector(submitPhone)];
    _primaryButton = button;
    [self addItem:button];

    [self addItem:[self footnoteWithText:@"Your number is only used to authorize this session."]];
}

- (void)buildCodeForm
{
    [self buildLogo];
    [self buildHeaderWithTitle:@"Enter the code" subtitle:[self codeSubtitle]];

    _codeField = [self makeFieldWithPlaceholder:@"Login code" keyboard:UIKeyboardTypeNumberPad secure:NO];
    if (@available(iOS 12.0, *)) {
        _codeField.textContentType = UITextContentTypeOneTimeCode;
    }
    [self addItem:_codeField];

    PGPrimaryButton *button = [self makePrimaryButtonWithTitle:@"Sign in" action:@selector(submitCode)];
    _primaryButton = button;
    [self addItem:button];

    _resendButton = [self makeLinkButtonWithTitle:@"Resend code" action:@selector(resendCode)];
    [self addItem:_resendButton];

    _changeNumberButton = [self makeLinkButtonWithTitle:@"Use a different number" action:@selector(changeNumber)];
    [self addItem:_changeNumberButton];

    NSInteger timeout = 0;
    NSDictionary *codeInfo = _info[PGAuthInfoCodeInfoKey];
    if ([codeInfo isKindOfClass:[NSDictionary class]]) {
        timeout = [codeInfo[@"timeout"] integerValue];
    }
    [self startResendCountdown:MAX(timeout, 0)];
}

- (void)buildPasswordForm
{
    [self buildLogo];
    [self buildHeaderWithTitle:@"Two-step verification"
                     subtitle:@"Your account is protected with an additional password."];

    NSString *hint = _info[PGAuthInfoPasswordHintKey];
    if ([hint isKindOfClass:[NSString class]] && hint.length > 0) {
        [self addItem:[self footnoteWithText:[NSString stringWithFormat:@"Hint: %@", hint]]];
    }

    _passwordField = [self makeFieldWithPlaceholder:@"Password" keyboard:UIKeyboardTypeDefault secure:YES];
    _passwordField.textContentType = UITextContentTypePassword;
    [self addItem:_passwordField];

    PGPrimaryButton *button = [self makePrimaryButtonWithTitle:@"Continue" action:@selector(submitPassword)];
    _primaryButton = button;
    [self addItem:button];
}

- (void)buildRegistrationForm
{
    [self buildLogo];
    [self buildHeaderWithTitle:@"Create an account"
                     subtitle:@"This phone number is not registered on Telegram yet. Choose how your name will appear."];

    _firstNameField = [self makeFieldWithPlaceholder:@"First name" keyboard:UIKeyboardTypeDefault secure:NO];
    _firstNameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    _firstNameField.textContentType = UITextContentTypeGivenName;
    [self addItem:_firstNameField];

    _lastNameField = [self makeFieldWithPlaceholder:@"Last name (optional)" keyboard:UIKeyboardTypeDefault secure:NO];
    _lastNameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    _lastNameField.textContentType = UITextContentTypeFamilyName;
    [self addItem:_lastNameField];

    PGPrimaryButton *button = [self makePrimaryButtonWithTitle:@"Create account" action:@selector(submitRegistration)];
    _primaryButton = button;
    [self addItem:button];
}

- (void)buildOtherDeviceForm
{
    [self buildLogo];
    [self buildHeaderWithTitle:@"Confirm on another device"
                     subtitle:@"Open Telegram on a device where you are already signed in and confirm this login."];

    NSString *link = _info[PGAuthInfoLinkKey];
    if ([link isKindOfClass:[NSString class]] && link.length > 0) {
        [self addItem:[self footnoteWithText:link]];
    }

    PGPrimaryButton *button = [self makePrimaryButtonWithTitle:@"Cancel sign-in" action:@selector(cancelSignIn)];
    _primaryButton = button;
    [self addItem:button];
}

- (void)buildBusyView:(NSString *)text
{
    [self buildLogo];

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 86)];
    box.tag = 200;

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
                                        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.tag = 201;
    spinner.frame = CGRectMake(0, 0, 24, 24);
    [spinner startAnimating];
    [box addSubview:spinner];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 44, 1, 20)];
    label.tag = 202;
    label.text = text;
    label.font = [UIFont systemFontOfSize:14.0];
    label.textColor = [PGTheme secondaryText];
    label.textAlignment = NSTextAlignmentCenter;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [box addSubview:label];

    [self addItem:box];
}

#pragma mark - Item helpers

- (void)addItem:(UIView *)view
{
    if (view == nil) {
        return;
    }
    [_items addObject:view];
    [_card addSubview:view];
}

- (UIView *)spacerWithHeight:(CGFloat)height
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, height)];
    view.userInteractionEnabled = NO;
    view.backgroundColor = [UIColor clearColor];
    return view;
}

- (UILabel *)footnoteWithText:(NSString *)text
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 0)];
    label.text = text;
    label.font = [UIFont systemFontOfSize:12.0];
    label.textColor = [PGTheme tertiaryText];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}

- (PGTextField *)makeFieldWithPlaceholder:(NSString *)placeholder
                                keyboard:(UIKeyboardType)keyboard
                                  secure:(BOOL)secure
{
    PGTextField *field = [[PGTextField alloc] initWithFrame:CGRectMake(0, 0, 1, 44)];
    field.placeholder = placeholder;
    field.keyboardType = keyboard;
    field.secureTextEntry = secure;
    field.delegate = self;
    field.returnKeyType = UIReturnKeyGo;
    return field;
}

- (PGPrimaryButton *)makePrimaryButtonWithTitle:(NSString *)title action:(SEL)action
{
    PGPrimaryButton *button = [[PGPrimaryButton alloc] initWithFrame:CGRectMake(0, 0, 1, 44)];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.enabled = !_busy;
    return button;
}

- (UIButton *)makeLinkButtonWithTitle:(NSString *)title action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(0, 0, 1, 30);
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14.0];
    [button setTitleColor:[PGTheme accent] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (NSString *)codeSubtitle
{
    NSDictionary *codeInfo = _info[PGAuthInfoCodeInfoKey];
    NSDictionary *type = [codeInfo isKindOfClass:[NSDictionary class]] ? codeInfo[@"type"] : nil;
    NSString *typeName = [type isKindOfClass:[NSDictionary class]] ? type[@"@type"] : nil;

    NSString *delivery = @"We sent you a login code";
    if ([typeName isEqualToString:@"authenticationCodeTypeSms"]) {
        delivery = @"We sent an SMS with a login code";
    } else if ([typeName isEqualToString:@"authenticationCodeTypeCall"]) {
        delivery = @"Telegram will call you with a login code";
    } else if ([typeName isEqualToString:@"authenticationCodeTypeFlashCall"]) {
        delivery = @"Telegram will call you; the code is the last digits of the number";
    } else if ([typeName isEqualToString:@"authenticationCodeTypeTelegramMessage"]) {
        delivery = @"We sent a login code to your Telegram app";
    }

    if (_phoneNumber.length > 0) {
        return [NSString stringWithFormat:@"%@ for %@.", delivery, _phoneNumber];
    }
    return [delivery stringByAppendingString:@"."];
}

#pragma mark - Actions

- (void)saveCredentials
{
    NSString *apiIDText = _apiIDField.text;
    NSString *hash = [_apiHashField.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSInteger apiID = apiIDText.integerValue;
    if (apiID <= 0) {
        [self showError:@"The API ID must be a positive number."];
        return;
    }
    if (hash.length < 16) {
        [self showError:@"The API hash looks too short. Copy it from my.telegram.org."];
        return;
    }

    [PGConfig setAPIID:apiID apiHash:hash];
    _busy = YES;
    _primaryButton.enabled = NO;
    [[PGClient shared] retryWithCredentials];
}

- (void)submitPhone
{
    NSString *phone = PGNormalizePhone(_phoneField.text);
    if (phone.length < 9) {
        [self showError:@"Enter your number in international format, for example +1 555 0100."];
        return;
    }

    _phoneNumber = phone;
    _busy = YES;
    _primaryButton.enabled = NO;
    [[PGClient shared] setPhoneNumber:phone];
}

- (void)submitCode
{
    NSString *code = PGCompactCode(_codeField.text);
    if (code.length == 0) {
        [self showError:@"Enter the login code."];
        return;
    }

    _busy = YES;
    _primaryButton.enabled = NO;
    [[PGClient shared] submitCode:code];
}

- (void)submitPassword
{
    NSString *password = _passwordField.text;
    if (password.length == 0) {
        [self showError:@"Enter your password."];
        return;
    }

    _busy = YES;
    _primaryButton.enabled = NO;
    [[PGClient shared] submitPassword:password];
}

- (void)submitRegistration
{
    NSString *firstName = [_firstNameField.text stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (firstName.length == 0) {
        [self showError:@"Enter your first name."];
        return;
    }

    NSString *lastName = [_lastNameField.text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    _busy = YES;
    _primaryButton.enabled = NO;
    [[PGClient shared] registerFirstName:firstName lastName:lastName ?: @""];
}

- (void)resendCode
{
    if (!_resendButton.enabled) {
        return;
    }
    _resendButton.enabled = NO;
    [[PGClient shared] resendCode];
    [self startResendCountdown:30];
}

- (void)changeNumber
{
    [self applyAuthState:PGAuthStateWaitPhoneNumber info:@{}];
}

- (void)cancelSignIn
{
    _busy = YES;
    _primaryButton.enabled = NO;
    [[PGClient shared] logout];
}

#pragma mark - Resend countdown

- (void)startResendCountdown:(NSInteger)seconds
{
    [_resendTimer invalidate];
    _resendTimer = nil;
    _resendSeconds = seconds;

    if (_resendButton == nil) {
        return;
    }

    if (seconds <= 0) {
        _resendButton.enabled = YES;
        [_resendButton setTitle:@"Resend code" forState:UIControlStateNormal];
        return;
    }

    _resendButton.enabled = NO;
    [self updateResendTitle];
    _resendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                    target:self
                                                  selector:@selector(resendTick)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)resendTick
{
    _resendSeconds -= 1;
    if (_resendSeconds <= 0) {
        [_resendTimer invalidate];
        _resendTimer = nil;
        _resendButton.enabled = YES;
        [_resendButton setTitle:@"Resend code" forState:UIControlStateNormal];
        return;
    }
    [self updateResendTitle];
}

- (void)updateResendTitle
{
    NSString *title = [NSString stringWithFormat:@"Resend code in %ld s", (long)_resendSeconds];
    [_resendButton setTitle:title forState:UIControlStateNormal];
    [_resendButton setTitle:title forState:UIControlStateDisabled];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
    CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
    _scrollView.frame = self.view.bounds;

    CGFloat cardWidth = MIN(380.0, viewWidth - 48.0);
    CGFloat innerWidth = cardWidth - 48.0;
    if (innerWidth < 100.0) {
        innerWidth = 100.0;
    }

    CGFloat y = 28.0;
    for (UIView *item in _items) {
        CGFloat height = [self heightForItem:item width:innerWidth];
        item.frame = CGRectMake(24.0, y, innerWidth, height);
        if (item.tag == 200) {
            UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)[item viewWithTag:201];
            spinner.center = CGPointMake(innerWidth / 2.0, 22.0);
            UIView *label = [item viewWithTag:202];
            label.frame = CGRectMake(0, 44.0, innerWidth, 20.0);
        }
        y += height + 12.0;
    }

    if (_errorText.length > 0) {
        CGSize size = [_errorLabel sizeThatFits:CGSizeMake(innerWidth, CGFLOAT_MAX)];
        CGFloat height = ceil(size.height);
        _errorLabel.frame = CGRectMake(24.0, y, innerWidth, height);
        y += height + 12.0;
    } else {
        _errorLabel.frame = CGRectZero;
    }

    CGFloat cardHeight = y + 16.0;
    CGFloat contentHeight = MAX(cardHeight + 80.0, viewHeight);

    _contentView.frame = CGRectMake(0, 0, viewWidth, contentHeight);
    CGFloat cardY = MAX(40.0, (contentHeight - cardHeight) / 2.0);
    _card.frame = CGRectMake((viewWidth - cardWidth) / 2.0, cardY, cardWidth, cardHeight);
    _scrollView.contentSize = CGSizeMake(viewWidth, contentHeight);
}

- (CGFloat)heightForItem:(UIView *)item width:(CGFloat)width
{
    if ([item isKindOfClass:[UILabel class]]) {
        CGSize size = [item sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
        return MAX(ceil(size.height), 1.0);
    }
    return CGRectGetHeight(item.frame) > 0.0 ? CGRectGetHeight(item.frame) : 44.0;
}

#pragma mark - Keyboard

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    CGRect frame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect converted = [self.view convertRect:frame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(converted));

    _scrollView.contentInset = UIEdgeInsetsMake(0, 0, overlap, 0);
    _scrollView.scrollIndicatorInsets = _scrollView.contentInset;

    if (_activeField != nil) {
        [self scrollFieldToVisible:_activeField];
    }
}

- (void)scrollFieldToVisible:(UITextField *)field
{
    CGRect rect = [field convertRect:field.bounds toView:_scrollView];
    rect = CGRectInset(rect, 0, -40.0);
    [_scrollView scrollRectToVisible:rect animated:YES];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    _activeField = textField;
    [self scrollFieldToVisible:textField];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (_activeField == textField) {
        _activeField = nil;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _phoneField) {
        [self submitPhone];
    } else if (textField == _codeField) {
        [self submitCode];
    } else if (textField == _passwordField) {
        [self submitPassword];
    } else if (textField == _firstNameField || textField == _lastNameField) {
        [self submitRegistration];
    } else if (textField == _apiIDField || textField == _apiHashField) {
        [self saveCredentials];
    }
    return YES;
}

@end
