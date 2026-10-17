// YTCanalCell.h -- fila de un canal en los resultados del buscador.
//
// Dibuja lo mismo que la aplicacion oficial: el avatar redondo, el nombre, los
// suscriptores y la frasecita de presentacion del canal.
#import <UIKit/UIKit.h>

@interface YTCanalCell : UITableViewCell

// El diccionario que devuelve YTClient buscarCanales::
//   id, titulo, suscritos, videos, manejador, descripcion, urlMiniatura
@property (nonatomic, strong) NSDictionary *canal;

- (void)configurarCon:(NSDictionary *)canal;

// Todas las filas miden igual: avatar, tres lineas de texto y margenes.
+ (CGFloat)alto;

@end
