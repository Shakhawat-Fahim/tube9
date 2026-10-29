// v1.0-en 2026-10-29: English UI build (textos traducidos al ingles; hl=en, gl=US)
// YTTheme.m
#import "YTTheme.h"

NSString *const YTThemaCambio = @"YTThemaCambio";

static NSString * const kDefFondo  = @"tube9_tema_fondo";
static NSString * const kDefAcento = @"tube9_tema_acento";

// Paleta ya construida, para no rehacer colores en cada celda (en un iPhone de
// 32 bits eso se nota). Se rehace sola cuando cambia el tema.
static NSDictionary *sPaleta = nil;
static NSString *sPaletaClave = nil;

#pragma mark - Tablas de temas

// Colores de cada fondo. Los nombres son los de siempre para no liarla.
static NSDictionary *YTPaletaBase(NSString *clave) {
    if ([clave isEqualToString:@"claro"]) {
        return @{ @"fondo"   : @0xFFFFFF,
                  @"sup"     : @0xF6F6F6,
                  @"alta"    : @0xE9E9E9,
                  @"borde"   : @0xD8D8D8,
                  @"texto"   : @0x0F0F0F,
                  @"texto2"  : @0x5F5F5F };
    }
    return @{ @"fondo"   : @0x0F0F0F,
              @"sup"     : @0x181818,
              @"alta"    : @0x272727,
              @"borde"   : @0x303030,
              @"texto"   : @0xF1F1F1,
              @"texto2"  : @0xAAAAAA };
}

static NSArray *YTTablaAcentos(void) {
    static NSArray *lista = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        lista = @[
            @{ @"clave" : @"rojo",     @"titulo" : @"Red",     @"hex" : @0xFF0033 },
            @{ @"clave" : @"azul",     @"titulo" : @"Blue",     @"hex" : @0x1A73E8 },
            @{ @"clave" : @"verde",    @"titulo" : @"Green",    @"hex" : @0x1FA34A },
            @{ @"clave" : @"morado",   @"titulo" : @"Purple",   @"hex" : @0x7C4DFF },
            @{ @"clave" : @"turquesa", @"titulo" : @"Teal", @"hex" : @0x00A6A6 },
            @{ @"clave" : @"ambar",    @"titulo" : @"Amber",    @"hex" : @0xFFAB00 },
            @{ @"clave" : @"rosa",     @"titulo" : @"Pink",     @"hex" : @0xE91E8C }
        ];
    });
    return lista;
}

// 0 cuando la clave no existe (ningun acento de la tabla es 0x000000).
static NSUInteger YTHexDeAcento(NSString *clave) {
    if (clave.length == 0) return 0;
    for (NSDictionary *a in YTTablaAcentos()) {
        if ([a[@"clave"] isEqualToString:clave]) {
            return [a[@"hex"] unsignedIntegerValue];
        }
    }
    return 0;
}

