// YTListaViewController.m -- el contenido de una lista de reproduccion.
//
// La ficha de la lista (titulo, dueño, cuantas piezas y su descripcion) viene en
// la misma respuesta que los videos, asi que se pinta todo de una vez.
#import "YTListaViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTVideoCell.h"
#import "YTPlayerViewController.h"
#import "YTChannelViewController.h"

static const CGFloat YTMargen = 14.0;

@interface YTListaViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation YTListaViewController {
    NSString *_listaId;
    NSString *_tituloRespaldo;
    NSDictionary *_ficha;
    NSArray *_videos;

    UITableView *_tabla;
    UIView *_cabecera;
    UILabel *_titulo;
    UILabel *_detalles;
    UILabel *_descripcion;
    UIButton *_reproducirTodo;

    UIActivityIndicatorView *_girador;
    UILabel *_estado;
    BOOL _pidiendo;
}

- (instancetype)initWithListaId:(NSString *)listaId titulo:(NSString *)titulo {
    self = [super init];
    if (self) {
        _listaId = [listaId copy];
        _tituloRespaldo = [titulo copy];
        _videos = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _tituloRespaldo.length ? _tituloRespaldo : @"Lista";
    self.view.backgroundColor = [YTTheme fondo];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;

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

    [self cargarLista];
}

- (void)montarCabecera {
    _cabecera = [[UIView alloc] init];
    _cabecera.backgroundColor = [YTTheme fondo];

    _titulo = [[UILabel alloc] init];
    _titulo.numberOfLines = 2;
    _titulo.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
    _titulo.textColor = [YTTheme textoPrimario];
    _titulo.text = _tituloRespaldo;
    [_cabecera addSubview:_titulo];

    _detalles = [[UILabel alloc] init];
    _detalles.numberOfLines = 1;
    _detalles.font = [YTTheme fuenteMenuda];
    _detalles.textColor = [YTTheme textoSecundario];
    [_cabecera addSubview:_detalles];

    _descripcion = [[UILabel alloc] init];
    _descripcion.numberOfLines = 3;
    _descripcion.font = [UIFont systemFontOfSize:13.0];
    _descripcion.textColor = [YTTheme textoSecundario];
    _descripcion.hidden = YES;
    [_cabecera addSubview:_descripcion];

    _reproducirTodo = [UIButton buttonWithType:UIButtonTypeCustom];
    [_reproducirTodo setTitle:@"Reproducir todo" forState:UIControlStateNormal];
    [_reproducirTodo setTitleColor:[YTTheme textoSobreAcento] forState:UIControlStateNormal];
    _reproducirTodo.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _reproducirTodo.backgroundColor = [YTTheme acento];
    _reproducirTodo.layer.cornerRadius = 17.0;
    _reproducirTodo.layer.masksToBounds = YES;
    _reproducirTodo.hidden = YES;
    [_reproducirTodo addTarget:self action:@selector(reproducirTodo)
              forControlEvents:UIControlEventTouchUpInside];
    [_cabecera addSubview:_reproducirTodo];
}

#pragma mark - Carga

- (void)cargarLista {
    if (_pidiendo) return;
    _pidiendo = YES;
    [_girador startAnimating];
    _estado.hidden = NO;
    _estado.text = @"Cargando la lista...";

    __weak YTListaViewController *deb = self;
    [[YTClient compartido] videosDeLista:_listaId
        completion:^(NSDictionary *lista, NSArray *videos, NSError *error) {
        YTListaViewController *yo = deb;
        if (!yo) return;
        yo->_pidiendo = NO;
        [yo->_girador stopAnimating];

        if (error) {
            yo->_estado.hidden = NO;
            yo->_estado.text = [NSString stringWithFormat:@"%@\n\n%@",
                [YTClient explicarError:error],
                @"Vuelve a entrar en la lista para intentarlo otra vez."];
            return;
        }

        yo->_ficha = lista;
        yo->_videos = videos ?: @[];
        [yo pintarFicha];
        [yo->_tabla reloadData];
        if (yo->_videos.count == 0) {
            yo->_estado.hidden = NO;
            yo->_estado.text = @"Esta lista esta vacia.";
        } else {
            yo->_estado.hidden = YES;
        }
        [yo.view setNeedsLayout];
    }];
}

- (void)pintarFicha {
    NSString *titulo = _ficha[@"titulo"];
    if ([titulo isKindOfClass:[NSString class]] && titulo.length) {
        _titulo.text = titulo;
        self.title = titulo;
    }

    NSMutableArray *partes = [NSMutableArray array];
    NSString *dueno = _ficha[@"dueno"];
    if ([dueno isKindOfClass:[NSString class]] && dueno.length) [partes addObject:dueno];
    NSString *cuantos = _ficha[@"cuantos"];
    if ([cuantos isKindOfClass:[NSString class]] && cuantos.length) {
        [partes addObject:cuantos];
    } else if (_videos.count) {
        [partes addObject:[NSString stringWithFormat:@"%lu vídeos", (unsigned long)_videos.count]];
    }
    _detalles.text = [partes componentsJoinedByString:@"  ·  "];

    NSString *descripcion = _ficha[@"descripcion"];
    if ([descripcion isKindOfClass:[NSString class]] && descripcion.length) {
        _descripcion.text = descripcion;
        _descripcion.hidden = NO;
    }

    _reproducirTodo.hidden = (_videos.count == 0);
    [self.view setNeedsLayout];
}

#pragma mark - Acciones

- (void)reproducirTodo {
    if (_videos.count == 0) return;
    YTPlayerViewController *reproductor =
        [[YTPlayerViewController alloc] initWithVideo:_videos.firstObject];
    reproductor.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:reproductor animated:YES];
}

