// YTVideoCell.h -- tarjeta plana con miniatura + titulo
#import <UIKit/UIKit.h>
#import "YTVideo.h"

@interface YTVideoCell : UITableViewCell

@property (nonatomic, strong) YTVideo *video;

// Se llama al tocar el nombre del canal (la linea de debajo del titulo). Solo
// responde si el video trae identificador de canal; si no, no hace nada.
@property (nonatomic, copy) void (^alTocarCanal)(YTVideo *video);

- (void)configurarCon:(YTVideo *)video;

// Alto que necesita la celda para un ancho dado (miniatura 16:9 + textos).
+ (CGFloat)altoParaAncho:(CGFloat)ancho;

@end
