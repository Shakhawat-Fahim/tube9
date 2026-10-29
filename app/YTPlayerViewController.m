// v1.0-en 2026-10-29: English UI build (textos traducidos al ingles; hl=en, gl=US)
// YTPlayerViewController.m -- reproductor.
//
// Ademas de reproducir (que es lo dificil: ver YTClient), esta pantalla hace
// lo que se espera de un reproductor de YouTube:
//   - reanuda donde lo dejaste, y lo recuerda para el estante "Continuar viendo";
//   - los mandos propios encima del video (reproducir, 10 s, velocidad, bucle,
//     descarga, compartir y pantalla completa), que se esconden solos;
//   - un toque enseña u oculta los mandos; dos toques, 10 s atras o adelante;
//   - arrastrar el dedo arriba/abajo cambia el volumen, y a lo ancho se busca
//     dentro del video;
//   - pantalla completa (con el telefono girado se ve mucho mas grande);
//   - la informacion que da la aplicacion oficial: canal, visitas, duracion y
//     la descripcion, con un boton para entrar en el canal;
//   - manda el titulo y los mandos a la pantalla de bloqueo;
//   - debajo, una lista de videos parecidos.
//
// NOTA: se usa AVPlayer + AVPlayerLayer en vez de AVPlayerViewController porque
// el reproductor de Apple es una caja cerrada: no se puede ni cambiar el color
// de los botones ni poner los iconos del tema, y con el tema claro desentonaba.
#import "YTPlayerViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTProgreso.h"
#import "YTDescargas.h"
#import "YTDescargasViewController.h"
#import "YTVideoCell.h"
#import "YTControlesReproductor.h"
#import "YTChannelViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

static const float kVelocidades[] = { 0.5f, 1.0f, 1.25f, 1.5f, 2.0f };
static const NSUInteger kNumeroDeVelocidades = 5;

// ---------------------------------------------------------------------------
//  La capa del video: un UIView cuya "layer" es la de AVFoundation. Es la forma
//  documentada de poner el video donde tu quieras (y poder taparlo con botones
//  propios).
// ---------------------------------------------------------------------------
@interface YTVistaDeVideo : UIView
@property (nonatomic, strong) AVPlayer *jugador;
@end

@implementation YTVistaDeVideo

+ (Class)layerClass { return [AVPlayerLayer class]; }

- (AVPlayerLayer *)capaVideo { return (AVPlayerLayer *)self.layer; }

- (void)setJugador:(AVPlayer *)jugador {
    [self capaVideo].player = jugador;
    [self capaVideo].videoGravity = AVLayerVideoGravityResizeAspect;
}

- (AVPlayer *)jugador { return [self capaVideo].player; }

@end

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

@interface YTPlayerViewController () <UITableViewDataSource, UITableViewDelegate,
                                      YTControlesDelegado>
@end

@implementation YTPlayerViewController {
    YTVideo *_video;
    NSString *_rutaLocal;

    UITableView *_tabla;
    UIView *_cabecera;              // cabecera de la tabla: reproductor + datos + botones
    UIView *_caja;                  // recuadro negro 16:9 donde vive el reproductor
    YTVistaDeVideo *_vistaVideo;    // el video (AVPlayerLayer)
    UIView *_capaGestos;            // toques y arrastres sobre el video
    YTControlesReproductor *_controles;
    AVPlayer *_jugador;
    UIActivityIndicatorView *_girador;

    UILabel *_titulo;
    UILabel *_autor;                // "Canal  ·  1.234.567 visitas  ·  12:34"
    UILabel *_descripcion;          // lo que cuenta el autor del video
    UIButton *_botonMas;            // "Ver mas" / "Ver menos"
    UIButton *_botonCanal;          // entra en la ficha del canal
    UILabel *_estado;               // linea tecnica (cliente, 360p...)
    UILabel *_aviso;                // cartelito flotante ("+10 s", "Volumen 60 %")
    UIButton *_reintentar;

    AVPlayerItem *_elemento;
    BOOL _observando;
    NSTimer *_vigilante;            // evita quedarse en "Cargando..." para siempre
    NSTimer *_latido;               // va apuntando por donde va el video
    id _reloj;                      // observador periodico del tiempo del video
    NSDate *_inicioCarga;
    NSString *_hostVideo;
    NSString *_clienteVideo;
    BOOL _listo;

    BOOL _bucle;
    float _velocidad;
    BOOL _reanudado;
    float _volumenInicial;
    NSInteger _porcentajeDescarga;

    BOOL _pantallaCompleta;
    double _totalVideo;
    double _segundosPreview;
    BOOL _ejeDecidido;
    BOOL _arrastreHorizontal;

    NSArray *_relacionados;
    BOOL _pidiendoRelacionados;
    id _mandoPlay;
    id _mandoPause;
    id _mandoAlternar;
    id _mandoAdelante;
    id _mandoAtras;
}

#pragma mark - Arranque

- (instancetype)initWithVideo:(YTVideo *)video {
    self = [super init];
    if (self) _video = video;
    return self;
}

- (instancetype)initConRutaLocal:(NSString *)ruta titulo:(NSString *)titulo {
    self = [super init];
    if (self) {
        _rutaLocal = [ruta copy];
        YTVideo *video = [[YTVideo alloc] init];
        video.titulo = titulo.length ? titulo : @"Downloaded video";
        _video = video;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Now playing";
    self.view.backgroundColor = [YTTheme fondo];
    // Con esto la tabla empieza justo debajo de la barra y no hay sorpresas.
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    _velocidad = 1.0f;

    _tabla = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tabla.dataSource = self;
    _tabla.delegate = self;
    _tabla.backgroundColor = [YTTheme fondo];
    _tabla.separatorColor = [YTTheme borde];
    _tabla.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tabla];

    [self construirCabecera];
    _tabla.tableHeaderView = _cabecera;

    // El reproductor de verdad. La capa ya existe desde el primer momento, asi
    // que el video aparece en cuanto llega, sin montar nada a ultima hora.
    _jugador = [[AVPlayer alloc] init];
    _vistaVideo.jugador = _jugador;

    // Con el interruptor de silencio activado tambien suena, y sigue sonando
    // con la pantalla apagada (es lo que hace util la pantalla de bloqueo).
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    [self prepararMandosRemotos];

    if (_rutaLocal.length) {
        _estado.text = @"Downloaded file: playing from the device.";
        [self prepararElementoConURL:[NSURL fileURLWithPath:_rutaLocal]];
    } else {
        [self resolver];
    }
}

