// YTLoginViewController.m
//
// Usa UIWebView (no WKWebView) a proposito: en iOS 9 UIWebView comparte las
// cookies con NSHTTPCookieStorage, asi que despues de iniciar sesion aqui las
// peticiones de YTClient ya van autenticadas sin copiar nada a mano.
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
    self.view.backgroundColor = [YTTheme fondo];

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

    _aviso = [[UILabel alloc] initWithFrame:CGRectMake(14, 62, self.view.bounds.size.width - 28, 40)];
    _aviso.numberOfLines = 2;
    _aviso.font = [UIFont systemFontOfSize:12.0];
    _aviso.textColor = [YTTheme textoSecundario];
    _aviso.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _aviso.text = @"Entra con tu cuenta de Google. Al terminar pulsa Listo.";
    [self.view addSubview:_aviso];

    _navegador = [[UIWebView alloc] initWithFrame:CGRectMake(0, 104,
        self.view.bounds.size.width, self.view.bounds.size.height - 104)];
    _navegador.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _navegador.delegate = self;
    _navegador.backgroundColor = [YTTheme fondo];
    _navegador.opaque = NO;
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

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)navegador {
    _aviso.text = @"Cargando...";
}

- (void)webViewDidFinishLoad:(UIWebView *)navegador {
    if ([YTClient haySesion]) {
        _listo.enabled = YES;
        _aviso.text = @"Sesion iniciada. Pulsa Listo para guardarla.";
        _aviso.textColor = [YTTheme acento];
    } else {
        _aviso.text = @"Entra con tu cuenta de Google. Al terminar pulsa Listo.";
        _aviso.textColor = [YTTheme textoSecundario];
    }
}

- (void)webView:(UIWebView *)navegador didFailLoadWithError:(NSError *)error {
    // -999 es una cancelacion normal al navegar; no lo tratamos como fallo
    if (error.code == NSURLErrorCancelled) return;
    _aviso.text = [NSString stringWithFormat:@"No se pudo cargar: %@",
                   [YTClient explicarError:error]];
    _aviso.textColor = [YTTheme acento];
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
