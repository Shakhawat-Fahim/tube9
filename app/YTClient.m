// YTClient.m -- habla con YouTube (InnerTube) o con el relay
#import "YTClient.h"

// --- Constantes de YouTube ------------------------------------------------
static NSString * const kClaveAPI = @"AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w";
static NSString * const kBaseYT   = @"https://www.youtube.com/youtubei/v1";
static NSString * const kBaseYTMusic = @"https://music.youtube.com/youtubei/v1";

// Ordenes de busqueda. Son "params" en base64 que YouTube ya tenia en su web;
// no hay que fabricarlos, se envian tal cual en la peticion de busqueda.
NSString *const YTOrdenPorPopularidad = @"CAMSAhAB";     // ordenar por mas vistos
NSString *const YTOrdenRecientes      = @"EgIQAQ%3D%3D"; // ordenar por mas nuevos

// Claves de NSUserDefaults
static NSString * const kDefModo      = @"tube9_modo";
static NSString * const kDefRelay     = @"tube9_relay";
static NSString * const kDefToken     = @"tube9_token";
static NSString * const kDefVisitante = @"tube9_visitante";

// --- Clientes de InnerTube ------------------------------------------------
//  Tabla tomada de yt-dlp (yt_dlp/extractor/youtube/_base.py), que a su vez la
//  mantiene contra los cambios de YouTube. Hay dos filtros y entre los dos
//  quedan muy pocos clientes utilizables desde un iPhone con iOS 9:
//
//  1) El reproductor JavaScript ("nsig"). En yt-dlp, REQUIRE_JS_PLAYER vale
//     True POR DEFECTO, y solo android, android_vr, ios y visionos lo ponen en
//     False. En esos cuatro la URL del MP4 muxado (itag 18, 360p con audio)
//     llega ya lista. En el resto (WEB, MWEB, TVHTML5...) hay que ejecutar el
//     JavaScript del reproductor para descifrar la firma, y en iOS 9 no hay
//     motor de JavaScript con el que hacerlo. O sea: solo valen esos cuatro.
//
//  2) El "po token" de descarga. YouTube exige a veces un token extra para
//     servir los bytes de googlevideo, y ese token SOLO se puede fabricar
//     ejecutando el JavaScript de BotGuard de Google (Node.js o un navegador
//     completo). De los cuatro clientes de arriba, la tabla marca android,
//     android_vr e ios como obligatorio y visionos como no exigido; pero al
//     medirlo de verdad (abajo) el que descarga siempre es android, y visionos
//     no devuelve ni un formato. Las tablas orientan; la medicion manda.
//
//  Ademas, cada cliente tiene su propio umbral antibot: YouTube contesta
//  "LOGIN_REQUIRED" ("Inicia sesion para confirmar que no eres un bot") de
//  forma distinta segun quien pregunte. Por eso se prueban todos, en orden, y
//  se comprueba que la URL se descargue de verdad antes de darsela al
//  reproductor.
//  Medido desde este mismo equipo (misma red que el dispositivo) con 12 videos:
//  el cliente ANDROID descargo los 12; ANDROID_VR fallo con HTTP 403 en 3 de
//  ellos (YouTube le exige po token en esos); y ni IOS ni VISIONOS devolvieron
//  un solo formato utilizable. Por eso el orden es ANDROID primero.
static NSArray *YTClientes(void) {
    static NSArray *lista = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        lista = @[
            // El que funciona hoy: resolvio y descargo los 12 de 12.
            @{ @"nombre"  : @"ANDROID",
               @"version" : @"21.26.364",
               @"id"      : @3,
               @"agente"  : @"com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip",
               @"sdk"     : @30,
               @"extra"   : @{ @"osName" : @"Android", @"osVersion" : @"11" },
               @"nota"    : @"app de Android (12 de 12 descargas correctas)" },

            @{ @"nombre"  : @"ANDROID_VR",
               @"version" : @"1.65.10",
               @"id"      : @28,
               @"agente"  : @"com.google.android.apps.youtube.vr.oculus/1.65.10 "
                            @"(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
               @"sdk"     : @32,
               @"extra"   : @{ @"deviceMake" : @"Oculus", @"deviceModel" : @"Quest 3",
                               @"osName" : @"Android", @"osVersion" : @"12L" },
               @"nota"    : @"gafas VR (9 de 12: YouTube le pide po token en algunos)" },

            @{ @"nombre"  : @"IOS",
               @"version" : @"21.26.4",
               @"id"      : @5,
               @"agente"  : @"com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 "
                            @"like Mac OS X;)",
               @"sdk"     : @0,
               @"extra"   : @{ @"deviceMake" : @"Apple", @"deviceModel" : @"iPhone16,2",
                               @"osName" : @"iPhone", @"osVersion" : @"18.3.2.22D82" },
               @"nota"    : @"app de iPhone (no devolvio formatos en la prueba)" },

            @{ @"nombre"  : @"VISIONOS",
               @"version" : @"1.02",
               @"id"      : @101,
               @"agente"  : @"Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) "
                            @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 "
                            @"Safari/605.1.15",
               @"sdk"     : @0,
               @"extra"   : @{ @"deviceMake" : @"Apple", @"deviceModel" : @"RealityDevice17,1",
                               @"osName" : @"visionOS", @"osVersion" : @"26.5.23O471" },
               @"nota"    : @"gafas Vision Pro (sin po token sobre el papel, pero no "
                            @"devolvio formatos en la prueba)" }
        ];
    });
    return lista;
}

// El primero de la lista es el que se usa para buscar y para pedir el
// "visitorData" (el identificador anonimo que YouTube espera en cada peticion).
static NSDictionary *YTClientePrincipal(void) {
    return YTClientes()[0];
}

// Cliente para la pantalla de YouTube Music. Se usa SOLO para navegar (listar
// canciones): sus enlaces de video necesitan el reproductor JavaScript, asi que
// al reproducir siempre se resuelve con ANDROID, el cliente de arriba.
static NSDictionary *YTClienteMusica(void) {
    static NSDictionary *cliente = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        cliente = @{ @"nombre"  : @"WEB_REMIX",
                     @"version" : @"1.20260707.12.00",
                     @"id"      : @67,
                     @"agente"  : @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                                  @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 "
                                  @"Safari/605.1.15,gzip(gfe)",
                     @"sdk"     : @0,
                     @"extra"   : @{},
                     @"base"    : kBaseYTMusic,
                     @"nota"    : @"YouTube Music (solo navegar)" };
    });
    return cliente;
}

static NSCache *sCacheMiniaturas = nil;

// Declarada al final del fichero; hace falta el prototipo aqui.
void YTRecogerRenderers(id nodo, NSString *sufijo, NSMutableArray *salida);

// Lo mismo para los carruseles de YouTube Music. "tituloRespaldo" se usa para
// agrupar las canciones que vienen sin estante con nombre.
NSArray *YTCarruselesMusicales(NSDictionary *json, NSString *tituloRespaldo);

// ---------------------------------------------------------------------------
//  NSURLSession entrega los resultados en una cola de fondo, y la interfaz de
//  iOS SOLO se puede tocar desde el hilo principal: actualizarla desde otra
//  cola deja la tabla vacia y el reproductor clavado en "Cargando...".
//  Todo lo que sale de esta clase pasa por aqui.
// ---------------------------------------------------------------------------
static void YTEnPrincipal(dispatch_block_t bloque) {
    if ([NSThread isMainThread]) {
        bloque();
    } else {
        dispatch_async(dispatch_get_main_queue(), bloque);
    }
}

@interface YTClient ()
@property (nonatomic, strong) NSURLSession *sesion;

// Adelantos: la implementacion de estos metodos esta mas abajo en el fichero.
- (void)obtener:(NSURL *)url completion:(void (^)(NSDictionary *json, NSError *error))completion;
- (void)resolverVideo:(NSString *)videoId
          conClientes:(NSArray *)clientes
               indice:(NSUInteger)indice
              errores:(NSMutableArray *)errores
           completion:(YTBloqueInfo)completion;
- (NSDictionary *)contextoParaCliente:(NSDictionary *)cliente
                    incluirVisitante:(BOOL)incluirVisitante;
- (void)comprobarEnlace:(NSString *)enlace
             completion:(void (^)(BOOL vale, NSString *detalle))completion;
