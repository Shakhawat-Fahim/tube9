// YTSearchViewController.m -- busqueda y lista de resultados.
//
// Tres filtros, los mismos que ofrece YouTube:
//   Videos  -> cliente ANDROID, que es el que mejor contesta a las busquedas;
//   Canales -> cliente ANDROID_VR con el "params" de solo-canales;
//   Listas  -> cliente ANDROID con el "params" de solo-listas.
// Los "params" son los mismos que usa la web de YouTube (van en base64 y no hay
// que entenderlos; sin ellos YouTube no devuelve canales ni listas).
#import "YTSearchViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTVideoCell.h"
#import "YTCanalCell.h"
#import "YTListaCell.h"
#import "YTPlayerViewController.h"
#import "YTChannelViewController.h"
#import "YTListaViewController.h"

// Filtros del buscador.
enum {
    YTFiltroVideos = 0,
    YTFiltroCanales = 1,
    YTFiltroListas = 2
};

@interface YTSearchViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>
@end

@implementation YTSearchViewController {
    UISearchBar *_barra;
    UIScrollView *_tiraDeFiltros;
    NSMutableArray *_botonesFiltro;
    UIScrollView *_tiraDeSugerencias;
    NSMutableArray *_botonesSugerencia;
    UITableView *_tabla;
    UIActivityIndicatorView *_girador;
    UILabel *_estado;

    NSArray *_resultados;
    NSString *_consulta;
    NSInteger _filtro;
    BOOL _cargando;
    BOOL _busquedaHecha;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Buscar";
    self.view.backgroundColor = [YTTheme fondo];
    self.navigationController.navigationBarHidden = NO;

    _filtro = YTFiltroVideos;
    _resultados = @[];

    _barra = [[UISearchBar alloc] init];
    _barra.delegate = self;
    _barra.placeholder = @"Buscar en YouTube";
    _barra.barStyle = UIBarStyleBlack;
    _barra.translucent = NO;
    _barra.barTintColor = [YTTheme fondo];
    _barra.searchBarStyle = UISearchBarStyleMinimal;
    _barra.tintColor = [YTTheme acento];
    _barra.returnKeyType = UIReturnKeySearch;
    _barra.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _barra.autocorrectionType = UITextAutocorrectionTypeNo;
    _barra.keyboardAppearance = UIKeyboardAppearanceDark;
    _barra.frame = CGRectMake(0, 0, self.view.bounds.size.width - 96.0, 44.0);
    [self configurarCampoDeTextoDeLaBarra];
    self.navigationItem.titleView = _barra;

    [self montarTiras];

    _tabla = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tabla.dataSource = self;
    _tabla.delegate = self;
    _tabla.backgroundColor = [YTTheme fondo];
    _tabla.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tabla.hidden = YES;
    _tabla.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:_tabla];

    _girador = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _girador.color = [YTTheme textoPrimario];
    _girador.hidesWhenStopped = YES;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:_girador];

    _estado = [[UILabel alloc] init];
    _estado.numberOfLines = 0;
    _estado.textAlignment = NSTextAlignmentCenter;
    _estado.textColor = [YTTheme textoSecundario];
    _estado.font = [YTTheme fuenteCuerpo];
    _estado.text = @"Escribe arriba o toca una sugerencia para empezar.\n\n"
                   @"Con las pestañas de abajo buscas videos, canales o listas "
                   @"de reproduccion.";
    [self.view addSubview:_estado];

    [self colocarTiras];
}

- (void)configurarCampoDeTextoDeLaBarra {
    for (UIView *sub in _barra.subviews) {
        for (UIView *nieto in sub.subviews) {
            if ([nieto isKindOfClass:[UITextField class]]) {
                UITextField *campo = (UITextField *)nieto;
                campo.textColor = [YTTheme textoPrimario];
                campo.tintColor = [YTTheme acento];
                campo.backgroundColor = [YTTheme superficieAlta];
                campo.layer.cornerRadius = 10.0;
                campo.layer.masksToBounds = YES;
                campo.attributedPlaceholder = [[NSAttributedString alloc]
                    initWithString:@"Buscar en YouTube"
                        attributes:@{NSForegroundColorAttributeName : [YTTheme textoSecundario]}];
            }
        }
    }
}

#pragma mark - Las dos tiras de pastillas

