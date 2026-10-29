// v1.0-en 2026-10-29: English UI build (textos traducidos al ingles; hl=en, gl=US)
// YTListaCell.m -- fila de una lista de reproduccion.
#import "YTListaCell.h"
#import "YTTheme.h"
#import "YTClient.h"

static const CGFloat YTMargen = 14.0;
static const CGFloat YTAnchoImagen = 112.0;
static const CGFloat YTAlto = 88.0;

@implementation YTListaCell {
    UIImageView *_imagen;
    UILabel *_titulo;
    UILabel *_datos;
    NSString *_urlPendiente;
}

+ (CGFloat)alto { return YTAlto; }

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
        _imagen.layer.cornerRadius = 8.0;
        [self.contentView addSubview:_imagen];

        _titulo = [[UILabel alloc] init];
        _titulo.numberOfLines = 2;
        _titulo.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold];
        _titulo.textColor = [YTTheme textoPrimario];
        [self.contentView addSubview:_titulo];

        _datos = [[UILabel alloc] init];
        _datos.numberOfLines = 1;
        _datos.font = [YTTheme fuenteMenuda];
        _datos.textColor = [YTTheme textoSecundario];
        [self.contentView addSubview:_datos];
    }
    return self;
}

- (void)configurarCon:(NSDictionary *)lista {
    _lista = lista;
    _titulo.text = lista[@"titulo"];

    NSMutableArray *partes = [NSMutableArray array];
    NSString *canal = lista[@"canal"];
    if ([canal isKindOfClass:[NSString class]] && canal.length) [partes addObject:canal];
    NSString *videos = lista[@"videos"];
    if ([videos isKindOfClass:[NSString class]] && videos.length) [partes addObject:videos];
    _datos.text = [partes count] ? [partes componentsJoinedByString:@"  ·  "] : @"Playlist";

    _imagen.image = nil;
    NSString *url = lista[@"urlMiniatura"];
    _urlPendiente = [url isKindOfClass:[NSString class]] ? url : nil;
    if (_urlPendiente.length == 0) return;

    __weak YTListaCell *deb = self;
    [YTClient cargarMiniatura:_urlPendiente completion:^(UIImage *imagen) {
        YTListaCell *yo = deb;
        if (yo && imagen && [yo->_urlPendiente isEqualToString:url]) {
            yo->_imagen.image = imagen;
        }
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.contentView.bounds);
    CGFloat alto = floor(YTAnchoImagen * 9.0 / 16.0);

    _imagen.frame = CGRectMake(YTMargen, 12.0, YTAnchoImagen, alto);

    CGFloat x = CGRectGetMaxX(_imagen.frame) + 12.0;
    CGFloat util = ancho - x - YTMargen;
    _titulo.frame = CGRectMake(x, 11.0, util, 38.0);
    _datos.frame = CGRectMake(x, CGRectGetMaxY(_titulo.frame) + 2.0, util, 16.0);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _urlPendiente = nil;
    _imagen.image = nil;
    _titulo.text = nil;
    _datos.text = nil;
}

@end
