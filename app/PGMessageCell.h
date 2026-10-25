//
//  PGMessageCell.h
//  Papergram
//

#import <UIKit/UIKit.h>
#import "PGModels.h"

@interface PGMessageCell : UITableViewCell

- (void)configureWithMessage:(PGMessage *)message;

@end
