//
//  PGQRCodeView.m
//  Papergram
//

#import "PGQRCodeView.h"
#import "PGQRCode.h"

@implementation PGQRCodeView {
    PGQRCode _code;
    BOOL _hasCode;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.opaque = YES;
        self.contentMode = UIViewContentModeRedraw;
        self.userInteractionEnabled = NO;
        _hasCode = NO;
    }
    return self;
}

- (void)dealloc
{
    pg_qr_free(&_code);
}

- (BOOL)setString:(NSString *)string
{
    pg_qr_free(&_code);
    _hasCode = NO;

    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        [self setNeedsDisplay];
        return NO;
    }

    if (!pg_qr_encode(data.bytes, (int)data.length, &_code)) {
        [self setNeedsDisplay];
        return NO;
    }

    _hasCode = YES;
    [self setNeedsDisplay];
    return YES;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL) {
        return;
    }

    [[UIColor whiteColor] setFill];
    CGContextFillRect(context, self.bounds);

    if (!_hasCode || _code.size <= 0) {
        return;
    }

    const int count = _code.size;
    const int quietZone = 4;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat available = MIN(width, height);
    CGFloat module = floor(available / (CGFloat)(count + quietZone * 2));
    if (module < 1.0) {
        module = 1.0;
    }

    CGFloat total = module * (CGFloat)(count + quietZone * 2);
    CGFloat originX = floor((width - total) / 2.0) + module * quietZone;
    CGFloat originY = floor((height - total) / 2.0) + module * quietZone;

    [[UIColor blackColor] setFill];
    for (int row = 0; row < count; row++) {
        for (int column = 0; column < count; column++) {
            if (!_code.modules[row * count + column]) {
                continue;
            }
            CGRect square = CGRectMake(originX + module * column,
                                       originY + module * row,
                                       module, module);
            CGContextFillRect(context, square);
        }
    }
}

@end

@implementation PGQRCodeBox {
    PGQRCodeView *_qrView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _qrView = [[PGQRCodeView alloc] initWithFrame:CGRectZero];
        [self addSubview:_qrView];
    }
    return self;
}

- (BOOL)setString:(NSString *)string
{
    return [_qrView setString:string];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    _qrView.frame = CGRectMake(floor((CGRectGetWidth(self.bounds) - side) / 2.0),
                               floor((CGRectGetHeight(self.bounds) - side) / 2.0),
                               side, side);
}

@end
