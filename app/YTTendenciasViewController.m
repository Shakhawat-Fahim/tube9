// YTTendenciasViewController.m -- lista de videos ordenada por "mas vistos",
// con una fila de "chips" arriba para cambiar de categoria.
//
// Nota honesta: YouTube cerro el listado publico de tendencias (el browseId
// "FEtrending" contesta 400 desde hace tiempo). Lo que si funciona es pedirle a
// la busqueda que ordene por numero de visitas, y eso es lo que se usa aqui.
#import "YTTendenciasViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTVideoCell.h"
#import "YTPlayerViewController.h"

@interface YTTendenciasViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation YTTendenciasViewController {
    UIScrollView *_tiraDeChips;
    NSMutableArray *_botonesChip;
    UITableView *_tabla;
    UILabel *_estado;
    UIActivityIndicatorView *_girador;
    UIBarButtonItem *_botonRecargar;

    NSArray *_categorias;      // @{ @"titulo", @"consulta", @"params" }
    NSUInteger _elegida;
    NSArray *_videos;
    NSError *_ultimoError;
    BOOL _cargando;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tendencias";
    self.view.backgroundColor = [YTTheme fondo];

    _categorias = @[
        @{ @"titulo" : @"Todo",        @"consulta" : @"tendencias",
           @"params" : YTOrdenPorPopularidad },
        @{ @"titulo" : @"Música",      @"consulta" : @"música",
           @"params" : YTOrdenPorPopularidad },
        @{ @"titulo" : @"Videojuegos", @"consulta" : @"videojuegos",
           @"params" : YTOrdenPorPopularidad },
        @{ @"titulo" : @"Noticias",    @"consulta" : @"noticias de hoy",
           @"params" : YTOrdenRecientes },
        @{ @"titulo" : @"Deportes",    @"consulta" : @"deportes",
           @"params" : YTOrdenRecientes },
        @{ @"titulo" : @"Películas",   @"consulta" : @"películas completas",
           @"params" : YTOrdenPorPopularidad },
        @{ @"titulo" : @"Comedia",     @"consulta" : @"comedia",
           @"params" : YTOrdenPorPopularidad },
        @{ @"titulo" : @"Aprender",    @"consulta" : @"documentales",
           @"params" : YTOrdenPorPopularidad }
    ];
    _elegida = 0;
    _videos = @[];

    [self montarChips];

    CGFloat y = 46.0;
    _tabla = [[UITableView alloc]
        initWithFrame:CGRectMake(0, y, self.view.bounds.size.width,
                                 self.view.bounds.size.height - y)
               style:UITableViewStylePlain];
    _tabla.dataSource = self;
    _tabla.delegate = self;
    _tabla.backgroundColor = [YTTheme fondo];
    _tabla.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tabla.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tabla];

    _estado = [[UILabel alloc]
        initWithFrame:CGRectMake(34, y, self.view.bounds.size.width - 68,
                                 self.view.bounds.size.height - y)];
    _estado.numberOfLines = 0;
    _estado.textAlignment = NSTextAlignmentCenter;
    _estado.textColor = [YTTheme textoSecundario];
    _estado.font = [YTTheme fuenteCuerpo];
    _estado.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_estado];

    _girador = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _girador.color = [YTTheme textoPrimario];
    _girador.hidesWhenStopped = YES;

    _botonRecargar = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                 target:self
                                                                 action:@selector(recargar)];
    self.navigationItem.rightBarButtonItem = _botonRecargar;

    [self recargar];
}

#pragma mark - Chips

- (void)montarChips {
    _tiraDeChips = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0,
                                                                  self.view.bounds.size.width, 46.0)];
    _tiraDeChips.backgroundColor = [YTTheme fondo];
    _tiraDeChips.showsHorizontalScrollIndicator = NO;
    _tiraDeChips.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_tiraDeChips];

    _botonesChip = [NSMutableArray array];
    CGFloat x = 12.0;
    CGFloat alto = 30.0;
    CGFloat y = (CGRectGetHeight(_tiraDeChips.bounds) - alto) / 2.0;

    for (NSUInteger i = 0; i < _categorias.count; i++) {
        NSString *titulo = _categorias[i][@"titulo"];
        UIFont *fuente = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
        CGFloat anchoTexto = [titulo sizeWithAttributes:@{ NSFontAttributeName : fuente }].width;
        CGFloat ancho = ceil(anchoTexto) + 28.0;

        UIButton *boton = [UIButton buttonWithType:UIButtonTypeCustom];
        boton.frame = CGRectMake(x, y, ancho, alto);
        boton.tag = (NSInteger)i;
        [boton setTitle:titulo forState:UIControlStateNormal];
        [boton addTarget:self action:@selector(tocarChip:)
        forControlEvents:UIControlEventTouchUpInside];
        [YTTheme aplicarEstiloChip:boton seleccionado:(i == _elegida)];
        [_tiraDeChips addSubview:boton];
        [_botonesChip addObject:boton];

        x += ancho + 8.0;
    }
    _tiraDeChips.contentSize = CGSizeMake(x + 4.0, CGRectGetHeight(_tiraDeChips.bounds));
}

- (void)tocarChip:(UIButton *)boton {
    if (_cargando || boton.tag == (NSInteger)_elegida) return;
    _elegida = (NSUInteger)boton.tag;
    for (UIButton *otro in _botonesChip) {
        [YTTheme aplicarEstiloChip:otro seleccionado:(otro.tag == boton.tag)];
    }
    [self recargar];
}

#pragma mark - Carga

- (void)recargar {
    if (_cargando) return;
    _cargando = YES;
    _ultimoError = nil;

    NSDictionary *categoria = _categorias[_elegida];
    _estado.text = @"Cargando...";
    _estado.hidden = NO;
    _tabla.hidden = YES;
    [_girador startAnimating];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:_girador];

    __weak YTTendenciasViewController *deb = self;
    [[YTClient compartido] buscar:categoria[@"consulta"]
                           params:categoria[@"params"]
                       completion:^(NSArray *videos, NSError *error) {
        YTTendenciasViewController *yo = deb;
        if (!yo) return;
        yo->_cargando = NO;
        [yo->_girador stopAnimating];
        yo.navigationItem.rightBarButtonItem = yo->_botonRecargar;

        if (error) {
            yo->_videos = @[];
            [yo->_tabla reloadData];
            yo->_tabla.hidden = YES;
            yo->_estado.hidden = NO;
            yo->_estado.text = [NSString stringWithFormat:@"%@\n\n%@",
                [YTClient explicarError:error],
                @"Pulsa el boton de arriba a la derecha para reintentar."];
            return;
        }
        yo->_videos = videos;
        [yo->_tabla reloadData];
        yo->_tabla.hidden = (videos.count == 0);
        yo->_estado.hidden = (videos.count > 0);
        if (videos.count == 0) yo->_estado.text = @"Sin resultados para esta categoria.";
    }];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    return _videos.count;
}

- (CGFloat)tableView:(UITableView *)tabla heightForRowAtIndexPath:(NSIndexPath *)indice {
    return [YTVideoCell altoParaAncho:self.view.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {
    static NSString *identificador = @"celdaVideo";
    YTVideoCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
    if (!celda) {
        celda = [[YTVideoCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:identificador];
    }
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
