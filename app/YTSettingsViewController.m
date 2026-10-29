// v1.0-en 2026-10-29: English UI build (textos traducidos al ingles; hl=en, gl=US)
// YTSettingsViewController.m -- conexion, cuenta, descargas y ayuda
#import "YTSettingsViewController.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTLoginViewController.h"
#import "YTDescargas.h"
#import "YTDescargasViewController.h"
#import "YTCarpetaViewController.h"
#import "YTTemaViewController.h"
#import "YTProgreso.h"

@implementation YTSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tabla { return 5; }

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    if (seccion == 0) return 4;   // conexion
    if (seccion == 1) return 3;   // cuenta
    if (seccion == 2) return 3;   // videos y descargas
    if (seccion == 3) return 1;   // apariencia
    return 2;                     // ayuda
}

- (NSString *)tableView:(UITableView *)tabla titleForHeaderInSection:(NSInteger)seccion {
    if (seccion == 0) return @"Connection";
    if (seccion == 1) return @"YouTube account";
    if (seccion == 2) return @"Videos and downloads";
    if (seccion == 3) return @"Appearance";
    return @"Help";
}

- (NSString *)tableView:(UITableView *)tabla titleForFooterInSection:(NSInteger)seccion {
    if (seccion == 0) {
        return @"Direct: the app talks to YouTube directly (needs the "
                "updated certificates on the device).\n"
                "Relay: the app talks to your own server over HTTP, no certificates.";
    }
    if (seccion == 1) {
        return @"Signing in stops YouTube from saying \"confirm you are not a bot\" "
                "and makes playback much more reliable.";
    }
    if (seccion == 2) {
        return @"Downloads are saved as MP4 360p in the folder you choose "
                "(also outside the app, useful with jailbreak). \"Continue watching\" "
                "is the list of half-watched videos shown on Home.";
    }
    if (seccion == 3) {
        return @"Two backgrounds (dark and light) and seven button colors: fourteen "
                "combinations. When you change it, the app redraws itself.";
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
            c.textLabel.text = @"Use my own relay";
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
            c.textLabel.text = @"Relay address";
            NSString *base = [YTClient relayBase];
            c.detailTextLabel.text = base.length ? base : @"not set";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (indice.row == 2) {
            UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
            c.textLabel.text = @"Token (optional)";
            NSString *token = [YTClient relayToken];
            c.detailTextLabel.text = token.length ? @"set" : @"none";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
        c.textLabel.text = @"Test connection";
        c.textLabel.textColor = [YTTheme acento];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }

    if (indice.section == 1) {
        if (indice.row == 0) {
            UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
            BOOL sesion = [YTClient haySesion];
            c.textLabel.text = sesion ? @"Signed in" : @"Sign in to YouTube";
            c.textLabel.textColor = sesion ? [YTTheme textoPrimario] : [YTTheme acento];
            c.detailTextLabel.text = sesion
                ? [NSString stringWithFormat:@"%lu cookies", (unsigned long)[YTClient numeroDeCookies]]
                : @"anonymous";
            c.accessoryType = sesion ? UITableViewCellAccessoryNone
                                     : UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (indice.row == 1) {
            UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
            c.textLabel.text = @"Paste cookies manually";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            c.detailTextLabel.text = @"";
            BOOL hayManuales = [YTClient cookiesManuales].length > 0;
            c.textLabel.textColor = hayManuales ? [YTTheme acento] : [YTTheme textoPrimario];
            return c;
        }
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
        c.textLabel.text = @"Sign out";
        c.textLabel.textColor = [YTTheme acento];
        return c;
    }

    if (indice.section == 2) {
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
        if (indice.row == 0) {
            NSUInteger cuantas = [[YTDescargas compartido] historial].count;
            c.textLabel.text = @"Downloads";
            c.detailTextLabel.text = cuantas
                ? [NSString stringWithFormat:@"%lu videos", (unsigned long)cuantas]
                : @"none";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (indice.row == 1) {
            c.textLabel.text = @"Download folder";
            c.detailTextLabel.text = [YTDescargas nombreBonitoDeCarpeta:[YTDescargas carpeta]];
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        c.textLabel.text = @"Clear \"Continue watching\"";
        c.textLabel.textColor = [YTTheme acento];
        NSUInteger cuantos = [YTProgreso continuarViendo].count;
        c.detailTextLabel.text = cuantos
            ? [NSString stringWithFormat:@"%lu videos", (unsigned long)cuantos]
            : @"empty";
        return c;
    }

    if (indice.section == 3) {
        UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleValue1];
        c.textLabel.text = @"Theme and color";
        c.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
            [YTTheme tituloDeFondo:[YTTheme fondoClave]],
            [YTTheme tituloDeAcento:[YTTheme acentoClave]]];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }

    UITableViewCell *c = [self celdaConEstilo:UITableViewCellStyleDefault];
    if (indice.row == 0) {
        c.textLabel.text = @"Fix iOS 9 certificates";
        c.textLabel.textColor = [YTTheme acento];
    } else {
        c.textLabel.text = @"About Tube9";
    }
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}

#pragma mark - Acciones

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];

    if (indice.section == 0) {
        if (indice.row == 1) { [self editarTextoParaClave:@"relay" titulo:@"Relay address"]; return; }
        if (indice.row == 2) { [self editarTextoParaClave:@"token" titulo:@"Token"]; return; }
        if (indice.row == 3) { [self probarConexion]; return; }
    }

    if (indice.section == 1) {
        if (indice.row == 0) {
            if ([YTClient haySesion]) { [self alerta:@"You are already signed in"
                                             texto:@"To change account, tap Sign out and sign in again."]; return; }
            YTLoginViewController *login = [[YTLoginViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:login];
            [self presentViewController:nav animated:YES completion:nil];
            return;
        }
        if (indice.row == 1) { [self editarCookies]; return; }
        [YTClient cerrarSesion];
        [self.tableView reloadData];
        [self alerta:@"Signed out" texto:@"Requests are now sent without an account."];
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
            [self alerta:@"Nothing to clear"
                   texto:@"\"Continue watching\" is empty right now."];
            return;
        }
        UIAlertController *alerta = [UIAlertController
            alertControllerWithTitle:@"Clear \"Continue watching\""
                             message:[NSString stringWithFormat:
                                @"The %lu half-watched videos will be forgotten. The videos "
                                @"stay on YouTube; only your place in them is lost.",
                                (unsigned long)cuantos]
                      preferredStyle:UIAlertControllerStyleAlert];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Clear"
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *accion) {
            [YTProgreso vaciar];
            [self.tableView reloadData];
        }]];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
        [self presentViewController:alerta animated:YES completion:nil];
        return;
    }

    if (indice.section == 3) {
        [self.navigationController pushViewController:[[YTTemaViewController alloc] init]
                                             animated:YES];
        return;
    }

    if (indice.row == 0) { [self ayudaCertificados]; return; }
    [self acercaDe];
}