- (void)construirCabecera {
    _cabecera = [[UIView alloc] init];
    _cabecera.backgroundColor = [YTTheme fondo];

    _caja = [[UIView alloc] init];
    _caja.backgroundColor = [UIColor blackColor];
    _caja.clipsToBounds = YES;
    [_cabecera addSubview:_caja];

    _vistaVideo = [[YTVistaDeVideo alloc] init];
    _vistaVideo.backgroundColor = [UIColor blackColor];
    [_caja addSubview:_vistaVideo];

    // Los gestos van en una capa transparente: asi los arrastres no chocan con
    // los botones de los mandos, que estan por encima.
    _capaGestos = [[UIView alloc] init];
    _capaGestos.backgroundColor = [UIColor clearColor];
    [_caja addSubview:_capaGestos];

    UITapGestureRecognizer *unToque =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tocarUnaVez:)];
    [_capaGestos addGestureRecognizer:unToque];

    UITapGestureRecognizer *dobleToque =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tocarDosVeces:)];
    dobleToque.numberOfTapsRequired = 2;
    [unToque requireGestureRecognizerToFail:dobleToque];   // primero, el doble toque
    [_capaGestos addGestureRecognizer:dobleToque];

    UIPanGestureRecognizer *arrastre =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(arrastrar:)];
    [_capaGestos addGestureRecognizer:arrastre];

    _controles = [[YTControlesReproductor alloc] init];
    _controles.delegado = self;
    _controles.bucle = NO;
    _controles.velocidad = _velocidad;
    [_caja addSubview:_controles];

    _girador = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _girador.color = [YTTheme acento];
    [_caja addSubview:_girador];

    _aviso = [[UILabel alloc] init];
    _aviso.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _aviso.textColor = [UIColor whiteColor];
    _aviso.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
    _aviso.textAlignment = NSTextAlignmentCenter;
    _aviso.layer.cornerRadius = 8.0;
    _aviso.layer.masksToBounds = YES;
    _aviso.hidden = YES;
    [_caja addSubview:_aviso];

    // --- Informacion del video (como en la aplicacion oficial) -------------
    _titulo = [[UILabel alloc] init];
    _titulo.numberOfLines = 2;
    _titulo.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    _titulo.textColor = [YTTheme textoPrimario];
    _titulo.text = _video.titulo;
    [_cabecera addSubview:_titulo];

    _autor = [[UILabel alloc] init];
    _autor.font = [UIFont systemFontOfSize:13.0];
    _autor.textColor = [YTTheme textoSecundario];
    _autor.text = _video.canal;
    [_cabecera addSubview:_autor];

    _botonCanal = [UIButton buttonWithType:UIButtonTypeSystem];
    [_botonCanal setTitle:@"View channel" forState:UIControlStateNormal];
    [_botonCanal setImage:[YTTheme icono:@"canal" lado:16.0] forState:UIControlStateNormal];
    _botonCanal.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [_botonCanal addTarget:self action:@selector(abrirCanal)
         forControlEvents:UIControlEventTouchUpInside];
    [YTTheme aplicarEstiloChip:_botonCanal seleccionado:NO];
    _botonCanal.hidden = (_video.canalId.length == 0);
    [_cabecera addSubview:_botonCanal];

    _descripcion = [[UILabel alloc] init];
    _descripcion.numberOfLines = 3;
    _descripcion.font = [UIFont systemFontOfSize:13.0];
    _descripcion.textColor = [YTTheme textoSecundario];
    _descripcion.hidden = YES;
    [_cabecera addSubview:_descripcion];

    _botonMas = [UIButton buttonWithType:UIButtonTypeSystem];
    [_botonMas setTitle:@"Show more" forState:UIControlStateNormal];
    [_botonMas setTitleColor:[YTTheme acento] forState:UIControlStateNormal];
    _botonMas.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    _botonMas.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [_botonMas addTarget:self action:@selector(alternarDescripcion)
        forControlEvents:UIControlEventTouchUpInside];
    _botonMas.hidden = YES;
    [_cabecera addSubview:_botonMas];

    _estado = [[UILabel alloc] init];
    _estado.numberOfLines = 0;
    _estado.font = [UIFont systemFontOfSize:13.0];
    _estado.textColor = [YTTheme textoSecundario];
    [_cabecera addSubview:_estado];

    _reintentar = [UIButton buttonWithType:UIButtonTypeSystem];
    [_reintentar setTitle:@"Retry" forState:UIControlStateNormal];
    [_reintentar setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _reintentar.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _reintentar.backgroundColor = [YTTheme acento];
    _reintentar.layer.cornerRadius = 10.0;
    _reintentar.hidden = YES;
    [_reintentar addTarget:self action:@selector(resolver) forControlEvents:UIControlEventTouchUpInside];
    [_cabecera addSubview:_reintentar];
}

- (void)viewWillAppear:(BOOL)animado {
    [super viewWillAppear:animado];
    [UIApplication sharedApplication].idleTimerDisabled = YES;   // que no se apague viendo un video
    [self reiniciarTemporizadorDeControles];
}

