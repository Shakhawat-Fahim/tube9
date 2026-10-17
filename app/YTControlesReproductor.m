// YTControlesReproductor.m -- mandos del reproductor.
//
// Todos los iconos se dibujan al vuelo con YTTheme, asi que no hace falta ni un
// fichero de imagen y el color de los botones sale del tema (blanco sobre el
// video; el acento cuando algo esta activo, como el bucle).
#import "YTControlesReproductor.h"
#import "YTTheme.h"
#import <QuartzCore/QuartzCore.h>

// 3725 -> "1:02:05"; 65 -> "1:05"
static NSString *YTTextoDeTiempo(double segundos) {
    if (isnan(segundos) || segundos < 0.0) return @"0:00";
    long total = (long)segundos;
    long horas = total / 3600;
    long minutos = (total % 3600) / 60;
    long segs = total % 60;
    if (horas > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", horas, minutos, segs];
    }
    return [NSString stringWithFormat:@"%ld:%02ld", minutos, segs];
}

@implementation YTControlesReproductor {
    CAGradientLayer *_degradado;   // sombreado para que se lean los iconos
    UIButton *_botonAtras;
    UIButton *_botonReproducir;
    UIButton *_botonAdelante;
    UILabel *_etiquetaActual;
    UILabel *_etiquetaTotal;
    UISlider *_deslizador;
    UIButton *_botonVelocidad;
    UIButton *_botonBucle;
    UIButton *_botonDescargar;
    UIButton *_botonCompartir;
    UIButton *_botonPantalla;

    BOOL _arrastrando;
    BOOL _visible;
    BOOL _pintandoPausa;
}

#pragma mark - Arranque

- (instancetype)initWithFrame:(CGRect)marco {
    self = [super initWithFrame:marco];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _velocidad = 1.0f;
        _visible = YES;

        _degradado = [CAGradientLayer layer];
        _degradado.colors = @[ (id)[UIColor colorWithWhite:0.0 alpha:0.55].CGColor,
                               (id)[UIColor colorWithWhite:0.0 alpha:0.04].CGColor,
                               (id)[UIColor colorWithWhite:0.0 alpha:0.68].CGColor ];
        _degradado.locations = @[ @0.0, @0.45, @1.0 ];
        [self.layer insertSublayer:_degradado atIndex:0];

        // --- Centro: 10 segundos atras, reproducir/pausa, 10 segundos adelante
        _botonAtras    = [self botonIcono:@"atras10"    lado:26.0 accion:@selector(tocarAtras)];
        _botonAdelante = [self botonIcono:@"adelante10" lado:26.0 accion:@selector(tocarAdelante)];
        _botonReproducir = [self botonIcono:@"pausa" lado:30.0 accion:@selector(tocarReproducir)];
        _botonReproducir.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.42];
        _botonReproducir.layer.cornerRadius = 28.0;

        // --- Abajo: tiempos y barra de progreso
        _etiquetaActual = [self etiquetaDeTiempo];
        _etiquetaTotal  = [self etiquetaDeTiempo];
        _etiquetaTotal.textAlignment = NSTextAlignmentRight;

        _deslizador = [[UISlider alloc] init];
        _deslizador.minimumValue = 0.0;
        _deslizador.maximumValue = 1.0;
        _deslizador.minimumTrackTintColor = [YTTheme acento];
        _deslizador.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.32];
        _deslizador.thumbTintColor = [YTTheme acento];
        [_deslizador addTarget:self action:@selector(empezarArrastre)
              forControlEvents:UIControlEventTouchDown];
        [_deslizador addTarget:self action:@selector(moverArrastre)
              forControlEvents:UIControlEventValueChanged];
        [_deslizador addTarget:self action:@selector(soltarArrastre)
              forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                                UIControlEventTouchCancel)];
        [self addSubview:_deslizador];

        // --- La fila de botones pequenos
        _botonVelocidad = [self botonTexto:@"1x" accion:@selector(tocarVelocidad)];
        _botonBucle     = [self botonIcono:@"bucle"     lado:24.0 accion:@selector(tocarBucle)];
        _botonDescargar = [self botonIcono:@"descargar" lado:24.0 accion:@selector(tocarDescargar)];
        _botonCompartir = [self botonIcono:@"compartir" lado:24.0 accion:@selector(tocarCompartir)];
        _botonPantalla  = [self botonIcono:@"pantalla"  lado:24.0 accion:@selector(tocarPantalla)];
    }
    return self;
}