- (void)cambioDeModo:(UISwitch *)interruptor {
    NSString *modo = interruptor.on ? @"relay" : @"directo";
    [YTClient guardarModo:modo relay:[YTClient relayBase] token:[YTClient relayToken]];
    if ([modo isEqualToString:@"relay"] && [YTClient relayBase].length == 0) {
        [self alerta:@"Address missing"
               texto:@"Type the address of your relay (for example "
                     "http://192.168.1.50:8787) in the option below."];
    }
    [self.tableView reloadData];
}

- (void)editarTextoParaClave:(NSString *)clave titulo:(NSString *)titulo {
    BOOL esRelay = [clave isEqualToString:@"relay"];
    NSString *actual = esRelay ? [YTClient relayBase] : [YTClient relayToken];

    UIAlertController *alerta =
        [UIAlertController alertControllerWithTitle:titulo
                                            message:(esRelay ? @"Example: http://192.168.1.50:8787"
                                                             : @"Must match the relay's --token.")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alerta addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = actual;
        campo.placeholder = esRelay ? @"http://192.168.1.50:8787" : @"optional";
        campo.keyboardType = esRelay ? UIKeyboardTypeURL : UIKeyboardTypeDefault;
        campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
        campo.autocorrectionType = UITextAutocorrectionTypeNo;
        campo.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault
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
        [UIAlertController alertControllerWithTitle:@"Paste cookies"
                                            message:@"Paste the youtube.com Cookie header here "
                                                    "(for example: SID=...; HSID=...). Leave it empty to clear."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alerta addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = [YTClient cookiesManuales];
        campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
        campo.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        [YTClient guardarCookiesManuales:alerta.textFields.firstObject.text];
        [self.tableView reloadData];
    }]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)probarConexion {
    [self alerta:@"Testing..." texto:@"This can take a few seconds."];
    __weak YTSettingsViewController *deb = self;
    [[YTClient compartido] probarConexion:^(NSString *informe) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [deb dismissViewControllerAnimated:YES completion:^{
                [deb alerta:@"Result" texto:informe];
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
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)ayudaCertificados {
    NSString *texto =
        @"iOS 9.3.5 is from 2016 and does not include the modern authorities, so "
        @"it gives a certificate error when connecting to YouTube.\n\n"
        @"Fix (only once, on a jailbroken device):\n\n"
        @"1. Download the updated root certificates to the device:\n"
        @"   - ISRG Root X1  (Let's Encrypt)\n"
        @"   - GTS Root R1 and GTS Root R4  (Google)\n"
        @"   Find them at letsencrypt.org/certificates and pki.goog/repository.\n\n"
        @"2. Install it as a profile: Settings > General > Profile > Install.\n\n"
        @"3. On iOS 9 an installed root is trusted automatically. "
        @"If the device has it, also check Settings > General > "
        @"About > Certificate Trust Settings.\n\n"
        @"4. Option without certificates: use Relay mode in Settings.";
    [self alerta:@"Fix certificates" texto:texto];
}

- (void)acercaDe {
    NSString *texto =
        @"Tube9 1.0.0 (English UI build)\nUnofficial YouTube client for iOS 9.3.5 (armv7).\n\n"
        @"Built with Theos + iPhoneOS9.3.sdk. Objective-C, flat interface.\n\n"
        @"Legal note: this is not a YouTube app and is not affiliated with Google. "
        @"Videos are accessed through YouTube's own web services, "
        @"whose terms of service still apply.";
    [self alerta:@"About" texto:texto];
}

@end
