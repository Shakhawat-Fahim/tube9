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
    UITableView *_tabla;
    UIActivityIndicatorView *_girador;
    UILabel *_estado;
    NSArray *_videos;
    BOOL _cargando;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tube9";
    self.view.backgroundColor = [YTTheme fondo];
    self.navigationController.navigationBarHidden = NO;
    [self.navigationController.navigationBar setTitleTextAttributes:@{
        NSForegroundColorAttributeName : [YTTheme textoPrimario]
    }];

    _barra = [[UISearchBar alloc] init];
    _barra.delegate = self;
    _barra.placeholder = @"Buscar en YouTube";
    _barra.barStyle = UIBarStyleBlack;
    _barra.translucent = NO;
    _barra.barTintColor = [YTTheme superficie];
    _barra.searchBarStyle = UISearchBarStyleMinimal;
    _barra.tintColor = [YTTheme acento];
    _barra.returnKeyType = UIReturnKeySearch;
    _barra.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _barra.autocorrectionType = UITextAutocorrectionTypeNo;
    _barra.keyboardAppearance = UIKeyboardAppearanceDark;
    _barra.frame = CGRectMake(0, 0, self.view.bounds.size.width - 96.0, 44.0);
    [self configurarCampoDeTextoDeLaBarra];
    self.navigationItem.titleView = _barra;

    // Con la barra de navegacion no translucida, self.view ya empieza debajo.
    _tabla = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tabla.dataSource = self;
    _tabla.delegate = self;
    _tabla.backgroundColor = [YTTheme fondo];
    _tabla.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tabla.rowHeight = 106.0;
    _tabla.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tabla.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:_tabla];

    _girador = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _girador.color = [YTTheme acento];
    _girador.hidesWhenStopped = YES;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:_girador];

    _estado = [[UILabel alloc] initWithFrame:CGRectInset(self.view.bounds, 34.0, 0)];
    _estado.numberOfLines = 0;
    _estado.textAlignment = NSTextAlignmentCenter;
    _estado.textColor = [YTTheme textoSecundario];
    _estado.font = [UIFont systemFontOfSize:14.0];
    _estado.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _estado.text = @"Escribe algo arriba para buscar en YouTube.\n\n"
                   @"Si es la primera vez, mira Ajustes: ahi se explica como "
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

#pragma mark - Busqueda

- (void)searchBarSearchButtonClicked:(UISearchBar *)barra {
    [barra resignFirstResponder];
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
        if (!deb) return;
        deb->_cargando = NO;
        [deb->_girador stopAnimating];
        if (error) {
            deb->_videos = @[];
            [deb->_tabla reloadData];
            deb->_tabla.hidden = YES;
            deb->_estado.hidden = NO;
            deb->_estado.text = [NSString stringWithFormat:@"%@\n\n%@",
                [YTClient explicarError:error],
                @"Ajustes > Probar conexion para mas detalle."];
            return;
        }
        deb->_videos = videos;
        [deb->_tabla reloadData];
        deb->_tabla.hidden = (videos.count == 0);
        deb->_estado.hidden = (videos.count > 0);
        if (videos.count == 0) {
            deb->_estado.text = @"Sin resultados.\nPrueba otra busqueda.";
        }
    }];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    return _videos.count;
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
    YTVideo *video = _videos[indice.row];
    YTPlayerViewController *reproductor = [[YTPlayerViewController alloc] initWithVideo:video];
    reproductor.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:reproductor animated:YES];
}

@end
