// YTCanalCell.m -- fila de un canal en los resultados del buscador.
#import "YTCanalCell.h"
#import "YTTheme.h"
#import "YTClient.h"

static const CGFloat YTMargen = 14.0;
static const CGFloat YTLadoAvatar = 56.0;
static const CGFloat YTAlto = 94.0;

@implementation YTCanalCell {
    UIImageView *_avatar;
    UILabel *_inicial;      // mientras no llega la foto se enseña la inicial
    UILabel *_nombre;
    UILabel *_datos;
    UILabel *_descripcion;
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

        _avatar = [[UIImageView alloc] init];
        _avatar.backgroundColor = [YTTheme superficieAlta];
        _avatar.contentMode = UIViewContentModeScaleAspectFill;
        _avatar.clipsToBounds = YES;
        _avatar.layer.cornerRadius = YTLadoAvatar / 2.0;
        [self.contentView addSubview:_avatar];

        _inicial = [[UILabel alloc] init];
        _inicial.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightSemibold];
        _inicial.textColor = [YTTheme textoSecundario];
        _inicial.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_inicial];

        _nombre = [[UILabel alloc] init];
        _nombre.numberOfLines = 1;
        _nombre.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        _nombre.textColor = [YTTheme textoPrimario];
        [self.contentView addSubview:_nombre];

        _datos = [[UILabel alloc] init];
        _datos.numberOfLines = 1;
        _datos.font = [YTTheme fuenteMenuda];
        _datos.textColor = [YTTheme textoSecundario];
        [self.contentView addSubview:_datos];

        _descripcion = [[UILabel alloc] init];
        _descripcion.numberOfLines = 2;
        _descripcion.font = [YTTheme fuenteCuerpo];
        _descripcion.textColor = [YTTheme textoSecundario];
        [self.contentView addSubview:_descripcion];
    }
    return self;
}

- (void)configurarCon:(NSDictionary *)canal {
    _canal = canal;

    NSString *nombre = canal[@"titulo"];
    _nombre.text = nombre;
    _inicial.text = nombre.length ? [[nombre substringToIndex:1] uppercaseString] : @"";

    // "@kurzgesagt · 2,35 M de suscriptores"
    NSMutableArray *partes = [NSMutableArray array];
    NSString *manejador = canal[@"manejador"];
    if ([manejador isKindOfClass:[NSString class]] && manejador.length) [partes addObject:manejador];
    NSString *suscritos = canal[@"suscritos"];
    if ([suscritos isKindOfClass:[NSString class]] && suscritos.length) [partes addObject:suscritos];
    NSString *videos = canal[@"videos"];
    if ([videos isKindOfClass:[NSString class]] && videos.length) [partes addObject:videos];
    _datos.text = [partes componentsJoinedByString:@"  ·  "];

    NSString *descripcion = canal[@"descripcion"];
    _descripcion.text = [descripcion isKindOfClass:[NSString class]] ? descripcion : @"";
    _descripcion.hidden = (_descripcion.text.length == 0);

    _avatar.image = nil;
    _inicial.hidden = NO;
    NSString *url = canal[@"urlMiniatura"];
    _urlPendiente = [url isKindOfClass:[NSString class]] ? url : nil;
    if (_urlPendiente.length == 0) return;

    __weak YTCanalCell *deb = self;
    [YTClient cargarMiniatura:_urlPendiente completion:^(UIImage *imagen) {
        YTCanalCell *yo = deb;
        if (yo && imagen && [yo->_urlPendiente isEqualToString:url]) {
            yo->_avatar.image = imagen;
            yo->_inicial.hidden = YES;
        }
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.contentView.bounds);
    CGFloat y = 12.0;

    _avatar.frame = CGRectMake(YTMargen, y, YTLadoAvatar, YTLadoAvatar);
    _inicial.frame = _avatar.frame;

    CGFloat x = CGRectGetMaxX(_avatar.frame) + 12.0;
    CGFloat util = ancho - x - YTMargen;

    _nombre.frame = CGRectMake(x, y, util, 20.0);
    _datos.frame = CGRectMake(x, CGRectGetMaxY(_nombre.frame) + 1.0, util, 16.0);
    _descripcion.frame = CGRectMake(x, CGRectGetMaxY(_datos.frame) + 5.0, util, 32.0);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _urlPendiente = nil;
    _avatar.image = nil;
    _inicial.hidden = NO;
    _inicial.text = nil;
    _nombre.text = nil;
    _datos.text = nil;
    _descripcion.text = nil;
}

@end
