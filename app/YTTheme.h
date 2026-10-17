// YTTheme.h -- paleta y estilos de la interfaz.
//
// Hay dos fondos (oscuro y claro) y, dentro de cada uno, siete colores de
// botones: catorce combinaciones en total. La idea es que "tema" no sea solo
// claro/oscuro, sino que se pueda cambiar el color de los botones sin salir
// del fondo que te gusta.
#import <UIKit/UIKit.h>

// Aviso de que el tema acaba de cambiar. Lo escucha AppDelegate, que vuelve a
// montar las pestanas: es la forma segura de repintarlo todo de una vez (si no,
// habria que repasar pantalla por pantalla).
extern NSString *const YTThemaCambio;

@interface YTTheme : NSObject

#pragma mark Elegir tema

+ (NSString *)fondoClave;        // @"oscuro" (por defecto) o @"claro"
+ (NSString *)acentoClave;       // @"rojo" (por defecto), @"azul", @"verde"...
+ (void)guardarFondo:(NSString *)fondo acento:(NSString *)acento;

// Listas para el selector, con su clave, su titulo y (los acentos) su color.
+ (NSArray *)fondosDisponibles;
+ (NSArray *)acentosDisponibles;

// El color de fondo de una opcion concreta, aunque no sea la elegida. Solo lo
// usa el selector de temas, para dibujar las muestras.
+ (UIColor *)fondoDeClave:(NSString *)clave;

// Nombre de la opcion elegida ("Oscuro", "Rojo"), para enseñarlo en Ajustes.
+ (NSString *)tituloDeFondo:(NSString *)clave;
+ (NSString *)tituloDeAcento:(NSString *)clave;

#pragma mark Colores

+ (UIColor *)fondo;              // fondo general
+ (UIColor *)superficie;         // tarjetas y celdas
+ (UIColor *)superficieAlta;     // campos de texto y "chips"
+ (UIColor *)borde;              // separadores suaves
+ (UIColor *)acento;             // color de los botones (ya ajustado al fondo)
+ (UIColor *)acentoSuave;        // relleno tenue del acento (chips activos)
+ (UIColor *)textoPrimario;
+ (UIColor *)textoSecundario;
+ (UIColor *)textoSobreAcento;   // blanco o negro, segun lo claro que sea el acento

#pragma mark Tipografia

+ (UIFont *)fuenteTituloFila;     // titulo de una fila ("Tendencias")
+ (UIFont *)fuenteTituloTarjeta;  // titulo dentro de una tarjeta pequena
+ (UIFont *)fuenteTituloLista;    // titulo de una fila grande de la lista
+ (UIFont *)fuenteCuerpo;
+ (UIFont *)fuenteMenuda;

#pragma mark Helpers de dibujo

+ (UIColor *)colorHex:(NSUInteger)hex;
+ (UIColor *)colorHex:(NSUInteger)hex alpha:(CGFloat)alpha;
+ (UIImage *)imagenRedondeada:(UIImage *)imagen radio:(CGFloat)radio;

// Iconos vectoriales dibujados al vuelo (no hacen falta ficheros de imagen).
//   Formas: inicio, tendencias, musica, buscar, ajustes, reproducir, chevron,
//           pausa, atras10, adelante10, descargar, compartir, bucle, velocidad,
//           pantalla, encoger, canal, lista, cerrar, marca
+ (UIImage *)icono:(NSString *)forma lado:(CGFloat)lado;
+ (UIImage *)icono:(NSString *)forma lado:(CGFloat)lado trazo:(CGFloat)trazo;

// Pastilla ("chip") de filtro, como las de YouTube.
+ (void)aplicarEstiloChip:(UIButton *)boton seleccionado:(BOOL)seleccionado;

#pragma mark Apariencia global

+ (void)prepararAparienciaGlobal;
+ (void)aplicarEstiloTabBar:(UITabBar *)tabBar;

@end