- (void)abrirCanal:(YTVideo *)video {
    if (video.canalId.length == 0) return;
    YTChannelViewController *canal = [[YTChannelViewController alloc]
        initWithCanalId:video.canalId titulo:video.canal];
    canal.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:canal animated:YES];
}

#pragma mark - Colocacion

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.view.bounds);
    CGFloat util = ancho - 2.0 * YTMargen;
    CGFloat y = 14.0;

    _titulo.frame = CGRectMake(YTMargen, y, util, 46.0);
    y = CGRectGetMaxY(_titulo.frame) + 2.0;
    _detalles.frame = CGRectMake(YTMargen, y, util, 16.0);
    y = CGRectGetMaxY(_detalles.frame) + 6.0;

    if (!_descripcion.hidden) {
        CGSize tamano = [_descripcion sizeThatFits:CGSizeMake(util, 400.0)];
        _descripcion.frame = CGRectMake(YTMargen, y, util, MAX(18.0, tamano.height));
        y = CGRectGetMaxY(_descripcion.frame) + 10.0;
    }

    if (!_reproducirTodo.hidden) {
        _reproducirTodo.frame = CGRectMake(YTMargen, y, 152.0, 34.0);
        y = CGRectGetMaxY(_reproducirTodo.frame) + 12.0;
    }

    CGFloat alto = y + 4.0;
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

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    return _videos.count;
}

- (NSString *)tableView:(UITableView *)tabla titleForHeaderInSection:(NSInteger)seccion {
    if (_videos.count == 0) return nil;
    return [NSString stringWithFormat:@"%lu vídeos", (unsigned long)_videos.count];
}

- (void)tableView:(UITableView *)tabla willDisplayHeaderView:(UIView *)vista
       forSection:(NSInteger)seccion {
    if ([vista isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *cabecera = (UITableViewHeaderFooterView *)vista;
        cabecera.textLabel.textColor = [YTTheme textoSecundario];
        cabecera.textLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    }
}

- (CGFloat)tableView:(UITableView *)tabla heightForRowAtIndexPath:(NSIndexPath *)indice {
    return [YTVideoCell altoParaAncho:CGRectGetWidth(tabla.bounds)];
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {
    static NSString *identificador = @"filaLista";
    YTVideoCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
    if (!celda) {
        celda = [[YTVideoCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:identificador];
    }
    __weak YTListaViewController *deb = self;
    celda.alTocarCanal = ^(YTVideo *video) {
        [deb abrirCanal:video];
    };
    [celda configurarCon:_videos[indice.row]];
    return celda;
}

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];
    YTPlayerViewController *reproductor =
        [[YTPlayerViewController alloc] initWithVideo:_videos[indice.row]];
    reproductor.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:reproductor animated:YES];
}

@end
