// v1.0-en 2026-10-29: English UI build (textos traducidos al ingles; hl=en, gl=US)
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

// Filtros del buscador. Son los mismos "params" que usa la web de YouTube; sin
// ellos YouTube no devuelve ni canales ni listas entre los resultados.
static NSString * const kFiltroCanales = @"EgIQAg%3D%3D";   // solo canales
static NSString * const kFiltroListas  = @"EgIQAw%3D%3D";   // solo listas

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
               @"nota"    : @"Android app (12 of 12 downloads OK)" },

            @{ @"nombre"  : @"ANDROID_VR",
               @"version" : @"1.65.10",
               @"id"      : @28,
               @"agente"  : @"com.google.android.apps.youtube.vr.oculus/1.65.10 "
                            @"(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
               @"sdk"     : @32,
               @"extra"   : @{ @"deviceMake" : @"Oculus", @"deviceModel" : @"Quest 3",
                               @"osName" : @"Android", @"osVersion" : @"12L" },
               @"nota"    : @"VR headset (9 of 12: YouTube asks for a po token on some)" },

            @{ @"nombre"  : @"IOS",
               @"version" : @"21.26.4",
               @"id"      : @5,
               @"agente"  : @"com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 "
                            @"like Mac OS X;)",
               @"sdk"     : @0,
               @"extra"   : @{ @"deviceMake" : @"Apple", @"deviceModel" : @"iPhone16,2",
                               @"osName" : @"iPhone", @"osVersion" : @"18.3.2.22D82" },
               @"nota"    : @"iPhone app (returned no formats in testing)" },

            @{ @"nombre"  : @"VISIONOS",
               @"version" : @"1.02",
               @"id"      : @101,
               @"agente"  : @"Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) "
                            @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 "
                            @"Safari/605.1.15",
               @"sdk"     : @0,
               @"extra"   : @{ @"deviceMake" : @"Apple", @"deviceModel" : @"RealityDevice17,1",
                               @"osName" : @"visionOS", @"osVersion" : @"26.5.23O471" },
               @"nota"    : @"Vision Pro headset (no po token on paper, but it "
                            @"returned no formats in testing)" }
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
                     @"nota"    : @"YouTube Music (browsing only)" };
    });
    return cliente;
}

// Cliente para moverse por los canales. Tiene que ser uno que conteste a
// "browse": el de Android (el de arriba) y el de iPhone devuelven HTTP 400 en
// las paginas de canal (probado uno por uno), y el de las gafas VR las
// contesta con la maqueta movil de siempre: cabecera con avatar y portada, y
// las pestanas (Inicio / Videos / Listas / Informacion) con sus "params".
// Sus enlaces de video tambien necesitan JavaScript, pero aqui solo se navega:
// al reproducir se resuelve siempre con el cliente ANDROID.
static NSDictionary *YTClienteMovil(void) {
    return YTClientes()[1];   // ANDROID_VR
}

static NSCache *sCacheMiniaturas = nil;

// Declarada al final del fichero; hace falta el prototipo aqui.
void YTRecogerRenderers(id nodo, NSString *sufijo, NSMutableArray *salida);

// Lo mismo para los carruseles de YouTube Music. "tituloRespaldo" se usa para
// agrupar las canciones que vienen sin estante con nombre.
NSArray *YTCarruselesMusicales(NSDictionary *json, NSString *tituloRespaldo);

// Ayudas de canales (definidas al final, con el resto de parsers).
static NSDictionary *YTDatosDeCanal(NSDictionary *json, NSString *canalId);
static NSArray *YTEstantesDeVideos(NSDictionary *sectionList);
static NSDictionary *YTListaDesdeRenderer(NSDictionary *renderer);
static NSArray *YTVideosDesdeRenderers(id raiz, NSArray *sufijos);
static NSArray *YTListasDesdeRenderers(id raiz);
static NSDictionary *YTCanalDesdeRenderer(NSDictionary *renderer);
static BOOL YTTituloContiene(NSString *texto, NSArray *agujas);
static NSString *YTCadenaOTexto(id valor);
static NSString *YTMejorMiniaturaDeNodo(id nodo);
static NSString *YTPortadaDeNodo(id nodo);
static NSString *YTTextoDeNodo(id nodo);
static id YTEncontrarPorClave(id nodo, NSString *claveBuscada);

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
- (void)buscarRenderers:(NSString *)consulta
                 params:(NSString *)params
                cliente:(NSDictionary *)cliente
             completion:(void (^)(NSDictionary *json, NSError *error))completion;
