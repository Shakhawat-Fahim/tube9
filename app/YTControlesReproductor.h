// YTControlesReproductor.h -- los mandos que van encima del video.
//
// Es lo que sale al tocar la imagen: el boton grande de reproducir en el
// centro, los de "10 segundos" a los lados y, abajo, la barra de progreso con
// los tiempos y los botones de velocidad, bucle, descarga, compartir y pantalla
// completa. La clase solo PINTA: quien decide que hace cada boton es la
// pantalla del reproductor (YTPlayerViewController), a traves del delegado.
#import <UIKit/UIKit.h>

@protocol YTControlesDelegado <NSObject>

- (void)controlesAlternarReproduccion;
- (void)controlesSaltarSegundos:(double)segundos;
- (void)controlesBuscarA:(double)segundos;   // al soltar la barra de progreso
- (void)controlesTocarVelocidad;
- (void)controlesTocarBucle;
- (void)controlesTocarDescargar;
- (void)controlesTocarCompartir;
- (void)controlesTocarPantallaCompleta;

@end

@interface YTControlesReproductor : UIView

@property (nonatomic, weak) id<YTControlesDelegado> delegado;

#pragma mark Estado (lo pinta quien manda)
@property (nonatomic, assign) BOOL bucle;
@property (nonatomic, assign) float velocidad;
@property (nonatomic, assign) BOOL pantallaCompleta;
@property (nonatomic, assign) BOOL descargando;

// Se llama muchas veces por segundo: actualiza la barra y el reloj.
- (void)actualizarConActual:(double)actual
                      total:(double)total
             reproduciendo:(BOOL)reproduciendo;

// Porcentaje de descarga (0..1) para el boton de descargar.
- (void)actualizarPorcentajeDescarga:(double)fraccion;

// Se enseña o se esconde (con el video andando se esconde solo).
- (void)mostrar:(BOOL)mostrar animado:(BOOL)animado;

@end