- (void)asegurarVisitante:(void (^)(void))completion;
- (void)enviarAlInnerTube:(NSString *)ruta
                  cliente:(NSDictionary *)cliente
                   cuerpo:(NSDictionary *)cuerpo
               completion:(void (^)(NSDictionary *json, NSError *error))completion;
- (NSString *)describir:(NSArray *)videos error:(NSError *)error desde:(NSDate *)inicio;
- (void)probarBytesDe:(NSString *)enlace completion:(void (^)(NSString *resultado))completion;
- (void)pedirMusica:(NSString *)ruta
              clave:(NSString *)clave
              valor:(NSString *)valor
     tituloRespaldo:(NSString *)respaldo
         completion:(void (^)(NSArray *carruseles, NSError *error))completion;

// Miniaturas: el estado (cola de espera, descargas en curso) solo se toca desde
// el hilo principal, que es desde donde llaman las celdas.
+ (void)prepararMiniaturas;
+ (void)bombearMiniaturas;
+ (void)descargarMiniatura:(NSString *)limpia
                candidatos:(NSArray *)candidatos
                     indice:(NSUInteger)indice;
+ (void)terminarMiniatura:(NSString *)limpia imagen:(UIImage *)imagen;
@end

@implementation YTClient

+ (instancetype)compartido {
    static YTClient *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{ instancia = [[YTClient alloc] init]; });
    return instancia;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *cfg =
            [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 25.0;
        cfg.timeoutIntervalForResource = 120.0;
        cfg.HTTPShouldSetCookies = YES;      // usa las cookies de la sesion
        cfg.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        _sesion = [NSURLSession sessionWithConfiguration:cfg];
        if (!sCacheMiniaturas) {
            sCacheMiniaturas = [[NSCache alloc] init];
            sCacheMiniaturas.countLimit = 180;
            // Limite por tamano (no solo por numero): en un iPhone de 512 MB
            // 180 miniaturas grandes serian demasiada memoria.
            sCacheMiniaturas.totalCostLimit = 24 * 1024 * 1024;
        }
    }
    return self;
}

#pragma mark - Ajustes

+ (NSString *)modo {
    NSString *m = [[NSUserDefaults standardUserDefaults] stringForKey:kDefModo];
    return m.length ? m : @"directo";
}

+ (NSString *)relayBase {
    NSString *r = [[NSUserDefaults standardUserDefaults] stringForKey:kDefRelay];
    return r.length ? r : @"";
}

+ (NSString *)relayToken {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kDefToken] ?: @"";
}

+ (void)guardarModo:(NSString *)modo relay:(NSString *)relay token:(NSString *)token {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:(modo.length ? modo : @"directo") forKey:kDefModo];
    [d setObject:(relay ?: @"") forKey:kDefRelay];
    [d setObject:(token ?: @"") forKey:kDefToken];
    [d synchronize];
}

+ (NSString *)clienteYT { return YTClientePrincipal()[@"nombre"]; }

+ (NSString *)listaDeClientes {
    NSMutableArray *nombres = [NSMutableArray array];
    for (NSDictionary *c in YTClientes()) [nombres addObject:c[@"nombre"]];
    return [nombres componentsJoinedByString:@", "];
}

// Identificador anonimo de visitante. NewPipe y yt-dlp se lo piden a YouTube y
// lo mandan en cada peticion (dentro del contexto y en la cabecera
// X-Goog-Visitor-Id). Sin el, YouTube contesta "LOGIN_REQUIRED" mucho mas a
// menudo porque no reconoce al visitante como un navegador normal.
+ (NSString *)visitante {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kDefVisitante] ?: @"";
}

+ (void)guardarVisitante:(NSString *)visitante {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (visitante.length) [d setObject:visitante forKey:kDefVisitante];
    [d synchronize];
}

+ (void)olvidarVisitante {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:kDefVisitante];
    [d synchronize];
}

#pragma mark - Sesion (cookies)

+ (NSArray *)cookiesDeYouTube {
    NSMutableArray *salida = [NSMutableArray array];
    for (NSHTTPCookie *c in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        NSString *dom = c.domain ?: @"";
        if ([dom rangeOfString:@"youtube.com"].location != NSNotFound ||
            [dom rangeOfString:@"google.com"].location != NSNotFound) {
            [salida addObject:c];
        }
    }
    return salida;
}

+ (BOOL)haySesion {
    // Una sesion util tiene al menos SID o __Secure-3PSID
    for (NSHTTPCookie *c in [self cookiesDeYouTube]) {
        if ([c.name isEqualToString:@"SID"] || [c.name isEqualToString:@"__Secure-3PSID"] ||
            [c.name isEqualToString:@"SAPISID"] || [c.name isEqualToString:@"HSID"]) {
            return YES;
        }
    }
    return NO;
}

+ (NSUInteger)numeroDeCookies {
    return [self cookiesDeYouTube].count;
}

+ (void)cerrarSesion {
    NSHTTPCookieStorage *almacen = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *c in [self cookiesDeYouTube]) {
        [almacen deleteCookie:c];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"tube9_usuario"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"tube9_cookies_manuales"];
    // Visitante nuevo tras cerrar sesion: YouTube identifica asi una conexion
    // limpia en vez de arrastrar la anterior.
    [self olvidarVisitante];
}

+ (void)guardarCookiesManuales:(NSString *)crudo {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (crudo.length) {
        [d setObject:crudo forKey:@"tube9_cookies_manuales"];
    } else {
        [d removeObjectForKey:@"tube9_cookies_manuales"];
    }
    [d synchronize];
}

+ (NSString *)cookiesManuales {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"tube9_cookies_manuales"] ?: @"";
}

#pragma mark - Utilidades

+ (NSURL *)urlDelRelay:(NSString *)ruta parametros:(NSDictionary *)parametros {
    NSString *base = [self relayBase];
    if (base.length == 0) return nil;
    if (![base hasPrefix:@"http://"] && ![base hasPrefix:@"https://"]) {
        base = [@"http://" stringByAppendingString:base];
    }
    while ([base hasSuffix:@"/"]) {
        base = [base substringToIndex:base.length - 1];
    }
    NSMutableString *url = [NSMutableString stringWithFormat:@"%@%@", base, ruta];
    NSMutableArray *partes = [NSMutableArray array];
    NSString *token = [self relayToken];
    if (token.length) {
        [partes addObject:[NSString stringWithFormat:@"t=%@",
            [token stringByAddingPercentEncodingWithAllowedCharacters:
                [NSCharacterSet URLQueryAllowedCharacterSet]]]];
    }
    [parametros enumerateKeysAndObjectsUsingBlock:^(id clave, id valor, BOOL *parar) {
        [partes addObject:[NSString stringWithFormat:@"%@=%@", clave,
            [(NSString *)valor stringByAddingPercentEncodingWithAllowedCharacters:
                [NSCharacterSet URLQueryAllowedCharacterSet]]]];
    }];
    if (partes.count) [url appendFormat:@"?%@", [partes componentsJoinedByString:@"&"]];
    return [NSURL URLWithString:url];
}

- (void)obtener:(NSURL *)url completion:(void (^)(NSDictionary *json, NSError *error))completion {
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:url];
    peticion.HTTPMethod = @"GET";
    peticion.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    NSString *manuales = [YTClient cookiesManuales];
    if (manuales.length) [peticion setValue:manuales forHTTPHeaderField:@"Cookie"];
    [[self.sesion dataTaskWithRequest:peticion
                            completionHandler:^(NSData *datos, NSURLResponse *respuesta,
                                                NSError *error) {
        if (error) { YTEnPrincipal(^{ completion(nil, error); }); return; }
        NSError *jsonError = nil;
        id objeto = [NSJSONSerialization JSONObjectWithData:datos options:0 error:&jsonError];
        if (![objeto isKindOfClass:[NSDictionary class]]) {
            YTEnPrincipal(^{
                completion(nil, jsonError ?: [NSError errorWithDomain:@"tube9"
                    code:1 userInfo:@{NSLocalizedDescriptionKey : @"Respuesta no valida"}]);
            });
            return;
        }
        YTEnPrincipal(^{ completion(objeto, nil); });
    }] resume];
}

#pragma mark - Busqueda

- (void)buscar:(NSString *)consulta completion:(YTBloqueLista)completion {
    [self buscar:consulta params:nil completion:completion];
}

