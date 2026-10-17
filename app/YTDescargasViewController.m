// YTDescargasViewController.m -- lista de videos descargados y carpeta de destino.
#import "YTDescargasViewController.h"
#import "YTTheme.h"
#import "YTDescargas.h"
#import "YTCarpetaViewController.h"
#import "YTPlayerViewController.h"

@implementation YTDescargasViewController {
    NSArray *_descargas;
    UIDocumentInteractionController *_compartir;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Descargas";
    self.tableView.backgroundColor = [YTTheme fondo];
    self.tableView.separatorColor = [YTTheme borde];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recargar)
                                                 name:YTDescargasCambio
                                               object:nil];
    [self recargar];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animado {
    [super viewWillAppear:animado];
    [self recargar];
}

- (void)recargar {
    _descargas = [[YTDescargas compartido] historial];
    [self.tableView reloadData];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tabla { return 3; }

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    if (seccion == 0) return 2;
    if (seccion == 1) return _descargas.count;
    return _descargas.count > 0 ? 1 : 0;
}

- (NSString *)tableView:(UITableView *)tabla titleForHeaderInSection:(NSInteger)seccion {
    if (seccion == 0) return @"Carpeta de descargas";
    if (seccion == 1) return @"Videos descargados";
    return nil;
}

- (NSString *)tableView:(UITableView *)tabla titleForFooterInSection:(NSInteger)seccion {
    if (seccion == 0) {
        return @"Puedes elegir cualquier carpeta, tambien fuera de la app (esto es "
                "util en dispositivos con jailbreak: /var/mobile/Documents, "
                "/var/mobile/Media...). Se comprueba de verdad si la app puede "
                "escribir antes de usar la carpeta.";
    }
    if (seccion == 1) {
        if (_descargas.count == 0) {
            return @"Todavia no hay nada descargado. Abre un video y pulsa el boton "
                    "Descargar que hay debajo del reproductor.\n\nLa descarga sigue "
                    "mientras la app este abierta.";
        }
        return @"Toca un video para reproducirlo, abrirlo con otra app o borrarlo. "
                "Tambien se puede deslizar para borrar.";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tabla heightForFooterInSection:(NSInteger)seccion {
    if (seccion == 0) return 76.0;
    if (seccion == 1 && _descargas.count == 0) return 96.0;
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tabla
    willDisplayHeaderView:(UIView *)vista forSection:(NSInteger)seccion {
    if ([vista isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)vista).textLabel.textColor = [YTTheme textoSecundario];
    }
}

- (UITableViewCell *)celdaConEstilo:(UITableViewCellStyle)estilo {
    UITableViewCell *celda = [[UITableViewCell alloc] initWithStyle:estilo reuseIdentifier:nil];
    celda.backgroundColor = [YTTheme superficie];
    celda.textLabel.textColor = [YTTheme textoPrimario];
    celda.detailTextLabel.textColor = [YTTheme textoSecundario];
    celda.detailTextLabel.font = [UIFont systemFontOfSize:11.0];
    celda.tintColor = [YTTheme acento];
    return celda;
}

static NSString *YTTextoDeTamano(id bytes) {
    unsigned long long valor = [bytes isKindOfClass:[NSNumber class]]
        ? [bytes unsignedLongLongValue] : 0;
    if (valor >= 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f MB", valor / (1024.0 * 1024.0)];
    }
    return [NSString stringWithFormat:@"%llu KB", valor / 1024ULL];
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {
    if (indice.section == 0) {
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
        if (indice.row == 0) {
            c.textLabel.text = @"Carpeta";
            c.detailTextLabel.text = [YTDescargas nombreBonitoDeCarpeta:[YTDescargas carpeta]];
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            c.textLabel.text = @"Espacio libre";
            unsigned long long libre = [[YTDescargas compartido] espacioLibre];
            unsigned long long gb = 1024ULL * 1024ULL * 1024ULL;
            c.detailTextLabel.text = libre >= gb
                ? [NSString stringWithFormat:@"%.1f GB", libre / (double)gb]
                : [NSString stringWithFormat:@"%llu MB", libre / (1024ULL * 1024ULL)];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        return c;
    }

    if (indice.section == 1) {
        if (indice.row >= (NSInteger)_descargas.count) return [self celdaConEstilo:UITableViewCellStyleDefault];
        NSDictionary *entrada = _descargas[indice.row];
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleSubtitle];
        c.textLabel.text = entrada[@"titulo"];
        c.textLabel.numberOfLines = 2;
        c.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  %@",
            YTTextoDeTamano(entrada[@"bytes"]), entrada[@"archivo"] ?: @""];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }

    UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
    c.textLabel.text = @"Borrar todas las descargas";
    c.textLabel.textColor = [YTTheme acento];
    return c;
}

#pragma mark - Acciones

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];

    if (indice.section == 0) {
        if (indice.row != 0) return;
        YTCarpetaViewController *selector = [[YTCarpetaViewController alloc] init];
        selector.alElegirCarpeta = ^(NSString *ruta) {
            [self recargar];
        };
        [self.navigationController pushViewController:selector animated:YES];
        return;
    }

    if (indice.section == 1) {
        if (indice.row >= (NSInteger)_descargas.count) return;
        [self opcionesPara:_descargas[indice.row]];
        return;
    }

    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:@"Borrar todas las descargas"
                         message:@"Se borraran los ficheros de la carpeta de descargas. "
                                 @"Esto no se puede deshacer."
                  preferredStyle:UIAlertControllerStyleActionSheet];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Borrar todo"
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *accion) {
        [[YTDescargas compartido] borrarTodo];
        [self recargar];
    }]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    if (alerta.popoverPresentationController) {
        UITableViewCell *celda = [tabla cellForRowAtIndexPath:indice];
        alerta.popoverPresentationController.sourceView = celda ?: self.view;
        alerta.popoverPresentationController.sourceRect = celda.bounds;
    }
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)opcionesPara:(NSDictionary *)entrada {
    NSString *titulo = entrada[@"titulo"] ?: @"Video";
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:titulo
                         message:entrada[@"archivo"]
                  preferredStyle:UIAlertControllerStyleActionSheet];

    [alerta addAction:[UIAlertAction actionWithTitle:@"Reproducir aqui"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *accion) {
        YTPlayerViewController *reproductor = [[YTPlayerViewController alloc]
            initConRutaLocal:entrada[@"ruta"] titulo:entrada[@"titulo"]];
        reproductor.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:reproductor animated:YES];
    }]];

    [alerta addAction:[UIAlertAction actionWithTitle:@"Abrir con otra app"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *accion) {
        NSURL *url = [NSURL fileURLWithPath:entrada[@"ruta"]];
        self->_compartir = [UIDocumentInteractionController interactionControllerWithURL:url];
        [self->_compartir presentOptionsMenuFromRect:self.view.bounds
                                              inView:self.view
                                            animated:YES];
    }]];

    [alerta addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *accion) {
        [[YTDescargas compartido] borrarEntrada:entrada];
        [self recargar];
    }]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    if (alerta.popoverPresentationController) {
        alerta.popoverPresentationController.sourceView = self.view;
        alerta.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self presentViewController:alerta animated:YES completion:nil];
}

// Deslizar para borrar.
- (void)tableView:(UITableView *)tabla
    commitEditingStyle:(UITableViewCellEditingStyle)estilo
     forRowAtIndexPath:(NSIndexPath *)indice {
    if (estilo != UITableViewCellEditingStyleDelete) return;
    if (indice.section != 1 || indice.row >= (NSInteger)_descargas.count) return;
    [[YTDescargas compartido] borrarEntrada:_descargas[indice.row]];
    [self recargar];
}

@end