- (UIButton *)pastillaConTitulo:(NSString *)titulo
                           tag:(NSInteger)tag
                        accion:(SEL)accion
                       enTira:(UIScrollView *)tira
                         x:(CGFloat *)x {
    UIFont *fuente = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    CGFloat anchoTexto = [titulo sizeWithAttributes:@{ NSFontAttributeName : fuente }].width;
    CGFloat ancho = ceil(anchoTexto) + 28.0;
    CGFloat alto = 30.0;

    UIButton *boton = [UIButton buttonWithType:UIButtonTypeCustom];
    boton.frame = CGRectMake(*x, (CGRectGetHeight(tira.bounds) - alto) / 2.0, ancho, alto);
    boton.tag = tag;
    [boton setTitle:titulo forState:UIControlStateNormal];
    [boton addTarget:self action:accion forControlEvents:UIControlEventTouchUpInside];
    [YTTheme aplicarEstiloChip:boton seleccionado:NO];
    [tira addSubview:boton];

    *x += ancho + 8.0;
    return boton;
}

- (void)montarTiras {
    CGFloat ancho = self.view.bounds.size.width;

    _tiraDeFiltros = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, ancho, 46.0)];
    _tiraDeFiltros.backgroundColor = [YTTheme fondo];
    _tiraDeFiltros.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:_tiraDeFiltros];

    _botonesFiltro = [NSMutableArray array];
    NSArray *titulos = @[ @"Vídeos", @"Canales", @"Listas" ];
    CGFloat x = 12.0;
    for (NSUInteger i = 0; i < titulos.count; i++) {
        UIButton *boton = [self pastillaConTitulo:titulos[i]
                                              tag:(NSInteger)i
                                           accion:@selector(tocarFiltro:)
                                          enTira:_tiraDeFiltros
                                              x:&x];
        [_botonesFiltro addObject:boton];
    }
    _tiraDeFiltros.contentSize = CGSizeMake(x + 4.0, 46.0);
    [self marcarFiltro:_filtro];

    _tiraDeSugerencias = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 46.0, ancho, 46.0)];
    _tiraDeSugerencias.backgroundColor = [YTTheme fondo];
    _tiraDeSugerencias.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:_tiraDeSugerencias];

    NSArray *sugerencias = @[ @"música", @"noticias", @"deportes", @"comedia",
                              @"documentales", @"tutoriales", @"películas",
                              @"videojuegos" ];
    _botonesSugerencia = [NSMutableArray array];
    x = 12.0;
    for (NSUInteger i = 0; i < sugerencias.count; i++) {
        UIButton *boton = [self pastillaConTitulo:sugerencias[i]
                                              tag:(NSInteger)i
                                           accion:@selector(tocarSugerencia:)
                                          enTira:_tiraDeSugerencias
                                              x:&x];
        [_botonesSugerencia addObject:boton];
    }
    _tiraDeSugerencias.contentSize = CGSizeMake(x + 4.0, 46.0);
}

// Las sugerencias desaparecen en cuanto se hace la primera busqueda: a partir
// de ahi el sitio lo ocupan los resultados, que es lo que se viene a ver.
- (void)colocarTiras {
    CGFloat ancho = CGRectGetWidth(self.view.bounds);
    CGFloat alto = CGRectGetHeight(self.view.bounds);
    CGFloat y = 0.0;

    _tiraDeFiltros.frame = CGRectMake(0, y, ancho, 46.0);
    y += 46.0;

    _tiraDeSugerencias.hidden = _busquedaHecha;
    if (!_busquedaHecha) {
        _tiraDeSugerencias.frame = CGRectMake(0, y, ancho, 46.0);
        y += 46.0;
    }

    _tabla.frame = CGRectMake(0, y, ancho, alto - y);
    _estado.frame = CGRectMake(34.0, y, ancho - 68.0, alto - y);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self colocarTiras];
}

- (void)marcarFiltro:(NSInteger)indice {
    for (UIButton *boton in _botonesFiltro) {
        [YTTheme aplicarEstiloChip:boton seleccionado:(boton.tag == indice)];
    }
}

- (void)tocarFiltro:(UIButton *)boton {
    if (_cargando) return;
    _filtro = boton.tag;
    [self marcarFiltro:_filtro];
    [_barra resignFirstResponder];
    if (_consulta.length) [self buscar:_consulta];   // repite la busqueda con el filtro nuevo
}

- (void)tocarSugerencia:(UIButton *)boton {
    _barra.text = [boton titleForState:UIControlStateNormal];
    [_barra resignFirstResponder];
    [self buscar:_barra.text];
}

#pragma mark - Busqueda

- (void)searchBarSearchButtonClicked:(UISearchBar *)barra {
    [barra resignFirstResponder];
    [self buscar:barra.text];
}

