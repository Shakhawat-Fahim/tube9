// YTCarruselCell.m -- estante horizontal: un titulo y una tira de tarjetas que
// se puede deslizar de lado. Es la pieza con la que se monta la pantalla de
// Inicio (y la de Musica), igual que en la aplicacion oficial.
#import "YTCarruselCell.h"
#import "YTTheme.h"
#import "YTClient.h"

static const CGFloat YTMargenLateral   = 12.0;
static const CGFloat YTAltoTituloFila  = 26.0;
static const CGFloat YTAnchoTarjeta    = 200.0;
static const CGFloat YTAltoImagenTarjeta = 112.0;   // 200 * 9/16
static const CGFloat YTAltoTarjeta     = 170.0;

#pragma mark - Tarjeta

// La tarjeta pequena que va dentro del estante. Es privada de este fichero.
@interface YTTarjetaCell : UICollectionViewCell
@property (nonatomic, strong) YTVideo *video;
- (void)configurarCon:(YTVideo *)video;
@end

@implementation YTTarjetaCell {
    UIImageView *_imagen;
    UIView *_vistaDuracion;
    UILabel *_etiquetaDuracion;
    UILabel *_titulo;
    UILabel *_subtitulo;
    NSString *_urlPendiente;
}

- (instancetype)initWithFrame:(CGRect)marco {
    self = [super initWithFrame:marco];
    if (self) {
        self.backgroundColor = [YTTheme fondo];
        self.contentView.backgroundColor = [YTTheme fondo];

        _imagen = [[UIImageView alloc] init];
        _imagen.backgroundColor = [YTTheme superficie];
        _imagen.contentMode = UIViewContentModeScaleAspectFill;
        _imagen.clipsToBounds = YES;
        _imagen.layer.cornerRadius = 8.0;
        [self.contentView addSubview:_imagen];

        _vistaDuracion = [[UIView alloc] init];
        _vistaDuracion.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.80];
        _vistaDuracion.layer.cornerRadius = 4.0;
        _vistaDuracion.layer.masksToBounds = YES;
        [self.contentView addSubview:_vistaDuracion];

        _etiquetaDuracion = [[UILabel alloc] init];
        _etiquetaDuracion.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
        _etiquetaDuracion.textColor = [UIColor whiteColor];
        _etiquetaDuracion.textAlignment = NSTextAlignmentCenter;
        [_vistaDuracion addSubview:_etiquetaDuracion];

        _titulo = [[UILabel alloc] init];
        _titulo.numberOfLines = 2;
        _titulo.font = [YTTheme fuenteTituloTarjeta];
        _titulo.textColor = [YTTheme textoPrimario];
        [self.contentView addSubview:_titulo];

        _subtitulo = [[UILabel alloc] init];
        _subtitulo.numberOfLines = 1;
        _subtitulo.font = [YTTheme fuenteMenuda];
        _subtitulo.textColor = [YTTheme textoSecundario];
        [self.contentView addSubview:_subtitulo];
    }
    return self;
}

