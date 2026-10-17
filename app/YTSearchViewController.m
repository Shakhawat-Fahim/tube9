// YTSearchViewController.m -- busqueda y lista de resultados
#import "YTSearchViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTVideoCell.h"
#import "YTPlayerViewController.h"

@interface YTSearchViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>
@end

@implementation YTSearchViewController {
    UISearchBar *_barra;
    UIScrollView *_tiraDeChips;
    NSMutableArray *_botonesChip;
    UITableView *_tabla;
    UIActivityIndicatorView *_girador;
    UILabel *_estado;
    NSArray *_videos;
    NSInteger _chipActivo;
    BOOL _cargando;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Buscar";
    self.view.backgroundColor = [YTTheme fondo];
    self.navigationController.navigationBarHidden = NO;

    _chipActivo = -1;

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
    _tabla.hidden = YES;
    _tabla.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tabla.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:_tabla];

    _girador = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _girador.color = [YTTheme textoPrimario];
    _girador.hidesWhenStopped = YES;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:_girador];

    _estado = [[UILabel alloc]
        initWithFrame:CGRectMake(34, y, self.view.bounds.size.width - 68,
                                 self.view.bounds.size.height - y)];
    _estado.numberOfLines = 0;
    _estado.textAlignment = NSTextAlignmentCenter;
    _estado.textColor = [YTTheme textoSecundario];
    _estado.font = [YTTheme fuenteCuerpo];
    _estado.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _estado.text = @"Escribe arriba o toca una sugerencia para empezar.\n\n"
                   @"Si es la primera vez, mira Ajustes: alli se explica como "
                   @"arreglar los certificados de iOS 9 y como iniciar sesion.";
    [self.view addSubview:_estado];
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

#pragma mark - Sugerencias

- (void)montarChips {
    _tiraDeChips = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0,
                                                                  self.view.bounds.size.width, 46.0)];
    _tiraDeChips.backgroundColor = [YTTheme fondo];
    _tiraDeChips.showsHorizontalScrollIndicator = NO;
    _tiraDeChips.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_tiraDeChips];

    NSArray *sugerencias = @[ @"música", @"noticias", @"deportes", @"comedia",
                              @"documentales", @"tutoriales", @"películas",
                              @"videojuegos" ];
    _botonesChip = [NSMutableArray array];
    CGFloat x = 12.0;
    CGFloat alto = 30.0;
    CGFloat y = (CGRectGetHeight(_tiraDeChips.bounds) - alto) / 2.0;

    for (NSUInteger i = 0; i < sugerencias.count; i++) {
        NSString *titulo = sugerencias[i];
        UIFont *fuente = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
        CGFloat anchoTexto = [titulo sizeWithAttributes:@{ NSFontAttributeName : fuente }].width;
        CGFloat ancho = ceil(anchoTexto) + 28.0;

        UIButton *boton = [UIButton buttonWithType:UIButtonTypeCustom];
        boton.frame = CGRectMake(x, y, ancho, alto);
        boton.tag = (NSInteger)i;
        [boton setTitle:titulo forState:UIControlStateNormal];
        [boton addTarget:self action:@selector(tocarSugerencia:)
        forControlEvents:UIControlEventTouchUpInside];
        [YTTheme aplicarEstiloChip:boton seleccionado:NO];
        [_tiraDeChips addSubview:boton];
        [_botonesChip addObject:boton];

        x += ancho + 8.0;
    }
    _tiraDeChips.contentSize = CGSizeMake(x + 4.0, CGRectGetHeight(_tiraDeChips.bounds));
}

- (void)marcarChip:(NSInteger)indice {
    _chipActivo = indice;
    for (UIButton *boton in _botonesChip) {
        [YTTheme aplicarEstiloChip:boton seleccionado:(boton.tag == indice)];
    }
}

- (void)tocarSugerencia:(UIButton *)boton {
    _barra.text = [boton titleForState:UIControlStateNormal];
    [self marcarChip:boton.tag];
    [_barra resignFirstResponder];
    [self buscar:_barra.text];
}

#pragma mark - Busqueda

- (void)searchBarSearchButtonClicked:(UISearchBar *)barra {
    [barra resignFirstResponder];
    [self marcarChip:-1];
    [self buscar:barra.text];
}

- (void)buscar:(NSString *)consulta {
    if (_cargando) return;
    if (consulta.length == 0) return;

    _cargando = YES;
    [_girador startAnimating];
    _estado.text = @"Buscando...";
    _estado.hidden = NO;
    _tabla.hidden = YES;

    __weak YTSearchViewController *deb = self;
    [[YTClient compartido] buscar:consulta completion:^(NSArray *videos, NSError *error) {
        YTSearchViewController *yo = deb;   // ARC no deja usar '->' sobre un __weak
        if (!yo) return;
        yo->_cargando = NO;
        [yo->_girador stopAnimating];
        if (error) {
            yo->_videos = @[];
            [yo->_tabla reloadData];
            yo->_tabla.hidden = YES;
            yo->_estado.hidden = NO;
            yo->_estado.text = [NSString stringWithFormat:@"%@\n\n%@",
                [YTClient explicarError:error],
                @"Ajustes > Probar conexion para mas detalle."];
            return;
        }
        yo->_videos = videos;
        [yo->_tabla reloadData];
        yo->_tabla.hidden = (videos.count == 0);
        yo->_estado.hidden = (videos.count > 0);
        if (videos.count == 0) {
            yo->_estado.text = @"Sin resultados.\nPrueba otra busqueda.";
        }
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
