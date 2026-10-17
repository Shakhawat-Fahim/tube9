// YTProgreso.m -- por donde iba cada video, guardado en NSUserDefaults.
//
// No hace falta cuenta ni red: es una lista local de los ultimos videos vistos
// con el minuto exacto en el que se dejo cada uno. Con eso se rellena el primer
// estante de Inicio y el reproductor reanuda solo.
#import "YTProgreso.h"

static NSString * const kClaveProgreso = @"tube9_progreso";
static const NSUInteger kMaximoEntradas = 60;
static const NSUInteger kMaximoContinuarViendo = 12;
static const double kMinimoParaGuardar = 5.0;    // segundos
static const double kMargenDelFinal = 10.0;      // segundos

@implementation YTProgreso

+ (NSMutableArray *)entradas {
    id guardado = [[NSUserDefaults standardUserDefaults] arrayForKey:kClaveProgreso];
    if ([guardado isKindOfClass:[NSArray class]]) return [guardado mutableCopy];
    return [NSMutableArray array];
}

+ (void)guardarEntradas:(NSArray *)entradas {
    NSArray *recortada = entradas;
    if (recortada.count > kMaximoEntradas) {
        recortada = [recortada subarrayWithRange:NSMakeRange(0, kMaximoEntradas)];
    }
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (recortada.count) {
        [d setObject:recortada forKey:kClaveProgreso];
    } else {
        [d removeObjectForKey:kClaveProgreso];
    }
    [d synchronize];
}

+ (NSDictionary *)entradaDe:(NSString *)videoId {
    if (videoId.length == 0) return nil;
    for (NSDictionary *entrada in [self entradas]) {
        if ([entrada isKindOfClass:[NSDictionary class]] &&
            [entrada[@"id"] isEqualToString:videoId]) {
            return entrada;
        }
    }
    return nil;
}

+ (void)guardarVideo:(YTVideo *)video segundos:(double)segundos total:(double)total {
    NSString *identificador = video.identificador;
    if (identificador.length == 0) return;

    if (total > 0.0 && segundos >= total - kMargenDelFinal) {
        // Visto hasta el final: se quita de la lista.
        [self olvidar:identificador];
        return;
    }
    if (segundos < kMinimoParaGuardar) return;

    NSMutableDictionary *entrada = [NSMutableDictionary dictionary];
    entrada[@"id"]     = identificador;
    entrada[@"titulo"] = video.titulo ?: @"";
    entrada[@"canal"]  = video.canal ?: @"";
    entrada[@"mini"]   = video.urlMiniatura ?: @"";
    entrada[@"seg"]    = @(segundos);
    entrada[@"total"]  = @(total);
    entrada[@"fecha"]  = @([[NSDate date] timeIntervalSince1970]);

    NSMutableArray *lista = [self entradas];
    NSMutableArray *limpia = [NSMutableArray array];
    for (NSDictionary *vieja in lista) {
        if (![vieja isKindOfClass:[NSDictionary class]]) continue;
        if ([vieja[@"id"] isEqualToString:identificador]) continue;
        [limpia addObject:vieja];
    }
    [limpia insertObject:entrada atIndex:0];
    [self guardarEntradas:limpia];
}

+ (double)segundosDe:(NSString *)videoId {
    NSDictionary *entrada = [self entradaDe:videoId];
    id valor = entrada[@"seg"];
    return [valor isKindOfClass:[NSNumber class]] ? [valor doubleValue] : 0.0;
}

+ (double)totalDe:(NSString *)videoId {
    NSDictionary *entrada = [self entradaDe:videoId];
    id valor = entrada[@"total"];
    return [valor isKindOfClass:[NSNumber class]] ? [valor doubleValue] : 0.0;
}

+ (void)olvidar:(NSString *)videoId {
    if (videoId.length == 0) return;
    NSMutableArray *limpia = [NSMutableArray array];
    for (NSDictionary *entrada in [self entradas]) {
        if (![entrada isKindOfClass:[NSDictionary class]]) continue;
        if ([entrada[@"id"] isEqualToString:videoId]) continue;
        [limpia addObject:entrada];
    }
    [self guardarEntradas:limpia];
}

+ (NSArray *)continuarViendo {
    NSMutableArray *salida = [NSMutableArray array];
    for (NSDictionary *entrada in [self entradas]) {
        if (![entrada isKindOfClass:[NSDictionary class]]) continue;
        id seg = entrada[@"seg"];
        if (![seg isKindOfClass:[NSNumber class]] || [seg doubleValue] < kMinimoParaGuardar) continue;

        YTVideo *video = [[YTVideo alloc] init];
        video.identificador = entrada[@"id"];
        video.titulo = entrada[@"titulo"];
        video.urlMiniatura = entrada[@"mini"];
        if (video.identificador.length == 0) continue;
        if (video.titulo.length == 0) video.titulo = @"(sin titulo)";

        // En el subtitulo se ve por donde iba, que es lo util aqui.
        double segundos = [seg doubleValue];
        double total = [self totalDe:video.identificador];
        NSString *canal = entrada[@"canal"];
        NSString *minuto = [NSString stringWithFormat:@"%d:%02d",
                            (int)(segundos / 60.0), (int)segundos % 60];
        NSMutableArray *partes = [NSMutableArray array];
        if (canal.length) [partes addObject:canal];
        [partes addObject:[NSString stringWithFormat:@"vas por %@", minuto]];
        if (total > 0.0) {
            [partes addObject:[NSString stringWithFormat:@"de %d:%02d",
                               (int)(total / 60.0), (int)total % 60]];
        }
        video.canal = [partes componentsJoinedByString:@"  ·  "];

        [salida addObject:video];
        if (salida.count >= kMaximoContinuarViendo) break;
    }
    return salida;
}

+ (void)vaciar {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kClaveProgreso];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
