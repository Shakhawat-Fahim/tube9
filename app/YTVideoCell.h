// YTVideoCell.h -- tarjeta plana con miniatura + titulo
#import <UIKit/UIKit.h>
#import "YTVideo.h"

@interface YTVideoCell : UITableViewCell

@property (nonatomic, strong) YTVideo *video;

- (void)configurarCon:(YTVideo *)video;

// Alto que necesita la celda para un ancho dado (miniatura 16:9 + textos).
+ (CGFloat)altoParaAncho:(CGFloat)ancho;

@end
