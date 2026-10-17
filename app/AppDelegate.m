// AppDelegate.m -- monta la interfaz (todo por codigo, sin storyboards)
#import "AppDelegate.h"
#import "YTTheme.h"
#import "YTClient.h"
#import "YTFeedViewController.h"
#import "YTTendenciasViewController.h"
#import "YTSearchViewController.h"
#import "YTSettingsViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [YTTheme prepararAparienciaGlobal];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // --- Pestana 1: Inicio -------------------------------------------------
    // YouTube no da la portada personalizada sin cuenta (devuelve la pantalla
    // vacia), asi que Inicio se monta con estantes tematicos: cada uno es una
    // busqueda ordenada, y el resultado se ve igual que la portada oficial.
    NSArray *estantesDeInicio = @[
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
    ];
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

    self.window.rootViewController = tabs;
    self.window.tintColor = [YTTheme textoPrimario];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