- (void)buscar:(NSString *)consulta
        params:(NSString *)params
    completion:(YTBloqueLista)completion {
    NSString *limpia = [consulta stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (limpia.length == 0) {
        completion(@[], nil);
        return;
    }

    if ([[YTClient modo] isEqualToString:@"relay"]) {
        NSURL *url = [YTClient urlDelRelay:@"/api/search" parametros:@{ @"q" : limpia }];
        if (!url) {
            completion(nil, [NSError errorWithDomain:@"tube9" code:2
                userInfo:@{NSLocalizedDescriptionKey :
                    @"No has configurado la direccion del relay en Ajustes."}]);
            return;
        }
        [self obtener:url completion:^(NSDictionary *json, NSError *error) {
            if (error) { completion(nil, error); return; }
            if (![json[@"ok"] boolValue]) {
                completion(nil, [NSError errorWithDomain:@"tube9" code:3
                    userInfo:@{NSLocalizedDescriptionKey :
                        json[@"error"] ?: @"El relay respondio con un error"}]);
                return;
            }
            completion([YTVideo listaDesdeRelay:json[@"resultados"]], nil);
        }];
        return;
    }

    // --- Modo directo: InnerTube -----------------------------------------
    NSDictionary *cliente = YTClientePrincipal();
    [self asegurarVisitante:^{
        NSMutableDictionary *cuerpo = [NSMutableDictionary dictionary];
        cuerpo[@"query"] = limpia;
        // "params" es el filtro de orden con el que YouTube ordena la lista
        // (mas vistos, mas nuevos...). Si no viene, YouTube usa su criterio.
        if (params.length) cuerpo[@"params"] = params;
        cuerpo[@"context"] = @{ @"client" : [self contextoParaCliente:cliente incluirVisitante:YES] };

        [self enviarAlInnerTube:@"search" cliente:cliente cuerpo:cuerpo
            completion:^(NSDictionary *json, NSError *error) {
            if (error) { completion(nil, error); return; }
            NSMutableArray *renderers = [NSMutableArray array];
            YTRecogerRenderers(json, @"VideoRenderer", renderers);
            NSMutableArray *videos = [NSMutableArray array];
            for (NSDictionary *r in renderers) {
                YTVideo *v = [YTVideo desdeRenderer:r];
                if (v) [videos addObject:v];
            }
            completion(videos, nil);
        }];
    }];
}

#pragma mark - Pantalla de musica (YouTube Music)

- (void)carruselesDeMusica:(NSString *)browseId
                completion:(void (^)(NSArray *carruseles, NSError *error))completion {
    [self pedirMusica:@"browse" clave:@"browseId" valor:browseId
       tituloRespaldo:nil completion:completion];
}

- (void)carruselesDeMusicaBuscando:(NSString *)consulta
                        completion:(void (^)(NSArray *carruseles, NSError *error))completion {
    [self pedirMusica:@"search" clave:@"query" valor:consulta
       tituloRespaldo:consulta completion:completion];
}

- (void)pedirMusica:(NSString *)ruta
              clave:(NSString *)clave
              valor:(NSString *)valor
     tituloRespaldo:(NSString *)respaldo
         completion:(void (^)(NSArray *carruseles, NSError *error))completion {
    if (valor.length == 0) {
        completion(@[], nil);
        return;
    }
    if ([[YTClient modo] isEqualToString:@"relay"]) {
        completion(nil, [NSError errorWithDomain:@"tube9" code:3
            userInfo:@{NSLocalizedDescriptionKey :
                @"La pantalla de Musica necesita el modo directo (sin relay)."}]);
        return;
    }

    NSDictionary *cliente = YTClienteMusica();
    [self asegurarVisitante:^{
        NSDictionary *cuerpo = @{
            clave : valor,
            @"context" : @{ @"client" : [self contextoParaCliente:cliente incluirVisitante:YES] }
        };
        [self enviarAlInnerTube:ruta cliente:cliente cuerpo:cuerpo
            completion:^(NSDictionary *json, NSError *error) {
            if (error) { completion(nil, error); return; }
            completion(YTCarruselesMusicales(json, respaldo), nil);
        }];
    }];
}

#pragma mark - Videos relacionados

- (void)relacionadosDe:(NSString *)titulo
           excluyendo:(NSString *)videoId
            completion:(YTBloqueLista)completion {
    NSString *limpio = [titulo stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (limpio.length == 0) { completion(@[], nil); return; }

    [self buscar:limpio params:nil completion:^(NSArray *videos, NSError *error) {
        if (error) { completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (YTVideo *v in videos) {
            if (videoId.length && [v.identificador isEqualToString:videoId]) continue;
            if (salida.count >= 12) break;
            [salida addObject:v];
        }
        completion(salida, nil);
    }];
}


#pragma mark - Resolucion del video

- (void)resolverVideo:(NSString *)videoId completion:(YTBloqueInfo)completion {
    if (videoId.length == 0) {
        completion(nil, [NSError errorWithDomain:@"tube9" code:4
            userInfo:@{NSLocalizedDescriptionKey : @"Video no valido"}]);
        return;
    }

    if ([[YTClient modo] isEqualToString:@"relay"]) {
        NSURL *url = [YTClient urlDelRelay:@"/api/stream" parametros:@{ @"id" : videoId }];
        if (!url) {
            completion(nil, [NSError errorWithDomain:@"tube9" code:2
                userInfo:@{NSLocalizedDescriptionKey :
                    @"No has configurado la direccion del relay en Ajustes."}]);
            return;
        }
        [self obtener:url completion:^(NSDictionary *json, NSError *error) {
            if (error) { completion(nil, error); return; }
            if (![json[@"ok"] boolValue]) {
                completion(nil, [NSError errorWithDomain:@"tube9" code:3
                    userInfo:@{NSLocalizedDescriptionKey :
                        json[@"error"] ?: @"El relay no pudo resolver el video"}]);
                return;
            }
            NSString *enlace = json[@"url_proxy"] ?: json[@"url_directa"];
            if (enlace.length == 0) {
                completion(nil, [NSError errorWithDomain:@"tube9" code:5
                    userInfo:@{NSLocalizedDescriptionKey : @"El relay no devolvio ninguna URL"}]);
                return;
            }
            completion(@{ @"url" : enlace,
                          @"titulo" : json[@"titulo"] ?: @"",
                          @"autor" : json[@"autor"] ?: @"" }, nil);
        }];
        return;
    }

    // --- Modo directo ----------------------------------------------------
    // Se prueba cliente por cliente: YouTube trata cada uno con un umbral
    // antibot distinto, asi que el que contesta "LOGIN_REQUIRED" a uno puede
    // responder bien a otro. Es lo que hacen NewPipe y yt-dlp.
    [self asegurarVisitante:^{
        [self resolverVideo:videoId
                conClientes:YTClientes()
                     indice:0
                    errores:[NSMutableArray array]
                 completion:completion];
    }];
}

- (void)resolverVideo:(NSString *)videoId
          conClientes:(NSArray *)clientes
               indice:(NSUInteger)indice
              errores:(NSMutableArray *)errores
           completion:(YTBloqueInfo)completion {
    if (indice >= clientes.count) {
        // Se agotaron los clientes: un solo mensaje con los motivos distintos.
        NSMutableArray *motivos = [NSMutableArray array];
        for (NSError *e in errores) {
            NSString *texto = e.localizedDescription;
            if (texto.length && ![motivos containsObject:texto]) [motivos addObject:texto];
        }
        NSString *resumen = motivos.count ? [motivos componentsJoinedByString:@" | "] : @"sin detalle";
        NSString *ayuda = @"";
        if ([resumen rangeOfString:@"LOGIN_REQUIRED"].location != NSNotFound ||
            [resumen rangeOfString:@"inicia sesion"].location != NSNotFound ||
            [resumen rangeOfString:@"bot"].location != NSNotFound) {
            ayuda = @"\n\nYouTube desconfia de esta conexion. Entra en "
                     "Ajustes > Iniciar sesion en YouTube: con la sesion iniciada "
                     "este aviso desaparece.";
        }
        completion(nil, [NSError errorWithDomain:@"tube9" code:6 userInfo:@{
            NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%@", resumen, ayuda]}]);
        return;
    }

    NSDictionary *cliente = clientes[indice];
    NSDictionary *cuerpo = @{
        @"videoId" : videoId,
        @"contentCheckOk" : @YES,
        @"racyCheckOk" : @YES,
        @"context" : @{ @"client" : [self contextoParaCliente:cliente incluirVisitante:YES] }
    };

    [self enviarAlInnerTube:@"player" cliente:cliente cuerpo:cuerpo
        completion:^(NSDictionary *json, NSError *error) {
        if (error) {
            [errores addObject:error];
            [self resolverVideo:videoId conClientes:clientes indice:indice + 1
                        errores:errores completion:completion];
            return;
        }

        NSDictionary *estado = json[@"playabilityStatus"];
        NSString *nombreEstado = estado[@"status"];
        if (![nombreEstado isEqualToString:@"OK"]) {
            NSString *motivo = estado[@"reason"] ?: nombreEstado ?: @"desconocido";
            [errores addObject:[NSError errorWithDomain:@"tube9" code:6 userInfo:@{
                NSLocalizedDescriptionKey : motivo}]];
            [self resolverVideo:videoId conClientes:clientes indice:indice + 1
                        errores:errores completion:completion];
            return;
        }

        NSDictionary *sd = json[@"streamingData"];
        NSArray *muxados = sd[@"formats"];
        NSArray *preferidos = @[ @18, @22, @59, @78, @17 ];
        NSDictionary *elegido = nil;
        for (NSNumber *itag in preferidos) {
            for (NSDictionary *f in muxados) {
                if ([f[@"itag"] isEqualToNumber:itag] && f[@"url"]) { elegido = f; break; }
            }
            if (elegido) break;
        }
        if (!elegido) {
            for (NSDictionary *f in muxados) {
                if (f[@"url"]) { elegido = f; break; }
            }
        }
        if (!elegido) {
            [errores addObject:[NSError errorWithDomain:@"tube9" code:7 userInfo:@{
                NSLocalizedDescriptionKey :
                    @"YouTube no devolvio un formato reproducible para este video."}]];
            [self resolverVideo:videoId conClientes:clientes indice:indice + 1
                        errores:errores completion:completion];
            return;
        }

        NSString *enlace = elegido[@"url"];
        // No basta con que YouTube devuelva una URL: tambien puede devolverla
        // y luego contestar 403 al pedir los bytes (es el caso del po token que
        // los clientes de app exigen y visionos no). Se piden 2 bytes y, si no
        // vienen, se prueba el cliente siguiente.
        [self comprobarEnlace:enlace completion:^(BOOL vale, NSString *detalle) {
            if (!vale) {
                [errores addObject:[NSError errorWithDomain:@"tube9" code:9 userInfo:@{
                    NSLocalizedDescriptionKey :
                        [NSString stringWithFormat:@"%@ dio una URL que no se puede "
                         @"descargar (%@)", cliente[@"nombre"], detalle]}]];
                [self resolverVideo:videoId conClientes:clientes indice:indice + 1
                            errores:errores completion:completion];
                return;
            }
            NSDictionary *detalles = json[@"videoDetails"];
            completion(@{ @"url" : enlace,
                          @"titulo" : detalles[@"title"] ?: @"",
                          @"autor" : detalles[@"author"] ?: @"",
                          @"itag" : elegido[@"itag"] ?: @0,
                          // Cuanto pesa el video segun YouTube: la descarga lo
                          // usa para darse cuenta de que algo se ha quedado corto.
                          @"bytes" : elegido[@"contentLength"] ?: @0,
                          @"cliente" : cliente[@"nombre"] ?: @"",
                          @"comprobacion" : detalle ?: @"" }, nil);
        }];
    }];
}

// Pide los dos primeros bytes del video. Es la unica forma de saber que la URL
// sirve de verdad: YouTube devuelve URLs validas que luego rechaza con 403.
// Importante: esta respuesta NO se puede cachear. Es una respuesta parcial de
// 2 bytes, y si quedara guardada, la descarga (misma URL) la reutilizaria y
// acabaria con un fichero de 2 bytes.
- (void)comprobarEnlace:(NSString *)enlace
             completion:(void (^)(BOOL vale, NSString *detalle))completion {
    NSURL *url = [NSURL URLWithString:enlace];
    if (!url) { completion(NO, @"la direccion no es valida"); return; }

    NSMutableURLRequest *peticion = [NSMutableURLRequest
        requestWithURL:url
           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
       timeoutInterval:12.0];
    [peticion setValue:@"bytes=0-1" forHTTPHeaderField:@"Range"];
    NSDate *inicio = [NSDate date];
    [[self.sesion dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        double segundos = -[inicio timeIntervalSinceNow];
        if (error) {
            completion(NO, [NSString stringWithFormat:@"%@ (en %.1f s)",
                [YTClient explicarError:error], segundos]);
            return;
        }
        NSInteger codigo = [respuesta isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)respuesta).statusCode : 0;
        if (codigo == 200 || codigo == 206) {
            completion(YES, [NSString stringWithFormat:@"HTTP %ld en %.1f s",
                             (long)codigo, segundos]);
        } else {
            completion(NO, [NSString stringWithFormat:@"HTTP %ld", (long)codigo]);
        }
    }] resume];
}

#pragma mark - InnerTube

- (NSDictionary *)contextoParaCliente:(NSDictionary *)cliente
                    incluirVisitante:(BOOL)incluirVisitante {
    NSMutableDictionary *ctx = [NSMutableDictionary dictionary];
    ctx[@"clientName"] = cliente[@"nombre"];
    ctx[@"clientVersion"] = cliente[@"version"];
    ctx[@"hl"] = @"es";
    ctx[@"gl"] = @"ES";
    NSNumber *sdk = cliente[@"sdk"];
    if (sdk.integerValue > 0) ctx[@"androidSdkVersion"] = sdk;
    // deviceMake/deviceModel/osName/osVersion: YouTube los usa para decidir si
    // el cliente es de verdad, y algunos formatos solo se ofrecen si cuadran.
    NSDictionary *extra = cliente[@"extra"];
    if ([extra isKindOfClass:[NSDictionary class]]) {
        [ctx addEntriesFromDictionary:extra];
    }
    if (incluirVisitante) {
        NSString *visitante = [YTClient visitante];
        if (visitante.length) ctx[@"visitorData"] = visitante;
    }
    return ctx;
}

// Pide una sola vez el "visitorData" y lo guarda. Si YouTube no lo da, la app
// sigue funcionando sin el (solo con menos proteccion antibot).
- (void)asegurarVisitante:(void (^)(void))completion {
    if ([YTClient visitante].length) { completion(); return; }

    NSDictionary *cliente = YTClientePrincipal();
    NSString *direccion = [NSString stringWithFormat:@"%@/visitor_id?key=%@&prettyPrint=false",
                           kBaseYT, kClaveAPI];
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:direccion]];
    peticion.HTTPMethod = @"POST";
    peticion.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [peticion setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString *agente = cliente[@"agente"];
    if (agente.length) [peticion setValue:agente forHTTPHeaderField:@"User-Agent"];
    peticion.HTTPBody = [NSJSONSerialization dataWithJSONObject:
        @{ @"context" : @{ @"client" : [self contextoParaCliente:cliente incluirVisitante:NO] } }
        options:0 error:nil];

    [[self.sesion dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        if (!error && datos.length) {
            id objeto = [NSJSONSerialization JSONObjectWithData:datos options:0 error:nil];
            if ([objeto isKindOfClass:[NSDictionary class]]) {
                id contexto = ((NSDictionary *)objeto)[@"responseContext"];
                if ([contexto isKindOfClass:[NSDictionary class]]) {
                    NSString *visitante = ((NSDictionary *)contexto)[@"visitorData"];
                    if ([visitante isKindOfClass:[NSString class]] && visitante.length) {
                        [YTClient guardarVisitante:visitante];
                    }
                }
            }
        }
        YTEnPrincipal(^{ completion(); });
    }] resume];
}

- (void)enviarAlInnerTube:(NSString *)ruta
                  cliente:(NSDictionary *)cliente
                   cuerpo:(NSDictionary *)cuerpo
               completion:(void (^)(NSDictionary *json, NSError *error))completion {
    // Cada cliente tiene su propio servidor: www.youtube.com para todos menos
    // YouTube Music, que vive en music.youtube.com.
    NSString *base = cliente[@"base"];
    if (![base isKindOfClass:[NSString class]] || base.length == 0) base = kBaseYT;
    NSString *sitio = [base stringByReplacingOccurrencesOfString:@"/youtubei/v1" withString:@""];

    NSString *direccion = [NSString stringWithFormat:@"%@/%@?key=%@&prettyPrint=false",
                           base, ruta, kClaveAPI];
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:direccion]];
    peticion.HTTPMethod = @"POST";
    peticion.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [peticion setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString *agente = cliente[@"agente"];
    if (agente.length) [peticion setValue:agente forHTTPHeaderField:@"User-Agent"];
    [peticion setValue:@"es-ES,es;q=0.9" forHTTPHeaderField:@"Accept-Language"];

    // Las mismas cabeceras que manda NewPipe en cada peticion. Si no van,
    // YouTube no sabe con que cliente habla y responde mucho mas a menudo con
    // "inicia sesion para confirmar que no eres un robot".
    [peticion setValue:[cliente[@"id"] stringValue] forHTTPHeaderField:@"X-YouTube-Client-Name"];
    [peticion setValue:cliente[@"version"] forHTTPHeaderField:@"X-YouTube-Client-Version"];
    [peticion setValue:sitio forHTTPHeaderField:@"Origin"];
    [peticion setValue:[sitio stringByAppendingString:@"/"] forHTTPHeaderField:@"Referer"];
    NSString *visitante = [YTClient visitante];
    if (visitante.length) [peticion setValue:visitante forHTTPHeaderField:@"X-Goog-Visitor-Id"];

    NSString *manuales = [YTClient cookiesManuales];
    if (manuales.length) [peticion setValue:manuales forHTTPHeaderField:@"Cookie"];
    peticion.HTTPBody = [NSJSONSerialization dataWithJSONObject:cuerpo options:0 error:nil];

    [[self.sesion dataTaskWithRequest:peticion
                            completionHandler:^(NSData *datos, NSURLResponse *respuesta,
                                                NSError *error) {
        if (error) { YTEnPrincipal(^{ completion(nil, error); }); return; }

        NSInteger codigo = [respuesta isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)respuesta).statusCode : 0;
        id objeto = datos.length
            ? [NSJSONSerialization JSONObjectWithData:datos options:0 error:nil] : nil;
        BOOL esDiccionario = [objeto isKindOfClass:[NSDictionary class]];

        // Un error HTTP se quedaba invisible: la app decia "no hay nada que
        // mostrar" en vez de contar lo que habia pasado de verdad.
        if (codigo >= 400) {
            NSString *detalle = @"";
            if (esDiccionario) {
                id err = ((NSDictionary *)objeto)[@"error"];
                if ([err isKindOfClass:[NSDictionary class]]) {
                    NSString *mensaje = ((NSDictionary *)err)[@"message"];
                    NSString *estado  = ((NSDictionary *)err)[@"status"];
                    if (mensaje.length) detalle = [NSString stringWithFormat:@" (%@)", mensaje];
                    else if (estado.length) detalle = [NSString stringWithFormat:@" (%@)", estado];
                }
            }
            YTEnPrincipal(^{
                completion(nil, [NSError errorWithDomain:@"tube9" code:10 userInfo:@{
                    NSLocalizedDescriptionKey : [NSString stringWithFormat:
                        @"YouTube respondio HTTP %ld al pedir %@.%@",
                        (long)codigo, ruta, detalle]}]); });
            return;
        }

        if (!esDiccionario) {
            YTEnPrincipal(^{
                completion(nil, [NSError errorWithDomain:@"tube9" code:8
                    userInfo:@{NSLocalizedDescriptionKey : @"YouTube devolvio algo inesperado"}]);
            });
            return;
        }
        YTEnPrincipal(^{ completion(objeto, nil); });
    }] resume];
}