// Lo claro que es un color (0 = negro, 1 = blanco). Sirve para decidir si un
// texto va en negro o en blanco encima.
static CGFloat YTLuminancia(UIColor *color) {
    CGFloat r = 0.0, g = 0.0, b = 0.0, a = 1.0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return 0.0;
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

// El mismo color, pero moviendo el brillo lo justo para que se lea sobre el
// fondo elegido. Sin esto, el ambar sobre blanco es ilegible y el azul sobre
// negro se queda apagado.
static UIColor *YTAcentoAjustado(NSUInteger hex, BOOL claro) {
    UIColor *base = [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                                    green:((hex >> 8) & 0xFF) / 255.0
                                     blue:(hex & 0xFF) / 255.0
                                    alpha:1.0];
    CGFloat h = 0.0, s = 1.0, b = 1.0, a = 1.0;
    if (![base getHue:&h saturation:&s brightness:&b alpha:&a]) return base;

    if (claro) {
        while (b > 0.30 &&
               YTLuminancia([UIColor colorWithHue:h saturation:s brightness:b alpha:1.0]) > 0.34) {
            b -= 0.02;
        }
        s = MIN(1.0, s + 0.06);   // al oscurecer se apaga: se compensa
    } else {
        while (b < 1.0 &&
               YTLuminancia([UIColor colorWithHue:h saturation:s brightness:b alpha:1.0]) < 0.20) {
            b += 0.02;
        }
    }
    return [UIColor colorWithHue:h saturation:s brightness:b alpha:1.0];
}

@implementation YTTheme

#pragma mark - Elegir tema

+ (NSString *)fondoClave {
    NSString *valor = [[NSUserDefaults standardUserDefaults] stringForKey:kDefFondo];
    return [valor isEqualToString:@"claro"] ? @"claro" : @"oscuro";
}

+ (NSString *)acentoClave {
    NSString *valor = [[NSUserDefaults standardUserDefaults] stringForKey:kDefAcento];
    return YTHexDeAcento(valor) ? valor : @"rojo";
}

+ (void)guardarFondo:(NSString *)fondo acento:(NSString *)acento {
    NSUserDefaults *ajustes = [NSUserDefaults standardUserDefaults];
    if (fondo.length) [ajustes setObject:fondo forKey:kDefFondo];
    if (acento.length) [ajustes setObject:acento forKey:kDefAcento];
    [ajustes synchronize];

    sPaleta = nil;        // se rehace en cuanto se pida el primer color
    sPaletaClave = nil;
    [self prepararAparienciaGlobal];
    [[NSNotificationCenter defaultCenter] postNotificationName:YTThemaCambio object:nil];
}

+ (NSArray *)fondosDisponibles {
    return @[
        @{ @"clave" : @"oscuro", @"titulo" : @"Dark",
           @"detalle" : @"The classic one, like YouTube at night" },
        @{ @"clave" : @"claro",  @"titulo" : @"Light",
           @"detalle" : @"White background, for bright sunlight" }
    ];
}

+ (NSArray *)acentosDisponibles {
    BOOL claro = [[self fondoClave] isEqualToString:@"claro"];
    NSMutableArray *salida = [NSMutableArray array];
    for (NSDictionary *a in YTTablaAcentos()) {
        NSUInteger hex = [a[@"hex"] unsignedIntegerValue];
        [salida addObject:@{ @"clave"  : a[@"clave"],
                             @"titulo" : a[@"titulo"],
                             @"color"  : YTAcentoAjustado(hex, claro) }];
    }
    return salida;
}

+ (UIColor *)fondoDeClave:(NSString *)clave {
    NSDictionary *base = YTPaletaBase([clave isEqualToString:@"claro"] ? @"claro" : @"oscuro");
    return [self colorHex:[base[@"fondo"] unsignedIntegerValue]];
}

+ (NSString *)tituloDeFondo:(NSString *)clave {
    for (NSDictionary *f in [self fondosDisponibles]) {
        if ([f[@"clave"] isEqualToString:clave]) return f[@"titulo"];
    }
    return @"Dark";
}

+ (NSString *)tituloDeAcento:(NSString *)clave {
    for (NSDictionary *a in YTTablaAcentos()) {
        if ([a[@"clave"] isEqualToString:clave]) return a[@"titulo"];
    }
    return @"Red";
}

#pragma mark - Paleta

+ (NSDictionary *)paleta {
    NSString *clave = [NSString stringWithFormat:@"%@|%@", [self fondoClave], [self acentoClave]];
    if (sPaleta && sPaletaClave && [sPaletaClave isEqualToString:clave]) return sPaleta;

    BOOL claro = [[self fondoClave] isEqualToString:@"claro"];
    NSDictionary *base = YTPaletaBase([self fondoClave]);
    UIColor *acento = YTAcentoAjustado(YTHexDeAcento([self acentoClave]), claro);

    sPaleta = @{
        @"fondo"    : [self colorHex:[base[@"fondo"] unsignedIntegerValue]],
        @"sup"      : [self colorHex:[base[@"sup"] unsignedIntegerValue]],
        @"alta"     : [self colorHex:[base[@"alta"] unsignedIntegerValue]],
        @"borde"    : [self colorHex:[base[@"borde"] unsignedIntegerValue]],
        @"texto"    : [self colorHex:[base[@"texto"] unsignedIntegerValue]],
        @"texto2"   : [self colorHex:[base[@"texto2"] unsignedIntegerValue]],
        @"acento"   : acento,
        @"suave"    : [acento colorWithAlphaComponent:0.16],
        @"sobreAcc" : YTLuminancia(acento) > 0.58 ? [self colorHex:0x101010]
                                                  : [UIColor whiteColor]
    };
    sPaletaClave = clave;
    return sPaleta;
}

#pragma mark - Colores

+ (UIColor *)colorHex:(NSUInteger)hex {
    return [self colorHex:hex alpha:1.0];
}

+ (UIColor *)colorHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:alpha];
}