- (void)viewWillDisappear:(BOOL)animado {
    [super viewWillDisappear:animado];
    [self guardarProgreso];
    [_jugador pause];
    [UIApplication sharedApplication].idleTimerDisabled = NO;

    // Si se sale estando en pantalla completa, la barra tiene que volver.
    if (_pantallaCompleta) {
        _pantallaCompleta = NO;
        [self.navigationController setNavigationBarHidden:NO animated:NO];
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                               withAnimation:UIStatusBarAnimationNone];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(esconderControles)
                                               object:nil];
}

- (void)dealloc {
    [_vigilante invalidate];
    [_latido invalidate];
    if (_reloj && _jugador) {
        [_jugador removeTimeObserver:_reloj];
        _reloj = nil;
    }
    if (_observando && _elemento) {
        [_elemento removeObserver:self forKeyPath:@"status"];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // Los mandos de la pantalla de bloqueo se quitan al salir de aqui; si no,
    // seguirian apuntando a un reproductor que ya no existe.
    MPRemoteCommandCenter *centro = [MPRemoteCommandCenter sharedCommandCenter];
    if (_mandoPlay)     [centro.playCommand removeTarget:_mandoPlay];
    if (_mandoPause)    [centro.pauseCommand removeTarget:_mandoPause];
    if (_mandoAlternar) [centro.togglePlayPauseCommand removeTarget:_mandoAlternar];
    if (_mandoAdelante) [centro.skipForwardCommand removeTarget:_mandoAdelante];
    if (_mandoAtras)    [centro.skipBackwardCommand removeTarget:_mandoAtras];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

#pragma mark - Colocacion de la interfaz

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.view.bounds);

    if (_pantallaCompleta) {
        _caja.frame = self.view.bounds;
    } else {
        _caja.frame = CGRectMake(0, 0, ancho, floor(ancho * 9.0 / 16.0));
    }
    _vistaVideo.frame = _caja.bounds;
    _capaGestos.frame = _caja.bounds;
    _controles.frame = _caja.bounds;
    _girador.center = CGPointMake(CGRectGetMidX(_caja.bounds), CGRectGetMidY(_caja.bounds));

    CGFloat margen = 14.0;
    CGFloat util = ancho - margen * 2.0;
    CGFloat y = CGRectGetMaxY(_caja.frame) + 12.0;

    if (_pantallaCompleta) {
        // En pantalla completa la tabla queda tapada: no hay que colocar nada.
        [_controles setNeedsLayout];
        [self colocarAviso];
        return;
    }

    _titulo.frame = CGRectMake(margen, y, util, 44.0);
    y = CGRectGetMaxY(_titulo.frame) + 2.0;
    _autor.frame = CGRectMake(margen, y, util, 18.0);
    y = CGRectGetMaxY(_autor.frame) + 10.0;

    if (!_botonCanal.hidden) {
        CGFloat anchoBoton = MIN(util, 122.0);
        _botonCanal.frame = CGRectMake(margen, y, anchoBoton, 30.0);
        y = CGRectGetMaxY(_botonCanal.frame) + 12.0;
    }

    if (!_descripcion.hidden) {
        CGSize tamano = [_descripcion sizeThatFits:CGSizeMake(util, 500.0)];
        _descripcion.frame = CGRectMake(margen, y, util, MAX(20.0, tamano.height));
        y = CGRectGetMaxY(_descripcion.frame) + 4.0;
    }
    if (!_botonMas.hidden) {
        _botonMas.frame = CGRectMake(margen, y, util, 24.0);
        y = CGRectGetMaxY(_botonMas.frame) + 8.0;
    }

    CGSize tamanoEstado = [_estado sizeThatFits:CGSizeMake(util, 500.0)];
    _estado.frame = CGRectMake(margen, y, util, MAX(18.0, tamanoEstado.height));
    y = CGRectGetMaxY(_estado.frame) + 12.0;

    if (!_reintentar.hidden) {
        _reintentar.frame = CGRectMake(margen, y, util, 44.0);
        y = CGRectGetMaxY(_reintentar.frame) + 12.0;
    }

    CGFloat alto = y + 6.0;
    if (fabs(alto - CGRectGetHeight(_cabecera.frame)) > 0.5) {
        _cabecera.frame = CGRectMake(0, 0, ancho, alto);
        _tabla.tableHeaderView = _cabecera;   // hay que reasignar para que recalcule
    }
    [_controles setNeedsLayout];
    [self colocarAviso];
}

- (void)colocarAviso {
    if (_aviso.hidden || _aviso.text.length == 0) return;
    CGSize tamano = [_aviso sizeThatFits:CGSizeMake(CGRectGetWidth(_caja.bounds) - 40.0, 60.0)];
    CGFloat ancho = MIN(tamano.width + 24.0, CGRectGetWidth(_caja.bounds) - 32.0);
    CGFloat alto = tamano.height + 12.0;
    _aviso.frame = CGRectMake(floor((CGRectGetWidth(_caja.bounds) - ancho) / 2.0),
                              floor(CGRectGetHeight(_caja.bounds) * 0.62),
                              ancho, alto);
}

- (void)ajustarCabecera {
    [self.view setNeedsLayout];
}

- (void)mostrarAviso:(NSString *)texto {
    _aviso.text = texto;
    _aviso.hidden = NO;
    _aviso.alpha = 1.0;
    [self colocarAviso];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(ocultarAviso)
                                               object:nil];
    [self performSelector:@selector(ocultarAviso) withObject:nil afterDelay:1.1];
}

- (void)ocultarAviso {
    [UIView animateWithDuration:0.25 animations:^{
        self->_aviso.alpha = 0.0;
    } completion:^(BOOL terminado) {
        self->_aviso.hidden = YES;
    }];
}

#pragma mark - Los mandos: enseñar, esconder y obedecer

