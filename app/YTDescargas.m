// YTDescargas.m -- descarga el MP4 (360p, itag 18) que resuelve YTClient.
#import "YTDescargas.h"
#import "YTClient.h"

NSString *const YTDescargasCambio = @"YTDescargasCambio";

static NSString * const kDefCarpeta   = @"tube9_descargas_carpeta";
static NSString * const kDefHistorial = @"tube9_descargas_historial";

// Caracteres que no valen en un nombre de fichero.
static NSCharacterSet *YTCaracteresProhibidos(void) {
    static NSCharacterSet *prohibidos = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        prohibidos = [NSCharacterSet characterSetWithCharactersInString:
                      @"\\/:*?\"<>|\n\r\t"];
    });
    return prohibidos;
}

static NSString *YTNombreDeArchivo(NSString *titulo, NSString *videoId) {
    NSString *base = titulo.length ? titulo : @"video";
    NSMutableString *limpio = [NSMutableString string];
    for (NSUInteger i = 0; i < base.length && limpio.length < 70; i++) {
        unichar c = [base characterAtIndex:i];
        if ([YTCaracteresProhibidos() characterIsMember:c]) {
            [limpio appendString:@"-"];
            continue;
        }
        [limpio appendFormat:@"%C", c];
    }
    // Nada de espacios ni puntos al final: algunos sistemas se atragantan.
    while (limpio.length &&
           ([limpio hasSuffix:@" "] || [limpio hasSuffix:@"."])) {
        [limpio deleteCharactersInRange:NSMakeRange(limpio.length - 1, 1)];
    }
    if (limpio.length == 0) limpio = [NSMutableString stringWithString:@"video"];
    return [NSString stringWithFormat:@"%@ [%@].mp4", limpio, videoId];
}

static NSString *YTTamanoLegible(unsigned long long bytes) {
    if (bytes >= 1024ULL * 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
    }
    if (bytes >= 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    }
    if (bytes >= 1024ULL) {
        return [NSString stringWithFormat:@"%llu KB", bytes / 1024ULL];
    }
    // Menos de un KB se dice en bytes. Un fichero de 2 bytes se veia como
    // "0 KB" y parecia una descarga vacia; dicho asi se entiende al instante.
    return [NSString stringWithFormat:@"%llu bytes", bytes];
}

@interface YTDescargas () <NSURLSessionDownloadDelegate>
@end

@implementation YTDescargas {
    NSURLSession *_sesion;
    NSMutableDictionary *_tareas;   // @(taskIdentifier) -> datos de la descarga
    NSMutableSet *_activos;         // videoId que se estan descargando
}

+ (instancetype)compartido {
    static YTDescargas *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{ instancia = [[YTDescargas alloc] init]; });
    return instancia;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *cfg =
            [NSURLSessionConfiguration defaultSessionConfiguration];
        // Sin cache, ni en memoria ni en disco. Ojo con esto: YTClient comprueba
        // que el enlace sirve pidiendo dos bytes ("Range: bytes=0-1"), y esa
        // respuesta parcial de 2 bytes se queda en la cache compartida. Si la
        // descarga mirase ahi, guardaria un fichero de 2 bytes (que luego se
        // veia como "0 KB"). Con una cache de cero bytes eso no puede pasar.
        cfg.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:0
                                                     diskCapacity:0
                                                         diskPath:nil];
        cfg.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        cfg.timeoutIntervalForRequest = 60.0;
        cfg.timeoutIntervalForResource = 7200.0;   // un video puede tardar
        // Cola principal: asi los avisos de progreso llegan ya listos para
        // tocar la interfaz y no hace falta proteger nada con candados.
        _sesion = [NSURLSession sessionWithConfiguration:cfg
                                                delegate:self
                                           delegateQueue:[NSOperationQueue mainQueue]];
        _tareas = [NSMutableDictionary dictionary];
        _activos = [NSMutableSet set];
    }
    return self;
}

#pragma mark - Carpeta

