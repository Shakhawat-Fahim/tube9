// YTSettingsViewController.m -- conexion, cuenta, descargas y ayuda
#import "YTSettingsViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTLoginViewController.h"
#import "YTDescargas.h"
#import "YTDescargasViewController.h"
#import "YTCarpetaViewController.h"
#import "YTProgreso.h"

@implementation YTSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Ajustes";
    self.tableView.backgroundColor = [YTTheme fondo];
    self.tableView.separatorColor = [YTTheme borde];
    self.tableView.rowHeight = 50.0;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

- (void)viewWillAppear:(BOOL)animado {
    [super viewWillAppear:animado];
    [self.tableView reloadData];
}

#pragma mark - Estructura

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tabla { return 4; }

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    if (seccion == 0) return 4;   // conexion
    if (seccion == 1) return 3;   // cuenta
    if (seccion == 2) return 3;   // videos y descargas
    return 2;                     // ayuda
}

- (NSString *)tableView:(UITableView *)tabla titleForHeaderInSection:(NSInteger)seccion {
    if (seccion == 0) return @"Conexion";
    if (seccion == 1) return @"Cuenta de YouTube";
    if (seccion == 2) return @"Videos y descargas";
    return @"Ayuda";
}

- (NSString *)tableView:(UITableView *)tabla titleForFooterInSection:(NSInteger)seccion {
    if (seccion == 0) {
        return @"Directo: la app habla con YouTube directamente (necesita los "
                "certificados actualizados en el dispositivo).\n"
                "Relay: la app habla con un servidor propio por HTTP, sin certificados.";
    }
    if (seccion == 1) {
        return @"Iniciar sesion evita que YouTube diga \"confirma que no eres un bot\" "
                "y mejora mucho la fiabilidad.";
    }
    if (seccion == 2) {
        return @"Las descargas se guardan como MP4 360p en la carpeta que elijas "
                "(tambien fuera de la app, util con jailbreak). \"Continuar viendo\" "
                "es la lista de videos a medias que aparece en Inicio.";
    }
    return nil;
}