- (void)reiniciarTemporizadorDeControles {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(esconderControles)
                                               object:nil];
    [_controles mostrar:YES animado:YES];
    // Con el video parado los mandos se quedan: no hay nada que tapar.
    if (_listo && _jugador.rate > 0.01f) {
        [self performSelector:@selector(esconderControles) withObject:nil afterDelay:3.5];
    }
}

- (void)esconderControles {
    if (!_listo || _jugador.rate < 0.01f) return;
    [_controles mostrar:NO animado:YES];
}

- (void)tocarUnaVez:(UITapGestureRecognizer *)gesto {
    if (gesto.state != UIGestureRecognizerStateEnded) return;
    if (_controles.alpha > 0.5) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(esconderControles)
                                                   object:nil];
        [_controles mostrar:NO animado:YES];
    } else {
        [self reiniciarTemporizadorDeControles];
    }
}

- (void)refrescarControles {
    if (!_elemento) return;
    double total = CMTimeGetSeconds(_elemento.duration);
    if (!isnan(total) && total > 0.0) _totalVideo = total;
    double actual = CMTimeGetSeconds(_jugador.currentTime);
    [_controles actualizarConActual:actual
                              total:_totalVideo
                     reproduciendo:(_jugador.rate > 0.01f)];
}

- (void)crearRelojDeLosMandos {
    if (_reloj || !_jugador) return;
    __weak YTPlayerViewController *deb = self;
    _reloj = [_jugador addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, 600)
                                                    queue:dispatch_get_main_queue()
                                               usingBlock:^(CMTime tiempo) {
        [deb refrescarControles];
    }];
}

#pragma mark - YTControlesDelegado

- (void)controlesAlternarReproduccion {
    if (_jugador.rate > 0.01f) {
        [_jugador pause];
        [self guardarProgreso];
        [self reiniciarTemporizadorDeControles];   // parado, los mandos se quedan
    } else {
        [_jugador play];
        if (_velocidad != 1.0f) _jugador.rate = _velocidad;
        [self reiniciarTemporizadorDeControles];
    }
    [self refrescarControles];
    [self actualizarInfoBloqueo];
}

- (void)controlesSaltarSegundos:(double)segundos {
    [self saltar:segundos];
    [self reiniciarTemporizadorDeControles];
}

- (void)controlesBuscarA:(double)segundos {
    [self irA:segundos];
    [self reiniciarTemporizadorDeControles];
}

- (void)controlesTocarVelocidad {
    [self cambiarVelocidad];
    [self reiniciarTemporizadorDeControles];
}

- (void)controlesTocarBucle {
    [self alternarBucle];
    [self reiniciarTemporizadorDeControles];
}

- (void)controlesTocarDescargar {
    [self descargar];
    [self reiniciarTemporizadorDeControles];
}

- (void)controlesTocarCompartir {
    [self compartir];
}

- (void)controlesTocarPantallaCompleta {
    [self alternarPantallaCompleta];
}

#pragma mark - Pantalla completa

- (void)alternarPantallaCompleta {
    _pantallaCompleta = !_pantallaCompleta;

    if (_pantallaCompleta) {
        // El video se saca de la tabla y se pone a pantalla completa encima.
        [_caja removeFromSuperview];
        _caja.frame = self.view.bounds;
        [self.view addSubview:_caja];
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:YES
                                               withAnimation:UIStatusBarAnimationFade];
    } else {
        [_caja removeFromSuperview];
        [_cabecera addSubview:_caja];
        [_cabecera sendSubviewToBack:_caja];
        [self.navigationController setNavigationBarHidden:NO animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                               withAnimation:UIStatusBarAnimationFade];
        _tabla.tableHeaderView = _cabecera;
    }

    _controles.pantallaCompleta = _pantallaCompleta;
    [self.view setNeedsLayout];
    [self reiniciarTemporizadorDeControles];
    [self mostrarAviso:(_pantallaCompleta ? @"Turn the device to see it bigger"
                                          : @"Normal view")];
}

#pragma mark - Resolucion y reproduccion

- (void)resolver {
    if (_rutaLocal.length) {
        [self prepararElementoConURL:[NSURL fileURLWithPath:_rutaLocal]];
        return;
    }
    _reintentar.hidden = YES;
    _estado.text = @"Finding the video...";
    [_girador startAnimating];
    [self ajustarCabecera];

    __weak YTPlayerViewController *deb = self;
    [[YTClient compartido] resolverVideo:_video.identificador
        completion:^(NSDictionary *info, NSError *error) {
        YTPlayerViewController *yo = deb;
        if (!yo) return;
        if (error) {
            [yo mostrarError:[YTClient explicarError:error]];
            return;
        }
        if ([(NSString *)info[@"titulo"] length]) {
            yo->_titulo.text = info[@"titulo"];
            yo->_video.titulo = info[@"titulo"];
        }
        if ([(NSString *)info[@"autor"] length]) {
            yo->_video.canal = info[@"autor"];
        }
        if ([(NSString *)info[@"canalId"] length]) {
            yo->_video.canalId = info[@"canalId"];
        }
        if ([(NSString *)info[@"cliente"] length]) yo->_clienteVideo = info[@"cliente"];
        [yo mostrarDatosDelVideo:info];
        [yo reproducir:info[@"url"]];
    }];
}

