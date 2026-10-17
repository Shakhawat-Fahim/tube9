// YTLoginViewController.m
//
// Usa UIWebView (no WKWebView) a proposito: en iOS 9 UIWebView comparte las
// cookies con NSHTTPCookieStorage, asi que despues de iniciar sesion aqui las
// peticiones de YTClient ya van autenticadas sin copiar nada a mano.
//
// ESTA PANTALLA ES CLARA A PROPOSITO, aunque el resto de la app sea oscura.
// La pagina de Google no admite que le impongamos colores: si su hoja de
// estilos no llega a cargar (cosa que pasa cuando la conexion recorta o
// bloquea parte de accounts.google.com) el navegador dibuja el texto plano, y
// el texto por defecto es NEGRO. Sobre el fondo oscuro de la app eso es
// exactamente "todo negro con letras negras". Con fondo claro se lee siempre,
// cargue o no cargue el CSS.
#import "YTLoginViewController.h"
#import "YTTheme.h"
#import "YTClient.h"

@interface YTLoginViewController () <UIWebViewDelegate>
@end

@implementation YTLoginViewController {
    UIWebView *_navegador;
    UILabel *_aviso;
    UIBarButtonItem *_listo;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Iniciar sesion";
    self.view.backgroundColor = [UIColor whiteColor];

    // El resto de la app lleva la barra oscura; aqui la ponemos clara para que
    // toda la pantalla sea coherente y legible.
    UINavigationBar *barra = self.navigationController.navigationBar;
    barra.barTintColor = [UIColor whiteColor];
    barra.tintColor = [UIColor colorWithRed:0.10 green:0.35 blue:0.85 alpha:1.0];
    barra.translucent = NO;
    barra.titleTextAttributes = @{ NSForegroundColorAttributeName :
        [UIColor colorWithWhite:0.13 alpha:1.0] };

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Cancelar"
                                        style:UIBarButtonItemStylePlain
                                       target:self
                                       action:@selector(cancelar)];
    _listo = [[UIBarButtonItem alloc] initWithTitle:@"Listo"
                                             style:UIBarButtonItemStyleDone
                                            target:self
                                            action:@selector(terminar)];
    _listo.enabled = [YTClient haySesion];
    self.navigationItem.rightBarButtonItem = _listo;

    _aviso = [[UILabel alloc] initWithFrame:CGRectMake(14, 8,
        self.view.bounds.size.width - 28, 46)];
    _aviso.numberOfLines = 3;
    _aviso.font = [UIFont systemFontOfSize:12.0];
    _aviso.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
    _aviso.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _aviso.text = @"Entra con tu cuenta de Google. Al terminar, vuelve aqui y pulsa Listo.";
    [self.view addSubview:_aviso];

    _navegador = [[UIWebView alloc] initWithFrame:CGRectMake(0, 60,
        self.view.bounds.size.width, self.view.bounds.size.height - 60)];
    _navegador.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _navegador.delegate = self;
    // Blanca y opaca: asi el fondo oscuro de la app no puede transparentarse
    // por debajo de la pagina y dejarla ilegible.
    _navegador.backgroundColor = [UIColor whiteColor];
    _navegador.opaque = YES;
    _navegador.scrollView.backgroundColor = [UIColor whiteColor];
    _navegador.scalesPageToFit = YES;
    [self.view addSubview:_navegador];

    NSString *direccion = @"https://accounts.google.com/ServiceLogin?service=youtube"
                           "&hl=es&continue=https%3A%2F%2Fm.youtube.com%2F";
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:direccion]];
    // Google bloquea a veces los navegadores incrustados; con un agente de
    // Safari movil se comporta como un navegador normal.
    [peticion setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 9_3_5 like Mac OS X) "
                       @"AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 "
                       @"Mobile/13G36 Safari/601.1"
        forHTTPHeaderField:@"User-Agent"];
    [_navegador loadRequest:peticion];
}

// Pinta el lienzo de la pagina de blanco. Solo toca html y body, no los
// colores propios que ya trae Google (botones, enlaces): si su CSS carga, se
// ve igual que en cualquier navegador; si no carga, el texto negro por defecto
// queda sobre fondo blanco y se lee.
- (void)forzarFondoClaro {
    NSString *js =
        @"(function(){"
         "if(!document.documentElement){return;}"
         "var s=document.createElement('style');"
         "s.type='text/css';"
         "s.appendChild(document.createTextNode('html,body{background-color:#ffffff "
            "!important;color:#202124 !important;}'));"
         "document.documentElement.appendChild(s);"
         "if(document.body){document.body.style.backgroundColor='#ffffff';}"
         "})();";
    [_navegador stringByEvaluatingJavaScriptFromString:js];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)navegador {
    _aviso.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
    _aviso.text = @"Cargando la pagina de Google...";
}

- (void)webViewDidFinishLoad:(UIWebView *)navegador {
    [self forzarFondoClaro];

    // A veces Google contesta que el navegador integrado no es de fiar. En ese
    // caso hay una alternativa que si funciona: pegar las cookies a mano.
    NSString *texto = [navegador stringByEvaluatingJavaScriptFromString:
        @"(function(){return (document.body && document.body.innerText) "
         "? document.body.innerText : '';})()"];
    BOOL bloqueado = ([texto rangeOfString:@"no es seguro"
                                   options:NSCaseInsensitiveSearch].location != NSNotFound) ||
                     ([texto rangeOfString:@"not be secure"
                                   options:NSCaseInsensitiveSearch].location != NSNotFound) ||
                     ([texto rangeOfString:@"navegador no es seguro"
                                   options:NSCaseInsensitiveSearch].location != NSNotFound);
    if (bloqueado) {
        _aviso.textColor = [YTTheme acento];
        _aviso.text = @"Google no acepta este navegador. Pulsa Cancelar y usa "
                       "\"Pegar cookies\" en Ajustes.";
        return;
    }

    if ([YTClient haySesion]) {
        _listo.enabled = YES;
        _aviso.textColor = [YTTheme acento];
        _aviso.text = @"Sesion iniciada. Pulsa Listo para guardarla.";
    } else {
        _aviso.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
        _aviso.text = @"Entra con tu cuenta de Google. Al terminar, vuelve aqui y pulsa Listo.";
    }
}

- (void)webView:(UIWebView *)navegador didFailLoadWithError:(NSError *)error {
    // -999 es una cancelacion normal al navegar; no lo tratamos como fallo
    if (error.code == NSURLErrorCancelled) return;
    _aviso.textColor = [YTTheme acento];
    _aviso.text = [NSString stringWithFormat:@"No se pudo cargar: %@",
                   [YTClient explicarError:error]];
}

#pragma mark - Acciones

- (void)cancelar {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)terminar {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"tube9_usuario"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