- (void)tableView:(UITableView *)tabla
    willDisplayHeaderView:(UIView *)vista forSection:(NSInteger)seccion {
    if ([vista isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *cabecera = (UITableViewHeaderFooterView *)vista;
        cabecera.textLabel.textColor = [YTTheme textoSecundario];
    }
}

#pragma mark - Celdas

- (UITableViewCell *)celdaConEstilo:(UITableViewCellStyle)estilo {
    UITableViewCell *celda = [[UITableViewCell alloc] initWithStyle:estilo reuseIdentifier:nil];
    celda.backgroundColor = [YTTheme superficie];
    celda.textLabel.textColor = [YTTheme textoPrimario];
    celda.detailTextLabel.textColor = [YTTheme textoSecundario];
    celda.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
    celda.tintColor = [YTTheme acento];
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = [YTTheme superficieAlta];
    celda.selectedBackgroundView = fondo;
    return celda;
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {

    if (indice.section == 0) {
        if (indice.row == 0) {
            UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
            c.textLabel.text = @"Usar relay propio";
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *interruptor = [[UISwitch alloc] init];
            interruptor.onTintColor = [YTTheme acento];
            interruptor.on = [[YTClient modo] isEqualToString:@"relay"];
            [interruptor addTarget:self action:@selector(cambioDeModo:)
                  forControlEvents:UIControlEventValueChanged];
            c.accessoryView = interruptor;
            return c;
        }
        if (indice.row == 1) {
            UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
            c.textLabel.text = @"Direccion del relay";
            NSString *base = [YTClient relayBase];
            c.detailTextLabel.text = base.length ? base : @"sin configurar";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (indice.row == 2) {
            UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
            c.textLabel.text = @"Token (opcional)";
            NSString *token = [YTClient relayToken];
            c.detailTextLabel.text = token.length ? @"configurado" : @"ninguno";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
        c.textLabel.text = @"Probar conexion";
        c.textLabel.textColor = [YTTheme acento];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }

    if (indice.section == 1) {
        if (indice.row == 0) {
            UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
            BOOL sesion = [YTClient haySesion];
            c.textLabel.text = sesion ? @"Sesion activa" : @"Iniciar sesion en YouTube";
            c.textLabel.textColor = sesion ? [YTTheme textoPrimario] : [YTTheme acento];
            c.detailTextLabel.text = sesion
                ? [NSString stringWithFormat:@"%lu cookies", (unsigned long)[YTClient numeroDeCookies]]
                : @"anonimo";
            c.accessoryType = sesion ? UITableViewCellAccessoryNone
                                     : UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (indice.row == 1) {
            UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
            c.textLabel.text = @"Pegar cookies manualmente";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            c.detailTextLabel.text = @"";
            BOOL hayManuales = [YTClient cookiesManuales].length > 0;
            c.textLabel.textColor = hayManuales ? [YTTheme acento] : [YTTheme textoPrimario];
            return c;
        }
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
        c.textLabel.text = @"Cerrar sesion";
        c.textLabel.textColor = [YTTheme acento];
        return c;
    }

    if (indice.section == 2) {
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
        if (indice.row == 0) {
            NSUInteger cuantas = [[YTDescargas compartido] historial].count;
            c.textLabel.text = @"Descargas";
            c.detailTextLabel.text = cuantas
                ? [NSString stringWithFormat:@"%lu videos", (unsigned long)cuantas]
                : @"ninguno";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (indice.row == 1) {
            c.textLabel.text = @"Carpeta de descargas";
            c.detailTextLabel.text = [YTDescargas nombreBonitoDeCarpeta:[YTDescargas carpeta]];
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        c.textLabel.text = @"Borrar \"Continuar viendo\"";
        c.textLabel.textColor = [YTTheme acento];
        NSUInteger cuantos = [YTProgreso continuarViendo].count;
        c.detailTextLabel.text = cuantos
            ? [NSString stringWithFormat:@"%lu videos", (unsigned long)cuantos]
            : @"vacio";
        return c;
    }

    UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
    if (indice.row == 0) {
        c.textLabel.text = @"Arreglar los certificados de iOS 9";
        c.textLabel.textColor = [YTTheme acento];
    } else {
        c.textLabel.text = @"Acerca de Tube9";
    }
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}

#pragma mark - Acciones

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];

    if (indice.section == 0) {
        if (indice.row == 1) { [self editarTextoParaClave:@"relay" titulo:@"Direccion del relay"]; return; }
        if (indice.row == 2) { [self editarTextoParaClave:@"token" titulo:@"Token"]; return; }
        if (indice.row == 3) { [self probarConexion]; return; }
    }

    if (indice.section == 1) {
        if (indice.row == 0) {
            if ([YTClient haySesion]) { [self alerta:@"Ya has iniciado sesion"
                                             texto:@"Para cambiarla, pulsa Cerrar sesion y vuelve a entrar."]; return; }
            YTLoginViewController *login = [[YTLoginViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:login];
            [self presentViewController:nav animated:YES completion:nil];
            return;
        }
        if (indice.row == 1) { [self editarCookies]; return; }
        [YTClient cerrarSesion];
        [self.tableView reloadData];
        [self alerta:@"Sesion cerrada" texto:@"Ahora las peticiones van sin cuenta."];
        return;
    }

    if (indice.section == 2) {
        if (indice.row == 0) {
            YTDescargasViewController *lista = [[YTDescargasViewController alloc] init];
            [self.navigationController pushViewController:lista animated:YES];
            return;
        }
        if (indice.row == 1) {
            YTCarpetaViewController *selector = [[YTCarpetaViewController alloc] init];
            [self.navigationController pushViewController:selector animated:YES];
            return;
        }
        NSUInteger cuantos = [YTProgreso continuarViendo].count;
        if (cuantos == 0) {
            [self alerta:@"Nada que borrar"
                   texto:@"\"Continuar viendo\" esta vacio ahora mismo."];
            return;
        }
        UIAlertController *alerta = [UIAlertController
            alertControllerWithTitle:@"Borrar \"Continuar viendo\""
                             message:[NSString stringWithFormat:
                                @"Se olvidaran los %lu videos a medias. Los videos "
                                @"seguiran en YouTube, solo se pierde por donde ibas.",
                                (unsigned long)cuantos]
                      preferredStyle:UIAlertControllerStyleAlert];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *accion) {
            [YTProgreso vaciar];
            [self.tableView reloadData];
        }]];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
        [self presentViewController:alerta animated:YES completion:nil];
        return;
    }

    if (indice.row == 0) { [self ayudaCertificados]; return; }
    [self acercaDe];
}

- (void)cambioDeModo:(UISwitch *)interruptor {
    NSString *modo = interruptor.on ? @"relay" : @"directo";
    [YTClient guardarModo:modo relay:[YTClient relayBase] token:[YTClient relayToken]];
    if ([modo isEqualToString:@"relay"] && [YTClient relayBase].length == 0) {
        [self alerta:@"Falta la direccion"
               texto:@"Escribe la direccion de tu relay (por ejemplo "
                     "http://192.168.1.50:8787) en la opcion de abajo."];
    }
    [self.tableView reloadData];
}

- (void)editarTextoParaClave:(NSString *)clave titulo:(NSString *)titulo {
    BOOL esRelay = [clave isEqualToString:@"relay"];
    NSString *actual = esRelay ? [YTClient relayBase] : [YTClient relayToken];

    UIAlertController *alerta =
        [UIAlertController alertControllerWithTitle:titulo
                                            message:(esRelay ? @"Ejemplo: http://192.168.1.50:8787"
                                                             : @"Debe coincidir con el --token del relay.")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alerta addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = actual;
        campo.placeholder = esRelay ? @"http://192.168.1.50:8787" : @"opcional";
        campo.keyboardType = esRelay ? UIKeyboardTypeURL : UIKeyboardTypeDefault;
        campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
        campo.autocorrectionType = UITextAutocorrectionTypeNo;
        campo.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Guardar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSString *valor = alerta.textFields.firstObject.text ?: @"";
        valor = [valor stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *modo = [YTClient modo];
        [YTClient guardarModo:modo
                        relay:(esRelay ? valor : [YTClient relayBase])
                        token:(esRelay ? [YTClient relayToken] : valor)];
        [self.tableView reloadData];
    }]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)editarCookies {
    UIAlertController *alerta =
        [UIAlertController alertControllerWithTitle:@"Pegar cookies"
                                            message:@"Pega aqui la cabecera Cookie de youtube.com "
                                                    "(por ejemplo: SID=...; HSID=...). Dejalo vacio para borrar."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alerta addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = [YTClient cookiesManuales];
        campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
        campo.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Guardar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        [YTClient guardarCookiesManuales:alerta.textFields.firstObject.text];
        [self.tableView reloadData];
    }]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)probarConexion {
    [self alerta:@"Probando..." texto:@"Esto puede tardar unos segundos."];
    __weak YTSettingsViewController *deb = self;
    [[YTClient compartido] probarConexion:^(NSString *informe) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [deb dismissViewControllerAnimated:YES completion:^{
                [deb alerta:@"Resultado" texto:informe];
                [deb.tableView reloadData];
            }];
        });
    }];
}

