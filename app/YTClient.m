// YTClient.m -- habla con YouTube (InnerTube) o con el relay
#import "YTClient.h"

// --- Constantes de YouTube ------------------------------------------------
// ANDROID_VR es hoy el cliente que todavia entrega URLs directas de MP4
// muxado (itag 18, 360p con audio) sin obligar a descifrar la firma "nsig".
static NSString * const kClaveAPI   = @"AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w";
static NSString * const kBaseYT     = @"https://www.youtube.com/youtubei/v1";
static NSString * const kClienteYT  = @"ANDROID_VR";
static NSString * const kVersionYT  = @"1.60.19";
static NSString * const kAgenteYT   =
    @"com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12; en_US) gzip";

// Claves de NSUserDefaults
static NSString * const kDefModo  = @"tube9_modo";
static NSString * const kDefRelay = @"tube9_relay";
static NSString * const kDefToken = @"tube9_token";

static NSCache *sCacheMiniaturas = nil;

// Declarada al final del fichero; hace falta el prototipo aqui.
void YTRecogerRenderers(id nodo, NSString *sufijo, NSMutableArray *salida);

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
            sCacheMiniaturas.countLimit = 220;
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

+ (NSString *)clienteYT { return kClienteYT; }

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
    NSDictionary *cuerpo = @{
        @"query" : limpia,
        @"context" : @{ @"client" : [self contextoDeCliente] }
    };
    [self enviarAlInnerTube:@"search" cuerpo:cuerpo completion:^(NSDictionary *json, NSError *error) {
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
    NSDictionary *cuerpo = @{
        @"videoId" : videoId,
        @"contentCheckOk" : @YES,
        @"racyCheckOk" : @YES,
        @"context" : @{ @"client" : [self contextoDeCliente] }
    };
    [self enviarAlInnerTube:@"player" cuerpo:cuerpo completion:^(NSDictionary *json, NSError *error) {
        if (error) { completion(nil, error); return; }

        NSDictionary *estado = json[@"playabilityStatus"];
        NSString *nombreEstado = estado[@"status"];
        if (![nombreEstado isEqualToString:@"OK"]) {
            NSString *motivo = estado[@"reason"] ?: nombreEstado ?: @"desconocido";
            NSString *ayuda = @"Vuelve a intentarlo o inicia sesion desde Ajustes.";
            if ([nombreEstado isEqualToString:@"LOGIN_REQUIRED"]) {
                ayuda = @"YouTube pide iniciar sesion. Entra en Ajustes > Iniciar sesion en YouTube.";
            }
            completion(nil, [NSError errorWithDomain:@"tube9" code:6 userInfo:@{
                NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@  %@", motivo, ayuda]}]);
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
            completion(nil, [NSError errorWithDomain:@"tube9" code:7 userInfo:@{
                NSLocalizedDescriptionKey :
                    @"YouTube no devolvio un formato reproducible para este video."}]);
            return;
        }

        NSDictionary *detalles = json[@"videoDetails"];
        completion(@{ @"url" : elegido[@"url"],
                      @"titulo" : detalles[@"title"] ?: @"",
                      @"autor" : detalles[@"author"] ?: @"" }, nil);
    }];
}

#pragma mark - InnerTube

- (NSDictionary *)contextoDeCliente {
    return @{
        @"clientName" : kClienteYT,
        @"clientVersion" : kVersionYT,
        @"androidSdkVersion" : @32,
        @"hl" : @"es",
        @"gl" : @"ES"
    };
}

- (void)enviarAlInnerTube:(NSString *)ruta
                   cuerpo:(NSDictionary *)cuerpo
               completion:(void (^)(NSDictionary *json, NSError *error))completion {
    NSString *direccion = [NSString stringWithFormat:@"%@/%@?key=%@&prettyPrint=false",
                           kBaseYT, ruta, kClaveAPI];
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:direccion]];
    peticion.HTTPMethod = @"POST";
    peticion.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [peticion setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [peticion setValue:kAgenteYT forHTTPHeaderField:@"User-Agent"];
    [peticion setValue:@"es-ES,es;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    NSString *manuales = [YTClient cookiesManuales];
    if (manuales.length) [peticion setValue:manuales forHTTPHeaderField:@"Cookie"];
    peticion.HTTPBody = [NSJSONSerialization dataWithJSONObject:cuerpo options:0 error:nil];

    [[self.sesion dataTaskWithRequest:peticion
                            completionHandler:^(NSData *datos, NSURLResponse *respuesta,
                                                NSError *error) {
        if (error) { YTEnPrincipal(^{ completion(nil, error); }); return; }
        NSError *jsonError = nil;
        id objeto = [NSJSONSerialization JSONObjectWithData:datos options:0 error:&jsonError];
        if (![objeto isKindOfClass:[NSDictionary class]]) {
            YTEnPrincipal(^{
                completion(nil, jsonError ?: [NSError errorWithDomain:@"tube9" code:8
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
    [informe appendFormat:@"Cliente: %@\n", kClienteYT];
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
                [informe appendString:@"\nSi aparece LOGIN_REQUIRED, inicia sesion en Ajustes."];
                completion(informe);
                return;
            }
            NSURL *url = [NSURL URLWithString:enlace];
            [informe appendFormat:@"   OK  URL obtenida en %.1f s\n", segundos];
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

+ (void)cargarMiniatura:(NSString *)url
             completion:(void (^)(UIImage *imagen))completion {
    if (url.length == 0) { completion(nil); return; }

    UIImage *guardada = [sCacheMiniaturas objectForKey:url];
    if (guardada) { completion(guardada); return; }

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest = 20.0;
    NSURLSession *sesion = [NSURLSession sessionWithConfiguration:cfg];

    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [peticion setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 9_3_5 like Mac OS X)"
        forHTTPHeaderField:@"User-Agent"];

    [[sesion dataTaskWithRequest:peticion
               completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        UIImage *imagen = datos.length ? [UIImage imageWithData:datos] : nil;
        if (imagen) [sCacheMiniaturas setObject:imagen forKey:url];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(imagen); });
    }] resume];
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
