// YTTheme.m
#import "YTTheme.h"

@implementation YTTheme

+ (UIColor *)colorHex:(NSUInteger)hex {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

+ (UIColor *)fondo            { return [self colorHex:0x0F1115]; }
+ (UIColor *)superficie       { return [self colorHex:0x171A21]; }
+ (UIColor *)superficieAlta   { return [self colorHex:0x1F2430]; }
+ (UIColor *)borde            { return [self colorHex:0x262B36]; }
+ (UIColor *)acento           { return [self colorHex:0xFF0033]; }
+ (UIColor *)textoPrimario    { return [self colorHex:0xF1F3F4]; }
+ (UIColor *)textoSecundario  { return [self colorHex:0x9AA0A6]; }

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

+ (void)prepararAparienciaGlobal {
    UINavigationBar *nav = [UINavigationBar appearance];
    nav.barTintColor = [self fondo];
    nav.tintColor = [self acento];
    nav.translucent = NO;
    nav.titleTextAttributes = @{
        NSForegroundColorAttributeName : [self textoPrimario],
        NSFontAttributeName : [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
    };

    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName : [self textoSecundario]
    } forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName : [self acento]
    } forState:UIControlStateSelected];

    UITableView *tv = [UITableView appearance];
    tv.backgroundColor = [self fondo];
    tv.separatorColor = [self borde];
}

+ (void)aplicarEstiloTabBar:(UITabBar *)tabBar {
    tabBar.barTintColor = [self superficie];
    tabBar.tintColor = [self acento];
    tabBar.translucent = NO;
    tabBar.backgroundColor = [self superficie];
}

@end
