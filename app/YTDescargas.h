// YTDescargas.h -- descarga videos al almacenamiento del dispositivo.
//
// En un dispositivo con jailbreak la app puede escribir fuera de su propia
// carpeta, asi que la carpeta de destino es elegible (Ajustes > Descargas).
// Si la carpeta elegida no se puede escribir de verdad, se avisa en vez de
// fallar en silencio y se usa la de la propia app, que siempre funciona.
#import <Foundation/Foundation.h>
#import "YTVideo.h"

// Se manda cuando cambia el historial de descargas (empieza, termina o se
// borra algo) para que las pantallas abiertas se refresquen.
extern NSString *const YTDescargasCambio;

@interface YTDescargas : NSObject

+ (instancetype)compartido;

// --- Carpeta de destino ---------------------------------------------------
+ (NSString *)carpetaPorDefecto;                  // Documents/Descargas de la app
+ (NSString *)carpeta;                            // la elegida, o la de defecto
+ (void)guardarCarpeta:(NSString *)ruta;
+ (BOOL)sePuedeEscribirEn:(NSString *)ruta;       // prueba real: escribe y borra
+ (NSString *)nombreBonitoDeCarpeta:(NSString *)ruta;

// --- Descargas ------------------------------------------------------------
- (NSArray *)historial;                           // mas reciente primero
- (BOOL)estaDescargando:(NSString *)videoId;
- (void)descargarVideo:(YTVideo *)video
              progreso:(void (^)(double fraccion))progreso
            completion:(void (^)(BOOL ok, NSString *mensaje, NSString *ruta))completion;
- (void)cancelarVideo:(NSString *)videoId;
- (void)borrarEntrada:(NSDictionary *)entrada;
- (void)borrarTodo;
- (unsigned long long)espacioLibre;               // bytes libres en la carpeta

@end