#pragma mark - Diagnostico

- (void)probarConexion:(void (^)(NSString *informe))completion {
    NSMutableString *informe = [NSMutableString string];
    [informe appendFormat:@"Modo: %@\n", [YTClient modo]];
    [informe appendFormat:@"Clientes: %@\n", [YTClient listaDeClientes]];
    [informe appendFormat:@"Sesion iniciada: %@  (%lu cookies)\n",
        ([YTClient haySesion] ? @"SI" : @"NO"), (unsigned long)[YTClient numeroDeCookies]];

    if ([[YTClient modo] isEqualToString:@"relay"]) {
        NSURL *url = [YTClient urlDelRelay:@"/api/health" parametros:nil];
        [informe appendFormat:@"Relay: %@\n\n", url.absoluteString ?: @"(sin configurar)"];
        if (!url) {
            [informe appendString:@"Falta la direccion del relay."];
            completion(informe);
            return;
        }
        [self obtener:url completion:^(NSDictionary *json, NSError *error) {
            if (error) {
                [informe appendFormat:@"FALLO: %@\n%@",
                    [YTClient explicarError:error],
                    @"\nComprueba que el relay esta arrancado y en la misma red."];
            } else {
                [informe appendFormat:@"OK  responde %@ v%@",
                    json[@"servicio"] ?: @"?", json[@"version"] ?: @"?"];
            }
            completion(informe);
        }];
        return;
    }

    [informe appendString:@"\n1) Buscando en youtube.com...\n"];
    NSDate *principioBusqueda = [NSDate date];
    [self buscar:@"prueba" completion:^(NSArray *videos, NSError *error) {
        [informe appendFormat:@"   %@\n", [self describir:videos error:error
                                                     desde:principioBusqueda]];
        [informe appendFormat:@"   visitante anonimo: %@\n",
            ([YTClient visitante].length ? @"obtenido" : @"NO disponible")];
        if (error) {
            [informe appendString:@"\nSi es un error de certificado, instala las raices "
                               @"actualizadas en el dispositivo (mira el README)."];
            completion(informe);
            return;
        }
        if (videos.count == 0) {
            [informe appendString:@"\nLa busqueda no devolvio ningun resultado."];
            completion(informe);
            return;
        }

        YTVideo *prueba = videos[0];
        NSString *recorte = prueba.titulo.length > 32
            ? [prueba.titulo substringToIndex:32] : prueba.titulo;
        [informe appendFormat:@"\n2) Pidiendo la URL del video \"%@\"...\n", recorte];
        NSDate *principioResolucion = [NSDate date];
        [self resolverVideo:prueba.identificador
            completion:^(NSDictionary *info, NSError *error) {
            double segundos = -[principioResolucion timeIntervalSinceNow];
            NSString *enlace = info[@"url"];
            if (error || enlace.length == 0) {
                [informe appendFormat:@"   FALLO tras %.1f s: %@\n", segundos,
                    [YTClient explicarError:error] ?: @"YouTube no devolvio URL"];
                [informe appendString:@"\nYa se han probado todos los clientes. Si el motivo "
                                   "es LOGIN_REQUIRED, inicia sesion en Ajustes > "
                                   "Iniciar sesion en YouTube."];
                completion(informe);
                return;
            }
            NSURL *url = [NSURL URLWithString:enlace];
            NSString *quien = info[@"cliente"];
            [informe appendFormat:@"   OK  URL obtenida en %.1f s%@\n", segundos,
                (quien.length ? [NSString stringWithFormat:@" con el cliente %@", quien] : @"")];
            NSString *comprobacion = info[@"comprobacion"];
            if (comprobacion.length) {
                [informe appendFormat:@"   descarga comprobada: %@\n", comprobacion];
            }
            [informe appendFormat:@"   servidor de video: %@\n", url.host ?: @"(desconocido)"];
            [informe appendString:@"\n3) Descargando los primeros KB del video...\n"];
            [self probarBytesDe:enlace completion:^(NSString *resultado) {
                [informe appendFormat:@"   %@\n", resultado];
                [informe appendString:
                    @"\nSi el paso 3 falla o tarda muchisimo, el problema esta en la "
                    @"descarga del video, no en la busqueda: suele ser el proveedor de "
                    @"Internet dando largas con googlevideo.com. Prueba el modo relay."];
                completion(informe);
            }];
        }];
    }];
}

