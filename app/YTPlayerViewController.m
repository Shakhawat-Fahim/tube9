// YTPlayerViewController.m -- reproductor.
//
// Ademas de reproducir (que es lo dificil: ver YTClient), esta pantalla hace
// lo que se espera de un reproductor de YouTube:
//   - reanuda donde lo dejaste, y lo recuerda para el estante "Continuar viendo";
//   - dos toques en el video: 10 s atras (izquierda) o 10 s adelante (derecha);
//   - arrastrar el dedo arriba/abajo por el video cambia el volumen;
//   - velocidad (0,5x a 2x) y reproduccion en bucle;
//   - descarga el video a la carpeta que hayas elegido;
//   - comparte el enlace;
//   - manda el titulo y los mandos a la pantalla de bloqueo;
//   - debajo, una lista de videos parecidos.
#import "YTPlayerViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTProgreso.h"
#import "YTDescargas.h"
#import "YTDescargasViewController.h"
#import "YTVideoCell.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>

static const float kVelocidades[] = { 0.5f, 1.0f, 1.25f, 1.5f, 2.0f };
static const NSUInteger kNumeroDeVelocidades = 5;

@interface YTPlayerViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation YTPlayerViewController {
    YTVideo *_video;
    NSString *_rutaLocal;

    UITableView *_tabla;
    UIView *_cabecera;          // cabecera de la tabla: reproductor + datos + botones
    UIView *_caja;              // recuadro negro 16:9 donde vive el reproductor
    AVPlayerViewController *_reproductor;
    UIActivityIndicatorView *_girador;
    UILabel *_titulo;
    UILabel *_autor;
    UILabel *_estado;
    UILabel *_aviso;            // cartelito flotante ("+10 s", "Volumen 60 %")
    UIButton *_reintentar;
    UIScrollView *_acciones;
    UIButton *_botonAtras;
    UIButton *_botonAdelante;
    UIButton *_botonVelocidad;
    UIButton *_botonBucle;
    UIButton *_botonDescargar;
    UIButton *_botonCompartir;

    AVPlayerItem *_elemento;
    BOOL _observando;
    NSTimer *_vigilante;        // evita quedarse en "Cargando..." para siempre
    NSTimer *_latido;           // va apuntando por donde va el video
    NSDate *_inicioCarga;
    NSString *_hostVideo;
    NSString *_clienteVideo;
    BOOL _listo;

    BOOL _bucle;
    float _velocidad;
    BOOL _reanudado;
    float _volumenInicial;
    NSInteger _porcentajeDescarga;

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
        video.titulo = titulo.length ? titulo : @"Video descargado";
        _video = video;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Reproduciendo";
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

    // Con el interruptor de silencio activado tambien suena, y sigue sonando
    // con la pantalla apagada (es lo que hace util la pantalla de bloqueo).
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    [self prepararMandosRemotos];

    if (_rutaLocal.length) {
        _estado.text = @"Fichero descargado: se reproduce desde el dispositivo.";
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

    _reproductor = [[AVPlayerViewController alloc] init];
    _reproductor.showsPlaybackControls = YES;
    _reproductor.videoGravity = AVLayerVideoGravityResizeAspect;
    [self addChildViewController:_reproductor];
    [_caja addSubview:_reproductor.view];
    [_reproductor didMoveToParentViewController:self];

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

    // Gestos clasicos del reproductor de YouTube.
    UITapGestureRecognizer *dobleToque =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tocarDosVeces:)];
    dobleToque.numberOfTapsRequired = 2;
    [_caja addGestureRecognizer:dobleToque];

    UIPanGestureRecognizer *arrastre =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(arrastrarVolumen:)];
    [_caja addGestureRecognizer:arrastre];

    _acciones = [[UIScrollView alloc] init];
    _acciones.showsHorizontalScrollIndicator = NO;
    _acciones.alwaysBounceHorizontal = YES;
    [_cabecera addSubview:_acciones];

    _botonAtras     = [self anadirBoton:@"-10 s"        accion:@selector(saltarAtras)];
    _botonAdelante  = [self anadirBoton:@"+10 s"        accion:@selector(saltarAdelante)];
    _botonVelocidad = [self anadirBoton:@"Velocidad 1x" accion:@selector(cambiarVelocidad)];
    _botonBucle     = [self anadirBoton:@"Bucle: no"    accion:@selector(alternarBucle)];
    _botonDescargar = [self anadirBoton:@"Descargar"    accion:@selector(descargar)];
    _botonCompartir = [self anadirBoton:@"Compartir"    accion:@selector(compartir)];
    if (_rutaLocal.length) _botonDescargar.hidden = YES;

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

    _estado = [[UILabel alloc] init];
    _estado.numberOfLines = 0;
    _estado.font = [UIFont systemFontOfSize:13.0];
    _estado.textColor = [YTTheme textoSecundario];
    [_cabecera addSubview:_estado];

    _reintentar = [UIButton buttonWithType:UIButtonTypeSystem];
    [_reintentar setTitle:@"Reintentar" forState:UIControlStateNormal];
    [_reintentar setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _reintentar.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _reintentar.backgroundColor = [YTTheme acento];
    _reintentar.layer.cornerRadius = 10.0;
    _reintentar.hidden = YES;
    [_reintentar addTarget:self action:@selector(resolver) forControlEvents:UIControlEventTouchUpInside];
    [_cabecera addSubview:_reintentar];
}

