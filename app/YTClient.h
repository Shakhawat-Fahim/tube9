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

// Igual que el anterior, pero buscando en el catalogo de YouTube Music. Sirve
// para rellenar la pestana de Musica con temas de un estilo ("baladas",
// "reggaeton"...): esas respuestas no traen estantes con nombre, asi que todo
// lo que aparece se agrupa en un estante titulado con la propia consulta.
- (void)carruselesDeMusicaBuscando:(NSString *)consulta
                        completion:(void (^)(NSArray *carruseles, NSError *error))completion;

// Devuelve un diccionario con: url, titulo, autor, canalId, visitas, duracion,
// descripcion, itag, bytes, cliente.
// Prueba varios clientes de YouTube en orden hasta que uno responda.
- (void)resolverVideo:(NSString *)videoId completion:(YTBloqueInfo)completion;

#pragma mark Canales y listas de reproduccion

// Ficha de un canal. Devuelve un diccionario con:
//   id, titulo, manejador ("@kurzgesagt"), suscritos, videos,
//   urlAvatar, urlPortada,
//   videosDestacados (NSArray<YTVideo*>) y listasDestacadas (NSArray de listas),
//   y los "params" de sus pestanas: paramsVideos, paramsListas, paramsInfo.
// Los "params" los manda YouTube en la propia pagina del canal y se devuelven
// tal cual: son cadenas en base64 que no hay que entender ni fabricar.
- (void)canalConId:(NSString *)canalId completion:(YTBloqueInfo)completion;

// Pestana "Videos" de un canal: sus videos recientes (unos 30).
- (void)videosDeCanal:(NSString *)canalId
               params:(NSString *)params
           completion:(YTBloqueLista)completion;

// Pestana "Listas" de un canal. Cada lista es un diccionario con:
//   id, titulo, videos ("28 videos"), canal, urlMiniatura
- (void)listasDeCanal:(NSString *)canalId
               params:(NSString *)params
           completion:(void (^)(NSArray *listas, NSError *error))completion;

// Pestana "Informacion" de un canal: descripcion larga, visitas de por vida,
// pais, fecha de alta y enlaces.
- (void)informacionDeCanal:(NSString *)canalId
                    params:(NSString *)params
                completion:(YTBloqueInfo)completion;

// Contenido de una lista de reproduccion. Devuelve la ficha de la lista
// (titulo, dueno, cuantos, descripcion) y el arreglo de videos.
- (void)videosDeLista:(NSString *)listaId
           completion:(void (^)(NSDictionary *lista, NSArray *videos,
                                NSError *error))completion;

// Los filtros del buscador de YouTube: por canales y por listas.
// Los canales vienen como diccionarios con:
//   id, titulo, suscritos, videos, manejador, descripcion, urlMiniatura
- (void)buscarCanales:(NSString *)consulta
           completion:(void (^)(NSArray *canales, NSError *error))completion;
- (void)buscarListas:(NSString *)consulta
          completion:(void (^)(NSArray *listas, NSError *error))completion;

// Videos parecidos a uno dado. YouTube tiene un endpoint propio para esto
// ("next"), pero su respuesta pesa unos 7 MB (demasiado para un telefono de
// 32 bits), asi que aqui se busca por el titulo y se descarta el propio video.
- (void)relacionadosDe:(NSString *)titulo
           excluyendo:(NSString *)videoId
            completion:(YTBloqueLista)completion;
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
