//
//  PGComposerView.h
//  Papergram
//

#import <UIKit/UIKit.h>

@class PGComposerView;

@protocol PGComposerViewDelegate <NSObject>
- (void)composerView:(PGComposerView *)composer didSubmitText:(NSString *)text;
@end

@interface PGComposerView : UIView

@property (nonatomic, weak) id<PGComposerViewDelegate> delegate;
/// Extra space below the input row, used for the home indicator area.
@property (nonatomic) CGFloat contentBottomInset;

- (void)clearText;
- (void)setDraftText:(NSString *)text;
- (void)focusInput;

@end