- (UIButton *)anadirBoton:(NSString *)titulo accion:(SEL)accion {
    UIButton *boton = [UIButton buttonWithType:UIButtonTypeSystem];
    [boton setTitle:titulo forState:UIControlStateNormal];
    boton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [YTTheme aplicarEstiloChip:boton seleccionado:NO];
    [boton addTarget:self action:accion forControlEvents:UIControlEventTouchUpInside];
    [_acciones addSubview:boton];
    return boton;
}

- (void)viewWillAppear:(BOOL)animado {
    [super viewWillAppear:animado];
    [UIApplication sharedApplication].idleTimerDisabled = YES;   // que no se apague viendo un video
}

- (void)viewWillDisappear:(BOOL)animado {
    [super viewWillDisappear:animado];
    [self guardarProgreso];
    [_reproductor.player pause];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)dealloc {
    [_vigilante invalidate];
    [_latido invalidate];
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
    _caja.frame = CGRectMake(0, 0, ancho, floor(ancho * 9.0 / 16.0));
    _reproductor.view.frame = _caja.bounds;
    _girador.center = CGPointMake(CGRectGetMidX(_caja.bounds), CGRectGetMidY(_caja.bounds));

    CGFloat y = CGRectGetMaxY(_caja.frame) + 12.0;
    _acciones.frame = CGRectMake(0, y, ancho, 36.0);
    [self colocarBotones];
    y = CGRectGetMaxY(_acciones.frame) + 14.0;

    CGFloat margen = 14.0;
    CGFloat util = ancho - margen * 2.0;
    _titulo.frame = CGRectMake(margen, y, util, 44.0);
    y = CGRectGetMaxY(_titulo.frame) + 2.0;
    _autor.frame = CGRectMake(margen, y, util, 18.0);
    y = CGRectGetMaxY(_autor.frame) + 10.0;

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
    [self colocarAviso];
}

- (void)colocarBotones {
    CGFloat x = 14.0;
    for (UIView *vista in _acciones.subviews) {
        if (![vista isKindOfClass:[UIButton class]] || vista.hidden) continue;
        UIButton *boton = (UIButton *)vista;
        CGSize tamano = [boton sizeThatFits:CGSizeMake(320.0, 30.0)];
        CGFloat ancho = MAX(64.0, tamano.width + 24.0);
        boton.frame = CGRectMake(x, 3.0, ancho, 30.0);
        x += ancho + 8.0;
    }
    _acciones.contentSize = CGSizeMake(x, 36.0);
}

- (void)colocarAviso {
    if (_aviso.hidden || _aviso.text.length == 0) return;
    CGSize tamano = [_aviso sizeThatFits:CGSizeMake(CGRectGetWidth(_caja.bounds) - 40.0, 60.0)];
    CGFloat ancho = MIN(tamano.width + 24.0, CGRectGetWidth(_caja.bounds) - 32.0);
    CGFloat alto = tamano.height + 12.0;
    _aviso.frame = CGRectMake(floor((CGRectGetWidth(_caja.bounds) - ancho) / 2.0),
                              floor(CGRectGetHeight(_caja.bounds) - alto - 16.0),
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

#pragma mark - Resolucion y reproduccion

- (void)resolver {
    if (_rutaLocal.length) {
        [self prepararElementoConURL:[NSURL fileURLWithPath:_rutaLocal]];
        return;
    }
    _reintentar.hidden = YES;
    _estado.text = @"Buscando el video...";
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
        NSString *enlace = info[@"url"];
        if ([(NSString *)info[@"titulo"] length]) {
            yo->_titulo.text = info[@"titulo"];
            yo->_video.titulo = info[@"titulo"];
        }
        if ([(NSString *)info[@"autor"] length]) {
            yo->_autor.text = info[@"autor"];
            yo->_video.canal = info[@"autor"];
        }
        if ([(NSString *)info[@"cliente"] length]) yo->_clienteVideo = info[@"cliente"];
        [yo reproducir:enlace];
    }];
}

