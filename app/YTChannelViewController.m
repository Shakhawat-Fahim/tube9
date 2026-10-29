// v1.0-en 2026-10-29: English UI build (textos traducidos al ingles; hl=en, gl=US)
// YTChannelViewController.m -- la ficha de un canal.
//
// Se monta en dos tiempos, y a proposito:
//
//   1) Al abrir se pide la pagina del canal (una sola peticion). De ahi salen
//      la portada, el avatar, el nombre, los suscriptores y, de regalo, los
//      estantes del "Inicio" con un monton de videos. Con eso ya se puede
//      navegar: si no se toca nada mas, no se pide nada mas.
//   2) Las pestanas Listas e Informacion se piden SOLO al abrirlas, y quedan
//      guardadas para no repetir la peticion.
//
// Todo lo que se ve sale de YouTube tal cual: aqui no se inventa nada.
#import "YTChannelViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTVideoCell.h"
#import "YTListaCell.h"
#import "YTPlayerViewController.h"
#import "YTListaViewController.h"

static const CGFloat YTMargen = 14.0;
static const CGFloat YTAltoPortada = 96.0;
static const CGFloat YTLadoAvatar = 64.0;

@interface YTChannelViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation YTChannelViewController {
    NSString *_canalId;
    NSString *_nombreRespaldo;
    NSDictionary *_canal;

    UITableView *_tabla;
    UIView *_cabecera;
    UIImageView *_portada;
    UIImageView *_avatar;
    UILabel *_inicial;              // mientras no llega la foto
    UILabel *_nombre;
    UILabel *_datos;                // "@kurzgesagt · 2,36 M de suscriptores"
    UIButton *_suscribirse;
    UIButton *_compartir;
    UISegmentedControl *_pestanas;

    UIActivityIndicatorView *_girador;
    UILabel *_estado;

    // La tabla va por secciones, y cada seccion tiene filas. Cada fila es un
    // diccionario con "tipo" (video / lista / texto) y "dato".
    NSArray *_secciones;
    NSArray *_clavesPestana;        // "videos", "listas", "info"
    NSMutableSet *_pedidas;         // pestanas ya pedidas
    NSInteger _pestanaElegida;
    BOOL _pidiendo;
}

#pragma mark - Arranque