+ (NSString *)carpetaPorDefecto {
    NSString *documentos = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (documentos.length == 0) documentos = NSTemporaryDirectory();
    NSString *carpeta = [documentos stringByAppendingPathComponent:@"Descargas"];
    [[NSFileManager defaultManager] createDirectoryAtPath:carpeta
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return carpeta;
}

+ (NSString *)carpeta {
    NSString *guardada = [[NSUserDefaults standardUserDefaults] stringForKey:kDefCarpeta];
    if (guardada.length && [self sePuedeEscribirEn:guardada]) return guardada;
    return [self carpetaPorDefecto];
}

+ (void)guardarCarpeta:(NSString *)ruta {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (ruta.length) [d setObject:ruta forKey:kDefCarpeta];
    else [d removeObjectForKey:kDefCarpeta];
    [d synchronize];
}

+ (BOOL)sePuedeEscribirEn:(NSString *)ruta {
    if (ruta.length == 0) return NO;
    BOOL esCarpeta = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:ruta isDirectory:&esCarpeta]) {
        return NO;
    }
    if (!esCarpeta) return NO;

    NSString *prueba = [ruta stringByAppendingPathComponent:@".tube9_prueba"];
    NSData *datos = [@"prueba" dataUsingEncoding:NSUTF8StringEncoding];
    if (![datos writeToFile:prueba atomically:YES]) return NO;
    [[NSFileManager defaultManager] removeItemAtPath:prueba error:nil];
    return YES;
}

+ (NSString *)nombreBonitoDeCarpeta:(NSString *)ruta {
    if (ruta.length == 0) return @"(sin carpeta)";
    NSString *inicio = NSHomeDirectory();
    // La parte de contenedor es larguisima ("/var/mobile/Containers/Data/
    // Application/<UUID>/"): se recorta para que quepa en una celda.
    NSRange rango = [ruta rangeOfString:@"/Application/"];
    if (rango.location != NSNotFound) {
        NSString *resto = [ruta substringFromIndex:NSMaxRange(rango)];
        NSRange barra = [resto rangeOfString:@"/"];
        if (barra.location != NSNotFound) {
            resto = [resto substringFromIndex:NSMaxRange(barra)];
        }
        return [NSString stringWithFormat:@".../%@", resto];
    }
    if (inicio.length && [ruta hasPrefix:inicio]) {
        return [NSString stringWithFormat:@"~%@", [ruta substringFromIndex:inicio.length]];
    }
    if (ruta.length > 44) {
        return [NSString stringWithFormat:@"...%@", [ruta substringFromIndex:ruta.length - 41]];
    }
    return ruta;
}

- (unsigned long long)espacioLibre {
    NSDictionary *datos = [[NSFileManager defaultManager]
        attributesOfFileSystemForPath:[YTDescargas carpeta] error:nil];
    id libre = datos[NSFileSystemFreeSize];
    return [libre isKindOfClass:[NSNumber class]] ? [libre unsignedLongLongValue] : 0;
}

#pragma mark - Historial