- (void)reproducir:(NSString *)enlace {
    NSURL *url = [NSURL URLWithString:enlace];
    if (!url) {
        [self mostrarError:@"La direccion del video no es valida."];
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
    _hostVideo = url.host ?: @"fichero del dispositivo";
    _elemento = [AVPlayerItem playerItemWithURL:url];
    // Para que a 1,5x no suene acelerado como una ardilla.
    _elemento.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmSpectral;
    [_elemento addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    _observando = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(terminoElVideo:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:_elemento];

    if (!_reproductor.player) _reproductor.player = [[AVPlayer alloc] init];
    [_reproductor.player replaceCurrentItemWithPlayerItem:_elemento];
    [_reproductor.player play];
    [_girador startAnimating];
    _estado.text = @"Cargando...";
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
    _estado.text = [NSString stringWithFormat:@"Cargando... %.0f s   (%@)",
                    segundos, _hostVideo];
    if (segundos >= 30.0) {
        [_vigilante invalidate];
        _vigilante = nil;
        [self mostrarError:[NSString stringWithFormat:
            @"El video no llega a empezar.\n\nServidor: %@\n30 segundos sin recibir "
            @"nada.\n\nSuele ser el proveedor de Internet dando largas con "
            @"googlevideo.com, o que YouTube pida iniciar sesion. Prueba "
            @"Ajustes > Iniciar sesion en YouTube, o el modo relay.", _hostVideo]];
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
            NSString *detalle = fallo.localizedDescription ?: @"error desconocido";
            NSInteger codigo = fallo.code;
            NSString *pista = @"";
            if (codigo == -11850 || codigo == -11800) {
                pista = @"\n\nYouTube ha rechazado la descarga (403). Inicia sesion en "
                        @"Ajustes para que las peticiones vayan autenticadas.";
            }
            [self mostrarError:[NSString stringWithFormat:@"No se pudo reproducir.\n%@%@",
                                detalle, pista]];
        }
    });
}

