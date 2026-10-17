// YTVideoCell.m -- tarjeta de video: miniatura grande 16:9, duracion encima de
// la imagen y, debajo, titulo y datos del canal. Es el mismo esquema que usa la
// aplicacion oficial de YouTube en el movil.
#import "YTVideoCell.h"
#import "YTTheme.h"
#import "YTClient.h"

static const CGFloat YTMargen = 12.0;

@implementation YTVideoCell {
    UIImageView *_imagen;
    UIView *_vistaDuracion;
    UILabel *_etiquetaDuracion;
    UILabel *_titulo;
    // La linea de debajo del titulo ("canal · visitas · fecha") es un boton:
    // al tocarla se entra en el canal, como en la aplicacion oficial.
    UIButton *_botonCanal;
    NSString *_urlPendiente;
}

+ (CGFloat)altoParaAncho:(CGFloat)ancho {
    CGFloat anchoImagen = ancho - YTMargen * 2.0;
    CGFloat altoImagen = floor(anchoImagen * 9.0 / 16.0);
    // 6 arriba + imagen + 9 + titulo (2 lineas) + 2 + subtitulo + 8 abajo
    return 6.0 + altoImagen + 9.0 + 40.0 + 2.0 + 16.0 + 8.0;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)estilo
              reuseIdentifier:(NSString *)identificador {
    self = [super initWithStyle:estilo reuseIdentifier:identificador];
    if (self) {
        self.backgroundColor = [YTTheme fondo];
        self.contentView.backgroundColor = [YTTheme fondo];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _imagen = [[UIImageView alloc] init];
        _imagen.backgroundColor = [YTTheme superficie];
        _imagen.contentMode = UIViewContentModeScaleAspectFill;
        _imagen.clipsToBounds = YES;
        _imagen.layer.cornerRadius = 10.0;
        [self.contentView addSubview:_imagen];

        _vistaDuracion = [[UIView alloc] init];
        _vistaDuracion.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.80];
        _vistaDuracion.layer.cornerRadius = 4.0;
        _vistaDuracion.layer.masksToBounds = YES;
        [self.contentView addSubview:_vistaDuracion];

        _etiquetaDuracion = [[UILabel alloc] init];
        _etiquetaDuracion.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
        _etiquetaDuracion.textColor = [UIColor whiteColor];
        _etiquetaDuracion.textAlignment = NSTextAlignmentCenter;
        [_vistaDuracion addSubview:_etiquetaDuracion];

        _titulo = [[UILabel alloc] init];
        _titulo.numberOfLines = 2;
        _titulo.font = [YTTheme fuenteTituloLista];
        _titulo.textColor = [YTTheme textoPrimario];
        [self.contentView addSubview:_titulo];

        _botonCanal = [UIButton buttonWithType:UIButtonTypeCustom];
        _botonCanal.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _botonCanal.contentEdgeInsets = UIEdgeInsetsMake(2.0, 0.0, 2.0, 0.0);
        _botonCanal.titleLabel.font = [YTTheme fuenteCuerpo];
        [_botonCanal setTitleColor:[YTTheme textoSecundario] forState:UIControlStateNormal];
        [_botonCanal setTitleColor:[YTTheme acento] forState:UIControlStateHighlighted];
        [_botonCanal addTarget:self action:@selector(tocarCanal)
              forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_botonCanal];
    }
    return self;
}

- (void)configurarCon:(YTVideo *)video {
    _video = video;
    _titulo.text = video.titulo;
    [_botonCanal setTitle:[video descripcion] forState:UIControlStateNormal];
    _botonCanal.enabled = (video.canalId.length > 0);
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
    CGFloat anchoImagen = ancho - YTMargen * 2.0;
    CGFloat altoImagen = floor(anchoImagen * 9.0 / 16.0);

    _imagen.frame = CGRectMake(YTMargen, 6.0, anchoImagen, altoImagen);

    if (_etiquetaDuracion.text.length) {
        CGFloat anchoTexto = [_etiquetaDuracion sizeThatFits:CGSizeMake(80.0, 18.0)].width + 12.0;
        _vistaDuracion.frame = CGRectMake(CGRectGetMaxX(_imagen.frame) - anchoTexto - 6.0,
                                          CGRectGetMaxY(_imagen.frame) - 24.0,
                                          anchoTexto, 18.0);
        _etiquetaDuracion.frame = CGRectMake(0, 0, anchoTexto, 18.0);
        _vistaDuracion.hidden = NO;
    } else {
        _vistaDuracion.hidden = YES;
    }

    CGFloat y = CGRectGetMaxY(_imagen.frame) + 9.0;
    _titulo.frame = CGRectMake(YTMargen, y, anchoImagen, 40.0);
    _botonCanal.frame = CGRectMake(YTMargen, y + 42.0, anchoImagen, 20.0);
}

// El nombre del canal funciona como boton: avisa a la pantalla para que abra
// la ficha del canal.
- (void)tocarCanal {
    if (self.alTocarCanal && _video) self.alTocarCanal(_video);
}

- (void)setHighlighted:(BOOL)resaltado animated:(BOOL)animado {
    [super setHighlighted:resaltado animated:animado];
    [UIView animateWithDuration:0.12 animations:^{
        self->_imagen.alpha = resaltado ? 0.72 : 1.0;
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _urlPendiente = nil;
    _imagen.image = nil;
    _imagen.alpha = 1.0;
    _titulo.text = nil;
    [_botonCanal setTitle:nil forState:UIControlStateNormal];
    _etiquetaDuracion.text = nil;
}

@end
