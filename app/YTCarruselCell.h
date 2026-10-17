// YTCarruselCell.h -- una fila con titulo ("Tendencias") y tarjetas que se
// deslizan en horizontal, como los estantes de la pantalla de Inicio.
#import <UIKit/UIKit.h>
#import "YTVideo.h"

@interface YTCarruselCell : UITableViewCell

// Se llama al tocar una tarjeta; la pantalla decide a donde ir.
@property (nonatomic, copy) void (^alElegirVideo)(YTVideo *video);

- (void)configurarConTitulo:(NSString *)titulo videos:(NSArray *)videos;

// Alto total de la fila (titulo + tarjetas).
+ (CGFloat)alto;

@end
