// v1.0-en 2026-10-29: English UI build (textos traducidos al ingles; hl=en, gl=US)
// YTTemaViewController.m -- elegir fondo (oscuro o claro) y, dentro de ese
// fondo, el color de los botones. Son catorce combinaciones.
//
// Un aviso importante sobre el flujo: al tocar una opcion se guarda el tema y
// se manda el aviso YTThemaCambio. AppDelegate lo escucha y vuelve a montar las
// pestanas enteras (es la forma segura de repintarlo todo). Como esta pantalla
// vive dentro de esas pestanas, se destruye. Por eso la ultima linea de cada
// accion es siempre el guardado, y nunca se toca "self" despues.
#import "YTTemaViewController.h"
#import "YTTheme.h"

// Muestra de un fondo: un cuadradito redondeado con ese color y su borde.
static UIImage *YTMuestraDeFondo(UIColor *fondo, UIColor *borde, CGFloat lado) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(lado, lado), NO, 0);
    CGRect marco = CGRectMake(0.5, 0.5, lado - 1.0, lado - 1.0);
    UIBezierPath *camino = [UIBezierPath bezierPathWithRoundedRect:marco
                                                          cornerRadius:lado * 0.26];
    [fondo setFill];
    [camino fill];
    [borde setStroke];
    camino.lineWidth = 1.0;
    [camino stroke];
    UIImage *imagen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [imagen imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

// Muestra de un acento: un circulo relleno.
static UIImage *YTMuestraDeAcento(UIColor *color, CGFloat lado) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(lado, lado), NO, 0);
    UIBezierPath *camino = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, lado - 2, lado - 2)];
    [color setFill];
    [camino fill];
    UIImage *imagen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [imagen imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

@interface YTTemaViewController ()
@end

@implementation YTTemaViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Theme";
    self.tableView.backgroundColor = [YTTheme fondo];
    self.tableView.separatorColor = [YTTheme borde];
    self.tableView.rowHeight = 50.0;
}

#pragma mark - Estructura

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tabla { return 3; }

- (NSInteger)tableView:(UITableView *)tabla numberOfRowsInSection:(NSInteger)seccion {
    if (seccion == 0) return [YTTheme fondosDisponibles].count;
    if (seccion == 1) return [YTTheme acentosDisponibles].count;
    return 1;   // vista previa
}

- (NSString *)tableView:(UITableView *)tabla titleForHeaderInSection:(NSInteger)seccion {
    if (seccion == 0) return @"Background";
    if (seccion == 1) return @"Button color";
    return @"Preview";
}

- (NSString *)tableView:(UITableView *)tabla titleForFooterInSection:(NSInteger)seccion {
    if (seccion == 0) {
        return @"The background changes the whole app. It can be combined with any of "
                "the colors below.";
    }
    if (seccion == 1) {
        return @"This color is used for buttons, list filters, the "
                "selected tab and the switches.";
    }
    return @"When you change the theme, the app goes back to Home to redraw all "
            "screens at once.";
}

- (CGFloat)tableView:(UITableView *)tabla heightForRowAtIndexPath:(NSIndexPath *)indice {
    return indice.section == 2 ? 92.0 : 50.0;
}

- (void)tableView:(UITableView *)tabla
    willDisplayHeaderView:(UIView *)vista forSection:(NSInteger)seccion {
    if ([vista isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)vista).textLabel.textColor = [YTTheme textoSecundario];
    }
}

#pragma mark - Celdas

- (UITableViewCell *)celda {
    UITableViewCell *celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                    reuseIdentifier:nil];
    celda.backgroundColor = [YTTheme superficie];
    celda.textLabel.textColor = [YTTheme textoPrimario];
    celda.tintColor = [YTTheme acento];
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = [YTTheme superficieAlta];
    celda.selectedBackgroundView = fondo;
    return celda;
}