// Resumen de una llamada con su duracion, para el informe.
- (NSString *)describir:(NSArray *)videos error:(NSError *)error desde:(NSDate *)inicio {
    double segundos = -[inicio timeIntervalSinceNow];
    if (error) {
        return [NSString stringWithFormat:@"FALLO tras %.1f s: %@",
                segundos, [YTClient explicarError:error]];
    }
    return [NSString stringWithFormat:@"OK  %lu resultados en %.1f s",
            (unsigned long)videos.count, segundos];
}

// Pide solo los primeros 64 KB, que es lo mismo que hace el reproductor al
// empezar. Es la prueba decisiva: separa "la busqueda falla" de "el video no
// se descarga".
- (void)probarBytesDe:(NSString *)enlace completion:(void (^)(NSString *resultado))completion {
    NSURL *url = [NSURL URLWithString:enlace];
    if (!url) { completion(@"La URL del video no es valida."); return; }

    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:url];
    [peticion setValue:@"bytes=0-65535" forHTTPHeaderField:@"Range"];
    peticion.timeoutInterval = 15.0;   // el informe no debe quedarse colgado
    NSDate *inicio = [NSDate date];
    [[self.sesion dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        double segundos = -[inicio timeIntervalSinceNow];
        if (error) {
            completion([NSString stringWithFormat:@"FALLO tras %.1f s: %@",
                segundos, [YTClient explicarError:error]]);
            return;
        }
        NSHTTPURLResponse *http = [respuesta isKindOfClass:[NSHTTPURLResponse class]]
                                ? (NSHTTPURLResponse *)respuesta : nil;
        NSString *firma = @"";
        if (datos.length >= 8) {
            NSString *atom = [[NSString alloc] initWithData:
                [datos subdataWithRange:NSMakeRange(4, 4)] encoding:NSASCIIStringEncoding];
            if (atom) firma = [NSString stringWithFormat:@", atom '%@'", atom];
        }
        completion([NSString stringWithFormat:@"OK  HTTP %ld, %@, %.0f KB en %.1f s%@",
                    (long)(http ? http.statusCode : 0),
                    [respuesta MIMEType] ?: @"tipo desconocido",
                    datos.length / 1024.0, segundos, firma]);
    }] resume];
}