- (NSArray *)historial {
    id guardado = [[NSUserDefaults standardUserDefaults] arrayForKey:kDefHistorial];
    if (![guardado isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray *salida = [NSMutableArray array];
    for (NSDictionary *entrada in guardado) {
        if (![entrada isKindOfClass:[NSDictionary class]]) continue;
        NSString *ruta = entrada[@"ruta"];
        if (ruta.length == 0) continue;
        // Si el fichero ya no esta (lo borro Filza, por ejemplo), no se lista.
        if (![[NSFileManager defaultManager] fileExistsAtPath:ruta]) continue;
        [salida addObject:entrada];
    }
    return salida;
}

- (void)guardarHistorial:(NSArray *)historial {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (historial.count) [d setObject:historial forKey:kDefHistorial];
    else [d removeObjectForKey:kDefHistorial];
    [d synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:YTDescargasCambio object:nil];
}

- (BOOL)estaDescargando:(NSString *)videoId {
    return videoId.length ? [_activos containsObject:videoId] : NO;
}

#pragma mark - Descargar

- (void)descargarVideo:(YTVideo *)video
              progreso:(void (^)(double fraccion))progreso
            completion:(void (^)(BOOL ok, NSString *mensaje, NSString *ruta))completion {
    if (video.identificador.length == 0) {
        if (completion) completion(NO, @"El video no tiene identificador.", nil);
        return;
    }
    if ([self estaDescargando:video.identificador]) {
        if (completion) completion(NO, @"Ese video ya se esta descargando.", nil);
        return;
    }

    NSString *carpeta = [YTDescargas carpeta];
    if (![YTDescargas sePuedeEscribirEn:carpeta]) {
        if (completion) {
            completion(NO, [NSString stringWithFormat:
                @"No se puede escribir en %@.\n\nElige otra carpeta en Ajustes > "
                @"Descargas, o borra lo que sobre: quedan %@ libres.",
                carpeta, YTTamanoLegible([self espacioLibre])], nil);
        }
        return;
    }

    [_activos addObject:video.identificador];
    [[NSNotificationCenter defaultCenter] postNotificationName:YTDescargasCambio object:nil];

    __weak YTDescargas *deb = self;
    [[YTClient compartido] resolverVideo:video.identificador
        completion:^(NSDictionary *info, NSError *error) {

        YTDescargas *yo = deb;
        if (!yo) return;

        NSString *enlace = info[@"url"];
        if (error || enlace.length == 0) {
            [yo->_activos removeObject:video.identificador];
            [[NSNotificationCenter defaultCenter] postNotificationName:YTDescargasCambio object:nil];
            if (completion) {
                completion(NO, [NSString stringWithFormat:@"No se pudo preparar el video: %@",
                    [YTClient explicarError:error] ?: @"YouTube no devolvio una direccion"], nil);
            }
            return;
        }

        // El titulo y el canal del reproductor mandan: son los de verdad.
        if ([(NSString *)info[@"titulo"] length]) video.titulo = info[@"titulo"];
        if ([(NSString *)info[@"autor"] length]) video.canal = info[@"autor"];
        if (video.urlMiniatura.length == 0) {
            video.urlMiniatura = [NSString stringWithFormat:
                @"https://i.ytimg.com/vi/%@/mqdefault.jpg", video.identificador];
        }

        NSString *destino = [carpeta stringByAppendingPathComponent:
            YTNombreDeArchivo(video.titulo, video.identificador)];

        NSMutableDictionary *datos = [NSMutableDictionary dictionary];
        datos[@"video"]    = video;
        datos[@"enlace"]   = enlace;
        datos[@"ruta"]     = destino;
        // Cuanto deberia pesar, segun YouTube. Sirve para darse cuenta de que
        // la descarga se ha quedado corta (un fichero de 2 bytes, por ejemplo).
        datos[@"esperado"] = info[@"bytes"] ?: @0;
        datos[@"intento"]  = @0;
        if (progreso) datos[@"progreso"] = [progreso copy];
        if (completion) datos[@"completion"] = [completion copy];

        [yo lanzarDescarga:datos];
    }];
}

// Crea la tarea de descarga. La primera vez se pide "desde el byte 0 hasta el
// final" (Range: bytes=0-), que devuelve 206 con el fichero entero: asi la
// respuesta no se puede confundir con la sonda de 2 bytes de la cache.
- (void)lanzarDescarga:(NSDictionary *)datos {
    NSURL *url = [NSURL URLWithString:datos[@"enlace"]];
    if (!url) {
        [self fallar:datos motivo:@"La direccion del video no es valida."];
        return;
    }
    BOOL conRango = ([datos[@"intento"] integerValue] == 0);

    NSMutableURLRequest *peticion = [NSMutableURLRequest
        requestWithURL:url
           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
       timeoutInterval:60.0];
    if (conRango) [peticion setValue:@"bytes=0-" forHTTPHeaderField:@"Range"];

    NSURLSessionDownloadTask *tarea = [_sesion downloadTaskWithRequest:peticion];

    NSMutableDictionary *d = [datos mutableCopy];
    d[@"tarea"] = tarea;
    d[@"hecho"] = @NO;
    d[@"error"] = @"";
    d[@"rango"] = @(conRango);
    _tareas[@(tarea.taskIdentifier)] = d;
    [tarea resume];
}

// Un final que no es el normal: se quita el video de "activos" y se avisa.
- (void)fallar:(NSDictionary *)datos motivo:(NSString *)motivo {
    YTVideo *video = datos[@"video"];
    if (video.identificador.length) [_activos removeObject:video.identificador];
    [self avisaCambio];
    void (^completion)(BOOL, NSString *, NSString *) = datos[@"completion"];
    if (completion) completion(NO, motivo, nil);
}

- (void)cancelarVideo:(NSString *)videoId {
    for (NSNumber *clave in [_tareas allKeys]) {
        NSDictionary *datos = _tareas[clave];
        YTVideo *video = datos[@"video"];
        if ([video.identificador isEqualToString:videoId]) {
            NSURLSessionDownloadTask *tarea = datos[@"tarea"];
            [tarea cancel];
            return;
        }
    }
}

- (void)borrarEntrada:(NSDictionary *)entrada {
    NSString *ruta = entrada[@"ruta"];
    if (ruta.length) [[NSFileManager defaultManager] removeItemAtPath:ruta error:nil];

    NSMutableArray *resto = [NSMutableArray array];
    for (NSDictionary *otra in [self historial]) {
        if ([otra[@"ruta"] isEqualToString:ruta]) continue;
        [resto addObject:otra];
    }
    [self guardarHistorial:resto];
}

- (void)borrarTodo {
    for (NSDictionary *entrada in [self historial]) {
        NSString *ruta = entrada[@"ruta"];
        if (ruta.length) [[NSFileManager defaultManager] removeItemAtPath:ruta error:nil];
    }
    [self guardarHistorial:@[]];
}

#pragma mark - Avisos de la sesion de descarga

- (void)URLSession:(NSURLSession *)sesion
      downloadTask:(NSURLSessionDownloadTask *)tarea
      didWriteData:(int64_t)bytesEscritos
 totalBytesWritten:(int64_t)escritos
totalBytesExpectedToWrite:(int64_t)esperados {
    NSDictionary *datos = _tareas[@(tarea.taskIdentifier)];
    if (!datos) return;
    void (^progreso)(double) = datos[@"progreso"];
    if (!progreso) return;
    double fraccion = esperados > 0 ? (double)escritos / (double)esperados : 0.0;
    progreso(fraccion);
}

- (void)URLSession:(NSURLSession *)sesion
      downloadTask:(NSURLSessionDownloadTask *)tarea
didFinishDownloadingToURL:(NSURL *)ubicacion {
    NSMutableDictionary *datos = _tareas[@(tarea.taskIdentifier)];
    if (!datos) return;

    // Un 403 (o la pagina de aviso de YouTube) tambien llega aqui como
    // "descarga terminada", con el cuerpo del error dentro. Solo 200 y 206 son
    // un video de verdad; cualquier otra cosa se rechaza antes de guardarla.
    NSInteger codigo = 0;
    if ([tarea.response isKindOfClass:[NSHTTPURLResponse class]]) {
        codigo = ((NSHTTPURLResponse *)tarea.response).statusCode;
    }
    datos[@"http"] = @(codigo);
    if (codigo != 200 && codigo != 206) {
        datos[@"error"] = [NSString stringWithFormat:
            @"YouTube ha contestado HTTP %ld al pedir el video.", (long)codigo];
        return;
    }

    // Cuanto deberia pesar. Normalmente lo dice la propia respuesta; si no,
    // se usa el dato que dio YouTube al resolver el video.
    long long declarado = [tarea.response expectedContentLength];
    if (declarado <= 0) declarado = [datos[@"esperado"] longLongValue];

    NSString *destino = datos[@"ruta"];
    NSFileManager *ficheros = [NSFileManager defaultManager];
    [ficheros removeItemAtPath:destino error:nil];   // si ya existia, se reemplaza

    NSError *error = nil;
    BOOL ok = [ficheros moveItemAtPath:ubicacion.path toPath:destino error:&error];
    datos[@"hecho"] = @(ok);
    if (!ok) {
        datos[@"error"] = error.localizedDescription ?: @"no se pudo guardar el fichero";
        return;
    }

    // Y, por si acaso, se comprueba que lo guardado pesa lo que debe. Un
    // fichero de 2 bytes (la respuesta de la sonda) ya no cuela como exito.
    NSDictionary *atributos = [ficheros attributesOfItemAtPath:destino error:nil];
    unsigned long long tamano = [atributos[NSFileSize] unsignedLongLongValue];
    datos[@"tamanoReal"] = @(tamano);
    if (tamano == 0) {
        datos[@"error"] = @"La descarga llego vacia (0 bytes).";
    } else if (declarado > 1024 && tamano + 1024 < (unsigned long long)declarado) {
        datos[@"error"] = [NSString stringWithFormat:@"La descarga se quedo corta: %@ de %@.",
                           YTTamanoLegible(tamano), YTTamanoLegible((unsigned long long)declarado)];
    }
}

- (void)URLSession:(NSURLSession *)sesion
               task:(NSURLSessionTask *)tarea
didCompleteWithError:(NSError *)error {
    NSMutableDictionary *datos = _tareas[@(tarea.taskIdentifier)];
    if (!datos) return;
    [_tareas removeObjectForKey:@(tarea.taskIdentifier)];

    YTVideo *video = datos[@"video"];
    void (^completion)(BOOL, NSString *, NSString *) = datos[@"completion"];

    if (error) {
        if (video.identificador.length) [_activos removeObject:video.identificador];
        [self avisaCambio];
        if (completion) {
            if (error.code == NSURLErrorCancelled) {
                completion(NO, @"Descarga cancelada.", nil);
            } else {
                completion(NO, [NSString stringWithFormat:@"La descarga fallo: %@",
                    [YTClient explicarError:error]], nil);
            }
        }
        return;
    }

    NSString *fallo = datos[@"error"];
    if ([fallo length]) {
        // Segundo intento, esta vez sin la cabecera Range. Si el primero se
        // quedo corto o vino vacio (una respuesta parcial cacheada, un 403
        // disfrazado), por aqui suele resolverse.
        if ([datos[@"intento"] integerValue] == 0) {
            NSString *ruta = datos[@"ruta"];
            if (ruta.length) [[NSFileManager defaultManager] removeItemAtPath:ruta error:nil];
            NSMutableDictionary *otra = [datos mutableCopy];
            otra[@"intento"] = @1;
            otra[@"error"] = @"";
            [self lanzarDescarga:otra];
            return;
        }
        [self fallar:datos motivo:[NSString stringWithFormat:
            @"No se pudo guardar el video en %@.\n\n(%@)",
            [YTDescargas nombreBonitoDeCarpeta:datos[@"ruta"]], fallo]];
        return;
    }

    if (![datos[@"hecho"] boolValue]) {
        [self fallar:datos motivo:[NSString stringWithFormat:
            @"No se pudo guardar el fichero en %@.",
            [YTDescargas nombreBonitoDeCarpeta:datos[@"ruta"]]]];
        return;
    }

    if (video.identificador.length) [_activos removeObject:video.identificador];

    // Queda apuntado en el historial, para poder verlo y reproducirlo luego.
    NSString *destino = datos[@"ruta"];
    NSDictionary *atributos = [[NSFileManager defaultManager]
        attributesOfItemAtPath:destino error:nil];
    NSNumber *tamano = atributos[NSFileSize] ?: @0;

    NSMutableDictionary *entrada = [NSMutableDictionary dictionary];
    entrada[@"id"]      = video.identificador ?: @"";
    entrada[@"titulo"]  = video.titulo ?: @"";
    entrada[@"canal"]   = video.canal ?: @"";
    entrada[@"mini"]    = video.urlMiniatura ?: @"";
    entrada[@"ruta"]    = destino;
    entrada[@"archivo"] = [destino lastPathComponent];
    entrada[@"bytes"]   = tamano;
    entrada[@"fecha"]   = @([[NSDate date] timeIntervalSince1970]);

    NSMutableArray *historial = [[self historial] mutableCopy];
    NSMutableArray *limpio = [NSMutableArray arrayWithObject:entrada];
    for (NSDictionary *otra in historial) {
        if ([otra[@"ruta"] isEqualToString:destino]) continue;
        [limpio addObject:otra];
    }
    [self guardarHistorial:limpio];

    if (completion) {
        completion(YES, [NSString stringWithFormat:@"%@\n\nGuardado en %@ (%@)",
            video.titulo ?: @"Video",
            [YTDescargas nombreBonitoDeCarpeta:[destino stringByDeletingLastPathComponent]],
            YTTamanoLegible([tamano unsignedLongLongValue])], destino);
    }
}

// El historial cambio (empezó, termino o se borro algo).
- (void)avisaCambio {
    [[NSNotificationCenter defaultCenter] postNotificationName:YTDescargasCambio object:nil];
}

@end