- (instancetype)initWithCanalId:(NSString *)canalId titulo:(NSString *)titulo {
    self = [super init];
    if (self) {
        _canalId = [canalId copy];
        _nombreRespaldo = [titulo copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _nombreRespaldo.length ? _nombreRespaldo : @"Channel";
    self.view.backgroundColor = [YTTheme fondo];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

    _pedidas = [NSMutableSet set];
    _secciones = @[];

    _tabla = [[UITableView alloc] initWithFrame:self.view.bounds
                                         style:UITableViewStylePlain];
    _tabla.dataSource = self;
    _tabla.delegate = self;
    _tabla.backgroundColor = [YTTheme fondo];
    _tabla.separatorColor = [YTTheme borde];
    _tabla.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tabla];

    [self montarCabecera];

    _girador = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _girador.color = [YTTheme acento];
    _girador.hidesWhenStopped = YES;
    [self.view addSubview:_girador];

    _estado = [[UILabel alloc] init];
    _estado.numberOfLines = 0;
    _estado.textAlignment = NSTextAlignmentCenter;
    _estado.textColor = [YTTheme textoSecundario];
    _estado.font = [YTTheme fuenteCuerpo];
    [self.view addSubview:_estado];

    [self cargarCanal];
}

- (void)montarCabecera {
    _cabecera = [[UIView alloc] init];
    _cabecera.backgroundColor = [YTTheme fondo];

    _portada = [[UIImageView alloc] init];
    _portada.backgroundColor = [YTTheme superficieAlta];
    _portada.contentMode = UIViewContentModeScaleAspectFill;
    _portada.clipsToBounds = YES;
    [_cabecera addSubview:_portada];

    _avatar = [[UIImageView alloc] init];
    _avatar.backgroundColor = [YTTheme superficieAlta];
    _avatar.contentMode = UIViewContentModeScaleAspectFill;
    _avatar.clipsToBounds = YES;
    _avatar.layer.cornerRadius = YTLadoAvatar / 2.0;
    _avatar.layer.borderWidth = 3.0;
    _avatar.layer.borderColor = [YTTheme fondo].CGColor;
    [_cabecera addSubview:_avatar];

    _inicial = [[UILabel alloc] init];
    _inicial.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold];
    _inicial.textColor = [YTTheme textoSecundario];
    _inicial.textAlignment = NSTextAlignmentCenter;
    if (_nombreRespaldo.length) {
        _inicial.text = [[_nombreRespaldo substringToIndex:1] uppercaseString];
    }
    [_cabecera addSubview:_inicial];

    _nombre = [[UILabel alloc] init];
    _nombre.numberOfLines = 1;
    _nombre.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    _nombre.textColor = [YTTheme textoPrimario];
    _nombre.text = _nombreRespaldo;
    [_cabecera addSubview:_nombre];

    _datos = [[UILabel alloc] init];
    _datos.numberOfLines = 1;
    _datos.font = [YTTheme fuenteMenuda];
    _datos.textColor = [YTTheme textoSecundario];
    [_cabecera addSubview:_datos];

    _suscribirse = [UIButton buttonWithType:UIButtonTypeCustom];
    [_suscribirse setTitle:@"Subscribe" forState:UIControlStateNormal];
    [_suscribirse setTitleColor:[YTTheme textoSobreAcento] forState:UIControlStateNormal];
    _suscribirse.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _suscribirse.backgroundColor = [YTTheme acento];
    _suscribirse.layer.cornerRadius = 17.0;
    _suscribirse.layer.masksToBounds = YES;
    [_suscribirse addTarget:self action:@selector(suscribirse)
           forControlEvents:UIControlEventTouchUpInside];
    [_cabecera addSubview:_suscribirse];

    _compartir = [UIButton buttonWithType:UIButtonTypeCustom];
    [_compartir setTitle:@"Share" forState:UIControlStateNormal];
    _compartir.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [_compartir addTarget:self action:@selector(compartir)
         forControlEvents:UIControlEventTouchUpInside];
    [YTTheme aplicarEstiloChip:_compartir seleccionado:NO];
    _compartir.layer.cornerRadius = 17.0;
    [_cabecera addSubview:_compartir];
}

#pragma mark - Carga de la ficha

- (void)cargarCanal {
    if (_pidiendo) return;
    _pidiendo = YES;
    [_girador startAnimating];
    _estado.hidden = NO;
    _estado.text = @"Loading the channel...";

    __weak YTChannelViewController *deb = self;
    [[YTClient compartido] canalConId:_canalId
        completion:^(NSDictionary *canal, NSError *error) {
        YTChannelViewController *yo = deb;
        if (!yo) return;
        yo->_pidiendo = NO;
        [yo->_girador stopAnimating];

        if (error || canal == nil) {
            yo->_estado.hidden = NO;
            yo->_estado.text = [NSString stringWithFormat:@"%@\n\n%@",
                [YTClient explicarError:error],
                @"Open the channel again to try once more."];
            return;
        }

        yo->_canal = canal;
        [yo pintarCabecera];
        [yo montarPestanas];
        [yo pedirPestana];
    }];
}

