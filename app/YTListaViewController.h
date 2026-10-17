// YTListaViewController.h -- el contenido de una lista de reproduccion.
#import <UIKit/UIKit.h>

@interface YTListaViewController : UIViewController

// Identificador de la lista (PL...). El titulo solo se usa para la barra de
// arriba mientras se carga.
- (instancetype)initWithListaId:(NSString *)listaId titulo:(NSString *)titulo;

@end
