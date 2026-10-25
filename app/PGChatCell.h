//
//  PGChatCell.h
//  Papergram
//

#import <UIKit/UIKit.h>
#import "PGModels.h"

@interface PGChatCell : UITableViewCell

- (void)configureWithChat:(PGChat *)chat;

@end