- (void)pintarCabecera {
    __weak YTChannelViewController *deb = self;

    NSString *titulo = _canal[@"titulo"];
    if ([titulo isKindOfClass:[NSString class]] && titulo.length) {
        _nombre.text = titulo;
        self.title = titulo;
        _inicial.text = [[titulo substringToIndex:1] uppercaseString];
    }

    NSMutableArray *partes = [NSMutableArray array];
    NSString *manejador = _canal[@"manejador"];
    if ([manejador isKindOfClass:[NSString class]] && manejador.length) [partes addObject:manejador];
    NSString *suscritos = _canal[@"suscritos"];
    if ([suscritos isKindOfClass:[NSString class]] && suscritos.length) [partes addObject:suscritos];
    NSString *videos = _canal[@"videos"];
    if ([videos isKindOfClass:[NSString class]] && videos.length) [partes addObject:videos];
    _datos.text = [partes componentsJoinedByString:@"  ·  "];

    NSString *urlPortada = _canal[@"urlPortada"];
    if ([urlPortada isKindOfClass:[NSString class]] && urlPortada.length) {
        [YTClient cargarMiniatura:urlPortada completion:^(UIImage *imagen) {
            YTChannelViewController *yo = deb;
            if (yo && imagen) yo->_portada.image = imagen;
        }];
    }

    NSString *urlAvatar = _canal[@"urlAvatar"];
    if ([urlAvatar isKindOfClass:[NSString class]] && urlAvatar.length) {
        [YTClient cargarMiniatura:urlAvatar completion:^(UIImage *imagen) {
            YTChannelViewController *yo = deb;
            if (yo && imagen) {
                yo->_avatar.image = imagen;
                yo->_inicial.hidden = YES;
            }
        }];
    }

    [self.view setNeedsLayout];
}

// Las pestanas se montan segun lo que YouTube haya mandado en la ficha: si el
// canal no tiene listas, no se enseña la pestana de listas.
- (void)montarPestanas {
    NSMutableArray *claves = [NSMutableArray array];
    NSMutableArray *titulos = [NSMutableArray array];

    // "Videos" siempre esta.
    [claves addObject:@"videos"];
    [titulos addObject:@"Videos"];

    NSArray *listasInicio = _canal[@"listasDestacadas"];
    BOOL hayListas = NO;
    if ([(NSString *)_canal[@"paramsListas"] length] > 0) hayListas = YES;
    if ([listasInicio isKindOfClass:[NSArray class]] && listasInicio.count > 0) hayListas = YES;
    if (hayListas) {
        [claves addObject:@"listas"];
        [titulos addObject:@"Playlists"];
    }

    if ([(NSString *)_canal[@"paramsInfo"] length] > 0) {
        [claves addObject:@"info"];
        [titulos addObject:@"About"];
    }

    _clavesPestana = claves;
    _pestanaElegida = 0;

    _pestanas = [[UISegmentedControl alloc] initWithItems:titulos];
    _pestanas.selectedSegmentIndex = 0;
    _pestanas.tintColor = [YTTheme acento];
    [_pestanas setTitleTextAttributes:@{ NSForegroundColorAttributeName : [YTTheme textoPrimario] }
                             forState:UIControlStateNormal];
    [_pestanas setTitleTextAttributes:@{ NSForegroundColorAttributeName : [YTTheme textoSobreAcento] }
                             forState:UIControlStateSelected];
    [_pestanas addTarget:self action:@selector(cambiarPestana:)
        forControlEvents:UIControlEventValueChanged];
    [_cabecera addSubview:_pestanas];

    [self.view setNeedsLayout];
}

- (void)cambiarPestana:(UISegmentedControl *)control {
    _pestanaElegida = control.selectedSegmentIndex;
    _secciones = @[];
    [_tabla reloadData];
    _estado.hidden = YES;
    [self pedirPestana];
}

#pragma mark - Contenido de cada pestana

- (void)pedirPestana {
    if (_pestanaElegida < 0 || _pestanaElegida >= (NSInteger)_clavesPestana.count) return;
    NSString *clave = _clavesPestana[_pestanaElegida];
    if ([_pedidas containsObject:clave]) return;
    [_pedidas addObject:clave];

    if ([clave isEqualToString:@"videos"]) { [self cargarVideos]; return; }
    if ([clave isEqualToString:@"listas"]) { [self cargarListas]; return; }
    [self cargarInformacion];
}

