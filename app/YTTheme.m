// YTTheme.m
#import "YTTheme.h"

@implementation YTTheme

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

// La paleta sigue el tema oscuro de YouTube (casi negro, sin azules).
+ (UIColor *)fondo            { return [self colorHex:0x0F0F0F]; }
+ (UIColor *)superficie       { return [self colorHex:0x181818]; }
+ (UIColor *)superficieAlta   { return [self colorHex:0x272727]; }
+ (UIColor *)borde            { return [self colorHex:0x303030]; }
+ (UIColor *)acento           { return [self colorHex:0xFF0033]; }
+ (UIColor *)acentoSuave      { return [self colorHex:0xFF0033 alpha:0.18]; }
+ (UIColor *)textoPrimario    { return [self colorHex:0xF1F1F1]; }
+ (UIColor *)textoSecundario  { return [self colorHex:0xAAAAAA]; }

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
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark - Chips

+ (void)aplicarEstiloChip:(UIButton *)boton seleccionado:(BOOL)seleccionado {
    boton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [boton setTitleColor:(seleccionado ? [UIColor whiteColor] : [self textoPrimario])
                forState:UIControlStateNormal];
    boton.backgroundColor = seleccionado ? [self acento] : [self superficieAlta];
    boton.layer.cornerRadius = 15.0;   // la mitad del alto estandar (30)
    boton.layer.masksToBounds = YES;
    boton.layer.borderWidth = seleccionado ? 0.0 : 1.0;
    boton.layer.borderColor = [self borde].CGColor;
}

#pragma mark - Apariencia global

+ (void)prepararAparienciaGlobal {
    UINavigationBar *nav = [UINavigationBar appearance];
    nav.barTintColor = [self fondo];
    nav.tintColor = [self textoPrimario];
    nav.translucent = NO;
    nav.titleTextAttributes = @{
        NSForegroundColorAttributeName : [self textoPrimario],
        NSFontAttributeName : [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
    };

    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName : [self textoSecundario]
    } forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName : [self textoPrimario]
    } forState:UIControlStateSelected];

    UITableView *tv = [UITableView appearance];
    tv.backgroundColor = [self fondo];
    tv.separatorColor = [self borde];
}

+ (void)aplicarEstiloTabBar:(UITabBar *)tabBar {
    tabBar.barTintColor = [self superficie];
    tabBar.tintColor = [self textoPrimario];
    tabBar.translucent = NO;
    tabBar.backgroundColor = [self superficie];
}

@end