#pragma mark - Miniaturas

// ---------------------------------------------------------------------------
//  iOS 9 no sabe decodificar WebP, y YouTube devuelve bastantes miniaturas en
//  ese formato (https://i.ytimg.com/vi_webp/<id>/sddefault.webp). La imagen se
//  descarga bien pero UIImage la rechaza y la celda se queda en blanco: eso era
//  el "unas cargan y otras no". Aqui se reescribe la direccion a la version
//  JPEG equivalente, que siempre existe.
// ---------------------------------------------------------------------------
static NSString *YTMiniaturaJpeg(NSString *url) {
    if (url.length == 0) return url;

    // Portadas de YouTube Music (lh3.googleusercontent.com): "-rw" pide WebP,
    // "-rj" pide JPEG.
    if ([url rangeOfString:@"googleusercontent.com"].location != NSNotFound) {
        if ([url hasSuffix:@"-rw"]) {
            return [[url substringToIndex:url.length - 3] stringByAppendingString:@"-rj"];
        }
        return url;
    }

    NSString *minusculas = [url lowercaseString];
    BOOL eraWebp = ([minusculas rangeOfString:@"/vi_webp/"].location != NSNotFound) ||
                   ([minusculas rangeOfString:@".webp"].location != NSNotFound);
    if (!eraWebp) return url;

    NSString *sinConsulta = url;
    NSRange interrogacion = [url rangeOfString:@"?"];
    if (interrogacion.location != NSNotFound) {
        sinConsulta = [url substringToIndex:interrogacion.location];
    }
    NSString *base = [sinConsulta stringByReplacingOccurrencesOfString:@"/vi_webp/"
                                                           withString:@"/vi/"];
    if ([[base lowercaseString] hasSuffix:@".webp"]) {
        base = [[base substringToIndex:base.length - 5] stringByAppendingString:@".jpg"];
    }
    // Se tira la parte "?sqp=..." a proposito: esa firma vale para la ruta
    // original, y al cambiar webp por jpg podria dejar de ser valida. Las rutas
    // i.ytimg.com/vi/<id>/<nombre>.jpg funcionan sin firma.
    return base;
}

// Saca el videoId de una direccion de miniatura, para poder pedir la version
// .jpg de i.ytimg.com cuando la original falla.
static NSString *YTVideoIdDeMiniatura(NSString *url) {
    NSUInteger inicio = NSNotFound;
    NSRange marca = [url rangeOfString:@"/vi_webp/"];
    if (marca.location == NSNotFound) marca = [url rangeOfString:@"/vi/"];
    if (marca.location != NSNotFound) {
        inicio = marca.location + marca.length;
    } else {
        NSRange v = [url rangeOfString:@"?v="];
        if (v.location == NSNotFound) v = [url rangeOfString:@"&v="];
        if (v.location != NSNotFound) inicio = v.location + v.length;
    }
    if (inicio == NSNotFound || inicio + 11 > url.length) return nil;

    NSString *posible = [url substringWithRange:NSMakeRange(inicio, 11)];
    NSCharacterSet *validos = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];
    if ([posible rangeOfCharacterFromSet:[validos invertedSet]].location != NSNotFound) return nil;
    return posible;
}

// Lista de direcciones a probar, en orden, para una misma miniatura.
static NSArray *YTCandidatosDeMiniatura(NSString *url) {
    NSMutableArray *candidatos = [NSMutableArray arrayWithObject:url];
    NSString *videoId = YTVideoIdDeMiniatura(url);
    if (videoId.length == 11) {
        for (NSString *nombre in @[ @"sddefault.jpg", @"hqdefault.jpg", @"mqdefault.jpg" ]) {
            NSString *candidato = [NSString stringWithFormat:
                @"https://i.ytimg.com/vi/%@/%@", videoId, nombre];
            if (![candidatos containsObject:candidato]) [candidatos addObject:candidato];
        }
    }
    return candidatos;
}

static NSURLSession *sSesionMiniaturas = nil;
static NSMutableDictionary *sMiniaturasEnCurso = nil;   // url -> bloques en espera
static NSMutableArray *sMiniaturasEnCola = nil;         // urls pendientes
static NSUInteger sMiniaturasActivas = 0;
static const NSUInteger kMiniaturasSimultaneas = 4;

+ (void)prepararMiniaturas {
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 20.0;
        cfg.timeoutIntervalForResource = 40.0;
        // Cache en disco: al volver a una pantalla las miniaturas ya estan y no
        // se vuelve a pedir nada a Google.
        cfg.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                     diskCapacity:32 * 1024 * 1024
                                                         diskPath:@"tube9_miniaturas"];
        cfg.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
        sSesionMiniaturas = [NSURLSession sessionWithConfiguration:cfg];
        sMiniaturasEnCurso = [NSMutableDictionary dictionary];
        sMiniaturasEnCola = [NSMutableArray array];
        // Con poca memoria lo primero que sobra es la cache de imagenes.
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *nota) {
            [sCacheMiniaturas removeAllObjects];
        }];
    });
}

+ (void)cargarMiniatura:(NSString *)url
             completion:(void (^)(UIImage *imagen))completion {
    if (completion == nil) return;
    [self prepararMiniaturas];

    NSString *limpia = YTMiniaturaJpeg(url);
    if (limpia.length == 0) { completion(nil); return; }

    void (^empezar)(void) = ^{
        UIImage *guardada = [sCacheMiniaturas objectForKey:limpia];
        if (guardada) { completion(guardada); return; }

        NSMutableArray *esperando = sMiniaturasEnCurso[limpia];
        if (esperando) {
            // Ya se esta descargando: se apunta a la lista en vez de pedirla otra vez.
            [esperando addObject:[completion copy]];
            return;
        }
        sMiniaturasEnCurso[limpia] = [NSMutableArray arrayWithObject:[completion copy]];
        [sMiniaturasEnCola addObject:limpia];
        [self bombearMiniaturas];
    };
    if ([NSThread isMainThread]) empezar();
    else dispatch_async(dispatch_get_main_queue(), empezar);
}

+ (void)bombearMiniaturas {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self bombearMiniaturas]; });
        return;
    }
    while (sMiniaturasActivas < kMiniaturasSimultaneas && sMiniaturasEnCola.count > 0) {
        NSString *siguiente = sMiniaturasEnCola[0];
        [sMiniaturasEnCola removeObjectAtIndex:0];
        if (!sMiniaturasEnCurso[siguiente]) continue;   // ya no interesa a nadie
        sMiniaturasActivas++;
        [self descargarMiniatura:siguiente
                      candidatos:YTCandidatosDeMiniatura(siguiente)
                           indice:0];
    }
}