- (void)cargarVideos {
    // El "Inicio" del canal ya viene con sus estantes de videos dentro de la
    // ficha, asi que la pestana de videos no necesita ni una peticion mas.
    NSArray *estantes = _canal[@"estantes"];
    if ([estantes isKindOfClass:[NSArray class]] && estantes.count > 0) {
        [self pintarEstantes:estantes];
        return;
    }

    NSString *params = _canal[@"paramsVideos"];
    if ([(NSString *)params length] == 0) {
        NSArray *sueltos = _canal[@"videosDestacados"];
        _secciones = [self seccionesConVideos:(sueltos ?: @[])];
        [self terminarConMensaje:@"This channel shows no single videos; look in its playlists."];
        return;
    }

    [self empezarCarga:@"Loading videos..."];
    __weak YTChannelViewController *deb = self;
    [[YTClient compartido] videosDeCanal:_canalId
                                  params:params
                              completion:^(NSArray *videos, NSError *error) {
        YTChannelViewController *yo = deb;
        if (!yo) return;
        if (error) { [yo fallo:[YTClient explicarError:error] clave:@"videos"]; return; }
        yo->_secciones = [yo seccionesConVideos:videos];
        [yo terminarConMensaje:@"This channel has no visible videos."];
    }];
}

- (void)cargarListas {
    NSArray *destacadas = _canal[@"listasDestacadas"];
    if (![destacadas isKindOfClass:[NSArray class]]) destacadas = @[];

    NSString *params = _canal[@"paramsListas"];
    if ([(NSString *)params length] == 0) {
        _secciones = [self seccionesConListas:destacadas];
        [self terminarConMensaje:@"This channel has no playlists."];
        return;
    }

    [self empezarCarga:@"Loading playlists..."];
    __weak YTChannelViewController *deb = self;
    [[YTClient compartido] listasDeCanal:_canalId
                                  params:params
                              completion:^(NSArray *listas, NSError *error) {
        YTChannelViewController *yo = deb;
        if (!yo) return;
        if (error) { [yo fallo:[YTClient explicarError:error] clave:@"listas"]; return; }

        NSArray *secciones = [yo seccionesConListas:listas];
        // Si YouTube no devolviera nada, al menos queda lo que venia en el Inicio.
        if (secciones.count == 0 && destacadas.count > 0) {
            secciones = [yo seccionesConListas:destacadas];
        }
        yo->_secciones = secciones;
        [yo terminarConMensaje:@"This channel has no playlists."];
    }];
}

- (void)cargarInformacion {
    NSString *params = _canal[@"paramsInfo"];
    if ([(NSString *)params length] == 0) {
        _secciones = [self seccionesDeInformacion:@{}];
        [self terminarConMensaje:@"No information for this channel."];
        return;
    }

    [self empezarCarga:@"Loading information..."];
    __weak YTChannelViewController *deb = self;
    [[YTClient compartido] informacionDeCanal:_canalId
                                       params:params
                                   completion:^(NSDictionary *info, NSError *error) {
        YTChannelViewController *yo = deb;
        if (!yo) return;
        if (error) { [yo fallo:[YTClient explicarError:error] clave:@"info"]; return; }
        yo->_secciones = [yo seccionesDeInformacion:info];
        [yo terminarConMensaje:@"No information for this channel."];
    }];
}

#pragma mark - Secciones

- (NSArray *)seccionesConVideos:(NSArray *)videos {
    if (![videos isKindOfClass:[NSArray class]] || videos.count == 0) return @[];
    NSMutableArray *filas = [NSMutableArray array];
    for (YTVideo *video in videos) {
        if (![video isKindOfClass:[YTVideo class]]) continue;
        [filas addObject:@{ @"tipo" : @"video", @"dato" : video }];
    }
    if (filas.count == 0) return @[];
    return @[ @{ @"titulo" : @"", @"filas" : filas } ];
}