- (void)pestanaDeCanal:(NSString *)canalId
                params:(NSString *)params
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
                    code:1 userInfo:@{NSLocalizedDescriptionKey : @"Invalid response"}]);
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
                    @"You have not set the relay address in Settings."}]);
            return;
        }
        [self obtener:url completion:^(NSDictionary *json, NSError *error) {
            if (error) { completion(nil, error); return; }
            if (![json[@"ok"] boolValue]) {
                completion(nil, [NSError errorWithDomain:@"tube9" code:3
                    userInfo:@{NSLocalizedDescriptionKey :
                        json[@"error"] ?: @"The relay replied with an error"}]);
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

#pragma mark - Canales y listas

- (void)canalConId:(NSString *)canalId completion:(YTBloqueInfo)completion {
    if (canalId.length == 0) {
        completion(nil, [NSError errorWithDomain:@"tube9" code:4
            userInfo:@{NSLocalizedDescriptionKey : @"Invalid channel"}]);
        return;
    }
    if ([[YTClient modo] isEqualToString:@"relay"]) {
        completion(nil, [NSError errorWithDomain:@"tube9" code:3
            userInfo:@{NSLocalizedDescriptionKey :
                @"Channels need direct mode (no relay)."}]);
        return;
    }

    NSDictionary *cliente = YTClienteMovil();
    [self asegurarVisitante:^{
        NSDictionary *cuerpo = @{
            @"browseId" : canalId,
            @"context" : @{ @"client" : [self contextoParaCliente:cliente incluirVisitante:YES] }
        };
        [self enviarAlInnerTube:@"browse" cliente:cliente cuerpo:cuerpo
            completion:^(NSDictionary *json, NSError *error) {
            if (error) { completion(nil, error); return; }
            completion(YTDatosDeCanal(json, canalId), nil);
        }];
    }];
}

// Pide una pestana concreta de un canal. El "params" lo mando YouTube con la
// propia pagina del canal, asi que aqui solo se devuelve.
- (void)pestanaDeCanal:(NSString *)canalId
                params:(NSString *)params
            completion:(void (^)(NSDictionary *json, NSError *error))completion {
    NSDictionary *cliente = YTClienteMovil();
    [self asegurarVisitante:^{
        NSMutableDictionary *cuerpo = [NSMutableDictionary dictionary];
        cuerpo[@"browseId"] = canalId;
        if (params.length) cuerpo[@"params"] = params;
        cuerpo[@"context"] = @{ @"client" : [self contextoParaCliente:cliente incluirVisitante:YES] };
        [self enviarAlInnerTube:@"browse" cliente:cliente cuerpo:cuerpo completion:completion];
    }];
}

// Las pestanas de lista traen los datos dentro de un "itemSectionRenderer"; las
// de canal, dentro de "sectionListRenderer". Se busca el primero que haya.
static id YTRaizDeContenido(NSDictionary *json) {
    NSDictionary *seccion = YTEncontrarPorClave(json, @"itemSectionRenderer");
    if ([seccion isKindOfClass:[NSDictionary class]] && seccion[@"contents"]) {
        return seccion[@"contents"];
    }
    return json;
}

- (void)videosDeCanal:(NSString *)canalId
               params:(NSString *)params
           completion:(YTBloqueLista)completion {
    [self pestanaDeCanal:canalId params:params
        completion:^(NSDictionary *json, NSError *error) {
        if (error) { completion(nil, error); return; }
        completion(YTVideosDesdeRenderers(YTRaizDeContenido(json),
                                          @[ @"VideoRenderer", @"ContextRenderer" ]), nil);
    }];
}

- (void)listasDeCanal:(NSString *)canalId
               params:(NSString *)params
           completion:(void (^)(NSArray *listas, NSError *error))completion {
    [self pestanaDeCanal:canalId params:params
        completion:^(NSDictionary *json, NSError *error) {
        if (error) { completion(nil, error); return; }
        completion(YTListasDesdeRenderers(YTRaizDeContenido(json)), nil);
    }];
}

- (void)informacionDeCanal:(NSString *)canalId
                    params:(NSString *)params
                completion:(YTBloqueInfo)completion {
    [self pestanaDeCanal:canalId params:params
        completion:^(NSDictionary *json, NSError *error) {
        if (error) { completion(nil, error); return; }

        // La maqueta movil mete todo en "channelAboutMetadataRenderer"; otras
        // versiones usan un "aboutChannelViewModel". Se acepta cualquiera.
        id about = YTEncontrarPorClave(json, @"channelAboutMetadataRenderer");
        id otro = YTEncontrarPorClave(json, @"aboutChannelViewModel");
        if ([otro isKindOfClass:[NSDictionary class]]) about = otro;
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        if ([about isKindOfClass:[NSDictionary class]]) {
            info[@"descripcion"] = YTCadenaOTexto(about[@"description"]) ?: @"";
            info[@"suscriptores"] = YTCadenaOTexto(about[@"subscriberCountText"]) ?: @"";
            info[@"visitas"] = YTCadenaOTexto(about[@"viewCountText"]) ?: @"";
            info[@"videos"] = YTCadenaOTexto(about[@"videoCountText"]) ?: @"";
            info[@"pais"] = YTCadenaOTexto(about[@"country"]) ?: YTCadenaOTexto(about[@"countryCode"]) ?: @"";
            info[@"alta"] = YTCadenaOTexto(about[@"joinedDateText"]) ?: @"";
        }
        completion(info, nil);
    }];
}

- (void)videosDeLista:(NSString *)listaId
           completion:(void (^)(NSDictionary *lista, NSArray *videos,
                                NSError *error))completion {
    if (listaId.length == 0) {
        completion(nil, @[], [NSError errorWithDomain:@"tube9" code:4
            userInfo:@{NSLocalizedDescriptionKey : @"Invalid playlist"}]);
        return;
    }
    if ([[YTClient modo] isEqualToString:@"relay"]) {
        completion(nil, nil, [NSError errorWithDomain:@"tube9" code:3
            userInfo:@{NSLocalizedDescriptionKey :
                @"Playlists need direct mode (no relay)."}]);
        return;
    }

    // La pagina de una lista se pide por su identificador con "VL" delante.
    NSString *browseId = [listaId hasPrefix:@"VL"] ? listaId
                                                   : [@"VL" stringByAppendingString:listaId];
    NSDictionary *cliente = YTClienteMovil();
    [self asegurarVisitante:^{
        NSDictionary *cuerpo = @{
            @"browseId" : browseId,
            @"context" : @{ @"client" : [self contextoParaCliente:cliente incluirVisitante:YES] }
        };
        [self enviarAlInnerTube:@"browse" cliente:cliente cuerpo:cuerpo
            completion:^(NSDictionary *json, NSError *error) {
            if (error) { completion(nil, nil, error); return; }

            NSMutableDictionary *ficha = [NSMutableDictionary dictionary];
            id cab = YTEncontrarPorClave(json, @"playlistHeaderRenderer");
            if ([cab isKindOfClass:[NSDictionary class]]) {
                // Los textos de esta ficha vienen de las dos maneras segun el
                // cliente (cadena suelta o {"runs": [...]}), asi que se leen con
                // YTCadenaOTexto, que acepta ambas.
                ficha[@"titulo"] = YTCadenaOTexto(cab[@"title"]) ?: @"";
                ficha[@"dueno"] = YTCadenaOTexto(cab[@"ownerText"]) ?: @"";
                ficha[@"cuantos"] = YTCadenaOTexto(cab[@"numVideosText"]) ?: @"";
                ficha[@"descripcion"] = YTCadenaOTexto(cab[@"descriptionText"]) ?: @"";
                NSDictionary *due = YTEncontrarPorClave(cab[@"ownerText"], @"browseEndpoint");
                if ([due isKindOfClass:[NSDictionary class]]) {
                    ficha[@"canalId"] = due[@"browseId"] ?: @"";
                }
            }
            NSArray *videos = YTVideosDesdeRenderers(json, @[ @"playlistVideoRenderer" ]);
            completion(ficha, videos, nil);
        }];
    }];
}

- (void)buscarCanales:(NSString *)consulta
           completion:(void (^)(NSArray *canales, NSError *error))completion {
    [self buscarRenderers:consulta
                   params:kFiltroCanales
                  cliente:YTClienteMovil()
               completion:^(NSDictionary *json, NSError *error) {
        if (error) { completion(nil, error); return; }
        NSMutableArray *renderers = [NSMutableArray array];
        YTRecogerRenderers(YTRaizDeContenido(json), @"ChannelRenderer", renderers);
        NSMutableArray *canales = [NSMutableArray array];
        NSMutableSet *vistos = [NSMutableSet set];
        for (NSDictionary *r in renderers) {
            NSDictionary *c = YTCanalDesdeRenderer(r);
            if (!c || [vistos containsObject:c[@"id"]]) continue;
            [vistos addObject:c[@"id"]];
            [canales addObject:c];
        }
        completion(canales, nil);
    }];
}

- (void)buscarListas:(NSString *)consulta
          completion:(void (^)(NSArray *listas, NSError *error))completion {
    [self buscarRenderers:consulta
                   params:kFiltroListas
                  cliente:YTClientePrincipal()
               completion:^(NSDictionary *json, NSError *error) {
        if (error) { completion(nil, error); return; }
        completion(YTListasDesdeRenderers(YTRaizDeContenido(json)), nil);
    }];
}

// Busqueda comun: sirve para los filtros (canales, listas) cambiando el cliente
// y el "params".
- (void)buscarRenderers:(NSString *)consulta
                 params:(NSString *)params
                cliente:(NSDictionary *)cliente
             completion:(void (^)(NSDictionary *json, NSError *error))completion {
    NSString *limpia = [consulta stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (limpia.length == 0) {
        completion(nil, [NSError errorWithDomain:@"tube9" code:4
            userInfo:@{NSLocalizedDescriptionKey : @"Type something to search for"}]);
        return;
    }
    if ([[YTClient modo] isEqualToString:@"relay"]) {
        completion(nil, [NSError errorWithDomain:@"tube9" code:3
            userInfo:@{NSLocalizedDescriptionKey :
                @"This filter needs direct mode (no relay)."}]);
        return;
    }
    [self asegurarVisitante:^{
        NSMutableDictionary *cuerpo = [NSMutableDictionary dictionary];
        cuerpo[@"query"] = limpia;
        if (params.length) cuerpo[@"params"] = params;
        cuerpo[@"context"] = @{ @"client" : [self contextoParaCliente:cliente incluirVisitante:YES] };
        [self enviarAlInnerTube:@"search" cliente:cliente cuerpo:cuerpo completion:completion];
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
                @"The Music screen needs direct mode (no relay)."}]);
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
            userInfo:@{NSLocalizedDescriptionKey : @"Invalid video"}]);
        return;
    }

    if ([[YTClient modo] isEqualToString:@"relay"]) {
        NSURL *url = [YTClient urlDelRelay:@"/api/stream" parametros:@{ @"id" : videoId }];
        if (!url) {
            completion(nil, [NSError errorWithDomain:@"tube9" code:2
                userInfo:@{NSLocalizedDescriptionKey :
                    @"You have not set the relay address in Settings."}]);
            return;
        }
        [self obtener:url completion:^(NSDictionary *json, NSError *error) {
            if (error) { completion(nil, error); return; }
            if (![json[@"ok"] boolValue]) {
                completion(nil, [NSError errorWithDomain:@"tube9" code:3
                    userInfo:@{NSLocalizedDescriptionKey :
                        json[@"error"] ?: @"The relay could not resolve the video"}]);
                return;
            }
            NSString *enlace = json[@"url_proxy"] ?: json[@"url_directa"];
            if (enlace.length == 0) {
                completion(nil, [NSError errorWithDomain:@"tube9" code:5
                    userInfo:@{NSLocalizedDescriptionKey : @"The relay returned no URL"}]);
                return;
            }
            completion(@{ @"url" : enlace,
                          @"titulo" : json[@"titulo"] ?: @"",
                          @"autor" : json[@"autor"] ?: @"",
                          @"canalId" : @"",
                          @"visitas" : @"",
                          @"duracion" : @"",
                          @"descripcion" : @"",
                          @"itag" : @0,
                          @"bytes" : @0 }, nil);
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
        NSString *resumen = motivos.count ? [motivos componentsJoinedByString:@" | "] : @"no details";
        NSString *ayuda = @"";
        if ([resumen rangeOfString:@"LOGIN_REQUIRED"].location != NSNotFound ||
            [resumen rangeOfString:@"inicia sesion"].location != NSNotFound ||
            [resumen rangeOfString:@"bot"].location != NSNotFound) {
            ayuda = @"\n\nYouTube does not trust this connection. Go to "
                     "Settings > Sign in to YouTube: once you are signed in, "
                     "this message goes away.";
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
            NSString *motivo = estado[@"reason"] ?: nombreEstado ?: @"unknown";
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
                    @"YouTube returned no playable format for this video."}]];
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
                        [NSString stringWithFormat:@"%@ gave a URL that cannot be "
                         @"downloaded (%@)", cliente[@"nombre"], detalle]}]];
                [self resolverVideo:videoId conClientes:clientes indice:indice + 1
                            errores:errores completion:completion];
                return;
            }
            NSDictionary *detalles = json[@"videoDetails"];
            NSString *descripcion = detalles[@"shortDescription"];
            if (![descripcion isKindOfClass:[NSString class]]) descripcion = @"";
            // El "visitante" (viewCount) viene como numero; se guarda tal cual
            // y se formatea en la pantalla, que es la que sabe de idiomas.
            id visitas = detalles[@"viewCount"];
            if (![visitas isKindOfClass:[NSNumber class]]
                && ![visitas isKindOfClass:[NSString class]]) visitas = @"";
            completion(@{ @"url" : enlace,
                          @"titulo" : detalles[@"title"] ?: @"",
                          @"autor" : detalles[@"author"] ?: @"",
                          @"canalId" : detalles[@"channelId"] ?: @"",
                          @"visitas" : visitas,
                          @"duracion" : detalles[@"lengthSeconds"] ?: @"",
                          @"descripcion" : descripcion,
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
    if (!url) { completion(NO, @"the address is not valid"); return; }

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
            completion(NO, [NSString stringWithFormat:@"%@ (in %.1f s)",
                [YTClient explicarError:error], segundos]);
            return;
        }
        NSInteger codigo = [respuesta isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)respuesta).statusCode : 0;
        if (codigo == 200 || codigo == 206) {
            completion(YES, [NSString stringWithFormat:@"HTTP %ld in %.1f s",
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
    ctx[@"hl"] = @"en";
    ctx[@"gl"] = @"US";
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
    [peticion setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];

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
                        @"YouTube replied HTTP %ld when asking for %@.%@",
                        (long)codigo, ruta, detalle]}]); });
            return;
        }

        if (!esDiccionario) {
            YTEnPrincipal(^{
                completion(nil, [NSError errorWithDomain:@"tube9" code:8
                    userInfo:@{NSLocalizedDescriptionKey : @"YouTube returned something unexpected"}]);
            });
            return;
        }
        YTEnPrincipal(^{ completion(objeto, nil); });
    }] resume];
}

