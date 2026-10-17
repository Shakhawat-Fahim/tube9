// AppDelegate.m -- monta la interfaz (todo por codigo, sin storyboards)
#import "AppDelegate.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTProgreso.h"
#import "YTFeedViewController.h"
#import "YTTendenciasViewController.h"
#import "YTSearchViewController.h"
#import "YTSettingsViewController.h"

@implementation AppDelegate {
    NSTimer *_rebote;   // espera corta antes de rehacer las pestanas
}

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [YTTheme prepararAparienciaGlobal];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [self montarPestanas];
    self.window.tintColor = [YTTheme textoPrimario];
    [self.window makeKeyAndVisible];

    // Cuando cambia el tema, se vuelven a montar las pestanas enteras. Es mas
    // simple (y mas seguro) que ir repintando pantalla por pantalla.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(alCambiarTema:)
                                                 name:YTThemaCambio
                                               object:nil];
    return YES;
}

#pragma mark - Interfaz

- (UITabBarController *)montarPestanas {
    // --- Pestana 1: Inicio -------------------------------------------------
    // YouTube no da la portada personalizada sin cuenta (devuelve la pantalla
    // vacia), asi que Inicio se monta con estantes tematicos: cada uno es una
    // busqueda ordenada, y el resultado se ve igual que la portada oficial.
    //
    // El primero es local y no cuesta red: "Continuar viendo", con los videos
    // que se han quedado a medias (lo apunta el reproductor).
    NSMutableArray *estantesDeInicio = [NSMutableArray array];
    [estantesDeInicio addObject:@{
        @"titulo"  : @"Continuar viendo",
        @"estante" : @{ @"videos" : [YTProgreso continuarViendo] }
    }];
    [estantesDeInicio addObjectsFromArray:@[
        @{ @"titulo" : @"Tendencias de hoy", @"consulta" : @"tendencias",
           @"params" : YTOrdenPorPopularidad },
        @{ @"titulo" : @"Música",            @"consulta" : @"música",
           @"params" : YTOrdenPorPopularidad },
        @{ @"titulo" : @"Noticias",          @"consulta" : @"noticias de hoy",
           @"params" : YTOrdenRecientes },
        @{ @"titulo" : @"Deportes",          @"consulta" : @"deportes",
           @"params" : YTOrdenRecientes },
        @{ @"titulo" : @"Comedia",           @"consulta" : @"comedia",
           @"params" : YTOrdenPorPopularidad },
        @{ @"titulo" : @"Para aprender",     @"consulta" : @"documentales",
           @"params" : YTOrdenPorPopularidad }
    ]];
    YTFeedViewController *inicio =
        [[YTFeedViewController alloc] initConTitulo:@"Inicio" fuentes:estantesDeInicio];
    UINavigationController *navInicio =
        [[UINavigationController alloc] initWithRootViewController:inicio];
    navInicio.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:@"Inicio"
                image:[YTTheme icono:@"inicio" lado:26]
        selectedImage:nil];

    // --- Pestana 2: Musica -------------------------------------------------
    YTFeedViewController *musica = [[YTFeedViewController alloc] initConMusica];
    UINavigationController *navMusica =
        [[UINavigationController alloc] initWithRootViewController:musica];
    navMusica.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:@"Música"
                image:[YTTheme icono:@"musica" lado:26]
        selectedImage:nil];

    // --- Pestana 3: Tendencias ---------------------------------------------
    YTTendenciasViewController *tendencias = [[YTTendenciasViewController alloc] init];
    UINavigationController *navTendencias =
        [[UINavigationController alloc] initWithRootViewController:tendencias];
    navTendencias.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:@"Tendencias"
                image:[YTTheme icono:@"tendencias" lado:26]
        selectedImage:nil];

    // --- Pestana 4: Buscar -------------------------------------------------
    YTSearchViewController *buscar = [[YTSearchViewController alloc] init];
    UINavigationController *navBuscar =
        [[UINavigationController alloc] initWithRootViewController:buscar];
    navBuscar.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:@"Buscar"
                image:[YTTheme icono:@"buscar" lado:26]
        selectedImage:nil];

    // --- Pestana 5: Ajustes ------------------------------------------------
    YTSettingsViewController *ajustes = [[YTSettingsViewController alloc] init];
    UINavigationController *navAjustes =
        [[UINavigationController alloc] initWithRootViewController:ajustes];
    navAjustes.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:@"Ajustes"
                image:[YTTheme icono:@"ajustes" lado:26]
        selectedImage:nil];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[ navInicio, navMusica, navTendencias, navBuscar, navAjustes ];
    [YTTheme aplicarEstiloTabBar:tabs.tabBar];
    return tabs;
}

#pragma mark - Cambio de tema

- (void)alCambiarTema:(NSNotification *)aviso {
    // Se aplaza un poco a proposito: el aviso llega desde una pantalla que vive
    // DENTRO de las pestanas (el selector de temas). Desmontarlas en mitad de
    // ese toque seria pedir problemas, asi que se deja terminar primero.
    [_rebote invalidate];
    _rebote = [NSTimer scheduledTimerWithTimeInterval:0.15
                                               target:self
                                             selector:@selector(rehacerPestanas)
                                             userInfo:nil
                                              repeats:NO];
}

- (void)rehacerPestanas {
    UITabBarController *viejas = (UITabBarController *)self.window.rootViewController;
    NSInteger cual = 0;
    if ([viejas isKindOfClass:[UITabBarController class]]) {
        cual = viejas.selectedIndex;   // no perder la pestana en la que estabas
    }
    if (viejas.presentedViewController) {
        [viejas dismissViewControllerAnimated:NO completion:nil];
    }

    [YTTheme prepararAparienciaGlobal];
    UITabBarController *nuevas = [self montarPestanas];
    nuevas.selectedIndex = (cual >= 0 && cual < (NSInteger)nuevas.viewControllers.count) ? cual : 0;
    self.window.rootViewController = nuevas;
    self.window.tintColor = [YTTheme textoPrimario];
    [self.window makeKeyAndVisible];
}

@end