- (void)buscar:(NSString *)consulta {
    NSString *limpia = [consulta stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (_cargando || limpia.length == 0) return;

    _consulta = limpia;
    _cargando = YES;
    _busquedaHecha = YES;
    [self colocarTiras];
    [_girador startAnimating];
    _estado.hidden = NO;
    _estado.text = @"Buscando...";
    _tabla.hidden = YES;

    __weak YTSearchViewController *deb = self;
    if (_filtro == YTFiltroCanales) {
        [[YTClient compartido] buscarCanales:limpia
            completion:^(NSArray *canales, NSError *error) {
            [deb acabarCon:canales error:error
                    vacio:@"Sin canales con ese nombre."];
        }];
        return;
    }
    if (_filtro == YTFiltroListas) {
        [[YTClient compartido] buscarListas:limpia
            completion:^(NSArray *listas, NSError *error) {
            [deb acabarCon:listas error:error
                    vacio:@"Sin listas de reproduccion con ese nombre."];
        }];
        return;
    }

    [[YTClient compartido] buscar:limpia completion:^(NSArray *videos, NSError *error) {
        [deb acabarCon:videos error:error vacio:@"Sin resultados.\nPrueba otra busqueda."];
    }];
}

- (void)acabarCon:(NSArray *)resultados error:(NSError *)error vacio:(NSString *)mensaje {
    _cargando = NO;
    [_girador stopAnimating];

    if (error) {
        _resultados = @[];
        [_tabla reloadData];
        _tabla.hidden = YES;
        _estado.hidden = NO;
        _estado.text = [NSString stringWithFormat:@"%@\n\n%@",
            [YTClient explicarError:error],
            @"Ajustes > Probar conexion para mas detalle."];
        return;
    }

    _resultados = resultados ?: @[];
    [_tabla reloadData];
    _tabla.hidden = (_resultados.count == 0);
    _estado.hidden = (_resultados.count > 0);
    if (_resultados.count == 0) _estado.text = mensaje;
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    return _resultados.count;
}

- (CGFloat)tableView:(UITableView *)tabla heightForRowAtIndexPath:(NSIndexPath *)indice {
    CGFloat ancho = CGRectGetWidth(tabla.bounds);
    if (_filtro == YTFiltroCanales) return [YTCanalCell alto];
    if (_filtro == YTFiltroListas) return [YTListaCell alto];
    return [YTVideoCell altoParaAncho:ancho];
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {
    if (_filtro == YTFiltroCanales) {
        static NSString *identificador = @"celdaCanal";
        YTCanalCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
        if (!celda) {
            celda = [[YTCanalCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identificador];
        }
        [celda configurarCon:_resultados[indice.row]];
        return celda;
    }

    if (_filtro == YTFiltroListas) {
        static NSString *identificador = @"celdaLista";
        YTListaCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
        if (!celda) {
            celda = [[YTListaCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identificador];
        }
        [celda configurarCon:_resultados[indice.row]];
        return celda;
    }

    static NSString *identificador = @"celdaVideo";
    YTVideoCell *celda = [tabla dequeueReusableCellWithIdentifier:identificador];
    if (!celda) {
        celda = [[YTVideoCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:identificador];
    }
    __weak YTSearchViewController *deb = self;
    celda.alTocarCanal = ^(YTVideo *video) {
        [deb abrirCanalConId:video.canalId titulo:video.canal];
    };
    [celda configurarCon:_resultados[indice.row]];
    return celda;
}

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];
    if (indice.row >= (NSInteger)_resultados.count) return;

    if (_filtro == YTFiltroCanales) {
        NSDictionary *canal = _resultados[indice.row];
        [self abrirCanalConId:canal[@"id"] titulo:canal[@"titulo"]];
        return;
    }

    if (_filtro == YTFiltroListas) {
        NSDictionary *lista = _resultados[indice.row];
        YTListaViewController *pantalla = [[YTListaViewController alloc]
            initWithListaId:lista[@"id"] titulo:lista[@"titulo"]];
        pantalla.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:pantalla animated:YES];
        return;
    }

    YTPlayerViewController *reproductor =
        [[YTPlayerViewController alloc] initWithVideo:_resultados[indice.row]];
    reproductor.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:reproductor animated:YES];
}

- (void)abrirCanalConId:(NSString *)canalId titulo:(NSString *)titulo {
    if (canalId.length == 0) return;
    YTChannelViewController *canal = [[YTChannelViewController alloc]
        initWithCanalId:canalId titulo:titulo];
    canal.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:canal animated:YES];
}

@end