// La informacion que enseña la aplicacion oficial: canal, visitas, duracion y
// descripcion del video.
- (void)mostrarDatosDelVideo:(NSDictionary *)info {
    NSMutableArray *partes = [NSMutableArray array];
    if (_video.canal.length) [partes addObject:_video.canal];

    id visitas = info[@"visitas"];
    // En modo directo YouTube manda un numero; por el relay, una cadena. Se
    // atienden las dos.
    if ([visitas isKindOfClass:[NSNumber class]] || [visitas isKindOfClass:[NSString class]]) {
        long long numero = [visitas longLongValue];
        if (numero > 0) {
            NSNumberFormatter *formato = [[NSNumberFormatter alloc] init];
            formato.numberStyle = NSNumberFormatterDecimalStyle;
            formato.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
            NSString *texto = [formato stringFromNumber:@(numero)];
            [partes addObject:[NSString stringWithFormat:@"%@ views", texto]];
        }
    }
    id duracion = info[@"duracion"];
    if ([duracion isKindOfClass:[NSNumber class]] || [duracion isKindOfClass:[NSString class]]) {
        double segundos = [duracion doubleValue];
        if (segundos > 0.5) [partes addObject:YTTextoDeTiempo(segundos)];
    }
    _autor.text = [partes componentsJoinedByString:@"  ·  "];

    _botonCanal.hidden = (_video.canalId.length == 0);

    NSString *descripcion = info[@"descripcion"];
    if ([descripcion isKindOfClass:[NSString class]] && descripcion.length > 0) {
        _descripcion.text = descripcion;
        _descripcion.hidden = NO;
        // Con la descripcion corta no hace falta el boton de "ver mas".
        _botonMas.hidden = (descripcion.length < 140);
    }
    [self ajustarCabecera];
}

- (void)alternarDescripcion {
    BOOL entera = (_descripcion.numberOfLines != 0);
    _descripcion.numberOfLines = entera ? 0 : 3;
    [_botonMas setTitle:(entera ? @"Show less" : @"Show more") forState:UIControlStateNormal];
    [self ajustarCabecera];
}

- (void)abrirCanal {
    if (_video.canalId.length == 0) return;
    YTChannelViewController *canal = [[YTChannelViewController alloc]
        initWithCanalId:_video.canalId titulo:_video.canal];
    canal.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:canal animated:YES];
}

- (void)reproducir:(NSString *)enlace {
    NSURL *url = [NSURL URLWithString:enlace];
    if (!url) {
        [self mostrarError:@"The video address is not valid."];
        return;
    }
    [self prepararElementoConURL:url];
}

- (void)prepararElementoConURL:(NSURL *)url {
    [_vigilante invalidate];
    _vigilante = nil;
    [_latido invalidate];
    _latido = nil;
    if (_observando && _elemento) {
        [_elemento removeObserver:self forKeyPath:@"status"];
        _observando = NO;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:_elemento];

    _listo = NO;
    _hostVideo = url.host ?: @"file on the device";
    _totalVideo = 0.0;
    _elemento = [AVPlayerItem playerItemWithURL:url];
    // Para que a 1,5x no suene acelerado como una ardilla.
    _elemento.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmSpectral;
    [_elemento addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    _observando = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(terminoElVideo:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:_elemento];

    [_jugador replaceCurrentItemWithPlayerItem:_elemento];
    [_jugador play];
    [_girador startAnimating];
    _estado.text = @"Loading...";
    [self crearRelojDeLosMandos];
    [self refrescarControles];
    [self ajustarCabecera];
    [self actualizarInfoBloqueo];

    if (url.host.length == 0) return;   // los ficheros locales no se quedan colgados
    _inicioCarga = [NSDate date];
    _vigilante = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(vigilarCarga)
                                                userInfo:nil
                                                 repeats:YES];
    [self vigilarCarga];
}

- (void)vigilarCarga {
    if (_elemento.status == AVPlayerItemStatusReadyToPlay) {
        [_vigilante invalidate];
        _vigilante = nil;
        return;
    }
    NSTimeInterval segundos = -[_inicioCarga timeIntervalSinceNow];
    _estado.text = [NSString stringWithFormat:@"Loading... %.0f s   (%@)",
                    segundos, _hostVideo];
    if (segundos >= 30.0) {
        [_vigilante invalidate];
        _vigilante = nil;
        [self mostrarError:[NSString stringWithFormat:
            @"The video does not start.\n\nServer: %@\n30 seconds without receiving "
            @"anything.\n\nUsually the Internet provider is slowing down "
            @"googlevideo.com, or YouTube wants you to sign in. Try "
            @"Settings > Sign in to YouTube, or relay mode.", _hostVideo]];
    }
}

- (void)observeValueForKeyPath:(NSString *)ruta
                      ofObject:(id)objeto
                        change:(NSDictionary *)cambio
                       context:(void *)contexto {
    if (![ruta isEqualToString:@"status"] || objeto != _elemento) return;

    // La notificacion puede llegar desde una cola interna de AVFoundation, y la
    // interfaz solo se puede tocar desde el hilo principal.
    AVPlayerItemStatus estado = _elemento.status;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (estado == AVPlayerItemStatusReadyToPlay) {
            [self yaEstaListo];
        } else if (estado == AVPlayerItemStatusFailed) {
            [self->_vigilante invalidate];
            self->_vigilante = nil;
            [self->_girador stopAnimating];
            NSError *fallo = self->_elemento.error;
            NSString *detalle = fallo.localizedDescription ?: @"unknown error";
            NSInteger codigo = fallo.code;
            NSString *pista = @"";
            if (codigo == -11850 || codigo == -11800) {
                pista = @"\n\nYouTube refused the download (403). Sign in under "
                        @"Settings so that requests are authenticated.";
            }
            [self mostrarError:[NSString stringWithFormat:@"Could not play.\n%@%@",
                                detalle, pista]];
        }
    });
}