- (void)pintarEstantes:(NSArray *)estantes {
    NSMutableArray *secciones = [NSMutableArray array];
    for (NSDictionary *estante in estantes) {
        if (![estante isKindOfClass:[NSDictionary class]]) continue;
        NSArray *videos = estante[@"videos"];
        if (![videos isKindOfClass:[NSArray class]]) continue;

        NSMutableArray *filas = [NSMutableArray array];
        for (YTVideo *video in videos) {
            if (![video isKindOfClass:[YTVideo class]]) continue;
            [filas addObject:@{ @"tipo" : @"video", @"dato" : video }];
        }
        if (filas.count == 0) continue;

        NSString *titulo = estante[@"titulo"];
        [secciones addObject:@{ @"titulo" : ([titulo isKindOfClass:[NSString class]] ? titulo : @""),
                                @"filas" : filas }];
    }
    _secciones = secciones;
    [self terminarConMensaje:@"This channel has no public videos yet."];
}

- (NSArray *)seccionesConListas:(NSArray *)listas {
    if (![listas isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *filas = [NSMutableArray array];
    for (NSDictionary *lista in listas) {
        if (![lista isKindOfClass:[NSDictionary class]]) continue;
        [filas addObject:@{ @"tipo" : @"lista", @"dato" : lista }];
    }
    if (filas.count == 0) return @[];
    return @[ @{ @"titulo" : @"Playlists", @"filas" : filas } ];
}

- (NSArray *)seccionesDeInformacion:(NSDictionary *)info {
    if (![info isKindOfClass:[NSDictionary class]]) info = @{};
    NSMutableArray *filas = [NSMutableArray array];

    id descripcion = info[@"descripcion"];
    if ([descripcion isKindOfClass:[NSString class]] && [(NSString *)descripcion length] > 0) {
        [filas addObject:@{ @"tipo" : @"texto",
                            @"dato" : @{ @"titulo" : @"About the channel",
                                         @"cuerpo" : descripcion } }];
    }

    NSMutableArray *lineas = [NSMutableArray array];
    NSString *manejador = _canal[@"manejador"];
    if ([manejador isKindOfClass:[NSString class]] && manejador.length) [lineas addObject:manejador];

    NSString *suscritos = info[@"suscriptores"];
    if (![suscritos isKindOfClass:[NSString class]] || suscritos.length == 0) {
        suscritos = _canal[@"suscritos"];
    }
    if ([suscritos isKindOfClass:[NSString class]] && suscritos.length) {
        [lineas addObject:[NSString stringWithFormat:@"Subscribers: %@", suscritos]];
    }

    id visitas = info[@"visitas"];
    if ([visitas isKindOfClass:[NSString class]] && [(NSString *)visitas length]) {
        [lineas addObject:[NSString stringWithFormat:@"Views: %@", visitas]];
    }
    id alta = info[@"alta"];
    if ([alta isKindOfClass:[NSString class]] && [(NSString *)alta length]) {
        [lineas addObject:alta];   // "Se unio el 9 jul 2013"
    }
    id pais = info[@"pais"];
    if ([pais isKindOfClass:[NSString class]] && [(NSString *)pais length]) {
        [lineas addObject:[NSString stringWithFormat:@"Country: %@", pais]];
    }

    if (lineas.count) {
        [filas addObject:@{ @"tipo" : @"texto",
                            @"dato" : @{ @"titulo" : @"Details",
                                         @"cuerpo" : [lineas componentsJoinedByString:@"\n"] } }];
    }

    [filas addObject:@{ @"tipo" : @"texto",
                        @"dato" : @{ @"titulo" : @"Subscribe",
                                     @"cuerpo" : @"The \"Subscribe\" button above opens "
                                                 @"the channel page on YouTube with the "
                                                 @"confirmation already set, so you can "
                                                 @"subscribe with your account." } }];

    if (filas.count == 0) return @[];
    return @[ @{ @"titulo" : @"", @"filas" : filas } ];
}

#pragma mark - Estados

- (void)empezarCarga:(NSString *)mensaje {
    if (_secciones.count > 0) return;   // si ya hay contenido, no se tapa
    _estado.hidden = NO;
    _estado.text = mensaje;
    [_girador startAnimating];
}

- (void)terminarConMensaje:(NSString *)mensaje {
    [_girador stopAnimating];
    [_tabla reloadData];
    if (_secciones.count == 0) {
        _estado.hidden = NO;
        _estado.text = mensaje;
    } else {
        _estado.hidden = YES;
        _estado.text = nil;
    }
    [self.view setNeedsLayout];
}

- (void)fallo:(NSString *)texto clave:(NSString *)clave {
    [_pedidas removeObject:clave];   // asi se puede reintentar volviendo a la pestana
    [_girador stopAnimating];
    _estado.hidden = NO;
    _estado.text = [NSString stringWithFormat:@"%@\n\nTap another tab and come back to retry.",
                    texto];
    [_tabla reloadData];
    [self.view setNeedsLayout];
}

#pragma mark - Acciones

- (void)suscribirse {
    // Suscribirse por dentro exigiria tener la sesion de Google abierta dentro
    // de la aplicacion y, aun asi, YouTube no lo sirve por InnerTube. La via
    // honesta: su propia pagina, con la confirmacion ya puesta.
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:@"Subscribe"
                         message:@"Tube9 opens the channel page on YouTube with the "
                                 "subscribe confirmation already set: there, with your "
                                 "account signed in to Safari, you subscribe in one tap."
                  preferredStyle:UIAlertControllerStyleAlert];
    __weak YTChannelViewController *deb = self;
    [alerta addAction:[UIAlertAction actionWithTitle:@"Open YouTube"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *accion) {
        YTChannelViewController *yo = deb;
        if (!yo) return;
        NSString *enlace = [NSString stringWithFormat:
            @"https://www.youtube.com/channel/%@?sub_confirmation=1", yo->_canalId];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:enlace]];
    }]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)compartir {
    NSString *enlace = [NSString stringWithFormat:@"https://www.youtube.com/channel/%@",
                        _canalId];
    UIActivityViewController *hoja = [[UIActivityViewController alloc]
        initWithActivityItems:@[ enlace ] applicationActivities:nil];
    if (hoja.popoverPresentationController) {
        hoja.popoverPresentationController.sourceView = _compartir;
        hoja.popoverPresentationController.sourceRect = _compartir.bounds;
    }
    [self presentViewController:hoja animated:YES completion:nil];
}

