// YTCarpetaViewController.m -- explorador de carpetas muy sencillo.
//
// En un iPhone con jailbreak la app puede escribir en carpetas que no son las
// suyas (/var/mobile/Media, por ejemplo), pero no siempre: depende del jailbreak
// y de los permisos. Por eso cada carpeta se somete a una prueba de escritura
// real y se marca con un visto o con un aviso, en vez de dejar que la descarga
// falle mas tarde y sin explicacion.
#import "YTCarpetaViewController.h"
#import "YTTheme.h"
#import "YTDescargas.h"

@implementation YTCarpetaViewController {
    NSString *_ruta;
    NSArray *_subcarpetas;
    NSMutableArray *_sitios;
    BOOL _cargando;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Carpeta";
    self.tableView.backgroundColor = [YTTheme fondo];
    self.tableView.separatorColor = [YTTheme borde];

    // Sitios a los que suele querer ir la gente en un dispositivo con jailbreak.
    NSString *documentos = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSMutableArray *sitios = [NSMutableArray array];
    if (documentos.length) [sitios addObject:documentos];
    for (NSString *ruta in @[ @"/var/mobile/Documents",
                              @"/var/mobile/Media/Downloads",
                              @"/var/mobile/Media",
                              @"/var/mobile",
                              @"/" ]) {
        if (![sitios containsObject:ruta]) [sitios addObject:ruta];
    }
    _sitios = sitios;

    NSString *inicial = [YTDescargas carpeta];
    if (inicial.length == 0) inicial = documentos;
    [self irA:inicial];
}

- (void)irA:(NSString *)ruta {
    _ruta = [ruta copy];
    _subcarpetas = @[];
    [self listar];
}

#pragma mark - Listado

- (void)listar {
    _cargando = YES;
    [self.tableView reloadData];

    NSString *ruta = _ruta;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *ficheros = [NSFileManager defaultManager];
        NSArray *contenido = [ficheros contentsOfDirectoryAtPath:ruta error:nil];
        NSMutableArray *subcarpetas = [NSMutableArray array];
        for (NSString *nombre in contenido) {
            if ([nombre hasPrefix:@"."]) continue;
            NSString *completa = [ruta stringByAppendingPathComponent:nombre];
            BOOL esCarpeta = NO;
            if (![ficheros fileExistsAtPath:completa isDirectory:&esCarpeta] || !esCarpeta) continue;
            [subcarpetas addObject:@{ @"nombre" : nombre,
                                      @"ruta" : completa,
                                      @"puede" : @([YTDescargas sePuedeEscribirEn:completa]) }];
            if (subcarpetas.count >= 400) break;
        }
        [subcarpetas sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"nombre"] localizedCaseInsensitiveCompare:b[@"nombre"]];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            // Si mientras tanto el usuario ya se ha movido a otra carpeta, esto
            // que llega tarde no vale para nada.
            if (![self->_ruta isEqualToString:ruta]) return;
            self->_subcarpetas = subcarpetas;
            self->_cargando = NO;
            [self.tableView reloadData];
        });
    });
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tabla { return 3; }

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    if (seccion == 0) return 1;
    if (seccion == 1) return _sitios.count;
    return _subcarpetas.count + ([_ruta isEqualToString:@"/"] ? 0 : 1);
}

- (NSString *)tableView:(UITableView *)tabla titleForHeaderInSection:(NSInteger)seccion {
    if (seccion == 0) return @"Carpeta elegida";
    if (seccion == 1) return @"Sitios rapidos";
    return @"Entrar en...";
}