- (void)configurarCon:(YTVideo *)video {
    _video = video;
    _titulo.text = video.titulo;
    _subtitulo.text = (video.canal.length ? video.canal : video.vistas);
    _etiquetaDuracion.text = video.duracion;
    _urlPendiente = video.urlMiniatura;
    _imagen.image = nil;
    [self setNeedsLayout];

    if (video.urlMiniatura.length == 0) return;

    __weak YTTarjetaCell *deb = self;
    [YTClient cargarMiniatura:video.urlMiniatura completion:^(UIImage *imagen) {
        YTTarjetaCell *yo = deb;
        if (yo && imagen && [yo->_urlPendiente isEqualToString:video.urlMiniatura]) {
            yo->_imagen.image = imagen;
        }
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.contentView.bounds);
    _imagen.frame = CGRectMake(0, 0, ancho, YTAltoImagenTarjeta);

    if (_etiquetaDuracion.text.length) {
        CGFloat anchoTexto = [_etiquetaDuracion sizeThatFits:CGSizeMake(70.0, 16.0)].width + 10.0;
        _vistaDuracion.frame = CGRectMake(CGRectGetMaxX(_imagen.frame) - anchoTexto - 5.0,
                                          CGRectGetMaxY(_imagen.frame) - 21.0,
                                          anchoTexto, 16.0);
        _etiquetaDuracion.frame = CGRectMake(0, 0, anchoTexto, 16.0);
        _vistaDuracion.hidden = NO;
    } else {
        _vistaDuracion.hidden = YES;
    }

    _titulo.frame = CGRectMake(0, YTAltoImagenTarjeta + 6.0, ancho, 34.0);
    _subtitulo.frame = CGRectMake(0, YTAltoImagenTarjeta + 40.0, ancho, 16.0);
}

- (void)setHighlighted:(BOOL)resaltado {
    [super setHighlighted:resaltado];
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
    _subtitulo.text = nil;
    _etiquetaDuracion.text = nil;
}

@end

#pragma mark - Fila con estante

@interface YTCarruselCell () <UICollectionViewDataSource, UICollectionViewDelegate>
@end

@implementation YTCarruselCell {
    UILabel *_titulo;
    UICollectionView *_coleccion;
    NSArray *_videos;
}

+ (CGFloat)alto {
    // 4 de arriba + titulo + 6 de separacion + tarjetas + 10 de abajo
    return 4.0 + YTAltoTituloFila + 6.0 + YTAltoTarjeta + 10.0;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)estilo
              reuseIdentifier:(NSString *)identificador {
    self = [super initWithStyle:estilo reuseIdentifier:identificador];
    if (self) {
        self.backgroundColor = [YTTheme fondo];
        self.contentView.backgroundColor = [YTTheme fondo];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _titulo = [[UILabel alloc] init];
        _titulo.font = [YTTheme fuenteTituloFila];
        _titulo.textColor = [YTTheme textoPrimario];
        [self.contentView addSubview:_titulo];

        UICollectionViewFlowLayout *flujo = [[UICollectionViewFlowLayout alloc] init];
        flujo.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        flujo.itemSize = CGSizeMake(YTAnchoTarjeta, YTAltoTarjeta);
        flujo.minimumLineSpacing = 10.0;
        flujo.minimumInteritemSpacing = 10.0;
        flujo.sectionInset = UIEdgeInsetsMake(0, YTMargenLateral, 0, YTMargenLateral);

        _coleccion = [[UICollectionView alloc] initWithFrame:CGRectZero
                                        collectionViewLayout:flujo];
        _coleccion.backgroundColor = [YTTheme fondo];
        _coleccion.dataSource = self;
        _coleccion.delegate = self;
        _coleccion.showsHorizontalScrollIndicator = NO;
        _coleccion.alwaysBounceHorizontal = YES;
        [_coleccion registerClass:[YTTarjetaCell class]
       forCellWithReuseIdentifier:@"tarjeta"];
        [self.contentView addSubview:_coleccion];
    }
    return self;
}

- (void)configurarConTitulo:(NSString *)titulo videos:(NSArray *)videos {
    _titulo.text = titulo;
    _videos = videos;
    [_coleccion setContentOffset:CGPointZero animated:NO];
    [_coleccion reloadData];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.contentView.bounds);
    _titulo.frame = CGRectMake(YTMargenLateral, 4.0, ancho - YTMargenLateral * 2.0,
                               YTAltoTituloFila);
    _coleccion.frame = CGRectMake(0, YTAltoTituloFila + 10.0, ancho, YTAltoTarjeta);
}

#pragma mark - Coleccion

- (NSInteger)collectionView:(UICollectionView *)coleccion
     numberOfItemsInSection:(NSInteger)seccion {
    return _videos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)coleccion
                  cellForItemAtIndexPath:(NSIndexPath *)indice {
    YTTarjetaCell *tarjeta =
        [coleccion dequeueReusableCellWithReuseIdentifier:@"tarjeta" forIndexPath:indice];
    [tarjeta configurarCon:_videos[indice.item]];
    return tarjeta;
}

- (void)collectionView:(UICollectionView *)coleccion
    didSelectItemAtIndexPath:(NSIndexPath *)indice {
    [coleccion deselectItemAtIndexPath:indice animated:NO];
    if (indice.item < _videos.count && self.alElegirVideo) {
        self.alElegirVideo(_videos[indice.item]);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _videos = nil;
    _titulo.text = nil;
    [_coleccion reloadData];
}

@end
