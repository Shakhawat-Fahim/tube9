// YTListaCell.h -- fila de una lista de reproduccion.
//
// La miniatura de una lista es el mosaico de sus cuatro primeros videos, asi que
// se enseña tal cual, con el titulo y el numero de videos al lado.
#import <UIKit/UIKit.h>

@interface YTListaCell : UITableViewCell

// El diccionario que devuelve YTClient (listasDeCanal:, buscarListas:):
//   id, titulo, videos ("28 videos"), canal, urlMiniatura
@property (nonatomic, strong) NSDictionary *lista;

- (void)configurarCon:(NSDictionary *)lista;

+ (CGFloat)alto;

@end
