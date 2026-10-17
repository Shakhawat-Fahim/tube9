// YTVideo.m
#import "YTVideo.h"

// YouTube mezcla {"simpleText": "..."} y {"runs": [{"text": "..."}]}
static NSString *YTTexto(NSDictionary *nodo) {
    if (![nodo isKindOfClass:[NSDictionary class]]) return nil;
    NSString *simple = nodo[@"simpleText"];
    if ([simple isKindOfClass:[NSString class]]) return simple;
    NSArray *runs = nodo[@"runs"];
    if ([runs isKindOfClass:[NSArray class]] && runs.count > 0) {
        NSMutableString *union = [NSMutableString string];
        for (NSDictionary *r in runs) {
            NSString *t = r[@"text"];
            if ([t isKindOfClass:[NSString class]]) [union appendString:t];
        }
        return union.length ? union : nil;
    }
    return nil;
}

@implementation YTVideo

+ (instancetype)desdeRelay:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    YTVideo *v = [[YTVideo alloc] init];
    v.identificador = d[@"id"];
    v.titulo        = d[@"titulo"];
    v.canal         = d[@"canal"];
    v.duracion      = d[@"duracion"];
    v.vistas        = d[@"vistas"];
    v.publicado     = d[@"publicado"];
    v.urlMiniatura  = d[@"miniatura"];
    if (!v.identificador) return nil;
    if (!v.titulo) v.titulo = @"(sin titulo)";
    return v;
}

+ (instancetype)desdeRenderer:(NSDictionary *)r {
    if (![r isKindOfClass:[NSDictionary class]]) return nil;
    NSString *vid = r[@"videoId"];
    if (![vid isKindOfClass:[NSString class]] || vid.length == 0) return nil;

    YTVideo *v = [[YTVideo alloc] init];
    v.identificador = vid;
    v.titulo    = YTTexto(r[@"title"]) ?: @"(sin titulo)";
    v.canal     = YTTexto(r[@"shortBylineText"]) ?: YTTexto(r[@"longBylineText"]);
    v.duracion  = YTTexto(r[@"lengthText"]);
    v.vistas    = YTTexto(r[@"shortViewCountText"]) ?: YTTexto(r[@"viewCountText"]);
    v.publicado = YTTexto(r[@"publishedTimeText"]);

    NSDictionary *mini = r[@"thumbnail"];
    NSArray *lista = [mini isKindOfClass:[NSDictionary class]] ? mini[@"thumbnails"] : nil;
    if ([lista isKindOfClass:[NSArray class]] && lista.count > 0) {
        v.urlMiniatura = lista.lastObject[@"url"];
    }
    if (!v.urlMiniatura) {
        v.urlMiniatura = [NSString stringWithFormat:
            @"https://i.ytimg.com/vi/%@/mqdefault.jpg", vid];
    }
    return v;
}

+ (NSArray *)listaDesdeRelay:(NSArray *)arreglo {
    NSMutableArray *salida = [NSMutableArray array];
    if ([arreglo isKindOfClass:[NSArray class]]) {
        for (NSDictionary *d in arreglo) {
            YTVideo *v = [YTVideo desdeRelay:d];
            if (v) [salida addObject:v];
        }
    }
    return salida;
}

- (NSString *)descripcion {
    NSMutableArray *partes = [NSMutableArray array];
    if (self.canal.length) [partes addObject:self.canal];
    if (self.vistas.length) [partes addObject:self.vistas];
    if (self.publicado.length) [partes addObject:self.publicado];
    return [partes componentsJoinedByString:@"  ·  "];
}

@end
