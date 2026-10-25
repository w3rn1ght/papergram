//
//  PGChatCell.m
//  Papergram
//

#import "PGChatCell.h"
#import "PGFormatters.h"
#import "PGTheme.h"

@implementation PGChatCell {
    UILabel *_avatarLabel;
    UILabel *_titleLabel;
    UILabel *_previewLabel;
    UILabel *_dateLabel;
    UILabel *_badgeLabel;
    UIView *_dotView;
    PGChat *_chat;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [PGTheme cardBackground];
        self.contentView.backgroundColor = [PGTheme cardBackground];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        _avatarLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _avatarLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
        _avatarLabel.textColor = [UIColor whiteColor];
        _avatarLabel.textAlignment = NSTextAlignmentCenter;
        _avatarLabel.layer.cornerRadius = 23.0;
        _avatarLabel.clipsToBounds = YES;
        [self.contentView addSubview:_avatarLabel];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [PGTheme chatTitleFont];
        _titleLabel.textColor = [PGTheme primaryText];
        [self.contentView addSubview:_titleLabel];

        _previewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _previewLabel.font = [PGTheme chatPreviewFont];
        _previewLabel.textColor = [PGTheme secondaryText];
        [self.contentView addSubview:_previewLabel];

        _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateLabel.font = [PGTheme chatDateFont];
        _dateLabel.textColor = [PGTheme tertiaryText];
        _dateLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_dateLabel];

        _badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _badgeLabel.font = [PGTheme badgeFont];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.backgroundColor = [PGTheme badge];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.layer.cornerRadius = 10.0;
        _badgeLabel.clipsToBounds = YES;
        [self.contentView addSubview:_badgeLabel];

        _dotView = [[UIView alloc] initWithFrame:CGRectZero];
        _dotView.backgroundColor = [PGTheme accent];
        _dotView.layer.cornerRadius = 5.0;
        [self.contentView addSubview:_dotView];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _chat = nil;
    _titleLabel.text = nil;
    _previewLabel.text = nil;
    _dateLabel.text = nil;
    _badgeLabel.text = nil;
    _badgeLabel.hidden = YES;
    _dotView.hidden = YES;
    _avatarLabel.text = nil;
}

- (void)configureWithChat:(PGChat *)chat
{
    _chat = chat;

    _titleLabel.text = chat.title.length > 0 ? chat.title : @"Untitled chat";
    _dateLabel.text = PGChatDateString(chat.lastMessageDate);

    NSString *preview = chat.lastMessagePreview;
    if (chat.lastMessageOutgoing && preview.length > 0) {
        preview = [@"You: " stringByAppendingString:preview];
    }
    _previewLabel.text = preview;

    _avatarLabel.text = [PGTheme initialsForTitle:chat.title];
    _avatarLabel.backgroundColor = [PGTheme avatarColorForIdentifier:chat.identifier];

    NSInteger unread = chat.unreadCount;
    if (unread > 0) {
        _badgeLabel.hidden = NO;
        _dotView.hidden = YES;
        _badgeLabel.text = unread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unread];
    } else {
        _badgeLabel.hidden = YES;
        _badgeLabel.text = nil;
        _dotView.hidden = !chat.markedAsUnread;
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat rightPadding = 16.0;
    CGFloat textX = 72.0;
    CGFloat dateWidth = 68.0;

    _avatarLabel.frame = CGRectMake(14.0, 11.0, 46.0, 46.0);
    _dateLabel.frame = CGRectMake(width - rightPadding - dateWidth, 12.0, dateWidth, 16.0);

    CGFloat titleWidth = width - textX - rightPadding - dateWidth - 8.0;
    if (titleWidth < 40.0) {
        titleWidth = 40.0;
    }
    _titleLabel.frame = CGRectMake(textX, 10.0, titleWidth, 21.0);

    CGFloat badgeWidth = 0.0;
    if (!_badgeLabel.hidden) {
        CGSize size = [_badgeLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 20.0)];
        badgeWidth = MAX(20.0, ceil(size.width) + 12.0);
        _badgeLabel.frame = CGRectMake(width - rightPadding - badgeWidth, 34.0, badgeWidth, 20.0);
    } else {
        _badgeLabel.frame = CGRectZero;
    }

    if (!_dotView.hidden) {
        _dotView.frame = CGRectMake(width - rightPadding - 10.0, 39.0, 10.0, 10.0);
    } else {
        _dotView.frame = CGRectZero;
    }

    CGFloat previewRight = width - rightPadding;
    if (badgeWidth > 0.0) {
        previewRight -= badgeWidth + 8.0;
    } else if (!_dotView.hidden) {
        previewRight -= 16.0;
    }
    CGFloat previewWidth = previewRight - textX;
    if (previewWidth < 40.0) {
        previewWidth = 40.0;
    }
    _previewLabel.frame = CGRectMake(textX, 34.0, previewWidth, 19.0);
}

@end
