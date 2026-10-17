// YTFeedViewController.m -- pantalla de estantes (Inicio y Musica).
//
// Carga las fuentes de una en una, no todas a la vez: asi la memoria se queda
// en un solo JSON grande y los estantes van apareciendo poco a poco, que ademas
// da sensacion de fluidez en un telefono de 32 bits.
#import "YTFeedViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTCarruselCell.h"
#import "YTPlayerViewController.h"

@interface YTFeedViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation YTFeedViewController {
    NSString *_tituloPantalla;
    NSArray *_fuentes;          // nil en el modo musica
    BOOL _esMusica;

    NSMutableArray *_filas;     // @{ @"titulo": ..., @"videos": ... }
    NSUInteger _indice;
    NSError *_ultimoError;

    UITableView *_tabla;
    UILabel *_estado;
    UIActivityIndicatorView *_girador;
    UIBarButtonItem *_botonRecargar;
    BOOL _cargando;
}

#pragma mark - Arranque

- (instancetype)initConTitulo:(NSString *)titulo fuentes:(NSArray *)fuentes {
    self = [super init];
    if (self) {
        _tituloPantalla = [titulo copy];
        _fuentes = [fuentes copy];
        _esMusica = NO;
    }
    return self;
}

- (instancetype)initConMusica {
    self = [super init];
    if (self) {
        _tituloPantalla = @"Música";
        _fuentes = nil;
        _esMusica = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _tituloPantalla;
    self.view.backgroundColor = [YTTheme fondo];

    _tabla = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tabla.dataSource = self;
    _tabla.delegate = self;
    _tabla.backgroundColor = [YTTheme fondo];
    _tabla.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tabla.rowHeight = [YTCarruselCell alto];
    _tabla.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tabla.contentInset = UIEdgeInsetsMake(4, 0, 8, 0);
    [self.view addSubview:_tabla];

    _estado = [[UILabel alloc] initWithFrame:CGRectInset(self.view.bounds, 34.0, 0)];
    _estado.numberOfLines = 0;
    _estado.textAlignment = NSTextAlignmentCenter;
    _estado.textColor = [YTTheme textoSecundario];
    _estado.font = [YTTheme fuenteCuerpo];
    _estado.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _estado.text = @"Cargando...";
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

#pragma mark - Carga

- (void)recargar {
    if (_cargando) return;
    _cargando = YES;
    _ultimoError = nil;
    _indice = 0;
    _filas = [NSMutableArray array];
    [_tabla reloadData];
    _estado.text = @"Cargando...";
    _estado.hidden = NO;
    [_girador startAnimating];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:_girador];

    if (_esMusica) {
        [self cargarMusica];
    } else {
        [self cargarSiguienteFuente];
    }
}

- (void)terminarCarga {
    _cargando = NO;
    [_girador stopAnimating];
    self.navigationItem.rightBarButtonItem = _botonRecargar;

    if (_filas.count > 0) {
        _estado.hidden = YES;
        [_tabla reloadData];
        return;
    }

    _estado.hidden = NO;
    if (_ultimoError) {
        _estado.text = [NSString stringWithFormat:@"%@\n\n%@",
            [YTClient explicarError:_ultimoError],
            @"Pulsa el boton de arriba a la derecha para reintentar."];
    } else {
        _estado.text = @"No hay nada que mostrar.\n\nComprueba la conexion y "
                       @"vuelve a intentarlo.";
    }
}

- (void)cargarSiguienteFuente {
    if (_indice >= _fuentes.count) { [self terminarCarga]; return; }

    NSDictionary *fuente = _fuentes[_indice];
    NSString *consulta = fuente[@"consulta"];
    NSString *params = fuente[@"params"];

    __weak YTFeedViewController *deb = self;
    [[YTClient compartido] buscar:consulta params:params completion:^(NSArray *videos,
                                                                    NSError *error) {
        YTFeedViewController *yo = deb;
        if (!yo) return;
        if (error) {
            yo->_ultimoError = error;
        } else if (videos.count > 0) {
            [yo->_filas addObject:@{ @"titulo" : (fuente[@"titulo"] ?: consulta),
                                     @"videos" : videos }];
            yo->_estado.hidden = YES;
            [yo->_tabla reloadData];
        }
        yo->_indice++;
        [yo cargarSiguienteFuente];
    }];
}

- (void)cargarMusica {
    __weak YTFeedViewController *deb = self;
    [[YTClient compartido] inicioMusica:^(NSArray *carruseles, NSError *error) {
        YTFeedViewController *yo = deb;
        if (!yo) return;
        if (error) {
            yo->_ultimoError = error;
        } else {
            [yo->_filas addObjectsFromArray:carruseles];
        }
        [yo terminarCarga];
    }];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    return _filas.count;
}

- (CGFloat)tableView:(UITableView *)tabla heightForRowAtIndexPath:(NSIndexPath *)indice {
    return [YTCarruselCell alto];
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {
    static NSString *identificador = @"estante";
    YTCarruselCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
    if (!celda) {
        celda = [[YTCarruselCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:identificador];
    }
    NSDictionary *fila = _filas[indice.row];
    [celda configurarConTitulo:fila[@"titulo"] videos:fila[@"videos"]];

    __weak YTFeedViewController *deb = self;
    celda.alElegirVideo = ^(YTVideo *video) {
        YTFeedViewController *yo = deb;
        if (!yo) return;
        YTPlayerViewController *reproductor =
            [[YTPlayerViewController alloc] initWithVideo:video];
        reproductor.hidesBottomBarWhenPushed = YES;
        [yo.navigationController pushViewController:reproductor animated:YES];
    };
    return celda;
}

@end