- (void)yaEstaListo {
    [_vigilante invalidate];
    _vigilante = nil;
    [_girador stopAnimating];
    _listo = YES;

    double total = CMTimeGetSeconds(_elemento.duration);
    if (!isnan(total) && total > 0.0) _totalVideo = total;
    if (_velocidad != 1.0f) _jugador.rate = _velocidad;

    NSString *extra = _clienteVideo.length
        ? [NSString stringWithFormat:@"\n\nResolved with client %@.", _clienteVideo]
        : @"";
    if (_rutaLocal.length) {
        _estado.text = @"Playing from the device.";
    } else {
        _estado.text = [NSString stringWithFormat:
            @"MP4 360p (32-bit devices cannot decode VP9 or AV1, so there is "
             "no 720p).%@\n\nOne tap shows the controls; double tap goes 10 s back or "
             "forward. Drag up/down for volume, and sideways to "
             "move through the video.", extra];
    }
    [self ajustarCabecera];
    [self refrescarControles];
    [self reiniciarTemporizadorDeControles];
    [self actualizarInfoBloqueo];
    [self cargarCaratulaBloqueo];
    [self pedirRelacionados];

    // Reanudar donde se quedo, si merece la pena.
    NSString *identificador = _video.identificador;
    double guardado = [YTProgreso segundosDe:identificador];
    if (!_reanudado && identificador.length && guardado > 15.0 &&
        (total <= 0.0 || guardado < total - 10.0)) {
        _reanudado = YES;
        __weak YTPlayerViewController *deb = self;
        [_jugador seekToTime:CMTimeMakeWithSeconds(guardado, 600.0)
             toleranceBefore:kCMTimeZero
                toleranceAfter:kCMTimeZero
             completionHandler:^(BOOL terminado) {
            YTPlayerViewController *yo = deb;
            if (!yo) return;
            [yo->_jugador play];
            if (yo->_velocidad != 1.0f) yo->_jugador.rate = yo->_velocidad;
            [yo mostrarAviso:[NSString stringWithFormat:@"Resuming where you left off (%d:%02d)",
                              (int)(guardado / 60.0), (int)guardado % 60]];
        }];
    }

    // Cada 5 segundos se apunta por donde va.
    [_latido invalidate];
    _latido = [NSTimer scheduledTimerWithTimeInterval:5.0
                                               target:self
                                             selector:@selector(guardarProgreso)
                                             userInfo:nil
                                              repeats:YES];
}

#pragma mark - Progreso

- (void)guardarProgreso {
    if (_rutaLocal.length || _video.identificador.length == 0) return;
    if (!_listo || !_elemento) return;
    if (_jugador.rate < 0.01f) return;   // en pausa no se toca el apunte

    double actual = CMTimeGetSeconds(_jugador.currentTime);
    double total = CMTimeGetSeconds(_elemento.duration);
    if (isnan(actual) || actual <= 0.0) return;
    if (isnan(total)) total = 0.0;
    [YTProgreso guardarVideo:_video segundos:actual total:total];
    [self actualizarInfoBloqueo];
}

- (void)terminoElVideo:(NSNotification *)nota {
    if (_bucle) {
        [_jugador seekToTime:kCMTimeZero];
        [_jugador play];
        if (_velocidad != 1.0f) _jugador.rate = _velocidad;
        [self reiniciarTemporizadorDeControles];
        return;
    }
    if (_video.identificador.length) [YTProgreso olvidar:_video.identificador];
    _estado.text = @"The video has ended.";
    [self ajustarCabecera];
    [self refrescarControles];
    [self reiniciarTemporizadorDeControles];
    [self actualizarInfoBloqueo];
    [self mostrarAviso:@"End of video"];
}

#pragma mark - Gestos

- (void)tocarDosVeces:(UITapGestureRecognizer *)gesto {
    if (gesto.state != UIGestureRecognizerStateEnded) return;
    CGPoint punto = [gesto locationInView:_caja];
    if (punto.x < CGRectGetMidX(_caja.bounds)) [self saltarAtras];
    else [self saltarAdelante];
    [self reiniciarTemporizadorDeControles];
}

// Un mismo arrastre sirve para dos cosas: arriba/abajo, el volumen; a lo ancho,
// moverse por el video. El eje se decide con el primer movimiento.
- (void)arrastrar:(UIPanGestureRecognizer *)gesto {
    if (!_jugador) return;
    CGPoint traslacion = [gesto translationInView:_caja];

    if (gesto.state == UIGestureRecognizerStateBegan) {
        _volumenInicial = _jugador.volume;
        _segundosPreview = CMTimeGetSeconds(_jugador.currentTime);
        if (isnan(_segundosPreview)) _segundosPreview = 0.0;
        _ejeDecidido = NO;
        _arrastreHorizontal = NO;
        return;
    }

    if (gesto.state == UIGestureRecognizerStateChanged) {
        if (!_ejeDecidido) {
            if (fabs(traslacion.x) < 6.0 && fabs(traslacion.y) < 6.0) return;
            _ejeDecidido = YES;
            _arrastreHorizontal = (fabs(traslacion.x) > fabs(traslacion.y));
        }
        if (_arrastreHorizontal) {
            double destino = _segundosPreview + traslacion.x / 4.0;
            if (destino < 0.0) destino = 0.0;
            if (_totalVideo > 1.0 && destino > _totalVideo - 1.0) destino = _totalVideo - 1.0;
            [self mostrarAviso:[NSString stringWithFormat:@"%@  /  %@",
                                YTTextoDeTiempo(destino), YTTextoDeTiempo(_totalVideo)]];
        } else {
            float volumen = _volumenInicial - (float)(traslacion.y / 220.0);
            if (volumen < 0.0f) volumen = 0.0f;
            if (volumen > 1.0f) volumen = 1.0f;
            _jugador.volume = volumen;
            [self mostrarAviso:[NSString stringWithFormat:@"Volume %d %%",
                                (int)roundf(volumen * 100.0f)]];
        }
        return;
    }

    if (gesto.state == UIGestureRecognizerStateEnded && _arrastreHorizontal) {
        [self irA:_segundosPreview + traslacion.x / 4.0];
    }
}

- (void)saltarAtras { [self saltar:-10.0]; }
- (void)saltarAdelante { [self saltar:10.0]; }

- (void)saltar:(double)segundos {
    if (!_elemento || !_jugador) return;
    double actual = CMTimeGetSeconds(_jugador.currentTime);
    [self irA:actual + segundos];
    [self mostrarAviso:(segundos < 0.0 ? @"-10 s" : @"+10 s")];
}

