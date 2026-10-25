//
//  PGMessageCell.m
//  Papergram
//

#import "PGMessageCell.h"
#import "PGFormatters.h"
#import "PGTheme.h"

@implementation PGMessageCell {
    UIView *_bubble;
    UILabel *_textLabel;
    UILabel *_senderLabel;
    UILabel *_timeLabel;
    UILabel *_serviceLabel;
    PGMessage *_message;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _bubble = [[UIView alloc] initWithFrame:CGRectZero];
        _bubble.layer.cornerRadius = 14.0;
        _bubble.layer.borderWidth = 0.5;
        [self.contentView addSubview:_bubble];

        _senderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _senderLabel.font = [PGTheme messageSenderFont];
        _senderLabel.textColor = [PGTheme accent];
        _senderLabel.numberOfLines = 1;
        [self.contentView addSubview:_senderLabel];

        _textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _textLabel.font = [PGTheme messageFont];
        _textLabel.textColor = [PGTheme primaryText];
        _textLabel.numberOfLines = 0;
        _textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self.contentView addSubview:_textLabel];

        _timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _timeLabel.font = [PGTheme messageTimeFont];
        _timeLabel.textColor = [PGTheme tertiaryText];
        _timeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_timeLabel];

        _serviceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _serviceLabel.font = [UIFont systemFontOfSize:12.0];
        _serviceLabel.textColor = [PGTheme secondaryText];
        _serviceLabel.textAlignment = NSTextAlignmentCenter;
        _serviceLabel.numberOfLines = 1;
        _serviceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_serviceLabel];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _message = nil;
    _textLabel.text = nil;
    _senderLabel.text = nil;
    _timeLabel.text = nil;
    _serviceLabel.text = nil;
}

- (void)configureWithMessage:(PGMessage *)message
{
    _message = message;

    if (message.service) {
        _bubble.hidden = YES;
        _textLabel.hidden = YES;
        _senderLabel.hidden = YES;
        _timeLabel.hidden = YES;
        _serviceLabel.hidden = NO;
        _serviceLabel.text = message.text;
    } else {
        _bubble.hidden = NO;
        _textLabel.hidden = NO;
        _timeLabel.hidden = NO;
        _serviceLabel.hidden = YES;
        _serviceLabel.text = nil;

        _bubble.backgroundColor = message.outgoing ? [PGTheme bubbleOutgoing] : [PGTheme bubbleIncoming];
        _bubble.layer.borderColor = message.outgoing ? [UIColor clearColor].CGColor
                                                     : [PGTheme bubbleBorder].CGColor;

        _textLabel.text = message.text;

        BOOL showsSender = message.senderName.length > 0 && !message.outgoing;
        _senderLabel.hidden = !showsSender;
        _senderLabel.text = showsSender ? message.senderName : nil;

        if (message.failed) {
            _timeLabel.text = @"Not delivered";
            _timeLabel.textColor = [PGTheme danger];
        } else {
            _timeLabel.text = PGMessageTimeString(message.date);
            _timeLabel.textColor = [PGTheme tertiaryText];
        }
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (_message == nil) {
        return;
    }

    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    if (_message.service) {
        _serviceLabel.frame = CGRectMake(16.0, (CGRectGetHeight(self.contentView.bounds) - 18.0) / 2.0,
                                         width - 32.0, 18.0);
        return;
    }

    PGMessageLayout layout = [_message layoutForWidth:width];
    _bubble.frame = layout.bubble;
    _senderLabel.frame = layout.sender;
    _textLabel.frame = layout.text;
    _timeLabel.frame = layout.time;
}

@end
