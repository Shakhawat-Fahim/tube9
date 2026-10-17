// YTVideoCell.h -- tarjeta plana con miniatura + titulo
#import <UIKit/UIKit.h>
#import "YTVideo.h"

@interface YTVideoCell : UITableViewCell

@property (nonatomic, strong) YTVideo *video;

- (void)configurarCon:(YTVideo *)video;

@end