- (void)abrirCanalConId:(NSString *)canalId titulo:(NSString *)titulo {
    if (canalId.length == 0) return;
    YTChannelViewController *canal = [[YTChannelViewController alloc]
        initWithCanalId:canalId titulo:titulo];
    canal.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:canal animated:YES];
}

#pragma mark - Colocacion

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.view.bounds);

    _portada.frame = CGRectMake(0, 0, ancho, YTAltoPortada);
    _avatar.frame = CGRectMake(YTMargen, YTAltoPortada - 32.0, YTLadoAvatar, YTLadoAvatar);
    _inicial.frame = _avatar.frame;

    CGFloat y = CGRectGetMaxY(_avatar.frame) + 8.0;
    _nombre.frame = CGRectMake(YTMargen, y, ancho - 2.0 * YTMargen, 24.0);
    _datos.frame = CGRectMake(YTMargen, CGRectGetMaxY(_nombre.frame) + 2.0,
                              ancho - 2.0 * YTMargen, 16.0);

    y = CGRectGetMaxY(_datos.frame) + 12.0;
    _suscribirse.frame = CGRectMake(YTMargen, y, 132.0, 34.0);
    _compartir.frame = CGRectMake(CGRectGetMaxX(_suscribirse.frame) + 8.0, y, 106.0, 34.0);

    CGFloat alto = CGRectGetMaxY(_suscribirse.frame) + 12.0;
    if (_pestanas) {
        _pestanas.frame = CGRectMake(YTMargen, alto, ancho - 2.0 * YTMargen, 32.0);
        alto = CGRectGetMaxY(_pestanas.frame) + 10.0;
    }

    // Si el alto ha cambiado hay que reasignar el tableHeaderView para que la
    // tabla lo tenga en cuenta (y para que no se entre en bucle, solo se hace
    // cuando de verdad cambia).
    if (fabs(alto - CGRectGetHeight(_cabecera.frame)) > 0.5) {
        _cabecera.frame = CGRectMake(0, 0, ancho, alto);
        _tabla.tableHeaderView = _cabecera;
    }

    CGFloat disponible = CGRectGetHeight(self.view.bounds) - alto;
    _girador.center = CGPointMake(CGRectGetMidX(self.view.bounds),
                                  alto + disponible / 2.0 - 24.0);
    _estado.frame = CGRectMake(28.0, alto, ancho - 56.0, MAX(80.0, disponible));
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tabla {
    return _secciones.count;
}

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    NSArray *filas = _secciones[seccion][@"filas"];
    return [filas isKindOfClass:[NSArray class]] ? filas.count : 0;
}

