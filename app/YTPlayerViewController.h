// YTPlayerViewController.h
#import <UIKit/UIKit.h>
#import "YTVideo.h"

@interface YTPlayerViewController : UIViewController

// Video de YouTube: se resuelve la direccion con YTClient y se reproduce.
- (instancetype)initWithVideo:(YTVideo *)video;

// Fichero ya descargado en el dispositivo (Descargas > Reproducir aqui).
- (instancetype)initConRutaLocal:(NSString *)ruta titulo:(NSString *)titulo;

@end
