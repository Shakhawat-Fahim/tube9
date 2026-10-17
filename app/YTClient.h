// YTClient.h -- obtiene datos de YouTube (directo o via relay) y miniaturas
#import <UIKit/UIKit.h>
#import "YTVideo.h"

typedef void (^YTBloqueLista)(NSArray *videos, NSError *error);
typedef void (^YTBloqueInfo)(NSDictionary *info, NSError *error);

@interface YTClient : NSObject

+ (instancetype)compartido;

// Ordenes que acepta YouTube en el campo "params" de una busqueda.
extern NSString *const YTOrdenPorPopularidad;   // mas vistos primero
extern NSString *const YTOrdenRecientes;        // subidos hace poco

// Datos
- (void)buscar:(NSString *)consulta completion:(YTBloqueLista)completion;

// Igual que buscar:, pero permite pedirle a YouTube un orden concreto
// (YTOrdenPorPopularidad / YTOrdenRecientes) o cualquier otro "params".
- (void)buscar:(NSString *)consulta
        params:(NSString *)params
    completion:(YTBloqueLista)completion;

// Estantes de YouTube Music (music.youtube.com) para un identificador de
// pantalla: "FEmusic_home", "FEmusic_explore", "FEmusic_new_releases".
// Devuelve "carruseles", un arreglo de filas:
//   @{ @"titulo": NSString, @"videos": NSArray<YTVideo*> }
// Solo sirve para NAVEGAR: los videos se reproducen siempre con el cliente
// ANDROID, porque YouTube Music pide JavaScript para descifrar sus enlaces.
- (void)carruselesDeMusica:(NSString *)browseId
                completion:(void (^)(NSArray *carruseles, NSError *error))completion;

// Devuelve un diccionario con: url, titulo, autor, cliente.
// Prueba varios clientes de YouTube en orden hasta que uno responda.
- (void)resolverVideo:(NSString *)videoId completion:(YTBloqueInfo)completion;
- (void)probarConexion:(void (^)(NSString *informe))completion;

// Miniaturas (con cache en memoria)
+ (void)cargarMiniatura:(NSString *)url
             completion:(void (^)(UIImage *imagen))completion;
+ (void)vaciarCacheMiniaturas;

// --- Ajustes persistentes ------------------------------------------------
+ (NSString *)modo;            // @"directo" o @"relay"
+ (NSString *)relayBase;       // p.ej. http://192.168.1.50:8787
+ (NSString *)relayToken;
+ (void)guardarModo:(NSString *)modo
              relay:(NSString *)relay
              token:(NSString *)token;

// --- Sesion (cookies de YouTube) -----------------------------------------
+ (BOOL)haySesion;
+ (NSUInteger)numeroDeCookies;
+ (void)cerrarSesion;
+ (NSString *)clienteYT;       // el que se usa para buscar
+ (NSString *)listaDeClientes; // todos los que se prueban al resolver el video

// Identificador anonimo de visitante ("visitorData"). YouTube lo pide y, sin
// el, contesta "LOGIN_REQUIRED" mucho mas a menudo. Se guarda entre arranques.
+ (NSString *)visitante;
+ (void)olvidarVisitante;

// Cookies pegadas a mano (alternativa al inicio de sesion con formulario).
// Se envian como cabecera Cookie en cada peticion.
+ (void)guardarCookiesManuales:(NSString *)crudo;
+ (NSString *)cookiesManuales;

// Mensaje de error traducido y util para el usuario
+ (NSString *)explicarError:(NSError *)error;

@end