- (NSString *)tableView:(UITableView *)tabla titleForHeaderInSection:(NSInteger)seccion {
    NSString *titulo = _secciones[seccion][@"titulo"];
    return ([titulo isKindOfClass:[NSString class]] && titulo.length) ? titulo : nil;
}

- (void)tableView:(UITableView *)tabla willDisplayHeaderView:(UIView *)vista
       forSection:(NSInteger)seccion {
    if ([vista isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *cabecera = (UITableViewHeaderFooterView *)vista;
        cabecera.textLabel.textColor = [YTTheme textoSecundario];
        cabecera.textLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    }
}

// Alto del texto de una fila "texto", medido con la misma fuente con la que se
// dibuja (si no, unas veces sobra y otras falta).
- (CGFloat)altoDelTexto:(NSString *)texto ancho:(CGFloat)ancho {
    if (![texto isKindOfClass:[NSString class]] || texto.length == 0) return 30.0;
    CGRect marco = [texto boundingRectWithSize:CGSizeMake(ancho - 2.0 * YTMargen, 6000.0)
                                       options:NSStringDrawingUsesLineFragmentOrigin
                                    attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:14.0] }
                                       context:nil];
    return ceil(marco.size.height) + 20.0;
}

- (CGFloat)tableView:(UITableView *)tabla heightForRowAtIndexPath:(NSIndexPath *)indice {
    NSArray *filas = _secciones[indice.section][@"filas"];
    NSDictionary *fila = filas[indice.row];
    NSString *tipo = fila[@"tipo"];
    CGFloat ancho = CGRectGetWidth(tabla.bounds);

    if ([tipo isEqualToString:@"video"]) return [YTVideoCell altoParaAncho:ancho];
    if ([tipo isEqualToString:@"lista"]) return [YTListaCell alto];

    NSDictionary *dato = fila[@"dato"];
    CGFloat alto = [self altoDelTexto:dato[@"cuerpo"] ancho:ancho];
    if ([(NSString *)dato[@"titulo"] length]) alto += 22.0;
    return alto;
}

