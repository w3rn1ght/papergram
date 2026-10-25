//
//  PGQRCodeView.h
//  Papergram
//

#import <UIKit/UIKit.h>

/// Renders a QR code without any image assets. The symbol is drawn with
/// CoreGraphics and a four-module quiet zone.
@interface PGQRCodeView : UIView

/// Encodes `string` as a QR code. Returns NO if it does not fit.
- (BOOL)setString:(NSString *)string;

@end

/// Square container that keeps the QR symbol centred in its bounds.
@interface PGQRCodeBox : UIView

- (BOOL)setString:(NSString *)string;

@end