- (UILabel *)etiquetaDeTiempo {
    UILabel *etiqueta = [[UILabel alloc] init];
    etiqueta.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    etiqueta.textColor = [UIColor whiteColor];
    etiqueta.text = @"0:00";
    [self addSubview:etiqueta];
    return etiqueta;
}

- (UIButton *)botonIcono:(NSString *)forma lado:(CGFloat)lado accion:(SEL)accion {
    UIButton *boton = [UIButton buttonWithType:UIButtonTypeCustom];
    [boton setImage:[YTTheme icono:forma lado:lado] forState:UIControlStateNormal];
    boton.tintColor = [UIColor whiteColor];
    boton.showsTouchWhenHighlighted = YES;
    [boton addTarget:self action:accion forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:boton];
    return boton;
}

- (UIButton *)botonTexto:(NSString *)texto accion:(SEL)accion {
    UIButton *boton = [UIButton buttonWithType:UIButtonTypeCustom];
    boton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [boton setTitle:texto forState:UIControlStateNormal];
    [boton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    boton.showsTouchWhenHighlighted = YES;
    [boton addTarget:self action:accion forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:boton];
    return boton;
}

#pragma mark - Acciones (solo avisan al delegado)

- (void)tocarAtras        { [self.delegado controlesSaltarSegundos:-10.0]; }
- (void)tocarAdelante     { [self.delegado controlesSaltarSegundos:10.0]; }
- (void)tocarReproducir   { [self.delegado controlesAlternarReproduccion]; }
- (void)tocarVelocidad    { [self.delegado controlesTocarVelocidad]; }
- (void)tocarBucle        { [self.delegado controlesTocarBucle]; }
- (void)tocarDescargar    { [self.delegado controlesTocarDescargar]; }
- (void)tocarCompartir    { [self.delegado controlesTocarCompartir]; }
- (void)tocarPantalla     { [self.delegado controlesTocarPantallaCompleta]; }

- (void)empezarArrastre {
    _arrastrando = YES;
}

- (void)moverArrastre {
    // Mientras el dedo esta puesto manda el dedo, no el reloj del video.
    _etiquetaActual.text = YTTextoDeTiempo(_deslizador.value);
}

- (void)soltarArrastre {
    _arrastrando = NO;
    [self.delegado controlesBuscarA:_deslizador.value];
}

#pragma mark - Estado

- (void)setBucle:(BOOL)bucle {
    _bucle = bucle;
    _botonBucle.tintColor = bucle ? [YTTheme acento] : [UIColor whiteColor];
}

- (void)setVelocidad:(float)velocidad {
    _velocidad = velocidad;
    [_botonVelocidad setTitle:[NSString stringWithFormat:@"%gx", velocidad]
                     forState:UIControlStateNormal];
}

- (void)setPantallaCompleta:(BOOL)pantallaCompleta {
    _pantallaCompleta = pantallaCompleta;
    [_botonPantalla setImage:[YTTheme icono:(pantallaCompleta ? @"encoger" : @"pantalla")
                                       lado:24.0]
                    forState:UIControlStateNormal];
}

- (void)setDescargando:(BOOL)descargando {
    _descargando = descargando;
    if (!descargando) {
        [_botonDescargar setTitle:nil forState:UIControlStateNormal];
        [_botonDescargar setImage:[YTTheme icono:@"descargar" lado:24.0]
                         forState:UIControlStateNormal];
        _botonDescargar.tintColor = [UIColor whiteColor];
    }
}

- (void)actualizarPorcentajeDescarga:(double)fraccion {
    if (!_descargando) return;
    NSString *texto = fraccion > 0.0
        ? [NSString stringWithFormat:@"%d %%", (int)round(fraccion * 100.0)]
        : @"...";
    [_botonDescargar setImage:nil forState:UIControlStateNormal];
    [_botonDescargar setTitle:texto forState:UIControlStateNormal];
    [_botonDescargar setTitleColor:[YTTheme acento] forState:UIControlStateNormal];
}

- (void)actualizarConActual:(double)actual
                      total:(double)total
             reproduciendo:(BOOL)reproduciendo {
    if (total > 0.0 && !isnan(total)) {
        _deslizador.maximumValue = total;
        _etiquetaTotal.text = YTTextoDeTiempo(total);
    } else {
        _deslizador.maximumValue = 1.0;
        _etiquetaTotal.text = @"--:--";
    }
    if (!_arrastrando) {
        if (!isnan(actual) && actual >= 0.0) {
            _deslizador.value = actual;
            _etiquetaActual.text = YTTextoDeTiempo(actual);
        } else {
            _etiquetaActual.text = @"0:00";
        }
    }

    // El icono grande solo se repinta cuando cambia de verdad.
    BOOL pausa = !reproduciendo;
    if (pausa != _pintandoPausa) {
        _pintandoPausa = pausa;
        [_botonReproducir setImage:[YTTheme icono:(pausa ? @"reproducir" : @"pausa") lado:30.0]
                          forState:UIControlStateNormal];
    }
}

- (void)mostrar:(BOOL)mostrar animado:(BOOL)animado {
    if (_visible == mostrar) return;
    _visible = mostrar;
    self.userInteractionEnabled = mostrar;
    if (!animado) {
        self.alpha = mostrar ? 1.0 : 0.0;
        return;
    }
    [UIView animateWithDuration:0.22 animations:^{
        self.alpha = mostrar ? 1.0 : 0.0;
    }];
}

#pragma mark - Colocacion

- (void)layoutSubviews {
    [super layoutSubviews];
    // Sin esto, cambiar el marco de la capa del degradado se animaria solo (y en
    // las rotaciones se veria el borde moviendose a destiempo).
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _degradado.frame = self.bounds;
    [CATransaction commit];

    CGFloat ancho = CGRectGetWidth(self.bounds);
    CGFloat alto = CGRectGetHeight(self.bounds);

    // Centro: los tres botones gordos.
    CGFloat medio = floor(alto * 0.40);
    _botonReproducir.frame = CGRectMake(floor(ancho / 2.0) - 28.0, medio - 28.0, 56.0, 56.0);
    _botonAtras.frame = CGRectMake(CGRectGetMinX(_botonReproducir.frame) - 56.0,
                                   medio - 22.0, 44.0, 44.0);
    _botonAdelante.frame = CGRectMake(CGRectGetMaxX(_botonReproducir.frame) + 12.0,
                                      medio - 22.0, 44.0, 44.0);

    // Abajo: reloj - barra - reloj.
    CGFloat margen = 12.0;
    CGFloat anchoReloj = 54.0;
    CGFloat yReloj = alto - 58.0;
    _etiquetaActual.frame = CGRectMake(margen, yReloj, anchoReloj, 16.0);
    _etiquetaTotal.frame = CGRectMake(ancho - margen - anchoReloj, yReloj, anchoReloj, 16.0);
    _deslizador.frame = CGRectMake(CGRectGetMaxX(_etiquetaActual.frame) + 2.0, yReloj - 5.0,
                                   ancho - 2.0 * margen - 2.0 * anchoReloj - 4.0, 26.0);

    // Y la fila de botones pequenos, repartida a lo ancho.
    CGFloat yIconos = alto - 32.0;
    CGFloat paso = (ancho - 2.0 * margen) / 5.0;
    UIButton *fila[5] = { _botonVelocidad, _botonBucle, _botonDescargar,
                          _botonCompartir, _botonPantalla };
    for (int i = 0; i < 5; i++) {
        fila[i].frame = CGRectMake(margen + i * paso, yIconos, paso, 28.0);
    }
}

@end