- (NSString *)tableView:(UITableView *)tabla titleForFooterInSection:(NSInteger)seccion {
    if (seccion == 0) {
        return [NSString stringWithFormat:@"%@\n\nCada carpeta se marca con un visto "
                @"si la app puede escribir de verdad en ella. En un dispositivo con "
                @"jailbreak lo normal es /var/mobile/Documents o /var/mobile/Media.",
                _ruta];
    }
    if (seccion == 2 && _subcarpetas.count == 0) {
        return _cargando ? @"Mirando que hay aqui..." : @"No hay subcarpetas.";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tabla heightForFooterInSection:(NSInteger)seccion {
    if (seccion == 0) return 96.0;
    if (seccion == 2 && _subcarpetas.count == 0) return 44.0;
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tabla
    willDisplayHeaderView:(UIView *)vista forSection:(NSInteger)seccion {
    if ([vista isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)vista).textLabel.textColor = [YTTheme textoSecundario];
    }
}

- (UITableViewCell *)celda {
    UITableViewCell *celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                    reuseIdentifier:nil];
    celda.backgroundColor = [YTTheme superficie];
    celda.textLabel.textColor = [YTTheme textoPrimario];
    celda.detailTextLabel.textColor = [YTTheme textoSecundario];
    celda.detailTextLabel.font = [UIFont systemFontOfSize:11.0];
    celda.tintColor = [YTTheme acento];
    return celda;
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {
    NSString *carpeta = [YTDescargas carpeta];

    if (indice.section == 0) {
        UITableViewCell *c = [self celda];
        c.textLabel.text = @"Usar esta carpeta";
        c.textLabel.textColor = [YTTheme acento];
        c.detailTextLabel.text = [YTDescargas nombreBonitoDeCarpeta:_ruta];
        BOOL puede = [YTDescargas sePuedeEscribirEn:_ruta];
        c.accessoryType = puede ? UITableViewCellAccessoryCheckmark
                                : UITableViewCellAccessoryNone;
        c.detailTextLabel.textColor = puede ? [YTTheme textoSecundario] : [YTTheme acento];
        if (!puede) c.detailTextLabel.text = @"(no se puede escribir aqui)";
        if ([carpeta isEqualToString:_ruta] && puede) {
            c.accessoryType = UITableViewCellAccessoryCheckmark;
            c.textLabel.textColor = [YTTheme textoSecundario];
        }
        return c;
    }

    if (indice.section == 1) {
        NSDictionary *sitio = [self sitio:indice.row];
        return [self celdaParaCarpeta:sitio];
    }

    BOOL hayPadre = ![_ruta isEqualToString:@"/"];
    if (hayPadre && indice.row == 0) {
        UITableViewCell *c = [self celda];
        c.textLabel.text = @"⋯  Carpeta superior";
        c.detailTextLabel.text = [YTDescargas nombreBonitoDeCarpeta:[_ruta stringByDeletingLastPathComponent]];
        return c;
    }
    NSInteger fila = hayPadre ? indice.row - 1 : indice.row;
    if (fila < 0 || (NSUInteger)fila >= _subcarpetas.count) return [self celda];
    return [self celdaParaCarpeta:_subcarpetas[fila]];
}

- (NSDictionary *)sitio:(NSInteger)indice {
    NSString *ruta = _sitios[indice];
    return @{ @"nombre" : ruta,
              @"ruta" : ruta,
              @"puede" : @([YTDescargas sePuedeEscribirEn:ruta]) };
}

- (UITableViewCell *)celdaParaCarpeta:(NSDictionary *)carpeta {
    UITableViewCell *c = [self celda];
    BOOL puede = [carpeta[@"puede"] boolValue];
    NSString *nombre = carpeta[@"nombre"];
    if ([nombre isEqualToString:@"/"]) nombre = @"/  (raiz del sistema)";
    c.textLabel.text = nombre;
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (puede) {
        c.detailTextLabel.text = @"se puede escribir";
    } else {
        c.detailTextLabel.text = @"sin permiso de escritura";
    }
    return c;
}

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];

    if (indice.section == 0) {
        if (![YTDescargas sePuedeEscribirEn:_ruta]) {
            UIAlertController *alerta = [UIAlertController
                alertControllerWithTitle:@"Sin permiso"
                                 message:@"La app no puede escribir en esta carpeta. "
                                         @"Prueba /var/mobile/Documents o la carpeta "
                                         @"Descargas de la propia app."
                          preferredStyle:UIAlertControllerStyleAlert];
            [alerta addAction:[UIAlertAction actionWithTitle:@"Vale"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil]];
            [self presentViewController:alerta animated:YES completion:nil];
            return;
        }
        [YTDescargas guardarCarpeta:_ruta];
        if (self.alElegirCarpeta) self.alElegirCarpeta(_ruta);
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    NSString *destino = nil;
    if (indice.section == 1) {
        destino = [self sitio:indice.row][@"ruta"];
    } else {
        BOOL hayPadre = ![_ruta isEqualToString:@"/"];
        if (hayPadre && indice.row == 0) {
            destino = [_ruta stringByDeletingLastPathComponent];
        } else {
            NSInteger fila = hayPadre ? indice.row - 1 : indice.row;
            if (fila >= 0 && (NSUInteger)fila < _subcarpetas.count) {
                destino = _subcarpetas[fila][@"ruta"];
            }
        }
    }
    if (destino.length) [self irA:destino];
}

@end
