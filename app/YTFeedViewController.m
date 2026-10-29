// v1.0-en 2026-10-29: English UI build (textos traducidos al ingles; hl=en, gl=US)
// YTFeedViewController.m -- pantalla de estantes (Inicio y Musica).
//
// Carga las fuentes de una en una, no todas a la vez: asi la memoria se queda
// en un solo JSON grande y los estantes van apareciendo poco a poco, que ademas
// da sensacion de fluidez en un telefono de 32 bits.
//
// Cada fuente es un diccionario:
//   @{ @"consulta" : ..., @"titulo" : ..., @"params" : ... }  busqueda normal
//   @{ @"browseId" : @"FEmusic_home" }                        pantalla de YT Music
//   @{ @"consulta" : ..., @"musica" : @YES }                  busqueda en YT Music
//   @{ @"titulo" : ..., @"estante" : @{...} }                 estante ya hecho
//                                                             (Continuar viendo)
#import "YTFeedViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTProgreso.h"
#import "YTCarruselCell.h"
#import "YTPlayerViewController.h"

@interface YTFeedViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation YTFeedViewController {
    NSString *_tituloPantalla;
    NSArray *_fuentes;
    BOOL _esMusica;             // las respuestas son ya estantes de YouTube Music
    BOOL _usandoRespaldo;       // YouTube Music no dio nada y se tira de busquedas
    BOOL _hayEstanteLocal;      // la primera fuente es "Continuar viendo"

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
        [self mirarSiHayEstanteLocal];
    }
    return self;
}

- (instancetype)initConMusica {
    self = [super init];
    if (self) {
        _tituloPantalla = @"Music";
        // Cuatro pantallas de YouTube Music y cuatro estilos buscados en su
        // catalogo. Medido: FEmusic_home 20 canciones, explore 24, novedades 24;
        // las busquedas, entre 11 y 15 cada una. FEmusic_charts NO vale: sus
        // listas son de artistas (llevan a un canal, no a un video).
        _fuentes = @[
            @{ @"browseId" : @"FEmusic_home" },
            @{ @"browseId" : @"FEmusic_explore" },
            @{ @"browseId" : @"FEmusic_new_releases" },
            @{ @"consulta" : @"Hip hop",        @"musica" : @YES },
            @{ @"consulta" : @"Country",        @"musica" : @YES },
            @{ @"consulta" : @"Rock",            @"musica" : @YES },
            @{ @"consulta" : @"Pop",             @"musica" : @YES }
        ];
        _esMusica = YES;
    }
    return self;
}

- (void)mirarSiHayEstanteLocal {
    if (_fuentes.count == 0) return;
    NSDictionary *primera = _fuentes[0];
    if ([primera[@"estante"] isKindOfClass:[NSDictionary class]]) _hayEstanteLocal = YES;
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
    _estado.text = @"Loading...";
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

- (void)viewWillAppear:(BOOL)animado {
    [super viewWillAppear:animado];
    [self refrescarEstanteLocal];
}

#pragma mark - Carga

- (void)recargar {
    if (_cargando) return;
    _cargando = YES;
    _ultimoError = nil;
    _indice = 0;
    _filas = [NSMutableArray array];
    [_tabla reloadData];
    _estado.text = @"Loading...";
    _estado.hidden = NO;
    [_girador startAnimating];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:_girador];

    [self cargarSiguienteFuente];
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

    // Plan B de Musica: si YouTube Music no devuelve nada (es raro, pero puede
    // pasar si cambian el formato), la pestana se rellena con busquedas normales
    // de musica en vez de quedarse vacia.
    if (_esMusica && !_usandoRespaldo) {
        _usandoRespaldo = YES;
        _esMusica = NO;
        _fuentes = @[
            @{ @"titulo" : @"Music",           @"consulta" : @"music",
               @"params" : YTOrdenPorPopularidad },
            @{ @"titulo" : @"Top hits now",    @"consulta" : @"top hits",
               @"params" : YTOrdenPorPopularidad },
            @{ @"titulo" : @"Ballads",         @"consulta" : @"ballads" },
            @{ @"titulo" : @"Rock",            @"consulta" : @"rock music" }
        ];
        [self recargar];
        return;
    }

    _estado.hidden = NO;
    if (_ultimoError) {
        _estado.text = [NSString stringWithFormat:@"%@\n\n%@",
            [YTClient explicarError:_ultimoError],
            @"Tap the button at the top right to retry."];
    } else {
        _estado.text = @"Nothing to show.\n\nCheck the connection and "
                       @"try again.";
    }
}