- (void)irA:(double)segundos {
    if (!_elemento || !_jugador) return;
    double total = _totalVideo > 0.0 ? _totalVideo : CMTimeGetSeconds(_elemento.duration);
    if (isnan(segundos)) segundos = 0.0;
    if (segundos < 0.0) segundos = 0.0;
    if (!isnan(total) && total > 1.0 && segundos > total - 1.0) segundos = total - 1.0;

    // El bloque de final no puede ser nil: AVFoundation lo exige.
    [_jugador seekToTime:CMTimeMakeWithSeconds(segundos, 600.0)
         toleranceBefore:kCMTimeZero
            toleranceAfter:kCMTimeZero
         completionHandler:^(BOOL terminado) { }];
    [_controles actualizarConActual:segundos
                              total:(isnan(total) ? 0.0 : total)
                     reproduciendo:(_jugador.rate > 0.01f)];
    [self actualizarInfoBloqueo];
}

- (void)cambiarVelocidad {
    NSUInteger siguiente = 1;
    for (NSUInteger i = 0; i < kNumeroDeVelocidades; i++) {
        if (fabsf(_velocidad - kVelocidades[i]) < 0.01f) {
            siguiente = (i + 1) % kNumeroDeVelocidades;
            break;
        }
    }
    _velocidad = kVelocidades[siguiente];
    if (_jugador && _jugador.rate > 0.01f) {
        _jugador.rate = _velocidad;
    }
    _controles.velocidad = _velocidad;
    [self mostrarAviso:[NSString stringWithFormat:@"Speed %gx", _velocidad]];
}

- (void)alternarBucle {
    _bucle = !_bucle;
    _controles.bucle = _bucle;
    [self mostrarAviso:(_bucle ? @"Loop on" : @"Loop off")];
}

- (void)compartir {
    NSString *enlace = _rutaLocal.length
        ? _rutaLocal
        : [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@",
           _video.identificador ?: @""];
    UIActivityViewController *hoja = [[UIActivityViewController alloc]
        initWithActivityItems:@[ enlace ] applicationActivities:nil];
    if (hoja.popoverPresentationController) {
        hoja.popoverPresentationController.sourceView = _caja;
        hoja.popoverPresentationController.sourceRect = _caja.bounds;
    }
    [self presentViewController:hoja animated:YES completion:nil];
}

#pragma mark - Descargar

- (void)descargar {
    if (_rutaLocal.length) {
        [self mostrarAviso:@"Already downloaded"];
        return;
    }
    if (_video.identificador.length == 0) return;

    YTDescargas *gestor = [YTDescargas compartido];

    if ([gestor estaDescargando:_video.identificador]) {
        [gestor cancelarVideo:_video.identificador];
        _controles.descargando = NO;
        [self mostrarAviso:@"Download cancelled"];
        return;
    }

    _controles.descargando = YES;
    _porcentajeDescarga = -1;
    _estado.text = @"Downloading the video...";
    [self ajustarCabecera];

    __weak YTPlayerViewController *deb = self;
    [gestor descargarVideo:_video
        progreso:^(double fraccion) {
            YTPlayerViewController *yo = deb;
            if (!yo) return;
            // Solo se repinta cuando cambia el numero entero: si no, la pantalla
            // se repintaria cientos de veces por minuto.
            NSInteger porcentaje = fraccion > 0.0 ? (NSInteger)round(fraccion * 100.0) : -1;
            if (porcentaje == yo->_porcentajeDescarga) return;
            yo->_porcentajeDescarga = porcentaje;
            [yo->_controles actualizarPorcentajeDescarga:fraccion];
            yo->_estado.text = porcentaje >= 0
                ? [NSString stringWithFormat:@"Downloading... %ld %%  (tap the icon "
                                            @"again to cancel)", (long)porcentaje]
                : @"Downloading...";
            [yo ajustarCabecera];
        }
        completion:^(BOOL ok, NSString *mensaje, NSString *ruta) {
            YTPlayerViewController *yo = deb;
            if (!yo) return;
            yo->_controles.descargando = NO;
            yo->_estado.text = (ok ? @"Downloaded. You will find it in Downloads."
                                   : @"Could not download.");
            [yo ajustarCabecera];

            UIAlertController *alerta = [UIAlertController
                alertControllerWithTitle:(ok ? @"Download finished" : @"Could not download")
                                 message:mensaje
                          preferredStyle:UIAlertControllerStyleAlert];
            [alerta addAction:[UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil]];
            if (ok) {
                [alerta addAction:[UIAlertAction actionWithTitle:@"View downloads"
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *accion) {
                    YTPlayerViewController *actual = deb;
                    if (!actual) return;
                    YTDescargasViewController *lista = [[YTDescargasViewController alloc] init];
                    lista.hidesBottomBarWhenPushed = YES;
                    [actual.navigationController pushViewController:lista animated:YES];
                }]];
            }
            [yo presentViewController:alerta animated:YES completion:nil];
        }];
}

#pragma mark - Pantalla de bloqueo

