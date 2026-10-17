// YTPlayerViewController.m -- resuelve la URL y reproduce con AVPlayer
#import "YTPlayerViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface YTPlayerViewController ()
@end

@implementation YTPlayerViewController {
    YTVideo *_video;
    UIView *_caja;
    AVPlayerViewController *_reproductor;
    UILabel *_titulo;
    UILabel *_autor;
    UILabel *_estado;
    UIButton *_reintentar;
    UIActivityIndicatorView *_girador;
    AVPlayerItem *_elemento;
    BOOL _observando;
    NSTimer *_vigilante;      // evita quedarse en "Cargando..." para siempre
    NSDate *_inicioCarga;
    NSString *_hostVideo;
}

- (instancetype)initWithVideo:(YTVideo *)video {
    self = [super init];
    if (self) {
        _video = video;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Reproduciendo";
    self.view.backgroundColor = [YTTheme fondo];

    _caja = [[UIView alloc] initWithFrame:CGRectZero];
    _caja.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_caja];

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

    _titulo = [[UILabel alloc] initWithFrame:CGRectZero];
    _titulo.numberOfLines = 2;
    _titulo.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    _titulo.textColor = [YTTheme textoPrimario];
    _titulo.text = _video.titulo;
    [self.view addSubview:_titulo];

    _autor = [[UILabel alloc] initWithFrame:CGRectZero];
    _autor.font = [UIFont systemFontOfSize:13.0];
    _autor.textColor = [YTTheme textoSecundario];
    _autor.text = _video.canal;
    [self.view addSubview:_autor];

    _estado = [[UILabel alloc] initWithFrame:CGRectZero];
    _estado.numberOfLines = 0;
    _estado.font = [UIFont systemFontOfSize:13.0];
    _estado.textColor = [YTTheme textoSecundario];
    [self.view addSubview:_estado];

    _reintentar = [UIButton buttonWithType:UIButtonTypeSystem];
    [_reintentar setTitle:@"Reintentar" forState:UIControlStateNormal];
    [_reintentar setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _reintentar.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _reintentar.backgroundColor = [YTTheme acento];
    _reintentar.layer.cornerRadius = 10.0;
    _reintentar.hidden = YES;
    [_reintentar addTarget:self action:@selector(resolver) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_reintentar];

    // Que el audio suene aunque el interruptor de silencio este activado
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    [self resolver];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat ancho = CGRectGetWidth(self.view.bounds);
    CGFloat altoCaja = floor(ancho * 9.0 / 16.0);
    _caja.frame = CGRectMake(0, 0, ancho, altoCaja);
    _reproductor.view.frame = _caja.bounds;
    _girador.center = CGPointMake(CGRectGetMidX(_caja.bounds), CGRectGetMidY(_caja.bounds));

    CGFloat y = CGRectGetMaxY(_caja.frame) + 18.0;
    CGFloat margen = 18.0;
    _titulo.frame = CGRectMake(margen, y, ancho - margen * 2.0, 44.0);
    y = CGRectGetMaxY(_titulo.frame) + 2.0;
    _autor.frame = CGRectMake(margen, y, ancho - margen * 2.0, 20.0);
    y = CGRectGetMaxY(_autor.frame) + 16.0;
    _estado.frame = CGRectMake(margen, y, ancho - margen * 2.0, 96.0);
    _reintentar.frame = CGRectMake(margen, CGRectGetMaxY(_estado.frame) + 10.0,
                                   ancho - margen * 2.0, 44.0);
}

#pragma mark - Resolucion y reproduccion

- (void)resolver {
    _reintentar.hidden = YES;
    _estado.text = @"Buscando el video...";
    [_girador startAnimating];

    NSString *identificador = _video.identificador;
    __weak YTPlayerViewController *deb = self;
    [[YTClient compartido] resolverVideo:identificador
        completion:^(NSDictionary *info, NSError *error) {
        YTPlayerViewController *yo = deb;   // ARC no deja usar '->' sobre un __weak
        if (!yo) return;
        if (error) {
            [yo mostrarError:[YTClient explicarError:error]];
            return;
        }
        NSString *enlace = info[@"url"];
        if (info[@"titulo"] && [(NSString *)info[@"titulo"] length]) {
            yo->_titulo.text = info[@"titulo"];
        }
        if (info[@"autor"] && [(NSString *)info[@"autor"] length]) {
            yo->_autor.text = info[@"autor"];
        }
        [yo reproducir:enlace];
    }];
}

- (void)reproducir:(NSString *)enlace {
    NSURL *url = [NSURL URLWithString:enlace];
    if (!url) {
        [self mostrarError:@"La URL del video no es valida."];
        return;
    }

    if (_observando && _elemento) {
        [_elemento removeObserver:self forKeyPath:@"status"];
        _observando = NO;
    }

    _hostVideo = url.host ?: @"desconocido";
    _elemento = [AVPlayerItem playerItemWithURL:url];
    [_elemento addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    _observando = YES;

    _reproductor.player = [AVPlayer playerWithPlayerItem:_elemento];
    [_reproductor.player play];

    // AVPlayer no avisa cuando el servidor de video no contesta: se queda en
    // "Cargando..." indefinidamente y desde fuera parece que la app se ha
    // colgado. Este vigilante muestra los segundos que lleva y, a los 30 s,
    // da un error util en lugar de quedarse mudo.
    _inicioCarga = [NSDate date];
    [_vigilante invalidate];
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

    // La notificacion puede llegar desde una cola interna de AVFoundation, y
    // la interfaz solo se puede tocar desde el hilo principal.
    AVPlayerItemStatus estado = _elemento.status;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (estado == AVPlayerItemStatusReadyToPlay) {
            [self->_vigilante invalidate];
            self->_vigilante = nil;
            [self->_girador stopAnimating];
            self->_estado.text = @"Reproduciendo en la mejor calidad disponible (MP4 360p).\n\n"
                                 @"Los dispositivos de 32 bits no pueden decodificar VP9 ni AV1, "
                                 @"por eso no hay 720p.";
        } else if (estado == AVPlayerItemStatusFailed) {
            [self->_vigilante invalidate];
            self->_vigilante = nil;
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

- (void)mostrarError:(NSString *)texto {
    [_vigilante invalidate];
    _vigilante = nil;
    [_girador stopAnimating];
    _estado.text = texto;
    _reintentar.hidden = NO;
}

- (void)dealloc {
    [_vigilante invalidate];
    if (_observando && _elemento) {
        [_elemento removeObserver:self forKeyPath:@"status"];
    }
    [_reproductor.player pause];
}

@end