+ (void)descargarMiniatura:(NSString *)limpia
                candidatos:(NSArray *)candidatos
                     indice:(NSUInteger)indice {
    NSString *candidato = candidatos[indice];
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:candidato]];
    peticion.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    peticion.timeoutInterval = 20.0;
    // Se piden JPEG explicitamente: asi Google no devuelve WebP ni aunque el
    // dispositivo lo pidiera.
    [peticion setValue:@"image/jpeg,image/png;q=0.9,*/*;q=0.5"
        forHTTPHeaderField:@"Accept"];
    [peticion setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 9_3_5 like Mac OS X)"
        forHTTPHeaderField:@"User-Agent"];

    [[sSesionMiniaturas dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        NSInteger codigo = [respuesta isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)respuesta).statusCode : 0;
        UIImage *imagen = (error == nil && (codigo == 0 || codigo == 200) && datos.length)
            ? [UIImage imageWithData:datos] : nil;

        if (imagen) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUInteger coste = (NSUInteger)(imagen.size.width * imagen.size.height * 4.0);
                if (coste > 0) [sCacheMiniaturas setObject:imagen forKey:limpia cost:coste];
                else [sCacheMiniaturas setObject:imagen forKey:limpia];
                [self terminarMiniatura:limpia imagen:imagen];
            });
            return;
        }

        // Fallo o formato que iOS 9 no entiende: se prueba el siguiente tamano.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (indice + 1 < candidatos.count) {
                [self descargarMiniatura:limpia candidatos:candidatos indice:indice + 1];
            } else {
                [self terminarMiniatura:limpia imagen:nil];
            }
        });
    }] resume];
}

+ (void)terminarMiniatura:(NSString *)limpia imagen:(UIImage *)imagen {
    NSArray *esperando = sMiniaturasEnCurso[limpia];
    [sMiniaturasEnCurso removeObjectForKey:limpia];
    if (sMiniaturasActivas > 0) sMiniaturasActivas--;
    for (void (^bloque)(UIImage *) in esperando) bloque(imagen);
    [self bombearMiniaturas];
}

+ (void)vaciarCacheMiniaturas {
    [sCacheMiniaturas removeAllObjects];
}

#pragma mark - Errores en castellano

+ (NSString *)explicarError:(NSError *)error {
    if (!error) return @"";
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        switch (error.code) {
            case NSURLErrorNotConnectedToInternet:
                return @"Sin conexion a Internet.";
            case NSURLErrorCannotFindHost:
                return @"No se encuentra el servidor (revisa la direccion).";
            case NSURLErrorCannotConnectToHost:
                return @"No se puede conectar al servidor (revisa el puerto y el firewall).";
            case NSURLErrorTimedOut:
                return @"El servidor tarda demasiado en responder.";
            case NSURLErrorServerCertificateUntrusted:
            case NSURLErrorServerCertificateHasBadDate:
            case NSURLErrorServerCertificateHasUnknownRoot:
            case NSURLErrorServerCertificateNotYetValid:
                return @"Certificado TLS no valido: iOS 9 no confia en la CA moderna. "
                        "Instala las raices actualizadas (README, pasos 1-3).";
            case NSURLErrorSecureConnectionFailed:
                return @"Fallo de conexion segura (TLS). Actualiza las raices del "
                        "dispositivo (README, pasos 1-3).";
            case NSURLErrorCancelled:
                return @"Peticion cancelada.";
            default:
                break;
        }
    }
    return error.localizedDescription ?: @"Error desconocido";
}

@end

// ---------------------------------------------------------------------------
//  Busca recursivamente cualquier clave que termine en 'sufijo'
//  (videoRenderer, compactVideoRenderer, ...) y acumula su valor.
// ---------------------------------------------------------------------------
void YTRecogerRenderers(id nodo, NSString *sufijo, NSMutableArray *salida) {
    if ([nodo isKindOfClass:[NSDictionary class]]) {
        [(NSDictionary *)nodo enumerateKeysAndObjectsUsingBlock:^(id clave, id valor, BOOL *parar) {
            if ([clave isKindOfClass:[NSString class]] && [(NSString *)clave hasSuffix:sufijo]
                && [valor isKindOfClass:[NSDictionary class]]) {
                [salida addObject:valor];
            }
            YTRecogerRenderers(valor, sufijo, salida);
        }];
    } else if ([nodo isKindOfClass:[NSArray class]]) {
        for (id elemento in (NSArray *)nodo) {
            YTRecogerRenderers(elemento, sufijo, salida);
        }
    }
}

// ---------------------------------------------------------------------------
//  YouTube Music
//
//  La pantalla de musica NO usa los mismos nodos que la de videos
//  (videoRenderer): YouTube Music devuelve "estantes" (musicCarouselShelfRenderer
//  y musicShelfRenderer) con canciones (musicResponsiveListItemRenderer y
//  musicTwoRowItemRenderer). De cada cancion interesa el videoId (para poder
//  reproducirla con el cliente ANDROID), el titulo, el artista y la portada.
// ---------------------------------------------------------------------------

// {"simpleText": "..."} o {"runs": [{"text": "..."}]} -> texto plano
static NSString *YTTextoDeNodo(id nodo) {
    if (![nodo isKindOfClass:[NSDictionary class]]) return nil;
    id simple = ((NSDictionary *)nodo)[@"simpleText"];
    if ([simple isKindOfClass:[NSString class]]) return simple;

    id runs = ((NSDictionary *)nodo)[@"runs"];
    if ([runs isKindOfClass:[NSArray class]] && [(NSArray *)runs count] > 0) {
        NSMutableString *unido = [NSMutableString string];
        for (id r in (NSArray *)runs) {
            if (![r isKindOfClass:[NSDictionary class]]) continue;
            id t = ((NSDictionary *)r)[@"text"];
            if ([t isKindOfClass:[NSString class]]) [unido appendString:t];
        }
        return unido.length ? unido : nil;
    }
    return nil;
}

// Subscripting defensivo: devuelve el valor solo si es un diccionario.
static id YTDiccionarioEn(id nodo, NSString *clave) {
    if (![nodo isKindOfClass:[NSDictionary class]]) return nil;
    id valor = ((NSDictionary *)nodo)[clave];
    return [valor isKindOfClass:[NSDictionary class]] ? valor : nil;
}

