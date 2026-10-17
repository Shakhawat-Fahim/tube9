// YTTheme.h -- paleta y estilos de la interfaz (diseno plano, tema oscuro)
#import <UIKit/UIKit.h>

@interface YTTheme : NSObject

// --- Colores --------------------------------------------------------------
+ (UIColor *)fondo;              // fondo general
+ (UIColor *)superficie;         // tarjetas y celdas
+ (UIColor *)superficieAlta;     // campos de texto y "chips"
+ (UIColor *)borde;              // separadores suaves
+ (UIColor *)acento;             // rojo de marca
+ (UIColor *)acentoSuave;        // relleno tenue del acento (chips activos)
+ (UIColor *)textoPrimario;
+ (UIColor *)textoSecundario;

// --- Tipografia -----------------------------------------------------------
+ (UIFont *)fuenteTituloFila;     // titulo de una fila ("Tendencias")
+ (UIFont *)fuenteTituloTarjeta;  // titulo dentro de una tarjeta pequena
+ (UIFont *)fuenteTituloLista;    // titulo de una fila grande de la lista
+ (UIFont *)fuenteCuerpo;
+ (UIFont *)fuenteMenuda;

// --- Helpers de dibujo ----------------------------------------------------
+ (UIColor *)colorHex:(NSUInteger)hex;
+ (UIColor *)colorHex:(NSUInteger)hex alpha:(CGFloat)alpha;
+ (UIImage *)imagenRedondeada:(UIImage *)imagen radio:(CGFloat)radio;

// Iconos vectoriales dibujados al vuelo (no hacen falta ficheros de imagen).
//   Formas: inicio, tendencias, musica, buscar, ajustes, reproducir, chevron
+ (UIImage *)icono:(NSString *)forma lado:(CGFloat)lado;
+ (UIImage *)icono:(NSString *)forma lado:(CGFloat)lado trazo:(CGFloat)trazo;

// Pastilla ("chip") de filtro, como las de YouTube.
+ (void)aplicarEstiloChip:(UIButton *)boton seleccionado:(BOOL)seleccionado;

// --- Apariencia global ----------------------------------------------------
+ (void)prepararAparienciaGlobal;
+ (void)aplicarEstiloTabBar:(UITabBar *)tabBar;

@end
