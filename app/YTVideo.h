// YTVideo.h -- un resultado de busqueda
#import <Foundation/Foundation.h>

@interface YTVideo : NSObject

@property (nonatomic, copy) NSString *identificador;   // videoId
@property (nonatomic, copy) NSString *titulo;
@property (nonatomic, copy) NSString *canal;
@property (nonatomic, copy) NSString *duracion;
@property (nonatomic, copy) NSString *vistas;
@property (nonatomic, copy) NSString *publicado;
@property (nonatomic, copy) NSString *urlMiniatura;    // imagen a descargar

// Construye un YTVideo a partir del JSON del relay (claves en espanol).
+ (instancetype)desdeRelay:(NSDictionary *)diccionario;

// Construye un YTVideo a partir de un videoRenderer de YouTube (InnerTube).
+ (instancetype)desdeRenderer:(NSDictionary *)renderer;

+ (NSArray *)listaDesdeRelay:(NSArray *)arreglo;

// "Canal  ·  1,2 M de vistas  ·  hace 3 anos"
- (NSString *)descripcion;

@end