#pragma mark - Diagnostico

- (void)probarConexion:(void (^)(NSString *informe))completion {
    NSMutableString *informe = [NSMutableString string];
    [informe appendFormat:@"Mode: %@\n", [YTClient modo]];
    [informe appendFormat:@"Clients: %@\n", [YTClient listaDeClientes]];
    [informe appendFormat:@"Signed in: %@  (%lu cookies)\n",
        ([YTClient haySesion] ? @"YES" : @"NO"), (unsigned long)[YTClient numeroDeCookies]];

    if ([[YTClient modo] isEqualToString:@"relay"]) {
        NSURL *url = [YTClient urlDelRelay:@"/api/health" parametros:nil];
        [informe appendFormat:@"Relay: %@\n\n", url.absoluteString ?: @"(not set)"];
        if (!url) {
            [informe appendString:@"The relay address is missing."];
            completion(informe);
            return;
        }
        [self obtener:url completion:^(NSDictionary *json, NSError *error) {
            if (error) {
                [informe appendFormat:@"FAILED: %@\n%@",
                    [YTClient explicarError:error],
                    @"\nCheck that the relay is running and on the same network."];
            } else {
                [informe appendFormat:@"OK  %@ v%@ replies",
                    json[@"servicio"] ?: @"?", json[@"version"] ?: @"?"];
            }
            completion(informe);
        }];
        return;
    }

    [informe appendString:@"\n1) Searching youtube.com...\n"];
    NSDate *principioBusqueda = [NSDate date];
    [self buscar:@"test" completion:^(NSArray *videos, NSError *error) {
        [informe appendFormat:@"   %@\n", [self describir:videos error:error
                                                     desde:principioBusqueda]];
        [informe appendFormat:@"   anonymous visitor ID: %@\n",
            ([YTClient visitante].length ? @"received" : @"NOT available")];
        if (error) {
            [informe appendString:@"\nIf this is a certificate error, install the updated "
                               @"root certificates on the device (see the README)."];
            completion(informe);
            return;
        }
        if (videos.count == 0) {
            [informe appendString:@"\nThe search returned no results."];
            completion(informe);
            return;
        }

        YTVideo *prueba = videos[0];
        NSString *recorte = prueba.titulo.length > 32
            ? [prueba.titulo substringToIndex:32] : prueba.titulo;
        [informe appendFormat:@"\n2) Asking for the URL of video \"%@\"...\n", recorte];
        NSDate *principioResolucion = [NSDate date];
        [self resolverVideo:prueba.identificador
            completion:^(NSDictionary *info, NSError *error) {
            double segundos = -[principioResolucion timeIntervalSinceNow];
            NSString *enlace = info[@"url"];
            if (error || enlace.length == 0) {
                [informe appendFormat:@"   FAILED after %.1f s: %@\n", segundos,
                    [YTClient explicarError:error] ?: @"YouTube returned no URL"];
                [informe appendString:@"\nAll clients have been tried. If the reason "
                                   "is LOGIN_REQUIRED, sign in under Settings > "
                                   "Sign in to YouTube."];
                completion(informe);
                return;
            }
            NSURL *url = [NSURL URLWithString:enlace];
            NSString *quien = info[@"cliente"];
            [informe appendFormat:@"   OK  URL received in %.1f s%@\n", segundos,
                (quien.length ? [NSString stringWithFormat:@" with client %@", quien] : @"")];
            NSString *comprobacion = info[@"comprobacion"];
            if (comprobacion.length) {
                [informe appendFormat:@"   download check: %@\n", comprobacion];
            }
            [informe appendFormat:@"   video server: %@\n", url.host ?: @"(unknown)"];
            [informe appendString:@"\n3) Downloading the first KB of the video...\n"];
            [self probarBytesDe:enlace completion:^(NSString *resultado) {
                [informe appendFormat:@"   %@\n", resultado];
                [informe appendString:
                    @"\nIf step 3 fails or takes very long, the problem is in the "
                    @"video download, not in the search: usually the Internet provider "
                    @"is slowing down googlevideo.com. Try relay mode."];
                completion(informe);
            }];
        }];
    }];
}

