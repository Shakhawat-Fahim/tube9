// YTProgreso.h -- recuerda por donde iba cada video ("Continuar viendo")
#import <Foundation/Foundation.h>
#import "YTVideo.h"

@interface YTProgreso : NSObject

// Guarda por donde va el video. Si va casi al final (ultimos 10 s) o apenas ha
// empezado (menos de 5 s), se olvida: no tiene sentido reanudar ahi.
+ (void)guardarVideo:(YTVideo *)video segundos:(double)segundos total:(double)total;

+ (double)segundosDe:(NSString *)videoId;
+ (double)totalDe:(NSString *)videoId;
+ (void)olvidar:(NSString *)videoId;

// Lista de YTVideo para el estante "Continuar viendo", lo mas reciente primero.
+ (NSArray *)continuarViendo;

+ (void)vaciar;

@end
