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
    return [NSString stringWithFormat:@"%llu KB", bytes / 1024ULL];
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
        cfg.timeoutIntervalForRequest = 30.0;
        cfg.timeoutIntervalForResource = 3600.0;   // un video puede tardar
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

        NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:
            [NSURL URLWithString:enlace]];
        peticion.timeoutInterval = 60.0;
        NSURLSessionDownloadTask *tarea = [yo->_sesion downloadTaskWithRequest:peticion];

        NSMutableDictionary *datos = [NSMutableDictionary dictionary];
        datos[@"video"]      = video;
        datos[@"tarea"]      = tarea;
        datos[@"ruta"]       = destino;
        datos[@"hecho"]      = @NO;
        datos[@"error"]      = @"";
        if (progreso) datos[@"progreso"] = [progreso copy];
        if (completion) datos[@"completion"] = [completion copy];
        yo->_tareas[@(tarea.taskIdentifier)] = datos;

        [tarea resume];
    }];
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

    NSString *destino = datos[@"ruta"];
    NSFileManager *ficheros = [NSFileManager defaultManager];
    [ficheros removeItemAtPath:destino error:nil];   // si ya existia, se reemplaza

    NSError *error = nil;
    BOOL ok = [ficheros moveItemAtPath:ubicacion.path toPath:destino error:&error];
    datos[@"hecho"] = @(ok);
    if (!ok) {
        datos[@"error"] = error.localizedDescription ?: @"no se pudo guardar el fichero";
    }
}

- (void)URLSession:(NSURLSession *)sesion
               task:(NSURLSessionTask *)tarea
didCompleteWithError:(NSError *)error {
    NSMutableDictionary *datos = _tareas[@(tarea.taskIdentifier)];
    if (!datos) return;
    [_tareas removeObjectForKey:@(tarea.taskIdentifier)];

    YTVideo *video = datos[@"video"];
    if (video.identificador.length) [_activos removeObject:video.identificador];

    void (^completion)(BOOL, NSString *, NSString *) = datos[@"completion"];
    NSString *destino = datos[@"ruta"];

    if (error) {
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

    if (![datos[@"hecho"] boolValue]) {
        [self avisaCambio];
        if (completion) {
            NSString *motivo = datos[@"error"];
            completion(NO, [NSString stringWithFormat:@"No se pudo guardar el fichero en %@.%@",
                [YTDescargas nombreBonitoDeCarpeta:destino],
                motivo.length ? [NSString stringWithFormat:@"\n\n(%@)", motivo] : @""], nil);
        }
        return;
    }

    // Queda apuntado en el historial, para poder verlo y reproducirlo luego.
    NSDictionary *atributos = [[NSFileManager defaultManager]
        attributesOfItemAtPath:destino error:nil];
    NSNumber *tamano = atributos[NSFileSize];

    NSMutableDictionary *entrada = [NSMutableDictionary dictionary];
    entrada[@"id"]      = video.identificador ?: @"";
    entrada[@"titulo"]  = video.titulo ?: @"";
    entrada[@"canal"]   = video.canal ?: @"";
    entrada[@"mini"]    = video.urlMiniatura ?: @"";
    entrada[@"ruta"]    = destino;
    entrada[@"archivo"] = [destino lastPathComponent];
    entrada[@"bytes"]   = tamano ?: @0;
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
