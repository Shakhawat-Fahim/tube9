# -*- coding: utf-8 -*-
"""
Genera los recursos graficos de Tube9 sin dependencias externas.

Escribe PNGs a mano (zlib + struct, ambos de la biblioteca estandar), asi que
funciona en Windows 7 con Python 3.8 sin instalar Pillow ni nada.

Produce:
  app/Resources/  -> iconos del sistema y imagenes de arranque
  app/recursos-generados.txt -> resumen de lo creado

Uso:
    python tools/generar_recursos.py
"""

import io
import os
import struct
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "app", "Resources")

# Paleta (coincide con YTTheme.m)
FONDO = (0x0F, 0x11, 0x15, 255)      # casi negro azulado
ACENTO = (0xFF, 0x00, 0x33, 255)     # rojo vivo (estilo YouTube, mas flat)
BLANCO = (0xFF, 0xFF, 0xFF, 255)


def escribir_png(ruta, ancho, alto, pixeles):
    """pixeles: bytearray RGBA de ancho*alto*4."""
    filas = []
    for y in range(alto):
        inicio = y * ancho * 4
        filas.append(b"\x00" + bytes(pixeles[inicio:inicio + ancho * 4]))
    crudo = b"".join(filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    cabecera = struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0)
    contenido = (b"\x89PNG\r\n\x1a\n"
                 + bloque(b"IHDR", cabecera)
                 + bloque(b"IDAT", zlib.compress(crudo, 9))
                 + bloque(b"IEND", b""))
    with io.open(ruta, "wb") as f:
        f.write(contenido)


def dentro_del_triangulo(x, y, ancho, alto):
    """Triangulo 'play' centrado, apuntando a la derecha."""
    x0, y0 = 0.36 * ancho, 0.27 * alto
    x1, y1 = 0.36 * ancho, 0.73 * alto
    x2, y2 = 0.75 * ancho, 0.50 * alto
    d = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
    a = ((y1 - y2) * (x - x2) + (x2 - x1) * (y - y2)) / d
    b = ((y2 - y0) * (x - x2) + (x0 - x2) * (y - y2)) / d
    c = 1 - a - b
    return a >= 0 and b >= 0 and c >= 0


def dentro_del_redondeo(x, y, ancho, alto, radio):
    """Esquinas redondeadas estilo iOS."""
    cx = min(max(x, radio), ancho - radio)
    cy = min(max(y, radio), alto - radio)
    dx, dy = x - cx, y - cy
    return dx * dx + dy * dy <= radio * radio


def icono(ancho, alto, con_fondo=True):
    """Icono: fondo rojo con esquinas redondeadas y triangulo blanco.
    Se dibuja con supermuestreo 3x para que los bordes queden suaves."""
    sup = 3
    radio = 0.2237 * ancho
    pixeles = bytearray(ancho * alto * 4)

    for y in range(alto):
        for x in range(ancho):
            acumulado = [0.0, 0.0, 0.0, 0.0]
            for sy in range(sup):
                for sx in range(sup):
                    px = x + (sx + 0.5) / sup
                    py = y + (sy + 0.5) / sup
                    if con_fondo and not dentro_del_redondeo(px, py, ancho, alto, radio):
                        color = (0, 0, 0, 0)
                    elif dentro_del_triangulo(px, py, ancho, alto):
                        color = BLANCO
                    else:
                        color = ACENTO
                    for i in range(4):
                        acumulado[i] += color[i]
            n = sup * sup
            base = (y * ancho + x) * 4
            for i in range(4):
                pixeles[base + i] = int(round(acumulado[i] / n))
    return pixeles


def arranque(ancho, alto):
    """Imagen de arranque: fondo oscuro con un triangulo rojo pequeno y centrado."""
    pixeles = bytearray(ancho * alto * 4)
    lado = int(min(ancho, alto) * 0.28)
    ox = (ancho - lado) // 2
    oy = (alto - lado) // 2
    for y in range(alto):
        for x in range(ancho):
            base = (y * ancho + x) * 4
            if ox <= x < ox + lado and oy <= y < oy + lado:
                lx, ly = x - ox, y - oy
                if dentro_del_triangulo(lx, ly, lado, lado):
                    color = BLANCO
                else:
                    color = (0, 0, 0, 0)
            else:
                color = FONDO
            pixeles[base:base + 4] = bytes(color)
    return pixeles


ICONOS = [
    ("Icon-Small.png", 29),
    ("Icon-Small@2x.png", 58),
    ("Icon-Small-40.png", 40),
    ("Icon-Small-40@2x.png", 80),
    ("Icon-Small-40@3x.png", 120),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-76.png", 76),
    ("Icon-76@2x.png", 152),
    ("iTunesArtwork", 512),
]

ARRANQUES = [
    ("LaunchImage.png", 320, 480),
    ("LaunchImage@2x.png", 640, 960),
    ("LaunchImage-568h@2x.png", 640, 1136),
    ("LaunchImage-700.png", 320, 480),
    ("LaunchImage-700@2x.png", 640, 960),
    ("LaunchImage-700-568h@2x.png", 640, 1136),
    ("LaunchImage-700-Portrait@2x.png", 1536, 2048),
    ("LaunchImage-700-Landscape@2x.png", 2048, 1536),
]


def main():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)
    hechos = []

    for nombre, lado in ICONOS:
        escribir_png(os.path.join(DESTINO, nombre), lado, lado,
                     icono(lado, lado, con_fondo=(nombre != "iTunesArtwork")))
        hechos.append("%s  %dx%d" % (nombre, lado, lado))

    for nombre, ancho, alto in ARRANQUES:
        escribir_png(os.path.join(DESTINO, nombre), ancho, alto, arranque(ancho, alto))
        hechos.append("%s  %dx%d" % (nombre, ancho, alto))

    resumen = os.path.join(RAIZ, "app", "recursos-generados.txt")
    with io.open(resumen, "w", encoding="utf-8") as f:
        f.write("Recursos generados por tools/generar_recursos.py\n\n")
        f.write("\n".join(hechos) + "\n")

    print("Generados %d archivos en app/Resources" % len(hechos))
    for h in hechos:
        print("   ", h)


if __name__ == "__main__":
    main()