+ (UIColor *)fondo            { return [self paleta][@"fondo"]; }
+ (UIColor *)superficie       { return [self paleta][@"sup"]; }
+ (UIColor *)superficieAlta   { return [self paleta][@"alta"]; }
+ (UIColor *)borde            { return [self paleta][@"borde"]; }
+ (UIColor *)acento           { return [self paleta][@"acento"]; }
+ (UIColor *)acentoSuave      { return [self paleta][@"suave"]; }
+ (UIColor *)textoPrimario    { return [self paleta][@"texto"]; }
+ (UIColor *)textoSecundario  { return [self paleta][@"texto2"]; }
+ (UIColor *)textoSobreAcento { return [self paleta][@"sobreAcc"]; }

#pragma mark - Tipografia

+ (UIFont *)fuenteTituloFila {
    return [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
}
+ (UIFont *)fuenteTituloTarjeta {
    return [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
}
+ (UIFont *)fuenteTituloLista {
    return [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
}
+ (UIFont *)fuenteCuerpo {
    return [UIFont systemFontOfSize:12.5];
}
+ (UIFont *)fuenteMenuda {
    return [UIFont systemFontOfSize:11.5];
}

#pragma mark - Imagenes

+ (UIImage *)imagenRedondeada:(UIImage *)imagen radio:(CGFloat)radio {
    if (!imagen) return nil;
    CGRect marco = CGRectMake(0, 0, imagen.size.width, imagen.size.height);
    UIGraphicsBeginImageContextWithOptions(imagen.size, NO, imagen.scale);
    [[UIBezierPath bezierPathWithRoundedRect:marco cornerRadius:radio] addClip];
    [imagen drawInRect:marco];
    UIImage *resultado = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultado;
}

+ (UIImage *)icono:(NSString *)forma lado:(CGFloat)lado {
    return [self icono:forma lado:lado trazo:MAX(1.6, lado * 0.082)];
}

// Dibuja un icono vectorial. Se devuelve como plantilla para que herede el
// color del sitio donde se use (barra de pestanas, boton, etc.).
+ (UIImage *)icono:(NSString *)forma lado:(CGFloat)lado trazo:(CGFloat)trazo {
    CGFloat L = lado;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(L, L), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, trazo);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    if ([forma isEqualToString:@"inicio"]) {
        // Tejado y cuerpo de la casa.
        CGContextMoveToPoint(ctx, 0.13 * L, 0.48 * L);
        CGContextAddLineToPoint(ctx, 0.50 * L, 0.16 * L);
        CGContextAddLineToPoint(ctx, 0.87 * L, 0.48 * L);
        CGContextStrokePath(ctx);

        CGContextMoveToPoint(ctx, 0.25 * L, 0.45 * L);
        CGContextAddLineToPoint(ctx, 0.25 * L, 0.84 * L);
        CGContextAddLineToPoint(ctx, 0.75 * L, 0.84 * L);
        CGContextAddLineToPoint(ctx, 0.75 * L, 0.45 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"tendencias"]) {
        // Grafica ascendente con punta de flecha.
        CGContextMoveToPoint(ctx, 0.12 * L, 0.74 * L);
        CGContextAddLineToPoint(ctx, 0.38 * L, 0.47 * L);
        CGContextAddLineToPoint(ctx, 0.56 * L, 0.63 * L);
        CGContextAddLineToPoint(ctx, 0.85 * L, 0.31 * L);
        CGContextStrokePath(ctx);

        CGContextMoveToPoint(ctx, 0.64 * L, 0.31 * L);
        CGContextAddLineToPoint(ctx, 0.85 * L, 0.31 * L);
        CGContextAddLineToPoint(ctx, 0.85 * L, 0.52 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"musica"]) {
        // Corchea: cabeza, plica y banderola.
        CGContextStrokeEllipseInRect(ctx, CGRectMake(0.22 * L, 0.60 * L, 0.32 * L, 0.26 * L));
        CGContextMoveToPoint(ctx, 0.54 * L, 0.73 * L);
        CGContextAddLineToPoint(ctx, 0.54 * L, 0.16 * L);
        CGContextAddQuadCurveToPoint(ctx, 0.86 * L, 0.19 * L, 0.79 * L, 0.45 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"buscar"]) {
        CGFloat d = L * 0.56;
        CGRect circulo = CGRectMake(0.15 * L, 0.15 * L, d, d);
        CGContextStrokeEllipseInRect(ctx, circulo);
        CGContextMoveToPoint(ctx, CGRectGetMaxX(circulo) - 0.07 * L,
                                   CGRectGetMaxY(circulo) - 0.07 * L);
        CGContextAddLineToPoint(ctx, 0.86 * L, 0.86 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"ajustes"]) {
        // Tres controles deslizantes (el icono clasico de ajustes).
        CGFloat posiciones[3] = { 0.68, 0.36, 0.58 };
        for (int i = 0; i < 3; i++) {
            CGFloat y = (0.26 + 0.24 * i) * L;
            CGContextMoveToPoint(ctx, 0.16 * L, y);
            CGContextAddLineToPoint(ctx, 0.84 * L, y);
            CGContextStrokePath(ctx);

            CGFloat x = posiciones[i] * L;
            CGContextFillEllipseInRect(ctx, CGRectMake(x - 0.095 * L, y - 0.095 * L,
                                                       0.19 * L, 0.19 * L));
        }

    } else if ([forma isEqualToString:@"reproducir"]) {
        CGContextMoveToPoint(ctx, 0.30 * L, 0.18 * L);
        CGContextAddLineToPoint(ctx, 0.30 * L, 0.82 * L);
        CGContextAddLineToPoint(ctx, 0.82 * L, 0.50 * L);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);

    } else if ([forma isEqualToString:@"chevron"]) {
        CGContextMoveToPoint(ctx, 0.38 * L, 0.22 * L);
        CGContextAddLineToPoint(ctx, 0.64 * L, 0.50 * L);
        CGContextAddLineToPoint(ctx, 0.38 * L, 0.78 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"marca"]) {
        // Triangulo de "play" dentro de una pastilla: la marca de Tube9.
        CGRect caja = CGRectMake(0.10 * L, 0.22 * L, 0.80 * L, 0.56 * L);
        CGContextAddPath(ctx, [UIBezierPath bezierPathWithRoundedRect:caja
                                                         cornerRadius:0.16 * L].CGPath);
        CGContextFillPath(ctx);
        CGContextSetBlendMode(ctx, kCGBlendModeClear);
        CGContextMoveToPoint(ctx, 0.42 * L, 0.36 * L);
        CGContextAddLineToPoint(ctx, 0.42 * L, 0.64 * L);
        CGContextAddLineToPoint(ctx, 0.64 * L, 0.50 * L);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        CGContextSetBlendMode(ctx, kCGBlendModeNormal);

    } else if ([forma isEqualToString:@"pausa"]) {
        // Dos barras, como el boton de pausa de cualquier reproductor.
        CGFloat arriba = 0.24 * L, abajo = 0.76 * L, grueso = 0.13 * L;
        CGContextFillRect(ctx, CGRectMake(0.30 * L, arriba, grueso, abajo - arriba));
        CGContextFillRect(ctx, CGRectMake(0.57 * L, arriba, grueso, abajo - arriba));

    } else if ([forma isEqualToString:@"atras10"] || [forma isEqualToString:@"adelante10"]) {
        // Flecha circular con un "10" dentro: los tipicos 10 segundos.
        BOOL atras = [forma isEqualToString:@"atras10"];
        CGFloat cx = 0.5 * L, cy = 0.52 * L, radio = 0.29 * L;
        CGFloat a0 = -1.25, a1 = 1.95;   // deja el hueco arriba, para la punta
        CGContextSetLineWidth(ctx, trazo);

        CGContextSaveGState(ctx);
        if (atras) {   // la misma flecha, del reves
            CGContextTranslateCTM(ctx, L, 0.0);
            CGContextScaleCTM(ctx, -1.0, 1.0);
        }
        CGContextAddArc(ctx, cx, cy, radio, a0, a1, 0);
        CGContextStrokePath(ctx);

        // Punta de flecha en el extremo inicial del arco.
        CGFloat px = cx + radio * cosf(a0), py = cy + radio * sinf(a0);
        CGFloat dx = -sinf(a0), dy = cosf(a0);
        CGFloat p = 0.085 * L;
        CGContextMoveToPoint(ctx, px + dx * p, py + dy * p);
        CGContextAddLineToPoint(ctx, px - dy * p, py + dx * p);
        CGContextAddLineToPoint(ctx, px + dy * p, py - dx * p);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        CGContextRestoreGState(ctx);

        // El "10", fuera del volteo para que no salga del reves.
        NSDictionary *estilo = @{
            NSFontAttributeName : [UIFont systemFontOfSize:0.36 * L weight:UIFontWeightBold],
            NSForegroundColorAttributeName : [UIColor whiteColor]
        };
        CGSize midiendo = [@"10" sizeWithAttributes:estilo];
        [@"10" drawAtPoint:CGPointMake(cx - midiendo.width / 2.0,
                                       cy - midiendo.height / 2.0)
            withAttributes:estilo];

    } else if ([forma isEqualToString:@"descargar"]) {
        // Flecha hacia abajo y bandeja que la recoge.
        CGContextSetLineWidth(ctx, trazo);
        CGContextMoveToPoint(ctx, 0.5 * L, 0.16 * L);
        CGContextAddLineToPoint(ctx, 0.5 * L, 0.54 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.33 * L, 0.38 * L);
        CGContextAddLineToPoint(ctx, 0.5 * L, 0.56 * L);
        CGContextAddLineToPoint(ctx, 0.67 * L, 0.38 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.22 * L, 0.62 * L);
        CGContextAddLineToPoint(ctx, 0.22 * L, 0.82 * L);
        CGContextAddLineToPoint(ctx, 0.78 * L, 0.82 * L);
        CGContextAddLineToPoint(ctx, 0.78 * L, 0.62 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"compartir"]) {
        // La caja con la flecha saliendo por arriba, como en iOS.
        CGContextSetLineWidth(ctx, trazo);
        CGContextMoveToPoint(ctx, 0.5 * L, 0.60 * L);
        CGContextAddLineToPoint(ctx, 0.5 * L, 0.18 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.35 * L, 0.33 * L);
        CGContextAddLineToPoint(ctx, 0.5 * L, 0.18 * L);
        CGContextAddLineToPoint(ctx, 0.65 * L, 0.33 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.26 * L, 0.46 * L);
        CGContextAddLineToPoint(ctx, 0.26 * L, 0.84 * L);
        CGContextAddLineToPoint(ctx, 0.74 * L, 0.84 * L);
        CGContextAddLineToPoint(ctx, 0.74 * L, 0.46 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"bucle"]) {
        // Dos flechas dandose la vuelta: repetir.
        CGContextSetLineWidth(ctx, trazo);
        CGContextMoveToPoint(ctx, 0.24 * L, 0.34 * L);
        CGContextAddLineToPoint(ctx, 0.70 * L, 0.34 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.58 * L, 0.23 * L);
        CGContextAddLineToPoint(ctx, 0.74 * L, 0.34 * L);
        CGContextAddLineToPoint(ctx, 0.58 * L, 0.45 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.76 * L, 0.66 * L);
        CGContextAddLineToPoint(ctx, 0.30 * L, 0.66 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.42 * L, 0.55 * L);
        CGContextAddLineToPoint(ctx, 0.26 * L, 0.66 * L);
        CGContextAddLineToPoint(ctx, 0.42 * L, 0.77 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"velocidad"]) {
        // Un velocimetro: media vuelta y aguja.
        CGContextSetLineWidth(ctx, trazo);
        CGFloat cx = 0.5 * L, cy = 0.62 * L, radio = 0.32 * L;
        CGContextAddArc(ctx, cx, cy, radio, M_PI, 2.0 * M_PI, 0);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, cx, cy);
        CGContextAddLineToPoint(ctx, cx + 0.19 * L, cy - 0.23 * L);
        CGContextStrokePath(ctx);
        CGContextFillEllipseInRect(ctx, CGRectMake(cx - 0.06 * L, cy - 0.06 * L,
                                                   0.12 * L, 0.12 * L));

    } else if ([forma isEqualToString:@"pantalla"]) {
        // Cuatro esquinas mirando hacia fuera: agrandar.
        CGContextSetLineWidth(ctx, trazo);
        CGContextMoveToPoint(ctx, 0.16 * L, 0.34 * L);
        CGContextAddLineToPoint(ctx, 0.16 * L, 0.16 * L);
        CGContextAddLineToPoint(ctx, 0.34 * L, 0.16 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.66 * L, 0.16 * L);
        CGContextAddLineToPoint(ctx, 0.84 * L, 0.16 * L);
        CGContextAddLineToPoint(ctx, 0.84 * L, 0.34 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.84 * L, 0.66 * L);
        CGContextAddLineToPoint(ctx, 0.84 * L, 0.84 * L);
        CGContextAddLineToPoint(ctx, 0.66 * L, 0.84 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.34 * L, 0.84 * L);
        CGContextAddLineToPoint(ctx, 0.16 * L, 0.84 * L);
        CGContextAddLineToPoint(ctx, 0.16 * L, 0.66 * L);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"encoger"]) {
        // Lo mismo, pero mirando hacia dentro: volver al tamano normal.
        CGContextSetLineWidth(ctx, trazo);
        CGFloat esquinas[4][2] = { { 0.16, 0.16 }, { 0.84, 0.16 }, { 0.84, 0.84 }, { 0.16, 0.84 } };
        for (int i = 0; i < 4; i++) {
            CGFloat ex = esquinas[i][0] * L, ey = esquinas[i][1] * L;
            CGFloat ix = 0.5 * L + (ex - 0.5 * L) * 0.55;
            CGFloat iy = 0.5 * L + (ey - 0.5 * L) * 0.55;
            CGContextMoveToPoint(ctx, ex, ey);
            CGContextAddLineToPoint(ctx, ix, iy);
            CGContextStrokePath(ctx);
            // Punta hacia el centro.
            CGFloat dx = ix - ex, dy = iy - ey;
            CGFloat largo = sqrtf(dx * dx + dy * dy);
            if (largo < 1.0) continue;
            dx /= largo; dy /= largo;
            CGFloat p = 0.10 * L;
            CGContextMoveToPoint(ctx, ix, iy);
            CGContextAddLineToPoint(ctx, ix - dx * p - dy * p, iy - dy * p + dx * p);
            CGContextAddLineToPoint(ctx, ix - dx * p + dy * p, iy - dy * p - dx * p);
            CGContextClosePath(ctx);
            CGContextFillPath(ctx);
        }

    } else if ([forma isEqualToString:@"canal"]) {
        // Una persona: cabeza y hombros.
        CGContextSetLineWidth(ctx, trazo);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(0.34 * L, 0.14 * L, 0.32 * L, 0.32 * L));
        CGContextAddArc(ctx, 0.5 * L, 0.88 * L, 0.30 * L, M_PI, 2.0 * M_PI, 0);
        CGContextStrokePath(ctx);

    } else if ([forma isEqualToString:@"lista"]) {
        // Tres rayas y una flecha de reproducir: una lista de reproduccion.
        CGContextSetLineWidth(ctx, trazo);
        for (int i = 0; i < 3; i++) {
            CGFloat y = (0.26 + 0.22 * i) * L;
            CGContextMoveToPoint(ctx, 0.14 * L, y);
            CGContextAddLineToPoint(ctx, 0.58 * L, y);
            CGContextStrokePath(ctx);
        }
        CGContextMoveToPoint(ctx, 0.72 * L, 0.62 * L);
        CGContextAddLineToPoint(ctx, 0.72 * L, 0.84 * L);
        CGContextAddLineToPoint(ctx, 0.90 * L, 0.73 * L);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);

    } else if ([forma isEqualToString:@"cerrar"]) {
        CGContextSetLineWidth(ctx, trazo);
        CGContextMoveToPoint(ctx, 0.26 * L, 0.26 * L);
        CGContextAddLineToPoint(ctx, 0.74 * L, 0.74 * L);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 0.74 * L, 0.26 * L);
        CGContextAddLineToPoint(ctx, 0.26 * L, 0.74 * L);
        CGContextStrokePath(ctx);
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark - Chips

