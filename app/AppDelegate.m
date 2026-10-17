// AppDelegate.m -- monta la interfaz (todo por codigo, sin storyboards)
#import "AppDelegate.h"
#import "YTTheme.h"
#import "YTSearchViewController.h"
#import "YTSettingsViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [YTTheme prepararAparienciaGlobal];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // --- Pestana 1: Buscar -------------------------------------------------
    YTSearchViewController *buscar = [[YTSearchViewController alloc] init];
    UINavigationController *navBuscar =
        [[UINavigationController alloc] initWithRootViewController:buscar];
    navBuscar.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:@"Buscar"
                image:[self imagenSimple:@"magnifyingglass" radio:22]
        selectedImage:nil];

    // --- Pestana 2: Ajustes -----------------------------------------------
    YTSettingsViewController *ajustes = [[YTSettingsViewController alloc] init];
    UINavigationController *navAjustes =
        [[UINavigationController alloc] initWithRootViewController:ajustes];
    navAjustes.tabBarItem = [[UITabBarItem alloc]
        initWithTitle:@"Ajustes"
                image:[self imagenSimple:@"gear" radio:22]
        selectedImage:nil];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[ navBuscar, navAjustes ];
    [YTTheme aplicarEstiloTabBar:tabs.tabBar];

    self.window.rootViewController = tabs;
    self.window.tintColor = [YTTheme acento];
    [self.window makeKeyAndVisible];
    return YES;
}

// Dibuja un icono vectorial sencillo (sin depender de ficheros de imagen).
- (UIImage *)imagenSimple:(NSString *)forma radio:(CGFloat)lado {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(lado, lado), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 1.9);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGRect r = CGRectInset(CGRectMake(0, 0, lado, lado), 3, 3);

    if ([forma isEqualToString:@"magnifyingglass"]) {
        CGFloat d = lado * 0.60;
        CGRect circulo = CGRectMake(r.origin.x, r.origin.y, d, d);
        CGContextStrokeEllipseInRect(ctx, circulo);
        CGContextMoveToPoint(ctx, CGRectGetMaxX(circulo) - 1.5, CGRectGetMaxY(circulo) - 1.5);
        CGContextAddLineToPoint(ctx, CGRectGetMaxX(r), CGRectGetMaxY(r));
        CGContextStrokePath(ctx);
    } else {
        CGContextStrokeEllipseInRect(ctx, CGRectInset(r, lado * 0.22, lado * 0.22));
        CGContextMoveToPoint(ctx, r.origin.x, CGRectGetMidY(r));
        CGContextAddLineToPoint(ctx, CGRectGetMaxX(r), CGRectGetMidY(r));
        CGContextStrokePath(ctx);
        CGFloat y = r.origin.y + (lado - 6) / 4;
        CGContextStrokeEllipseInRect(ctx, CGRectMake(CGRectGetMidX(r) - 1.4, y - 1.4, 2.8, 2.8));
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@end