// Las filas de texto son dos etiquetas colocadas a mano: una celda normal de
// UIKit no da para titulo con color propio y cuerpo de varias lineas.
- (UITableViewCell *)celdaDeTexto:(NSDictionary *)dato enTabla:(UITableView *)tabla {
    static NSString *identificador = @"canalTexto";
    UITableViewCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
    UILabel *titulo = nil;
    UILabel *cuerpo = nil;

    if (!celda) {
        celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identificador];
        celda.backgroundColor = [YTTheme fondo];
        celda.contentView.backgroundColor = [YTTheme fondo];
        celda.selectionStyle = UITableViewCellSelectionStyleNone;

        titulo = [[UILabel alloc] init];
        titulo.tag = 11;
        titulo.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        titulo.textColor = [YTTheme acento];
        [celda.contentView addSubview:titulo];

        cuerpo = [[UILabel alloc] init];
        cuerpo.tag = 12;
        cuerpo.numberOfLines = 0;
        cuerpo.font = [UIFont systemFontOfSize:14.0];
        cuerpo.textColor = [YTTheme textoSecundario];
        [celda.contentView addSubview:cuerpo];
    } else {
        titulo = (UILabel *)[celda.contentView viewWithTag:11];
        cuerpo = (UILabel *)[celda.contentView viewWithTag:12];
    }

    titulo.text = dato[@"titulo"];
    cuerpo.text = dato[@"cuerpo"];
    return celda;
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {
    NSArray *filas = _secciones[indice.section][@"filas"];
    NSDictionary *fila = filas[indice.row];
    NSString *tipo = fila[@"tipo"];

    if ([tipo isEqualToString:@"video"]) {
        static NSString *identificador = @"canalVideo";
        YTVideoCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
        if (!celda) {
            celda = [[YTVideoCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identificador];
        }
        __weak YTChannelViewController *deb = self;
        celda.alTocarCanal = ^(YTVideo *video) {
            [deb abrirCanalConId:video.canalId titulo:video.canal];
        };
        [celda configurarCon:fila[@"dato"]];
        return celda;
    }

    if ([tipo isEqualToString:@"lista"]) {
        static NSString *identificador = @"canalLista";
        YTListaCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
        if (!celda) {
            celda = [[YTListaCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identificador];
        }
        [celda configurarCon:fila[@"dato"]];
        return celda;
    }

    return [self celdaDeTexto:fila[@"dato"] enTabla:tabla];
}

// Las celdas de texto se colocan aqui: en este momento ya se conoce su alto.
- (void)tableView:(UITableView *)tabla
    willDisplayCell:(UITableViewCell *)celda forRowAtIndexPath:(NSIndexPath *)indice {
    UILabel *titulo = (UILabel *)[celda.contentView viewWithTag:11];
    if (!titulo) return;
    UILabel *cuerpo = (UILabel *)[celda.contentView viewWithTag:12];

    CGFloat ancho = CGRectGetWidth(tabla.bounds);
    CGFloat y = 10.0;
    if (titulo.text.length) {
        titulo.frame = CGRectMake(YTMargen, y, ancho - 2.0 * YTMargen, 18.0);
        y += 22.0;
    } else {
        titulo.frame = CGRectZero;
    }
    CGFloat alto = CGRectGetHeight(celda.contentView.bounds) - y - 8.0;
    cuerpo.frame = CGRectMake(YTMargen, y, ancho - 2.0 * YTMargen, MAX(20.0, alto));
}

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];

    NSArray *filas = _secciones[indice.section][@"filas"];
    NSDictionary *fila = filas[indice.row];
    NSString *tipo = fila[@"tipo"];

    if ([tipo isEqualToString:@"video"]) {
        YTPlayerViewController *reproductor =
            [[YTPlayerViewController alloc] initWithVideo:fila[@"dato"]];
        reproductor.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:reproductor animated:YES];
        return;
    }

    if ([tipo isEqualToString:@"lista"]) {
        NSDictionary *lista = fila[@"dato"];
        YTListaViewController *pantalla = [[YTListaViewController alloc]
            initWithListaId:lista[@"id"] titulo:lista[@"titulo"]];
        pantalla.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:pantalla animated:YES];
    }
}

@end
