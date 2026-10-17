// YTVideoCell.m
#import "YTVideoCell.h"
#import "YTTheme.h"
#import "YTClient.h"

@implementation YTVideoCell {
    UIView *_tarjeta;
    UIImageView *_imagen;
    UIImageView *_marca;       // triangulo de reproduccion sobre la miniatura
    UIView *_vistaDuracion;
    UILabel *_etiquetaDuracion;
    UILabel *_titulo;
    UILabel *_subtitulo;
    NSString *_urlPendiente;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)estilo
              reuseIdentifier:(NSString *)identificador {
    self = [super initWithStyle:estilo reuseIdentifier:identificador];
    if (self) {
        self.backgroundColor = [YTTheme fondo];
        self.contentView.backgroundColor = [YTTheme fondo];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _tarjeta = [[UIView alloc] init];
        _tarjeta.backgroundColor = [YTTheme superficie];
        _tarjeta.layer.cornerRadius = 12.0;
        _tarjeta.layer.masksToBounds = YES;
        [self.contentView addSubview:_tarjeta];

        _imagen = [[UIImageView alloc] init];
        _imagen.backgroundColor = [YTTheme superficieAlta];
        _imagen.contentMode = UIViewContentModeScaleAspectFill;
        _imagen.clipsToBounds = YES;
        _imagen.layer.cornerRadius = 8.0;
        [_tarjeta addSubview:_imagen];

        _marca = [[UIImageView alloc] init];
        _marca.image = [[self class] imagenReproducir];
        _marca.contentMode = UIViewContentModeScaleAspectFit;
        [_tarjeta addSubview:_marca];

        _vistaDuracion = [[UIView alloc] init];
        _vistaDuracion.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.78];
        _vistaDuracion.layer.cornerRadius = 4.0;
        _vistaDuracion.layer.masksToBounds = YES;
        [_tarjeta addSubview:_vistaDuracion];

        _etiquetaDuracion = [[UILabel alloc] init];
        _etiquetaDuracion.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
        _etiquetaDuracion.textColor = [UIColor whiteColor];
        _etiquetaDuracion.textAlignment = NSTextAlignmentCenter;
        [_vistaDuracion addSubview:_etiquetaDuracion];

        _titulo = [[UILabel alloc] init];
        _titulo.numberOfLines = 2;
        _titulo.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold];
        _titulo.textColor = [YTTheme textoPrimario];
        [_tarjeta addSubview:_titulo];

        _subtitulo = [[UILabel alloc] init];
        _subtitulo.numberOfLines = 2;
        _subtitulo.font = [UIFont systemFontOfSize:12.0];
        _subtitulo.textColor = [YTTheme textoSecundario];
        [_tarjeta addSubview:_subtitulo];
    }
    return self;
}

+ (UIImage *)imagenReproducir {
    CGFloat lado = 22.0;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(lado, lado), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.92].CGColor);
    CGContextMoveToPoint(ctx, lado * 0.30, lado * 0.18);
    CGContextAddLineToPoint(ctx, lado * 0.30, lado * 0.82);
    CGContextAddLineToPoint(ctx, lado * 0.82, lado * 0.50);
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)configurarCon:(YTVideo *)video {
    _video = video;
    _titulo.text = video.titulo;
    _subtitulo.text = [video descripcion];
    _etiquetaDuracion.text = video.duracion;
    _urlPendiente = video.urlMiniatura;
    _imagen.image = nil;

    if (video.urlMiniatura.length == 0) return;

    __weak YTVideoCell *deb = self;
    [YTClient cargarMiniatura:video.urlMiniatura completion:^(UIImage *imagen) {
        YTVideoCell *yo = deb;   // ARC no deja usar '->' sobre un puntero __weak
        if (yo && imagen && [yo->_urlPendiente isEqualToString:video.urlMiniatura]) {
            yo->_imagen.image = imagen;
        }
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.contentView.bounds);
    CGFloat margen = 12.0;
    _tarjeta.frame = CGRectMake(margen, 5.0, ancho - margen * 2.0,
                                CGRectGetHeight(self.contentView.bounds) - 10.0);

    CGFloat pad = 10.0;
    CGFloat altoTarjeta = CGRectGetHeight(_tarjeta.bounds);
    CGFloat altoImagen = altoTarjeta - pad * 2.0;
    CGFloat anchoImagen = floor(altoImagen * 16.0 / 9.0);
    _imagen.frame = CGRectMake(pad, pad, anchoImagen, altoImagen);

    _marca.frame = CGRectMake(CGRectGetMidX(_imagen.frame) - 11.0,
                              CGRectGetMidY(_imagen.frame) - 11.0, 22.0, 22.0);

    CGFloat anchoDuracion = 0.0;
    if (_etiquetaDuracion.text.length) {
        anchoDuracion = [_etiquetaDuracion sizeThatFits:CGSizeMake(60.0, 20.0)].width + 10.0;
        _vistaDuracion.frame = CGRectMake(CGRectGetMaxX(_imagen.frame) - anchoDuracion - 5.0,
                                          CGRectGetMaxY(_imagen.frame) - 19.0,
                                          anchoDuracion, 15.0);
        _etiquetaDuracion.frame = CGRectMake(0, 0, anchoDuracion, 15.0);
        _vistaDuracion.hidden = NO;
    } else {
        _vistaDuracion.hidden = YES;
    }

    CGFloat xTexto = CGRectGetMaxX(_imagen.frame) + 11.0;
    CGFloat anchoTexto = CGRectGetWidth(_tarjeta.bounds) - xTexto - pad;
    CGFloat altoTitulo = 38.0;
    _titulo.frame = CGRectMake(xTexto, pad + 1.0, anchoTexto, altoTitulo);
    _subtitulo.frame = CGRectMake(xTexto, pad + altoTitulo + 1.0, anchoTexto,
                                  altoTarjeta - pad * 2.0 - altoTitulo - 2.0);
}

- (void)setHighlighted:(BOOL)resaltado animated:(BOOL)animado {
    [super setHighlighted:resaltado animated:animado];
    [UIView animateWithDuration:0.12 animations:^{
        self->_tarjeta.backgroundColor = resaltado ? [YTTheme superficieAlta] : [YTTheme superficie];
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _urlPendiente = nil;
    _imagen.image = nil;
    _titulo.text = nil;
    _subtitulo.text = nil;
    _etiquetaDuracion.text = nil;
}

@end