// Primer valor, a cualquier profundidad, cuya clave sea la buscada.
static id YTEncontrarPorClave(id nodo, NSString *claveBuscada) {
    if ([nodo isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dic = nodo;
        id directo = dic[claveBuscada];
        if (directo) return directo;
        for (NSString *clave in dic) {
            id hallado = YTEncontrarPorClave(dic[clave], claveBuscada);
            if (hallado) return hallado;
        }
    } else if ([nodo isKindOfClass:[NSArray class]]) {
        for (id hijo in (NSArray *)nodo) {
            id hallado = YTEncontrarPorClave(hijo, claveBuscada);
            if (hallado) return hallado;
        }
    }
    return nil;
}

// ¿Cuelga de aqui otro estante? Entonces este nodo es solo un envoltorio (en
// YouTube Music los estantes van dentro de estantes) y no se debe consumir
// entero: hay que bajar y tratar cada estante de dentro por separado.
static BOOL YTContieneEstante(id nodo) {
    if ([nodo isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dic = nodo;
        if (YTDiccionarioEn(dic, @"musicCarouselShelfRenderer") ||
            YTDiccionarioEn(dic, @"musicShelfRenderer") ||
            YTDiccionarioEn(dic, @"musicPlaylistShelfRenderer")) return YES;
        for (NSString *clave in dic) if (YTContieneEstante(dic[clave])) return YES;
    } else if ([nodo isKindOfClass:[NSArray class]]) {
        for (id hijo in (NSArray *)nodo) if (YTContieneEstante(hijo)) return YES;
    }
    return NO;
}

// Acumula las canciones de un estante, en el orden en que vienen. No se entra
// en estantes anidados (eso lo hace YTRecorrerEstantes) ni en cabeceras/pies,
// que traen botones y menus y solo ensuciarian la lista.
static void YTRecogerFilasMusicales(id nodo, NSMutableArray *salida) {
    if ([nodo isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dic = nodo;
        NSDictionary *fila = YTDiccionarioEn(dic, @"musicResponsiveListItemRenderer");
        if (fila) { [salida addObject:fila]; return; }
        NSDictionary *dosFilas = YTDiccionarioEn(dic, @"musicTwoRowItemRenderer");
        if (dosFilas) { [salida addObject:dosFilas]; return; }
        for (NSString *clave in dic) {
            if ([clave isEqualToString:@"header"] || [clave isEqualToString:@"footer"]) continue;
            if (YTContieneEstante(dic[clave])) continue;
            YTRecogerFilasMusicales(dic[clave], salida);
        }
    } else if ([nodo isKindOfClass:[NSArray class]]) {
        for (id hijo in (NSArray *)nodo) YTRecogerFilasMusicales(hijo, salida);
    }
}

static NSString *YTUrlMiniaturaMusical(NSDictionary *fila) {
    NSDictionary *render = YTEncontrarPorClave(fila, @"musicThumbnailRenderer");
    NSArray *lista = nil;
    if ([render isKindOfClass:[NSDictionary class]]) {
        lista = YTDiccionarioEn(render, @"thumbnail")[@"thumbnails"];
    }
    if ([lista isKindOfClass:[NSArray class]] && lista.count > 0) {
        NSDictionary *ultima = lista.lastObject;
        if ([ultima isKindOfClass:[NSDictionary class]]) {
            id url = ultima[@"url"];
            if ([url isKindOfClass:[NSString class]]) return url;
        }
    }
    return nil;
}

static YTVideo *YTVideoDeFilaMusical(NSDictionary *fila) {
    NSString *identificador = nil;

    // En las listas verticales viene en "playlistItemData"; en las tarjetas,
    // dentro del punto de navegacion del clic.
    NSDictionary *datos = YTDiccionarioEn(fila, @"playlistItemData");
    if (datos) {
        id vid = datos[@"videoId"];
        if ([vid isKindOfClass:[NSString class]]) identificador = vid;
    }
    if (identificador.length == 0) {
        NSDictionary *punto = YTDiccionarioEn(fila, @"navigationEndpoint");
        NSDictionary *watch = YTDiccionarioEn(punto, @"watchEndpoint");
        if (watch) {
            id vid = watch[@"videoId"];
            if ([vid isKindOfClass:[NSString class]]) identificador = vid;
        }
    }
    // Ultimo recurso: cualquier watchEndpoint del nodo (los menus y botones
    // traen uno, pero suele ser el mismo video).
    if (identificador.length == 0) {
        NSDictionary *watch = YTEncontrarPorClave(fila, @"watchEndpoint");
        if (watch) {
            id vid = watch[@"videoId"];
            if ([vid isKindOfClass:[NSString class]]) identificador = vid;
        }
    }
    // Sin videoId es un album o una lista de reproduccion: no lo podemos
    // reproducir, asi que se descarta.
    if (identificador.length == 0) return nil;

    YTVideo *video = [[YTVideo alloc] init];
    video.identificador = identificador;

    NSArray *columnas = fila[@"flexColumns"];
    if ([columnas isKindOfClass:[NSArray class]] && columnas.count > 0) {
        // Lista vertical: cancion / artista y discos / duracion
        video.titulo = YTTextoDeNodo(YTDiccionarioEn(
            YTDiccionarioEn(columnas[0], @"musicResponsiveListItemFlexColumnRenderer"), @"text"));
        if (columnas.count > 1) {
            video.canal = YTTextoDeNodo(YTDiccionarioEn(
                YTDiccionarioEn(columnas[1], @"musicResponsiveListItemFlexColumnRenderer"), @"text"));
        }
        if (columnas.count > 2) {
            NSString *posible = YTTextoDeNodo(YTDiccionarioEn(
                YTDiccionarioEn(columnas[2], @"musicResponsiveListItemFlexColumnRenderer"), @"text"));
            if (posible.length <= 8 && [posible rangeOfString:@":"].location != NSNotFound) {
                video.duracion = posible;
            }
        }
    } else {
        // Tarjeta horizontal: solo titulo y subtitulo.
        video.titulo = YTTextoDeNodo(fila[@"title"]);
        video.canal  = YTTextoDeNodo(fila[@"subtitle"]);
    }
    if (video.titulo.length == 0) video.titulo = @"(sin titulo)";

    video.urlMiniatura = YTUrlMiniaturaMusical(fila);
    if (video.urlMiniatura.length == 0) {
        video.urlMiniatura = [NSString stringWithFormat:
            @"https://i.ytimg.com/vi/%@/mqdefault.jpg", identificador];
    }
    return video;
}

// Convierte un estante ya localizado (carrusel o lista) en una fila de la
// pantalla: titulo que pone YouTube + canciones reproducibles.
static void YTConsumirEstante(NSDictionary *contenedor, NSMutableArray *filas,
                              NSMutableSet *vistos) {
    NSString *titulo = nil;
    NSDictionary *cabecera = YTDiccionarioEn(contenedor, @"header");
    if (cabecera) {
        NSDictionary *basica =
            YTDiccionarioEn(cabecera, @"musicCarouselShelfBasicHeaderRenderer");
        if (basica) titulo = YTTextoDeNodo(YTDiccionarioEn(basica, @"title"));
    }
    if (titulo.length == 0) titulo = YTTextoDeNodo(YTDiccionarioEn(contenedor, @"title"));

    // OJO: "contents" es un ARRAY. Con un ayudante que exigiera diccionario,
    // como estaba antes, no se veia ni una cancion y la pestana salia vacia.
    NSMutableArray *candidatas = [NSMutableArray array];
    YTRecogerFilasMusicales(contenedor[@"contents"], candidatas);
    NSMutableArray *videos = [NSMutableArray array];
    for (NSDictionary *fila in candidatas) {
        YTVideo *video = YTVideoDeFilaMusical(fila);
        if (video) [videos addObject:video];
    }
    // Con una o dos canciones no vale la pena una fila entera.
    if (videos.count >= 3) {
        for (YTVideo *v in videos) [vistos addObject:v.identificador];
        [filas addObject:@{ @"titulo" : (titulo.length ? titulo : @"Música"),
                            @"videos" : videos }];
    }
}

static void YTRecorrerEstantes(id nodo, NSMutableArray *filas, NSMutableSet *vistos) {
    if ([nodo isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dic = nodo;

        NSDictionary *carrusel = YTDiccionarioEn(dic, @"musicCarouselShelfRenderer");
        if (carrusel) { YTConsumirEstante(carrusel, filas, vistos); return; }

        NSDictionary *estante = YTDiccionarioEn(dic, @"musicShelfRenderer");
        if (estante) {
            if (YTContieneEstante(estante[@"contents"])) {
                YTRecorrerEstantes(estante[@"contents"], filas, vistos);
                return;
            }
            YTConsumirEstante(estante, filas, vistos);
            return;
        }
        for (NSString *clave in dic) YTRecorrerEstantes(dic[clave], filas, vistos);
    } else if ([nodo isKindOfClass:[NSArray class]]) {
        for (id hijo in (NSArray *)nodo) YTRecorrerEstantes(hijo, filas, vistos);
    }
}

NSArray *YTCarruselesMusicales(NSDictionary *json, NSString *tituloRespaldo) {
    NSMutableArray *filas = [NSMutableArray array];
    NSMutableSet *vistos = [NSMutableSet set];
    YTRecorrerEstantes(json, filas, vistos);

    // Muchas respuestas de YouTube Music (sobre todo las busquedas) no traen
    // estantes con nombre: las canciones cuelgan de un "itemSectionRenderer".
    // Lo que queda suelto se agrupa en un unico estante para no perderlo.
    NSMutableArray *sueltas = [NSMutableArray array];
    YTRecogerFilasMusicales(json, sueltas);
    NSMutableArray *restantes = [NSMutableArray array];
    for (NSDictionary *fila in sueltas) {
        YTVideo *video = YTVideoDeFilaMusical(fila);
        if (video == nil || [vistos containsObject:video.identificador]) continue;
        [vistos addObject:video.identificador];
        [restantes addObject:video];
    }
    if (restantes.count >= 3) {
        [filas addObject:@{ @"titulo" : (tituloRespaldo.length ? tituloRespaldo : @"Música"),
                            @"videos" : restantes }];
    }
    return filas;
}