// Resumen de una llamada con su duracion, para el informe.
- (NSString *)describir:(NSArray *)videos error:(NSError *)error desde:(NSDate *)inicio {
    double segundos = -[inicio timeIntervalSinceNow];
    if (error) {
        return [NSString stringWithFormat:@"FAILED after %.1f s: %@",
                segundos, [YTClient explicarError:error]];
    }
    return [NSString stringWithFormat:@"OK  %lu results in %.1f s",
            (unsigned long)videos.count, segundos];
}

// Pide solo los primeros 64 KB, que es lo mismo que hace el reproductor al
// empezar. Es la prueba decisiva: separa "la busqueda falla" de "el video no
// se descarga".
- (void)probarBytesDe:(NSString *)enlace completion:(void (^)(NSString *resultado))completion {
    NSURL *url = [NSURL URLWithString:enlace];
    if (!url) { completion(@"The video URL is not valid."); return; }

    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:url];
    [peticion setValue:@"bytes=0-65535" forHTTPHeaderField:@"Range"];
    peticion.timeoutInterval = 15.0;   // el informe no debe quedarse colgado
    NSDate *inicio = [NSDate date];
    [[self.sesion dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        double segundos = -[inicio timeIntervalSinceNow];
        if (error) {
            completion([NSString stringWithFormat:@"FAILED after %.1f s: %@",
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
        completion([NSString stringWithFormat:@"OK  HTTP %ld, %@, %.0f KB in %.1f s%@",
                    (long)(http ? http.statusCode : 0),
                    [respuesta MIMEType] ?: @"unknown type",
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
                return @"No Internet connection.";
            case NSURLErrorCannotFindHost:
                return @"Server not found (check the address).";
            case NSURLErrorCannotConnectToHost:
                return @"Cannot connect to the server (check the port and the firewall).";
            case NSURLErrorTimedOut:
                return @"The server takes too long to reply.";
            case NSURLErrorServerCertificateUntrusted:
            case NSURLErrorServerCertificateHasBadDate:
            case NSURLErrorServerCertificateHasUnknownRoot:
            case NSURLErrorServerCertificateNotYetValid:
                return @"Invalid TLS certificate: iOS 9 does not trust the modern CA. "
                        "Install the updated root certificates (README, steps 1-3).";
            case NSURLErrorSecureConnectionFailed:
                return @"Secure connection (TLS) failed. Update the root certificates "
                        "on the device (README, steps 1-3).";
            case NSURLErrorCancelled:
                return @"Request cancelled.";
            default:
                break;
        }
    }
    return error.localizedDescription ?: @"Unknown error";
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
    if (video.titulo.length == 0) video.titulo = @"(no title)";

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
        [filas addObject:@{ @"titulo" : (titulo.length ? titulo : @"Music"),
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
        [filas addObject:@{ @"titulo" : (tituloRespaldo.length ? tituloRespaldo : @"Music"),
                            @"videos" : restantes }];
    }
    return filas;
}

// ---------------------------------------------------------------------------
//  Parsers de canales y listas de reproduccion.
//
//  La maqueta que devuelve el cliente de las gafas VR (el unico que contesta a
//  las peticiones de canal) es la movil de siempre:
//
//    header.c4TabbedHeaderRenderer   nombre, avatar, portada, suscriptores
//    contents.singleColumnBrowseResultsRenderer.tabs[]
//                                    Inicio / Videos / Listas / Informacion,
//                                    cada una con sus "params"
//    ...sectionListRenderer.contents[].shelfRenderer
//                                    los estantes del Inicio
//
//  En los resultados de busqueda los videos son "compactVideoRenderer" y en
//  los estantes "videoWithContextRenderer".
// ---------------------------------------------------------------------------

// La miniatura mas grande que traiga el nodo ({"thumbnails":[{url,width,...}]})
static NSString *YTMejorMiniaturaDeNodo(id nodo) {
    if (![nodo isKindOfClass:[NSDictionary class]]) return nil;
    id lista = ((NSDictionary *)nodo)[@"thumbnails"];
    if (![lista isKindOfClass:[NSArray class]] || [(NSArray *)lista count] == 0) return nil;
    id ultima = [(NSArray *)lista lastObject];
    if (![ultima isKindOfClass:[NSDictionary class]]) return nil;
    id url = ((NSDictionary *)ultima)[@"url"];
    return [url isKindOfClass:[NSString class]] ? url : nil;
}

// Para la portada del canal se busca la miniatura de ~1060 px de ancho: la de
// 2560 ocupa mas de 4 MB una vez descomprimida y en un telefono de 32 bits se
// nota (la de 1060 se queda en unos 700 KB y en el movil se ve igual de bien).
static NSString *YTPortadaDeNodo(id nodo) {
    if (![nodo isKindOfClass:[NSDictionary class]]) return nil;
    NSArray *lista = ((NSDictionary *)nodo)[@"thumbnails"];
    if (![lista isKindOfClass:[NSArray class]] || lista.count == 0) return nil;

    NSString *mejor = nil;
    CGFloat mejorDiferencia = CGFLOAT_MAX;
    for (id candidata in lista) {
        if (![candidata isKindOfClass:[NSDictionary class]]) continue;
        NSString *url = ((NSDictionary *)candidata)[@"url"];
        if (![url isKindOfClass:[NSString class]] || url.length == 0) continue;
        CGFloat ancho = [((NSDictionary *)candidata)[@"width"] doubleValue];
        CGFloat diferencia = fabs(ancho - 1060.0);
        if (!mejor || diferencia < mejorDiferencia) {
            mejor = url;
            mejorDiferencia = diferencia;
        }
    }
    return mejor;
}

// Un texto puede venir ya como cadena ("Alemania") o como {"runs":[...]}.
static NSString *YTCadenaOTexto(id valor) {
    if ([valor isKindOfClass:[NSString class]]) return valor;
    return YTTextoDeNodo(valor);
}

// Compara titulos sin acentos ni mayusculas ("Vídeos" == "videos").
static BOOL YTTituloContiene(NSString *texto, NSArray *agujas) {
    if (![texto isKindOfClass:[NSString class]] || texto.length == 0) return NO;
    for (NSString *aguja in agujas) {
        NSRange donde = [texto rangeOfString:aguja
                                     options:(NSCaseInsensitiveSearch |
                                              NSDiacriticInsensitiveSearch)];
        if (donde.location != NSNotFound) return YES;
    }
    return NO;
}

// Recoge videos de un JSON (probando varios sufijos de renderer) y quita los
// repetidos: en el Inicio de un canal el mismo video sale en varios estantes.
static NSArray *YTVideosDesdeRenderers(id raiz, NSArray *sufijos) {
    NSMutableArray *renderers = [NSMutableArray array];
    for (NSString *sufijo in sufijos) {
        YTRecogerRenderers(raiz, sufijo, renderers);
    }
    NSMutableArray *videos = [NSMutableArray array];
    NSMutableSet *vistos = [NSMutableSet set];
    for (id r in renderers) {
        if (![r isKindOfClass:[NSDictionary class]]) continue;
        YTVideo *video = [YTVideo desdeRenderer:r];
        if (!video) continue;
        if ([vistos containsObject:video.identificador]) continue;
        [vistos addObject:video.identificador];
        [videos addObject:video];
    }
    return videos;
}

// Un renderer de lista de reproduccion (compactPlaylistRenderer,
// gridPlaylistRenderer, playlistRenderer...) -> diccionario sencillo.
static NSDictionary *YTListaDesdeRenderer(NSDictionary *r) {
    if (![r isKindOfClass:[NSDictionary class]]) return nil;
    id ident = r[@"playlistId"];
    if (![ident isKindOfClass:[NSString class]] || [ident length] == 0) return nil;

    NSMutableDictionary *lista = [NSMutableDictionary dictionary];
    lista[@"id"] = ident;
    lista[@"titulo"] = YTCadenaOTexto(r[@"title"]) ?: @"(untitled playlist)";
    NSString *cuantos = YTCadenaOTexto(r[@"videoCountText"])
                        ?: YTCadenaOTexto(r[@"videoCountShortText"]);
    lista[@"videos"] = cuantos ?: @"";
    lista[@"canal"] = YTCadenaOTexto(r[@"shortBylineText"])
                      ?: YTCadenaOTexto(r[@"longBylineText"]) ?: @"";
    NSString *mini = YTMejorMiniaturaDeNodo(r[@"thumbnail"]);
    if (mini) lista[@"urlMiniatura"] = mini;

    // El canal de la lista, para poder entrar en el desde ella.
    NSDictionary *be = YTEncontrarPorClave(r[@"shortBylineText"], @"browseEndpoint");
    if (![be isKindOfClass:[NSDictionary class]]) {
        be = YTEncontrarPorClave(r[@"longBylineText"], @"browseEndpoint");
    }
    if ([be isKindOfClass:[NSDictionary class]] && be[@"browseId"]) {
        lista[@"canalId"] = be[@"browseId"];
    }
    return lista;
}

static NSArray *YTListasDesdeRenderers(id raiz) {
    NSMutableArray *renderers = [NSMutableArray array];
    YTRecogerRenderers(raiz, @"PlaylistRenderer", renderers);
    NSMutableArray *listas = [NSMutableArray array];
    NSMutableSet *vistos = [NSMutableSet set];
    for (id r in renderers) {
        if (![r isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *lista = YTListaDesdeRenderer(r);
        if (!lista) continue;
        if ([vistos containsObject:lista[@"id"]]) continue;
        [vistos addObject:lista[@"id"]];
        [listas addObject:lista];
    }
    return listas;
}

// Un canal de los resultados de busqueda. En el cliente de las gafas VR los
// textos vienen cambiados de sitio ("subscriberCountText" trae el manejador y
// "videoCountText" los suscriptores), asi que en vez de fiarse del nombre del
// campo se mira lo que dice cada texto.
static NSDictionary *YTCanalDesdeRenderer(NSDictionary *r) {
    if (![r isKindOfClass:[NSDictionary class]]) return nil;
    id ident = r[@"channelId"];
    if (![ident isKindOfClass:[NSString class]] || [ident length] == 0) return nil;

    NSString *subs = @"", *videos = @"", *manejador = @"";
    NSArray *textos = @[ YTCadenaOTexto(r[@"subscriberCountText"]) ?: @"",
                         YTCadenaOTexto(r[@"videoCountText"]) ?: @"" ];
    for (NSString *texto in textos) {
        if (texto.length == 0) continue;
        if ([texto hasPrefix:@"@"]) { manejador = texto; continue; }
        if ([texto rangeOfString:@"subscriber" options:NSCaseInsensitiveSearch].location
            != NSNotFound ||
            [texto rangeOfString:@"suscriptor" options:NSCaseInsensitiveSearch].location
            != NSNotFound) { subs = texto; continue; }
        if ([texto rangeOfString:@"video" options:NSCaseInsensitiveSearch].location
            != NSNotFound) { videos = texto; continue; }
        if (subs.length == 0) subs = texto;
        else if (videos.length == 0) videos = texto;
    }

    NSMutableDictionary *canal = [NSMutableDictionary dictionary];
    canal[@"id"] = ident;
    canal[@"titulo"] = YTCadenaOTexto(r[@"title"]) ?: @"(unnamed channel)";
    canal[@"suscritos"] = subs;
    canal[@"videos"] = videos;
    canal[@"manejador"] = manejador;
    canal[@"descripcion"] = YTCadenaOTexto(r[@"descriptionSnippet"]) ?: @"";
    NSString *mini = YTMejorMiniaturaDeNodo(r[@"thumbnail"]);
    if (mini) canal[@"urlMiniatura"] = mini;
    return canal;
}

// Los estantes del "Inicio" de un canal: cada uno con su titulo y sus videos.
static NSArray *YTEstantesDeVideos(NSDictionary *sectionList) {
    NSMutableArray *salida = [NSMutableArray array];
    if (![sectionList isKindOfClass:[NSDictionary class]]) return salida;
    NSArray *secciones = sectionList[@"contents"];
    if (![secciones isKindOfClass:[NSArray class]]) return salida;

    for (id seccion in secciones) {
        NSDictionary *estante = YTDiccionarioEn(seccion, @"shelfRenderer");
        if (!estante) continue;
        NSString *titulo = YTCadenaOTexto(estante[@"title"]);
        NSArray *videos = YTVideosDesdeRenderers(estante[@"content"],
                                                 @[ @"ContextRenderer", @"VideoRenderer" ]);
        if (videos.count == 0) continue;
        [salida addObject:@{ @"titulo" : titulo ?: @"", @"videos" : videos }];
    }
    return salida;
}

// La ficha de un canal: cabecera, pestanas (con sus "params") y lo que traiga
// el Inicio.
static NSDictionary *YTDatosDeCanal(NSDictionary *json, NSString *canalId) {
    NSMutableDictionary *canal = [NSMutableDictionary dictionary];
    canal[@"id"] = canalId;
    canal[@"titulo"] = @"";
    canal[@"suscritos"] = @"";
    canal[@"videos"] = @"";
    canal[@"manejador"] = @"";
    canal[@"urlAvatar"] = @"";
    canal[@"urlPortada"] = @"";
    canal[@"descripcion"] = @"";

    // --- Cabecera ---------------------------------------------------------
    // Ojo: en esta maqueta "title" es una cadena suelta ("Kurzgesagt – In a
    // Nutshell"), mientras que los demas textos son {"runs": [...]}. Por eso se
    // usa YTCadenaOTexto, que acepta las dos formas.
    NSDictionary *cab = YTEncontrarPorClave(json, @"c4TabbedHeaderRenderer");
    if (![cab isKindOfClass:[NSDictionary class]]) {
        cab = YTEncontrarPorClave(json, @"pageHeaderRenderer");
    }
    if ([cab isKindOfClass:[NSDictionary class]]) {
        canal[@"titulo"] = YTCadenaOTexto(cab[@"title"])
                           ?: YTCadenaOTexto(cab[@"pageTitle"]) ?: @"";
        canal[@"suscritos"] = YTTextoDeNodo(cab[@"subscriberCountText"]) ?: @"";
        canal[@"videos"] = YTTextoDeNodo(cab[@"videosCountText"]) ?: @"";
        canal[@"manejador"] = YTTextoDeNodo(cab[@"channelHandleText"]) ?: @"";
        NSString *avatar = YTMejorMiniaturaDeNodo(cab[@"avatar"]);
        if (avatar.length) canal[@"urlAvatar"] = avatar;
        NSString *portada = YTPortadaDeNodo(cab[@"banner"]);
        if (portada.length) canal[@"urlPortada"] = portada;
    }

    // --- Pestanas y estantes del Inicio -----------------------------------
    NSDictionary *browse = YTEncontrarPorClave(json, @"singleColumnBrowseResultsRenderer");
    NSArray *tabs = nil;
    if ([browse isKindOfClass:[NSDictionary class]]) tabs = browse[@"tabs"];
    if (![tabs isKindOfClass:[NSArray class]]) {
        id posible = YTEncontrarPorClave(json, @"tabs");
        if ([posible isKindOfClass:[NSArray class]]) tabs = posible;
    }

    NSMutableArray *pestanas = [NSMutableArray array];
    NSDictionary *contenido = nil;
    NSDictionary *primero = nil;
    for (id t in tabs) {
        NSDictionary *tab = YTDiccionarioEn(t, @"tabRenderer");
        if (!tab) continue;
        // Aqui el titulo SI es una cadena ("Inicio", "Vídeos", "Listas"...).
        NSString *titulo = YTCadenaOTexto(tab[@"title"]);
        NSDictionary *be = YTEncontrarPorClave(tab[@"endpoint"], @"browseEndpoint");
        NSString *params = [be isKindOfClass:[NSDictionary class]] ? be[@"params"] : nil;
        if (![params isKindOfClass:[NSString class]]) params = @"";

        [pestanas addObject:@{ @"titulo" : titulo ?: @"", @"params" : params }];

        if (params.length) {
            if (!canal[@"paramsVideos"] && YTTituloContiene(titulo, @[ @"video" ])) {
                canal[@"paramsVideos"] = params;
            } else if (!canal[@"paramsListas"] &&
                       YTTituloContiene(titulo, @[ @"list", @"playlist" ])) {
                canal[@"paramsListas"] = params;
            } else if (!canal[@"paramsInfo"] &&
                       YTTituloContiene(titulo, @[ @"about", @"inform", @"acerca" ])) {
                canal[@"paramsInfo"] = params;
            }
        }
        if (!primero && tab[@"content"]) primero = tab[@"content"];
        if ([tab[@"selected"] boolValue] && tab[@"content"]) contenido = tab[@"content"];
    }

    // Red de seguridad: si YouTube cambiara los titulos y no se reconociera
    // ninguno, se tira del orden de siempre (Inicio, Videos, Listas, ...).
    if (!canal[@"paramsVideos"] && !canal[@"paramsListas"] && !canal[@"paramsInfo"]
        && pestanas.count >= 3) {
        canal[@"paramsVideos"] = pestanas[1][@"params"];
        canal[@"paramsListas"] = pestanas[2][@"params"];
        if (pestanas.count >= 4) canal[@"paramsInfo"] = pestanas[3][@"params"];
    }

    canal[@"pestanas"] = pestanas;
    if (!contenido) contenido = primero;

    NSDictionary *seccionLista = YTDiccionarioEn(contenido, @"sectionListRenderer");
    if (!seccionLista) seccionLista = YTEncontrarPorClave(json, @"sectionListRenderer");
    canal[@"estantes"] = YTEstantesDeVideos(seccionLista);
    canal[@"listasDestacadas"] = YTListasDesdeRenderers(seccionLista);

    NSMutableArray *todos = [NSMutableArray array];
    NSMutableSet *vistos = [NSMutableSet set];
    for (NSDictionary *estante in canal[@"estantes"]) {
        for (YTVideo *v in estante[@"videos"]) {
            if ([vistos containsObject:v.identificador]) continue;
            [vistos addObject:v.identificador];
            [todos addObject:v];
        }
    }
    canal[@"videosDestacados"] = todos;
    return canal;
}