- (void)prepararMandosRemotos {
    MPRemoteCommandCenter *centro = [MPRemoteCommandCenter sharedCommandCenter];
    __weak YTPlayerViewController *deb = self;

    _mandoPlay = [centro.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) {
        YTPlayerViewController *yo = deb;
        if (!yo) return MPRemoteCommandHandlerStatusCommandFailed;
        [yo->_jugador play];
        if (yo->_velocidad != 1.0f) yo->_jugador.rate = yo->_velocidad;
        [yo actualizarInfoBloqueo];
        [yo refrescarControles];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    _mandoPause = [centro.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) {
        YTPlayerViewController *yo = deb;
        if (!yo) return MPRemoteCommandHandlerStatusCommandFailed;
        [yo->_jugador pause];
        [yo guardarProgreso];
        [yo actualizarInfoBloqueo];
        [yo refrescarControles];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    _mandoAlternar = [centro.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) {
        YTPlayerViewController *yo = deb;
        if (!yo) return MPRemoteCommandHandlerStatusCommandFailed;
        if (yo->_jugador.rate > 0.01f) {
            [yo->_jugador pause];
            [yo guardarProgreso];
        } else {
            [yo->_jugador play];
            if (yo->_velocidad != 1.0f) yo->_jugador.rate = yo->_velocidad;
        }
        [yo actualizarInfoBloqueo];
        [yo refrescarControles];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    _mandoAdelante = [centro.skipForwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) {
        [deb saltarAdelante];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    _mandoAtras = [centro.skipBackwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) {
        [deb saltarAtras];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    centro.skipForwardCommand.preferredIntervals = @[ @10 ];
    centro.skipBackwardCommand.preferredIntervals = @[ @10 ];
}

- (void)actualizarInfoBloqueo {
    if (!_elemento) return;
    double total = CMTimeGetSeconds(_elemento.duration);
    double actual = CMTimeGetSeconds(_jugador.currentTime);

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = _titulo.text.length ? _titulo.text : @"Tube9";
    if (_autor.text.length) info[MPMediaItemPropertyArtist] = _autor.text;
    if (total > 0.0 && !isnan(total)) info[MPMediaItemPropertyPlaybackDuration] = @(total);
    if (actual > 0.0 && !isnan(actual)) info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(actual);
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(_jugador.rate);
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

- (void)cargarCaratulaBloqueo {
    if (_video.urlMiniatura.length == 0) return;
    __weak YTPlayerViewController *deb = self;
    [YTClient cargarMiniatura:_video.urlMiniatura completion:^(UIImage *imagen) {
        YTPlayerViewController *yo = deb;
        if (!yo || !imagen) return;
        NSMutableDictionary *info = [[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo
                                     mutableCopy] ?: [NSMutableDictionary dictionary];
        info[MPMediaItemPropertyArtwork] = [[MPMediaItemArtwork alloc] initWithImage:imagen];
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    }];
}

#pragma mark - Videos parecidos

- (void)pedirRelacionados {
    if (_rutaLocal.length) return;
    if (_video.identificador.length == 0 || _video.titulo.length == 0) return;
    if (_pidiendoRelacionados || _relacionados) return;

    _pidiendoRelacionados = YES;
    [_tabla reloadData];

    __weak YTPlayerViewController *deb = self;
    [[YTClient compartido] relacionadosDe:_video.titulo
                              excluyendo:_video.identificador
                               completion:^(NSArray *videos, NSError *error) {
        YTPlayerViewController *yo = deb;
        if (!yo) return;
        yo->_pidiendoRelacionados = NO;
        yo->_relacionados = (error || videos.count == 0) ? @[] : videos;
        [yo->_tabla reloadData];
    }];
}

#pragma mark - Tabla (videos parecidos)

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    if (_rutaLocal.length) return 0;
    if (_relacionados) return _relacionados.count;
    return _pidiendoRelacionados ? 1 : 0;
}

- (NSString *)tableView:(UITableView *)tabla titleForHeaderInSection:(NSInteger)seccion {
    if (_relacionados.count == 0) return nil;
    return @"Related";
}

- (NSString *)tableView:(UITableView *)tabla titleForFooterInSection:(NSInteger)seccion {
    if (_relacionados.count == 0) return nil;
    return @"This list comes from searching the video title: YouTube's official "
            "related list is about 7 MB and does not fit in a "
            "32-bit device.";
}

- (CGFloat)tableView:(UITableView *)tabla heightForRowAtIndexPath:(NSIndexPath *)indice {
    if (_relacionados) return [YTVideoCell altoParaAncho:CGRectGetWidth(tabla.bounds)];
    return 50.0;
}

- (void)tableView:(UITableView *)tabla
    willDisplayHeaderView:(UIView *)vista forSection:(NSInteger)seccion {
    if ([vista isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)vista).textLabel.textColor = [YTTheme textoSecundario];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {
    if (!_relacionados) {
        UITableViewCell *celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                        reuseIdentifier:nil];
        celda.backgroundColor = [YTTheme fondo];
        celda.textLabel.text = @"Finding related videos...";
        celda.textLabel.font = [YTTheme fuenteCuerpo];
        celda.textLabel.textColor = [YTTheme textoSecundario];
        celda.selectionStyle = UITableViewCellSelectionStyleNone;
        return celda;
    }

    static NSString *identificador = @"parecido";
    YTVideoCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
    if (!celda) {
        celda = [[YTVideoCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:identificador];
    }
    __weak YTPlayerViewController *deb = self;
    celda.alTocarCanal = ^(YTVideo *video) {
        YTPlayerViewController *yo = deb;
        if (!yo || video.canalId.length == 0) return;
        YTChannelViewController *canal = [[YTChannelViewController alloc]
            initWithCanalId:video.canalId titulo:video.canal];
        canal.hidesBottomBarWhenPushed = YES;
        [yo.navigationController pushViewController:canal animated:YES];
    };
    [celda configurarCon:_relacionados[indice.row]];
    return celda;
}

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];
    if (!_relacionados || indice.row >= (NSInteger)_relacionados.count) return;

    YTPlayerViewController *siguiente = [[YTPlayerViewController alloc]
        initWithVideo:_relacionados[indice.row]];
    siguiente.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:siguiente animated:YES];
}

#pragma mark - Errores

- (void)mostrarError:(NSString *)texto {
    [_vigilante invalidate];
    _vigilante = nil;
    [_latido invalidate];
    _latido = nil;
    [_girador stopAnimating];
    _estado.text = texto;
    _reintentar.hidden = NO;
    [_controles mostrar:YES animado:NO];
    [self ajustarCabecera];
}

@end
