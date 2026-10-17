// YTChannelViewController.h -- la ficha de un canal: portada, avatar, nombre,
// suscriptores y sus pestanas (Videos / Listas / Informacion).
#import <UIKit/UIKit.h>

@interface YTChannelViewController : UIViewController

// El identificador (UC...) es lo unico imprescindible. El titulo solo sirve
// para que la barra de arriba tenga algo mientras se carga la ficha.
- (instancetype)initWithCanalId:(NSString *)canalId titulo:(NSString *)titulo;

@end