- (void)yaEstaListo {
    [_vigilante invalidate];
    _vigilante = nil;
    [_girador stopAnimating];
    _listo = YES;

    if (_velocidad != 1.0f) _reproductor.player.rate = _velocidad;

    double total = CMTimeGetSeconds(_elemento.duration);
    NSString *extra = _clienteVideo.length
        ? [NSString stringWithFormat:@"\n\nResuelto con el cliente %@.", _clienteVideo]
        : @"";
    if (_rutaLocal.length) {
        _estado.text = @"Reproduciendo desde el dispositivo.";
    } else {
        _estado.text = [NSString stringWithFormat:
            @"MP4 360p (los iPhone de 32 bits no decodifican VP9 ni AV1, por eso no "
             "hay 720p).%@\n\nDos toques en el video: 10 s atras o adelante. "
             "Arrastra arriba/abajo para el volumen.", extra];
    }
    [self ajustarCabecera];
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
        [_reproductor.player seekToTime:CMTimeMakeWithSeconds(guardado, 600.0)
                        toleranceBefore:kCMTimeZero
                           toleranceAfter:kCMTimeZero
                        completionHandler:^(BOOL terminado) {
            YTPlayerViewController *yo = deb;
            if (!yo) return;
            [yo->_reproductor.player play];
            if (yo->_velocidad != 1.0f) yo->_reproductor.player.rate = yo->_velocidad;
            [yo mostrarAviso:[NSString stringWithFormat:@"Sigo donde lo dejaste (%d:%02d)",
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
    if (_reproductor.player.rate < 0.01f) return;   // en pausa no se toca el apunte

    double actual = CMTimeGetSeconds(_reproductor.player.currentTime);
    double total = CMTimeGetSeconds(_elemento.duration);
    if (isnan(actual) || actual <= 0.0) return;
    if (isnan(total)) total = 0.0;
    [YTProgreso guardarVideo:_video segundos:actual total:total];
    [self actualizarInfoBloqueo];
}

- (void)terminoElVideo:(NSNotification *)nota {
    if (_bucle) {
        [_reproductor.player seekToTime:kCMTimeZero];
        [_reproductor.player play];
        if (_velocidad != 1.0f) _reproductor.player.rate = _velocidad;
        return;
    }
    if (_video.identificador.length) [YTProgreso olvidar:_video.identificador];
    _estado.text = @"El video ha terminado.";
    [self ajustarCabecera];
    [self actualizarInfoBloqueo];
    [self mostrarAviso:@"Fin del video"];
}

#pragma mark - Gestos y controles

- (void)tocarDosVeces:(UITapGestureRecognizer *)gesto {
    if (gesto.state != UIGestureRecognizerStateEnded) return;
    CGPoint punto = [gesto locationInView:_caja];
    if (punto.x < CGRectGetMidX(_caja.bounds)) [self saltarAtras];
    else [self saltarAdelante];
}

- (void)arrastrarVolumen:(UIPanGestureRecognizer *)gesto {
    if (!_reproductor.player) return;
    if (gesto.state == UIGestureRecognizerStateBegan) {
        _volumenInicial = _reproductor.player.volume;
        return;
    }
    if (gesto.state != UIGestureRecognizerStateChanged &&
        gesto.state != UIGestureRecognizerStateEnded) return;

    CGPoint traslacion = [gesto translationInView:_caja];
    float volumen = _volumenInicial - (float)(traslacion.y / 220.0);
    if (volumen < 0.0f) volumen = 0.0f;
    if (volumen > 1.0f) volumen = 1.0f;
    _reproductor.player.volume = volumen;
    [self mostrarAviso:[NSString stringWithFormat:@"Volumen %d %%",
                        (int)roundf(volumen * 100.0f)]];
}

- (void)saltarAtras { [self saltar:-10.0]; }
- (void)saltarAdelante { [self saltar:10.0]; }

- (void)saltar:(double)segundos {
    if (!_elemento || !_reproductor.player) return;
    double actual = CMTimeGetSeconds(_reproductor.player.currentTime);
    double total = CMTimeGetSeconds(_elemento.duration);
    double destino = actual + segundos;
    if (isnan(destino)) destino = 0.0;
    if (destino < 0.0) destino = 0.0;
    if (!isnan(total) && total > 1.0 && destino > total - 1.0) destino = total - 1.0;

    // El bloque de final no puede ser nil: AVFoundation lo exige.
    [_reproductor.player seekToTime:CMTimeMakeWithSeconds(destino, 600.0)
                    toleranceBefore:kCMTimeZero
                       toleranceAfter:kCMTimeZero
                    completionHandler:^(BOOL terminado) { }];
    [self mostrarAviso:(segundos < 0.0 ? @"-10 s" : @"+10 s")];
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
    if (_reproductor.player && _reproductor.player.rate > 0.01f) {
        _reproductor.player.rate = _velocidad;
    }
    [_botonVelocidad setTitle:[NSString stringWithFormat:@"Velocidad %gx", _velocidad]
                     forState:UIControlStateNormal];
    [self colocarBotones];
    [self ajustarCabecera];
    [self mostrarAviso:[NSString stringWithFormat:@"Velocidad %gx", _velocidad]];
}

- (void)alternarBucle {
    _bucle = !_bucle;
    [_botonBucle setTitle:(_bucle ? @"Bucle: si" : @"Bucle: no")
                 forState:UIControlStateNormal];
    [YTTheme aplicarEstiloChip:_botonBucle seleccionado:_bucle];
    [self colocarBotones];
    [self ajustarCabecera];
    [self mostrarAviso:(_bucle ? @"Se repetira el video" : @"Ya no se repite")];
}

- (void)compartir {
    NSString *enlace = _rutaLocal.length
        ? _rutaLocal
        : [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@",
           _video.identificador ?: @""];
    UIActivityViewController *hoja = [[UIActivityViewController alloc]
        initWithActivityItems:@[ enlace ] applicationActivities:nil];
    if (hoja.popoverPresentationController) {
        hoja.popoverPresentationController.sourceView = _botonCompartir;
        hoja.popoverPresentationController.sourceRect = _botonCompartir.bounds;
    }
    [self presentViewController:hoja animated:YES completion:nil];
}

#pragma mark - Descargar

- (void)descargar {
    if (_rutaLocal.length) {
        [self mostrarAviso:@"Ya esta descargado"];
        return;
    }
    if (_video.identificador.length == 0) return;

    YTDescargas *gestor = [YTDescargas compartido];

    if ([gestor estaDescargando:_video.identificador]) {
        [gestor cancelarVideo:_video.identificador];
        [_botonDescargar setTitle:@"Descargar" forState:UIControlStateNormal];
        [self colocarBotones];
        [self ajustarCabecera];
        [self mostrarAviso:@"Descarga cancelada"];
        return;
    }

    [_botonDescargar setTitle:@"Preparando..." forState:UIControlStateNormal];
    [self colocarBotones];
    [self ajustarCabecera];
    _porcentajeDescarga = -1;

    __weak YTPlayerViewController *deb = self;
    [gestor descargarVideo:_video
        progreso:^(double fraccion) {
            YTPlayerViewController *yo = deb;
            if (!yo) return;
            // Solo se repinta cuando cambia el numero entero: si no, la fila de
            // botones se recolocaria cientos de veces por minuto.
            NSInteger porcentaje = fraccion > 0.0 ? (NSInteger)round(fraccion * 100.0) : -1;
            if (porcentaje == yo->_porcentajeDescarga) return;
            yo->_porcentajeDescarga = porcentaje;
            NSString *texto = porcentaje >= 0
                ? [NSString stringWithFormat:@"%ld %%  (toca para cancelar)", (long)porcentaje]
                : @"Descargando...";
            [yo->_botonDescargar setTitle:texto forState:UIControlStateNormal];
            [yo colocarBotones];
            [yo ajustarCabecera];
        }
        completion:^(BOOL ok, NSString *mensaje, NSString *ruta) {
            YTPlayerViewController *yo = deb;
            if (!yo) return;
            [yo->_botonDescargar setTitle:@"Descargar" forState:UIControlStateNormal];
            [yo colocarBotones];
            [yo ajustarCabecera];

            UIAlertController *alerta = [UIAlertController
                alertControllerWithTitle:(ok ? @"Descarga terminada" : @"No se pudo descargar")
                                 message:mensaje
                          preferredStyle:UIAlertControllerStyleAlert];
            [alerta addAction:[UIAlertAction actionWithTitle:@"Vale"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil]];
            if (ok) {
                [alerta addAction:[UIAlertAction actionWithTitle:@"Ver descargas"
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
        [yo->_reproductor.player play];
        if (yo->_velocidad != 1.0f) yo->_reproductor.player.rate = yo->_velocidad;
        [yo actualizarInfoBloqueo];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    _mandoPause = [centro.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) {
        YTPlayerViewController *yo = deb;
        if (!yo) return MPRemoteCommandHandlerStatusCommandFailed;
        [yo->_reproductor.player pause];
        [yo guardarProgreso];
        [yo actualizarInfoBloqueo];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    _mandoAlternar = [centro.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *e) {
        YTPlayerViewController *yo = deb;
        if (!yo) return MPRemoteCommandHandlerStatusCommandFailed;
        if (yo->_reproductor.player.rate > 0.01f) {
            [yo->_reproductor.player pause];
            [yo guardarProgreso];
        } else {
            [yo->_reproductor.player play];
            if (yo->_velocidad != 1.0f) yo->_reproductor.player.rate = yo->_velocidad;
        }
        [yo actualizarInfoBloqueo];
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
    double actual = CMTimeGetSeconds(_reproductor.player.currentTime);

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = _titulo.text.length ? _titulo.text : @"Tube9";
    if (_autor.text.length) info[MPMediaItemPropertyArtist] = _autor.text;
    if (total > 0.0 && !isnan(total)) info[MPMediaItemPropertyPlaybackDuration] = @(total);
    if (actual > 0.0 && !isnan(actual)) info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(actual);
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(_reproductor.player.rate);
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
    return @"Parecidos";
}

- (NSString *)tableView:(UITableView *)tabla titleForFooterInSection:(NSInteger)seccion {
    if (_relacionados.count == 0) return nil;
    return @"Esta lista sale de buscar el titulo del video: la lista oficial de "
            "relacionados de YouTube pesa unos 7 MB y no cabe en un telefono de "
            "32 bits.";
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
        celda.textLabel.text = @"Buscando videos parecidos...";
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
    [self ajustarCabecera];
}

@end