- (void)cargarSiguienteFuente {
    if (_indice >= _fuentes.count) { [self terminarCarga]; return; }

    NSDictionary *fuente = _fuentes[_indice];

    // Lo que devuelve cada carga se trata igual: en el modo de busquedas es una
    // lista de videos (que se convierte en un estante con titulo propio) y en el
    // modo de musica son ya estantes con el titulo que pone YouTube.
    __weak YTFeedViewController *deb = self;
    void (^alLlegar)(NSArray *videos, NSError *error) = ^(NSArray *videos, NSError *error) {
        YTFeedViewController *yo = deb;
        if (!yo) return;
        if (error) {
            yo->_ultimoError = error;
        } else if (videos.count > 0) {
            if (yo->_esMusica) {
                [yo->_filas addObjectsFromArray:videos];
            } else {
                [yo->_filas addObject:@{ @"titulo" : (fuente[@"titulo"] ?: fuente[@"consulta"]),
                                         @"videos" : videos }];
            }
            yo->_estado.hidden = YES;
            [yo->_tabla reloadData];
        }
        yo->_indice++;
        [yo cargarSiguienteFuente];
    };

    // Estante ya hecho (Continuar viendo): no hay que pedir nada a YouTube.
    NSDictionary *estante = fuente[@"estante"];
    if ([estante isKindOfClass:[NSDictionary class]]) {
        NSArray *videos = estante[@"videos"];
        alLlegar([videos isKindOfClass:[NSArray class]] ? videos : @[], nil);
        return;
    }

    if (_esMusica) {
        NSString *browseId = fuente[@"browseId"];
        if ([browseId isKindOfClass:[NSString class]] && browseId.length) {
            [[YTClient compartido] carruselesDeMusica:browseId completion:alLlegar];
        } else {
            [[YTClient compartido] carruselesDeMusicaBuscando:fuente[@"consulta"]
                                                   completion:alLlegar];
        }
        return;
    }

    [[YTClient compartido] buscar:fuente[@"consulta"]
                           params:fuente[@"params"]
                       completion:alLlegar];
}

// Al volver a Inicio se refresca solo el estante "Continuar viendo": es local y
// puede haber cambiado mientras se veia un video.
- (void)refrescarEstanteLocal {
    if (!_hayEstanteLocal || _cargando) return;

    NSArray *videos = [YTProgreso continuarViendo];
    NSInteger posicion = -1;
    for (NSUInteger i = 0; i < _filas.count; i++) {
        NSDictionary *fila = _filas[i];
        if (fila[@"local"] || [fila[@"titulo"] isEqualToString:@"Continue watching"]) {
            posicion = (NSInteger)i;
            break;
        }
    }

    if (videos.count == 0) {
        if (posicion >= 0) {
            [_filas removeObjectAtIndex:(NSUInteger)posicion];
            [_tabla reloadData];
        }
        return;
    }

    NSDictionary *fila = @{ @"titulo" : @"Continue watching", @"videos" : videos, @"local" : @YES };
    if (posicion >= 0) {
        _filas[(NSUInteger)posicion] = fila;
    } else {
        [_filas insertObject:fila atIndex:0];
    }
    [_tabla reloadData];
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
