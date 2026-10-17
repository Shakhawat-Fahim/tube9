// YTCarpetaViewController.h -- elige en que carpeta se guardan las descargas
#import <UIKit/UIKit.h>

@interface YTCarpetaViewController : UITableViewController

// Se llama al pulsar "Usar esta carpeta".
@property (nonatomic, copy) void (^alElegirCarpeta)(NSString *ruta);

@end
