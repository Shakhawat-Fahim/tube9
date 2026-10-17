// YTTheme.h -- paleta y estilos de la interfaz (diseno plano, tema oscuro)
#import <UIKit/UIKit.h>

@interface YTTheme : NSObject

// Colores
+ (UIColor *)fondo;              // fondo general
+ (UIColor *)superficie;         // tarjetas y celdas
+ (UIColor *)superficieAlta;     // campos de texto
+ (UIColor *)borde;              // separadores suaves
+ (UIColor *)acento;             // rojo de marca
+ (UIColor *)textoPrimario;
+ (UIColor *)textoSecundario;

// Helpers de dibujo
+ (UIColor *)colorHex:(NSUInteger)hex;
+ (UIImage *)imagenRedondeada:(UIImage *)imagen radio:(CGFloat)radio;

// Apariencia global
+ (void)prepararAparienciaGlobal;
+ (void)aplicarEstiloTabBar:(UITabBar *)tabBar;

@end