+ (void)aplicarEstiloChip:(UIButton *)boton seleccionado:(BOOL)seleccionado {
    boton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [boton setTitleColor:(seleccionado ? [self textoSobreAcento] : [self textoPrimario])
                forState:UIControlStateNormal];
    boton.backgroundColor = seleccionado ? [self acento] : [self superficieAlta];
    boton.layer.cornerRadius = 15.0;   // la mitad del alto estandar (30)
    boton.layer.masksToBounds = YES;
    boton.layer.borderWidth = seleccionado ? 0.0 : 1.0;
    boton.layer.borderColor = [self borde].CGColor;
}

#pragma mark - Apariencia global

+ (void)prepararAparienciaGlobal {
    BOOL claro = [[self fondoClave] isEqualToString:@"claro"];

    UINavigationBar *nav = [UINavigationBar appearance];
    nav.barTintColor = [self fondo];
    nav.tintColor = [self acento];            // botones y flecha de volver
    nav.translucent = NO;
    nav.titleTextAttributes = @{
        NSForegroundColorAttributeName : [self textoPrimario],
        NSFontAttributeName : [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
    };

    // La barra de estado tambien cambia: oscura sobre fondo claro.
    [[UIApplication sharedApplication] setStatusBarStyle:
        claro ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent];

    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName : [self textoSecundario]
    } forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName : [self acento]
    } forState:UIControlStateSelected];

    UITableView *tv = [UITableView appearance];
    tv.backgroundColor = [self fondo];
    tv.separatorColor = [self borde];

    // Las alertas heredan el color de los botones.
    [UIView appearance].tintColor = [self acento];
}

+ (void)aplicarEstiloTabBar:(UITabBar *)tabBar {
    tabBar.barTintColor = [self superficie];
    tabBar.tintColor = [self acento];   // pestana elegida
    tabBar.translucent = NO;
    tabBar.backgroundColor = [self superficie];

    // Los iconos de TYTheme se dibujan en modo "plantilla", asi que la propia
    // barra los pinta: el elegido con el acento y el resto en gris. Al
    // principio se tintaban a mano y quedaban invisibles (se usaba SourceIn
    // sobre un lienzo vacio, que no deja nada); asi, ademas, es lo nativo.
    for (UITabBarItem *item in tabBar.items) {
        if (item.image) {
            item.image = [item.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        if (item.selectedImage) {
            item.selectedImage = [item.selectedImage
                imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
}

@end