#pragma mark - Ayudas

- (void)alerta:(NSString *)titulo texto:(NSString *)texto {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:titulo
                                                              message:texto
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Vale" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)ayudaCertificados {
    NSString *texto =
        @"iOS 9.3.5 es de 2016 y no incluye las autoridades modernas, por eso "
        @"da error de certificado al conectar con YouTube.\n\n"
        @"Solucion (una sola vez, en un dispositivo con jailbreak):\n\n"
        @"1. Descarga en el dispositivo las raices actualizadas:\n"
        @"   - ISRG Root X1  (Let's Encrypt)\n"
        @"   - GTS Root R1 y GTS Root R4  (Google)\n"
        @"   Buscalas en letsencrypt.org/certificates y pki.goog/repository.\n\n"
        @"2. Instalalo como perfil: Ajustes > General > Perfil > Instalar.\n\n"
        @"3. En iOS 9 la raiz instalada pasa a ser de confianza automaticamente. "
        @"Si el dispositivo lo permite, comprueba ademas en Ajustes > General > "
        @"Informacion > Ajustes de confianza de certificados.\n\n"
        @"4. Alternativa sin tocar certificados: usa el modo Relay en Ajustes.";
    [self alerta:@"Arreglar certificados" texto:texto];
}

- (void)acercaDe {
    NSString *texto =
        @"Tube9 1.0.0\nCliente no oficial de YouTube para iOS 9.3.5 (armv7).\n\n"
        @"Compilado con Theos + iPhoneOS9.3.sdk. Objective-C, interfaz plana.\n\n"
        @"Nota legal: no es una app de YouTube ni esta afiliada a Google. "
        @"El acceso a los videos se hace mediante la propia web de YouTube, "
        @"cuyas condiciones de uso siguen aplicando.";
    [self alerta:@"Acerca de" texto:texto];
}

@end
