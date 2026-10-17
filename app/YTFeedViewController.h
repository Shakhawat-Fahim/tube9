// YTFeedViewController.h -- pantalla con varios "estantes" de videos.
// Sirve para Inicio (temas buscados en YouTube) y para Musica (YouTube Music).
#import <UIKit/UIKit.h>

@interface YTFeedViewController : UIViewController

// Cada fuente es un diccionario:  @{ @"titulo": ..., @"consulta": ...,
//                                    @"params": ... (opcional, el orden) }
- (instancetype)initConTitulo:(NSString *)titulo fuentes:(NSArray *)fuentes;

// Pantalla de YouTube Music: los estantes los arma YouTube, no nosotros.
- (instancetype)initConMusica;

@end