- (UITableViewCell *)tableView:(UITableView *)tabla
         cellForRowAtIndexPath:(NSIndexPath *)indice {

    if (indice.section == 0) {
        NSDictionary *opcion = [YTTheme fondosDisponibles][indice.row];
        UITableViewCell *c = [self celda];
        c.textLabel.text = opcion[@"titulo"];
        c.imageView.image = YTMuestraDeFondo([YTTheme fondoDeClave:opcion[@"clave"]],
                                             [YTTheme borde], 28.0);
        if ([opcion[@"clave"] isEqualToString:[YTTheme fondoClave]]) {
            c.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        return c;
    }

    if (indice.section == 1) {
        NSDictionary *opcion = [YTTheme acentosDisponibles][indice.row];
        UITableViewCell *c = [self celda];
        c.textLabel.text = opcion[@"titulo"];
        c.imageView.image = YTMuestraDeAcento(opcion[@"color"], 26.0);
        if ([opcion[@"clave"] isEqualToString:[YTTheme acentoClave]]) {
            c.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        return c;
    }

    // Vista previa: un trocito de interfaz de verdad, con el tema elegido.
    UITableViewCell *c = [self celda];
    c.selectionStyle = UITableViewCellSelectionStyleNone;

    UIView *caja = [[UIView alloc] initWithFrame:CGRectMake(12.0, 8.0,
        CGRectGetWidth(tabla.bounds) - 24.0, 76.0)];
    caja.backgroundColor = [YTTheme fondo];
    caja.layer.cornerRadius = 10.0;
    caja.layer.borderWidth = 1.0;
    caja.layer.borderColor = [YTTheme borde].CGColor;
    caja.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // Un boton del color elegido, como los filtros de Tendencias.
    UILabel *pastilla = [[UILabel alloc] initWithFrame:CGRectMake(12.0, 22.0, 74.0, 30.0)];
    pastilla.text = @"Button";
    pastilla.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    pastilla.textAlignment = NSTextAlignmentCenter;
    pastilla.textColor = [YTTheme textoSobreAcento];
    pastilla.backgroundColor = [YTTheme acento];
    pastilla.layer.cornerRadius = 15.0;
    pastilla.layer.masksToBounds = YES;
    [caja addSubview:pastilla];

    UILabel *titulo = [[UILabel alloc] initWithFrame:CGRectMake(98.0, 20.0,
        CGRectGetWidth(caja.bounds) - 110.0, 18.0)];
    titulo.text = @"Video title";
    titulo.font = [YTTheme fuenteTituloLista];
    titulo.textColor = [YTTheme textoPrimario];
    titulo.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [caja addSubview:titulo];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(98.0, 40.0,
        CGRectGetWidth(caja.bounds) - 110.0, 16.0)];
    sub.text = @"Channel  ·  1.2M views";
    sub.font = [YTTheme fuenteMenuda];
    sub.textColor = [YTTheme textoSecundario];
    sub.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [caja addSubview:sub];

    // Y abajo, la barra de pestanas con la primera en el acento.
    NSArray *tonos = @[ [YTTheme acento], [YTTheme textoSecundario], [YTTheme borde] ];
    for (NSUInteger i = 0; i < tonos.count; i++) {
        UIView *cuadro = [[UIView alloc] initWithFrame:CGRectMake(12.0 + 22.0 * i, 62.0, 14.0, 4.0)];
        cuadro.backgroundColor = tonos[i];
        cuadro.layer.cornerRadius = 2.0;
        [caja addSubview:cuadro];
    }

    [c.contentView addSubview:caja];
    return c;
}

#pragma mark - Acciones

- (void)tableView:(UITableView *)tabla didSelectRowAtIndexPath:(NSIndexPath *)indice {
    [tabla deselectRowAtIndexPath:indice animated:YES];
    if (indice.section == 2) return;   // la vista previa no se toca

    NSString *fondo  = [YTTheme fondoClave];
    NSString *acento = [YTTheme acentoClave];
    if (indice.section == 0) {
        fondo = [YTTheme fondosDisponibles][indice.row][@"clave"];
    } else {
        acento = [YTTheme acentosDisponibles][indice.row][@"clave"];
    }

    // Ultima llamada de este metodo: guardar manda el aviso y AppDelegate vuelve
    // a montar las pestanas, con lo que esta pantalla desaparece. Nada de "self"
    // despues de esto.
    [YTTheme guardarFondo:fondo acento:acento];
}

@end
