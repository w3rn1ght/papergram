//
//  PGLogoView.m
//  Papergram
//

#import "PGLogoView.h"
#import "PGTheme.h"

@implementation PGLogoView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL) {
        return;
    }

    CGRect bounds = self.bounds;
    CGFloat size = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    CGRect circle = CGRectMake((CGRectGetWidth(bounds) - size) / 2.0,
                               (CGRectGetHeight(bounds) - size) / 2.0,
                               size, size);

    [[PGTheme accent] setFill];
    CGContextFillEllipseInRect(context, circle);

    CGFloat left = CGRectGetMinX(circle);
    CGFloat top = CGRectGetMinY(circle);

    UIBezierPath *plane = [UIBezierPath bezierPath];
    [plane moveToPoint:CGPointMake(left + size * 0.18, top + size * 0.52)];
    [plane addLineToPoint:CGPointMake(left + size * 0.82, top + size * 0.22)];
    [plane addLineToPoint:CGPointMake(left + size * 0.60, top + size * 0.80)];
    [plane addLineToPoint:CGPointMake(left + size * 0.48, top + size * 0.58)];
    [plane closePath];
    [[UIColor whiteColor] setFill];
    [plane fill];

    UIBezierPath *fold = [UIBezierPath bezierPath];
    [fold moveToPoint:CGPointMake(left + size * 0.48, top + size * 0.58)];
    [fold addLineToPoint:CGPointMake(left + size * 0.82, top + size * 0.22)];
    [fold addLineToPoint:CGPointMake(left + size * 0.60, top + size * 0.80)];
    [fold closePath];
    [[UIColor colorWithWhite:1.0 alpha:0.55] setFill];
    [fold fill];
}

@end
