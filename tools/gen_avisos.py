"""Genera los avisos de los negocios, las vallas, los huecos, las manchas de aceite y los perros.

    python tools/gen_avisos.py

Todo sale de la paleta (tools/paleta.py). Los negocios y las vallas son INVENTADOS: nada de
marcas reales ni logos. Semilla fija por archivo: regenerar da siempre lo mismo.

Archivos (en assets/texturas/):
  avisos.png      96×288: 12 avisos de 96×24, uno por fila (orden en AVISOS), RGBA.
  avisos_luz.png  96×288: lo que brilla de noche (cajas de luz y letras de neón), RGB negro.
  vallas.png      128×192: 3 vallas de 128×64, una por fila (orden en VALLAS), RGB.
  hueco.png       64×64: hueco de la calle visto desde arriba, RGBA.
  aceite.png      64×64: mancha de aceite vista desde arriba, RGBA.
  perros.png      128×72: 3 perros (filas) × 4 cuadros de 32×24 (caminar A, caminar B,
                  sentado feliz, asustado saltando), de perfil mirando a la derecha, RGBA.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from paleta import PALETA as P
from pixel import cuantizar

RAIZ = Path(__file__).resolve().parent.parent
TEX = RAIZ / "assets" / "texturas"
FUENTE = RAIZ / "assets" / "fuentes" / "PressStart2P-Regular.ttf"


def c(nombre):
    return np.array(P[nombre], dtype=np.float32)


def col(nombre):
    return P[nombre] + (255,)


def oscuro(nombre, k=0.68):
    return tuple(int(v * k) for v in P[nombre]) + (255,)


def ruido(rng, h, w, suave=0):
    n = rng.standard_normal((h, w)).astype(np.float32)
    for _ in range(suave):
        n = (n + np.roll(n, 1, 0) + np.roll(n, -1, 0) + np.roll(n, 1, 1) + np.roll(n, -1, 1)) / 5.0
    return n / (n.std() + 1e-6)


def borde_de(lleno):
    """Píxeles vacíos que tocan (en cruz) un píxel lleno: el contorno de 1 px."""
    m = np.pad(lleno, 1)
    return (m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~lleno


def guardar_mixto(rgb, ruta, alfa=None, fuerza=8.0, plano=None):
    """Cuantiza a la paleta: con dithering donde hay degradados y sin él donde `plano` es True
    (letras, contornos), para que el texto quede limpio."""
    q = cuantizar(rgb.astype(np.float32), fuerza)
    if plano is not None:
        q0 = cuantizar(rgb.astype(np.float32), 0.0)
        q[plano] = q0[plano]
    if alfa is None:
        Image.fromarray(q, "RGB").save(ruta)
    else:
        a = (alfa > 0.5).astype(np.uint8) * 255
        Image.fromarray(np.dstack([q, a]), "RGBA").save(ruta)


# --- letras -------------------------------------------------------------------------------------

# Letra chica de 3×5 (la misma familia que las señales de gen_texturas.py, completa).
CHICA = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
    "M": ["10001", "11011", "10101", "10001", "10001"], "N": ["1001", "1101", "1011", "1001", "1001"],
    "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
    "W": ["10001", "10001", "10101", "10101", "01010"], "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
    "6": ["011", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "110"],
    "$": ["011", "110", "010", "011", "110"], "!": ["1", "1", "1", "0", "1"],
    ".": ["0", "0", "0", "0", "1"], ",": ["00", "00", "00", "01", "10"],
    "-": ["000", "000", "111", "000", "000"], "*": ["101", "010", "101", "000", "000"],
    "/": ["001", "001", "010", "100", "100"], ":": ["0", "1", "0", "1", "0"],
    "(": ["01", "10", "10", "10", "01"], ")": ["10", "01", "01", "01", "10"],
    " ": ["00", "00", "00", "00", "00"],
}

# Letra grande de 4×7 (M, T, V, W, Y de 5 de ancho) para los nombres de los negocios y las vallas.
GRANDE = {
    "A": ["0110", "1001", "1001", "1111", "1001", "1001", "1001"],
    "B": ["1110", "1001", "1001", "1110", "1001", "1001", "1110"],
    "C": ["0110", "1001", "1000", "1000", "1000", "1001", "0110"],
    "D": ["1110", "1001", "1001", "1001", "1001", "1001", "1110"],
    "E": ["1111", "1000", "1000", "1110", "1000", "1000", "1111"],
    "F": ["1111", "1000", "1000", "1110", "1000", "1000", "1000"],
    "G": ["0110", "1001", "1000", "1011", "1001", "1001", "0111"],
    "H": ["1001", "1001", "1001", "1111", "1001", "1001", "1001"],
    "I": ["111", "010", "010", "010", "010", "010", "111"],
    "J": ["0011", "0001", "0001", "0001", "0001", "1001", "0110"],
    "K": ["1001", "1010", "1100", "1100", "1010", "1001", "1001"],
    "L": ["1000", "1000", "1000", "1000", "1000", "1000", "1111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["1001", "1101", "1101", "1011", "1011", "1001", "1001"],
    "O": ["0110", "1001", "1001", "1001", "1001", "1001", "0110"],
    "P": ["1110", "1001", "1001", "1110", "1000", "1000", "1000"],
    "Q": ["0110", "1001", "1001", "1001", "1011", "1001", "0111"],
    "R": ["1110", "1001", "1001", "1110", "1010", "1001", "1001"],
    "S": ["0111", "1000", "1000", "0110", "0001", "0001", "1110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["1001", "1001", "1001", "1001", "1001", "1001", "0110"],
    "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "X": ["1001", "1001", "0110", "0110", "0110", "1001", "1001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["1111", "0001", "0010", "0100", "1000", "1000", "1111"],
    "0": ["0110", "1001", "1011", "1101", "1001", "1001", "0110"],
    "1": ["010", "110", "010", "010", "010", "010", "111"],
    "2": ["0110", "1001", "0001", "0010", "0100", "1000", "1111"],
    "3": ["1110", "0001", "0001", "0110", "0001", "0001", "1110"],
    "4": ["1001", "1001", "1001", "1111", "0001", "0001", "0001"],
    "5": ["1111", "1000", "1110", "0001", "0001", "1001", "0110"],
    "6": ["0110", "1000", "1000", "1110", "1001", "1001", "0110"],
    "7": ["1111", "0001", "0010", "0010", "0100", "0100", "0100"],
    "8": ["0110", "1001", "1001", "0110", "1001", "1001", "0110"],
    "9": ["0110", "1001", "1001", "0111", "0001", "0001", "0110"],
    "$": ["0010", "0111", "1010", "0110", "0101", "1110", "0100"],
    "!": ["1", "1", "1", "1", "1", "0", "1"],
    "¡": ["1", "0", "1", "1", "1", "1", "1"],
    ".": ["0", "0", "0", "0", "0", "0", "1"],
    ",": ["00", "00", "00", "00", "00", "01", "10"],
    "-": ["000", "000", "000", "111", "000", "000", "000"],
    "*": ["00000", "10101", "01110", "11111", "01110", "10101", "00000"],
    "?": ["0110", "1001", "0001", "0010", "0010", "0000", "0010"],
    ":": ["0", "0", "1", "0", "0", "1", "0"],
    "'": ["1", "1", "0", "0", "0", "0", "0"],
    "(": ["01", "10", "10", "10", "10", "10", "01"],
    ")": ["10", "01", "01", "01", "01", "01", "10"],
    " ": ["00", "00", "00", "00", "00", "00", "00"],
}

# Letras con tilde: la base y una marca 2 px encima (fila -2).
TILDES = {"Á": ("A", "agudo"), "É": ("E", "agudo"), "Í": ("I", "agudo"), "Ó": ("O", "agudo"),
          "Ú": ("U", "agudo"), "Ñ": ("N", "virgulilla")}


def ancho_texto(texto, fuente, espacio=1):
    return sum(len(fuente[TILDES.get(ch, (ch,))[0]][0]) + espacio for ch in texto) - espacio


def mascara_texto(texto, fuente, espacio=1, saltos=None):
    """Máscara booleana del texto, con 3 filas arriba para las tildes (tilde y 1 fila de aire).
    `saltos`: lista opcional con el desfase vertical de cada letra."""
    alto = len(fuente["A"])
    w = ancho_texto(texto, fuente, espacio)
    m = np.zeros((alto + 5, w + 1), bool)
    x = 0
    for k, ch in enumerate(texto):
        base, marca = TILDES.get(ch, (ch, None))
        g = fuente[base]
        dy = 3 + (saltos[k] if saltos else 0)
        gw = len(g[0])
        for fy, fila in enumerate(g):
            for fx, bit in enumerate(fila):
                if bit == "1":
                    m[dy + fy, x + fx] = True
        if marca == "agudo":
            m[dy - 3, x + gw // 2 + 1 - (gw < 4)] = True
            m[dy - 2, x + gw // 2 - (gw < 4)] = True
        elif marca == "virgulilla":
            for fx, fy in ((0, 1), (1, 0), (2, 1), (3, 0)):
                if fx < gw:
                    m[dy - 3 + fy, x + fx] = True
        x += gw + espacio
    return m


def mascara_ps2p(texto):
    """Texto con Press Start 2P a 8 px, sin suavizado (para los títulos de las vallas)."""
    f = ImageFont.truetype(str(FUENTE), 8)
    w = int(f.getlength(texto)) + 2
    im = Image.new("L", (w, 10))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((0, 0), texto, font=f, fill=255)
    m = np.array(im) > 0
    cols = np.where(m.any(0))[0]
    return m[:, : cols.max() + 1]


def estampar(img, m, x, y, color, plano=None):
    """Pinta la máscara `m` con su esquina en (x, y) (y es 3 px sobre la letra: ahí van las tildes)."""
    h, w = m.shape
    sub = img[y:y + h, x:x + w]
    mm = m[: sub.shape[0], : sub.shape[1]]
    sub[mm] = color
    if plano is not None:
        plano[y:y + h, x:x + w][mm] = True


def recorrer(m, dx, dy):
    """Desplaza una máscara sin dar la vuelta."""
    r = np.zeros_like(m)
    h, w = m.shape
    r[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = m[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)]
    return r


def pegar_rgba(img, alfa, sprite, x, y, plano=None):
    a = np.array(sprite).astype(np.float32)
    lleno = a[..., 3] > 0
    h, w = lleno.shape
    img[y:y + h, x:x + w][lleno] = a[..., :3][lleno]
    if alfa is not None:
        alfa[y:y + h, x:x + w][lleno] = 1.0
    if plano is not None:
        plano[y:y + h, x:x + w][lleno] = True


def con_contorno(im, color="negro"):
    """Le pone contorno de 1 px a un sprite RGBA de PIL."""
    a = np.array(im)
    lleno = a[..., 3] > 0
    b = borde_de(lleno)
    a[b] = col(color)
    return Image.fromarray(a, "RGBA")


# --- pictogramas de 16×16 (cada negocio con su dibujito) ------------------------------------------

def _lienzo16():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def pic_pan():
    """Pan francés en diagonal con sus cortes, dorado arriba y tostado abajo."""
    im, d = _lienzo16()
    d.line([(2, 12), (13, 3)], fill=col("guante"), width=6)
    d.line([(2, 11), (12, 3)], fill=col("amarillo_casa"), width=3)
    d.line([(3, 10), (11, 4)], fill=col("hueso"), width=1)
    for k in range(3):
        x, y = 4 + k * 3, 10 - k * 3
        d.line([(x, y - 1), (x + 1, y + 1)], fill=col("guante_oscuro"), width=1)
    return con_contorno(im)


def pic_cruz():
    """Cruz verde de droguería con volumen (filo claro arriba a la izquierda)."""
    im, d = _lienzo16()
    d.rectangle([5, 1, 10, 14], fill=col("verde_ninja"))
    d.rectangle([1, 5, 14, 10], fill=col("verde_ninja"))
    d.line([(5, 1), (10, 1)], fill=col("verde_ninja_claro"))
    d.line([(1, 5), (5, 5)], fill=col("verde_ninja_claro"))
    d.line([(5, 1), (5, 5)], fill=col("verde_ninja_claro"))
    d.line([(1, 5), (1, 10)], fill=col("verde_ninja_claro"))
    d.line([(10, 10), (10, 14)], fill=col("verde_ninja_oscuro"))
    d.line([(10, 10), (14, 10)], fill=col("verde_ninja_oscuro"))
    d.line([(5, 14), (10, 14)], fill=col("verde_ninja_oscuro"))
    return con_contorno(im)


def pic_pollo():
    """Pollo asado corriendo (con patas y rayas de velocidad): el pollo veloz."""
    im, d = _lienzo16()
    for y in (5, 8, 11):
        d.line([(0, y), (2, y)], fill=col("blanco"))
    d.ellipse([3, 3, 14, 12], fill=col("naranja"))
    d.ellipse([4, 3, 12, 8], fill=col("amarillo_casa"))
    d.point((6, 4), fill=col("hueso"))
    d.chord([3, 5, 14, 12], 0, 180, fill=col("ladrillo_claro"))
    d.line([(12, 4), (15, 2)], fill=col("hueso"), width=2)       # hueso de la pata
    d.line([(7, 12), (6, 15)], fill=col("amarillo_via"))          # patas corriendo
    d.line([(10, 12), (12, 15)], fill=col("amarillo_via"))
    return con_contorno(im)


def pic_tornillo():
    """Tornillo con cabeza hexagonal y rosca, en cromo."""
    im, d = _lienzo16()
    d.polygon([(4, 1), (11, 1), (13, 3), (11, 5), (4, 5), (2, 3)], fill=col("cromo"))
    d.line([(4, 1), (11, 1)], fill=col("cromo_brillo"))
    d.line([(4, 5), (11, 5)], fill=col("cromo_oscuro"))
    d.rectangle([6, 6, 9, 13], fill=col("cromo"))
    d.line([(6, 6), (6, 13)], fill=col("cromo_brillo"))
    d.line([(9, 6), (9, 13)], fill=col("cromo_oscuro"))
    for y in range(7, 13, 2):
        d.line([(5, y + 1), (10, y)], fill=col("cromo_oscuro"))
    d.polygon([(6, 14), (9, 14), (8, 15), (7, 15)], fill=col("cromo_oscuro"))
    return con_contorno(im)


def pic_tijeras():
    """Tijeras abiertas doradas."""
    im, d = _lienzo16()
    d.line([(4, 1), (10, 10)], fill=col("cromo_brillo"), width=2)
    d.line([(11, 1), (5, 10)], fill=col("cromo"), width=2)
    d.point((7, 6), fill=col("negro"))
    d.ellipse([1, 9, 6, 14], outline=col("amarillo_via"), width=2)
    d.ellipse([9, 9, 14, 14], outline=col("sodio"), width=2)
    return con_contorno(im)


def pic_botella():
    """Gaseosa en botella de vidrio con etiqueta."""
    im, d = _lienzo16()
    d.rectangle([7, 0, 9, 1], fill=col("rojo"))                   # tapa
    d.polygon([(7, 2), (9, 2), (9, 5), (11, 7), (11, 15), (5, 15), (5, 7), (7, 5)], fill=col("vinotinto"))
    d.line([(6, 7), (6, 14)], fill=col("rojo"))
    d.rectangle([5, 9, 11, 12], fill=col("blanco"))
    d.line([(6, 10), (10, 10)], fill=col("rojo"))
    d.line([(10, 7), (10, 14)], fill=col("vinotinto_oscuro"))
    return con_contorno(im)


def pic_plato():
    """Plato de sopa humeante (el corrientazo)."""
    im, d = _lienzo16()
    for x in (5, 10):                                             # dos hilos de vapor
        d.line([(x, 0), (x - 1, 2), (x, 4), (x - 1, 5)], fill=col("blanco"))
    d.ellipse([1, 7, 14, 11], fill=col("blanco"))
    d.ellipse([3, 7, 12, 10], fill=col("amarillo_casa"))
    d.point((6, 8), fill=col("verde_casa"))
    d.point((9, 8), fill=col("naranja"))
    d.chord([1, 5, 14, 14], 0, 180, fill=col("hueso"))
    d.line([(3, 13), (12, 13)], fill=col("concreto_claro"))
    return con_contorno(im)


def pic_moneda():
    """Moneda de mil con el signo pesos."""
    im, d = _lienzo16()
    d.ellipse([1, 1, 14, 14], fill=col("amarillo_casa"))
    d.ellipse([1, 1, 13, 13], fill=col("amarillo_via"))
    d.arc([1, 1, 14, 14], 20, 200, fill=col("ventana_luz"))
    d.ellipse([3, 3, 12, 12], outline=col("amarillo_taxi_oscuro"))
    for fy, fila in enumerate(GRANDE["$"]):
        for fx, bit in enumerate(fila):
            if bit == "1":
                d.point((6 + fx, 4 + fy), fill=col("guante_oscuro"))
    return con_contorno(im)


def pic_piston():
    """Pistón con su biela, en cromo."""
    im, d = _lienzo16()
    d.rectangle([3, 1, 12, 7], fill=col("cromo"))
    d.line([(3, 1), (12, 1)], fill=col("cromo_brillo"))
    d.line([(3, 1), (3, 7)], fill=col("cromo_brillo"))
    d.line([(12, 1), (12, 7)], fill=col("cromo_oscuro"))
    d.line([(3, 3), (12, 3)], fill=col("cromo_oscuro"))           # anillos
    d.line([(3, 5), (12, 5)], fill=col("cromo_oscuro"))
    d.line([(7, 8), (6, 13)], fill=col("cromo_oscuro"), width=3)  # biela
    d.ellipse([3, 11, 9, 15], outline=col("cromo"), width=2)
    return con_contorno(im)


def pic_lapiz():
    """Lápiz amarillo en diagonal (la miscelánea)."""
    im, d = _lienzo16()
    d.line([(3, 12), (12, 3)], fill=col("amarillo_via"), width=4)
    d.line([(3, 11), (11, 3)], fill=col("ventana_luz"), width=1)
    d.line([(12, 3), (14, 1)], fill=col("rojo"), width=4)         # borrador
    d.polygon([(1, 14), (2, 10), (5, 13)], fill=col("hueso"))     # punta
    d.point((1, 14), fill=col("negro"))
    return con_contorno(im)


def pic_arepa():
    """Arepa asada con las marcas de la parrilla y su cuadrito de mantequilla."""
    im, d = _lienzo16()
    d.ellipse([1, 3, 14, 13], fill=col("amarillo_casa"))
    d.ellipse([2, 3, 13, 11], fill=col("ventana_luz"))
    d.ellipse([2, 4, 13, 11], fill=col("amarillo_casa"))
    for x in (1, 5, 9):
        d.line([(x + 2, 11), (x + 6, 5)], fill=col("guante"))       # marcas de la parrilla
    d.rectangle([9, 7, 10, 8], fill=col("ventana_luz"))              # mantequilla derretida
    d.point((11, 9), fill=col("ventana_luz"))
    d.arc([1, 3, 14, 13], 20, 160, fill=col("amarillo_taxi_oscuro"))
    return con_contorno(im)


def pic_pantalla():
    """Monitor con un marcianito (el café internet gamer)."""
    im, d = _lienzo16()
    d.rectangle([1, 1, 14, 11], fill=col("carbon"))
    d.rectangle([2, 2, 13, 9], fill=col("vidrio_oscuro"))
    alien = ["0100010", "0011100", "0111110", "1101011", "1111111", "0100010"]
    for fy, fila in enumerate(alien):
        for fx, bit in enumerate(fila):
            if bit == "1":
                d.point((4 + fx, 3 + fy), fill=col("verde_ninja_claro"))
    d.rectangle([6, 12, 9, 13], fill=col("cromo_oscuro"))
    d.rectangle([3, 14, 12, 15], fill=col("cromo"))
    return con_contorno(im)


# --- avisos de 96×24 ----------------------------------------------------------------------------

# tipo (letra chica), nombre (letra grande), estilo, fondo, fondo claro, letra, sombra, pictograma
AVISOS = [
    ("PANADERIA", "LA FE", "metal", "amarillo_casa", "ventana_luz", "ladrillo_oscuro", "guante", pic_pan),
    ("DROGUERIA", "SAN JUDAS", "caja", "blanco", "blanco", "azul_sitp", "azul_bwis", pic_cruz),
    ("ASADERO", "EL POLLO VELOZ", "caja", "rojo", "naranja", "ventana_luz", "rojo_oscuro", pic_pollo),
    ("FERRETERIA", "EL TORNILLO", "metal", "azul_casa", "azul_bwis_oscuro", "blanco", "azul_sitp_oscuro", pic_tornillo),
    ("PELUQUERIA", "TIJERAS DE ORO", "neon", "carbon", "asfalto_oscuro", "amarillo_via", "sodio", pic_tijeras),
    ("TIENDA", "DOÑA MARTHA", "mano", "hueso", "blanco", "rojo", "rojo_oscuro", pic_botella),
    ("CORRIENTAZO", "LA SAZON", "mano", "amarillo_casa", "ventana_luz", "vinotinto", "guante_oscuro", pic_plato),
    ("CACHARRERIA", "TODO A MIL", "metal", "naranja", "chaqueta_clara", "negro", "chaqueta_oscura", pic_moneda),
    ("REPUESTOS", "EL PISTON", "metal", "carbon", "asfalto", "blanco", "rojo", pic_piston),
    ("MISCELANEA", "LA ECONOMICA", "caja", "amarillo_taxi", "ventana_luz", "azul_sitp_oscuro", "amarillo_taxi_oscuro", pic_lapiz),
    ("AREPAS", "DONDE EL MONO", "mano", "verde_casa", "pasto_claro", "blanco", "pasto_oscuro", pic_arepa),
    ("CAFE INTERNET", "GAMER", "neon", "negro", "carbon", "verde_ninja_claro", "azul_bwis_claro", pic_pantalla),
]


def _aviso(k, datos):
    """Un aviso de 96×24. Devuelve (rgb, alfa, luz, plano)."""
    tipo, nombre, estilo, fondo, fondo_claro, letra, sombra, pictograma = datos
    rng = np.random.default_rng(300 + k)
    W, H = 96, 24
    img = np.zeros((H, W, 3), np.float32)
    alfa = np.zeros((H, W), np.float32)
    luz = np.zeros((H, W, 3), np.float32)
    plano = np.zeros((H, W), bool)
    y0, y1 = 0, H                                   # la tabla ocupa todo el cuadro salvo en «mano»

    # Fondo con volumen: más claro arriba (la luz viene de arriba) y un poco de mugre.
    grad = np.linspace(0, 1, H)[:, None, None]
    if estilo == "caja":
        # Caja de luz: brilla más en el centro (los tubos van por dentro).
        centro = 1 - np.abs(np.linspace(-1, 1, H))[:, None, None] ** 2
        cara = c(fondo) * (0.55 + 0.45 * centro) + c(fondo_claro) * 0.45 * centro
        img[:] = np.clip(cara, 0, 255)
    else:
        img[:] = c(fondo_claro) * (1 - grad) * 0.5 + c(fondo) * (0.5 + 0.5 * grad)
    img += ruido(rng, H, W, 3)[..., None] * (2 if estilo == "caja" else 4)
    alfa[y0:y1] = 1.0

    if estilo == "mano":
        # Tabla de madera pintada: filo irregular, vetas y pintura saltada.
        filo = np.clip(np.round(ruido(rng, 1, W, 4)[0] * 0.7), -1, 1).astype(int)
        for x in range(W):
            arriba, abajo = 1 + filo[x], 23 - (filo[(x + 37) % W] > 0)
            alfa[:max(arriba, 0), x] = 0
            alfa[abajo:, x] = 0
            img[max(arriba, 0), x] = c(fondo_claro)
            img[abajo - 1, x] = c(sombra)
        for x in (0, W - 1):
            alfa[:, x] = 0
        img[:, 1] = c(sombra)
        img[:, W - 2] = c(sombra)
        vetas = np.repeat(ruido(rng, H, 1, 0), W, 1)          # vetas a lo largo de la tabla
        img *= (1 + 0.03 * vetas[..., None])
        pelado = ruido(rng, H, W, 3) < -2.0
        img[pelado] = c("guante")                   # se ve la madera
        img[pelado & (ruido(rng, H, W) > 0.8)] = c("guante_oscuro")
        # Clavos
        for x in (4, W - 5):
            img[4, x] = c("cromo_oscuro")
            img[19, x] = c("cromo_oscuro")
    else:
        # Marco: aluminio en las cajas de luz y en el neón, lámina doblada en los de metal.
        if estilo == "caja":
            marco = ("cromo_brillo", "cromo", "cromo_oscuro")
        elif estilo == "neon":
            marco = ("gris", "asfalto", "negro")
        else:
            marco = (fondo_claro, sombra, "carbon")
        img[0, :] = c(marco[0])
        img[1, :] = c(marco[1])
        img[:, 0] = c(marco[0])
        img[:, 1] = c(marco[1])
        img[H - 2, :] = c(marco[1])
        img[H - 1, :] = c(marco[2])
        img[:, W - 2] = c(marco[1])
        img[:, W - 1] = c(marco[2])
        plano[:2, :] = plano[-2:, :] = True
        plano[:, :2] = plano[:, -2:] = True
        if estilo == "metal":
            # Remaches en las esquinas con su chorreón de óxido.
            for x in (3, W - 4):
                for y in (3, H - 4):
                    img[y, x] = c("cromo_brillo")
                    img[y + 1, x] = c("carbon")
                    plano[y:y + 2, x] = True
                    if y < H // 2:
                        largo = int(rng.integers(3, 8))
                        for yy in range(y + 2, min(y + 2 + largo, H - 2)):
                            f = 0.55 * (1 - (yy - y - 2) / largo)
                            img[yy, x] = img[yy, x] * (1 - f) + c("ladrillo") * f
            # Abolladura: una diagonal de luz y otra de sombra.
            ax = int(rng.integers(30, 70))
            for t in range(6):
                img[4 + t, ax + t] = img[4 + t, ax + t] * 0.7 + c(fondo_claro) * 0.3
                img[5 + t, ax + t] *= 0.85
        if estilo == "caja":
            luz[2:H - 2, 2:W - 2] = img[2:H - 2, 2:W - 2] * 0.9
        if estilo == "neon":
            # Bombillitos de feria en el marco, prendidos uno sí y otro no.
            for x in range(5, W - 4, 6):
                for y in (1, H - 2):
                    on = (x // 6) % 2 == 0
                    img[y, x] = c("ventana_luz" if on else "sodio")
                    plano[y, x] = True
                    luz[y, x] = c("ventana_luz") if on else c("sodio") * 0.5

    # Pictograma a la izquierda.
    pic = pictograma()
    pegar_rgba(img, None, pic, 4, 4, plano)
    if estilo == "neon":
        a = np.array(pic)
        luz[4:20, 4:20][a[..., 3] > 0] = a[..., :3][a[..., 3] > 0] * 0.8

    # Textos centrados en lo que queda (x 22..93).
    x_ini, x_fin = 22, W - 3
    mt = mascara_texto(tipo, CHICA)
    mn = mascara_texto(nombre, GRANDE)
    xt = x_ini + (x_fin - x_ini - mt.shape[1]) // 2 + 1
    xn = x_ini + (x_fin - x_ini - mn.shape[1]) // 2 + 1
    assert mn.shape[1] <= x_fin - x_ini + 1, nombre
    yt, yn = 1, 9                                       # 3 px sobre la letra (sitio de las tildes)
    if estilo in ("metal", "caja", "mano"):
        # Sombra de la letra pintada, 1 px abajo a la derecha: le da cuerpo (el pintor de brocha
        # solo se la pone al nombre).
        if estilo != "mano":
            estampar(img, recorrer(mt, 1, 1), xt, yt, c(sombra), plano)
        estampar(img, recorrer(mn, 1, 1), xn, yn, c(sombra), plano)
        estampar(img, mt, xt, yt, c(letra), plano)
        estampar(img, mn, xn, yn, c(letra), plano)
        if estilo == "caja":
            for m, x, y in ((mt, xt, yt), (mn, xn, yn)):
                sub = luz[y:y + m.shape[0], x:x + m.shape[1]]
                # Letra clara: deja pasar la luz; letra oscura: pintura opaca, casi no brilla.
                paso = 0.9 if c(letra).mean() > 150 else 0.25
                sub[m[: sub.shape[0], : sub.shape[1]]] = c(letra) * paso
    else:
        # Neón: tubo brillante con un halo del color de «sombra» alrededor.
        for m, x, y, tubo, halo in ((mt, xt, yt, sombra, fondo_claro), (mn, xn, yn, letra, sombra)):
            mm = np.pad(m, 1)
            h = borde_de(mm)
            estampar(img, h, x - 1, y - 1, c(halo) * 0.35 + c(fondo) * 0.65)
            estampar(img, m, x, y, c(tubo), plano)
            estampar(luz, h, x - 1, y - 1, c(halo) * 0.45)
            estampar(luz, m, x, y, c(tubo))
    # Chorreón de pintura bajo alguna letra en los pintados a mano.
    if estilo == "mano":
        cols = np.where(mn.any(0))[0]
        for cx in rng.choice(cols, 2, replace=False):
            fila = np.where(mn[:, cx])[0].max()
            for yy in range(yn + fila + 1, min(yn + fila + 1 + int(rng.integers(2, 4)), 22)):
                img[yy, xn + cx] = c(letra)
                plano[yy, xn + cx] = True
    return img, alfa, luz, plano


def avisos():
    H = 24
    rgb = np.zeros((H * len(AVISOS), 96, 3), np.float32)
    alfa = np.zeros((H * len(AVISOS), 96), np.float32)
    luz = np.zeros_like(rgb)
    plano = np.zeros(alfa.shape, bool)
    for k, datos in enumerate(AVISOS):
        a, b, l, p = _aviso(k, datos)
        rgb[k * H:(k + 1) * H], alfa[k * H:(k + 1) * H] = a, b
        luz[k * H:(k + 1) * H], plano[k * H:(k + 1) * H] = l, p
    guardar_mixto(rgb, TEX / "avisos.png", alfa=alfa, fuerza=8, plano=plano)
    luz[alfa < 0.5] = 0
    guardar_mixto(luz, TEX / "avisos_luz.png", fuerza=0)


# --- vallas de 128×64 ---------------------------------------------------------------------------

# título, líneas del eslogan, letra chica de abajo, fondo arriba, fondo abajo, título, eslogan
VALLAS = [
    ("SEGUROS LA FE", ["PORQUE EL AGARRE", "NO ALCANZA"], "DESDE $9.900 AL MES*",
     "azul_sitp", "azul_sitp_oscuro", "blanco", "amarillo_via"),
    ("CASCOS ETERNO", ["USALO, MIJO.", "TU MAMA TE LO PIDE"], "*LA CABEZA NO TRAE REPUESTO",
     "rojo", "rojo_oscuro", "ventana_luz", "blanco"),
    ("APP RAPIDITO", ["LLEGA O LLEGA."], "TU PEDIDO EN 10 MIN O RECE",
     "verde_casa", "pasto_oscuro", "blanco", "amarillo_via"),
]


def _veladora(d):
    """Veladora encendida en su vaso, con el resplandor detrás (seguros La Fe)."""
    d.ellipse([2, 0, 26, 24], fill=col("azul_sitp"))
    d.ellipse([6, 3, 22, 20], fill=col("azul_bwis_oscuro"))
    d.polygon([(14, 2), (18, 9), (16, 13), (12, 13), (10, 9)], fill=col("naranja"))
    d.polygon([(14, 5), (16, 10), (14, 13), (12, 10)], fill=col("ventana_luz"))
    d.line([(14, 13), (14, 15)], fill=col("negro"))
    d.rectangle([7, 15, 21, 34], fill=col("vidrio"))
    d.rectangle([9, 15, 19, 33], fill=col("hueso"))
    d.line([(9, 15), (19, 15)], fill=col("blanco"))
    d.line([(8, 16), (8, 33)], fill=col("vidrio_brillo"))
    d.line([(20, 16), (20, 33)], fill=col("vidrio_oscuro"))
    d.rectangle([10, 20, 18, 28], fill=col("amarillo_casa"))       # estampita (una moto con aureola)
    d.ellipse([11, 25, 13, 27], fill=col("negro"))
    d.ellipse([15, 25, 17, 27], fill=col("negro"))
    d.line([(12, 25), (16, 24)], fill=col("carbon"))
    d.ellipse([12, 20, 16, 22], outline=col("ventana_luz"))
    d.rectangle([6, 34, 22, 35], fill=col("cromo_oscuro"))


def _casco(d):
    """Casco integral brillante con visor ahumado y reflejo."""
    d.pieslice([2, 2, 30, 34], 180, 360, fill=col("blanco"))
    d.rectangle([2, 18, 30, 28], fill=col("blanco"))
    d.polygon([(2, 28), (30, 28), (27, 32), (4, 32)], fill=col("concreto_claro"))
    d.arc([2, 2, 30, 34], 200, 260, fill=col("hueso"), width=2)
    d.pieslice([2, 2, 30, 34], 270, 360, fill=col("hueso"))
    d.pieslice([4, 4, 28, 32], 270, 360, fill=col("blanco"))
    d.polygon([(10, 12), (30, 12), (30, 22), (12, 22), (8, 17)], fill=col("vidrio_oscuro"))
    d.line([(13, 14), (18, 14)], fill=col("vidrio_brillo"))
    d.line([(12, 15), (14, 15)], fill=col("vidrio_brillo"))
    d.line([(4, 24), (30, 24)], fill=col("rojo"), width=2)         # franja
    d.rectangle([13, 28, 18, 31], fill=col("cromo_oscuro"))         # ventilación de la quijada
    for x in (14, 16):
        d.point((x, 29), fill=col("negro"))
    # Aureola: el casco «eterno»
    d.ellipse([8, -1, 26, 3], outline=col("amarillo_via"))


def _caja_domicilio(d):
    """Caja térmica de domicilios con alitas y rayas de velocidad (la app Rapidito)."""
    for y in (12, 18, 24):
        d.line([(0, y), (6, y)], fill=col("blanco"))
    d.polygon([(10, 8), (26, 8), (30, 4), (14, 4)], fill=col("amarillo_via"))   # tapa
    d.polygon([(26, 8), (30, 4), (30, 26), (26, 30)], fill=col("amarillo_taxi_oscuro"))
    d.rectangle([10, 8, 26, 30], fill=col("amarillo_taxi"))
    d.line([(10, 8), (26, 8)], fill=col("ventana_luz"))
    # Rayo del logo inventado
    d.polygon([(19, 11), (14, 20), (18, 20), (16, 27), (22, 17), (18, 17)], fill=col("verde_casa"))
    # Alitas
    d.polygon([(10, 12), (3, 6), (4, 10), (1, 11), (5, 14), (10, 16)], fill=col("blanco"))
    d.line([(5, 10), (9, 13)], fill=col("hueso"))


def _valla(k, datos):
    titulo, lineas, chica, fondo, fondo_osc, c_tit, c_esl = datos
    rng = np.random.default_rng(400 + k)
    W, H = 128, 64
    grad = np.linspace(0, 1, H)[:, None, None]
    img = c(fondo) * (1 - grad) + c(fondo_osc) * grad
    img = img + ruido(rng, H, W, 4)[..., None] * 4
    plano = np.zeros((H, W), bool)
    # Rayos de sol desde la esquina del dibujo, muy suaves (publicidad de los noventa).
    yy, xx = np.mgrid[0:H, 0:W]
    ang = np.arctan2(yy - 36, xx - 108)
    rayos = (np.sin(ang * 14) > 0.6) & (yy > 14)
    img[rayos] = img[rayos] * 0.85 + c("blanco") * 0.15
    # Dibujo a la derecha
    dib = Image.new("RGBA", (34, 38), (0, 0, 0, 0))
    [_veladora, _casco, _caja_domicilio][k](ImageDraw.Draw(dib))
    pegar_rgba(img, None, con_contorno(dib), 91, 16, plano)
    # Título en Press Start 2P con sombra dura.
    mt = mascara_ps2p(titulo)
    xt = 5
    estampar(img, recorrer(mt, 1, 1), xt, 4, c("negro"), plano)
    estampar(img, mt, xt, 4, c(c_tit), plano)
    # Subrayado
    img[14, xt:xt + mt.shape[1]] = c(c_esl)
    plano[14, xt:xt + mt.shape[1]] = True
    # Eslogan en letra grande (4×7) con sombra.
    y = 17 if len(lineas) > 1 else 23
    for linea in lineas:
        m = mascara_texto(linea, GRANDE)
        estampar(img, recorrer(m, 1, 1), 6, y, c("negro"), plano)
        estampar(img, m, 6, y, c(c_esl), plano)
        y += 10
    # Letra menuda de abajo, en franja oscura (como las condiciones que nadie lee).
    img[H - 11:H - 2, 2:W - 2] = img[H - 11:H - 2, 2:W - 2] * 0.45 + c("negro") * 0.55
    m = mascara_texto(chica, CHICA)
    estampar(img, m, (W - m.shape[1]) // 2, H - 12, c("hueso"), plano)
    # Marco de la valla: perfil galvanizado con tornillos, y una esquina del papel despegada.
    img[0, :] = img[:, 0] = c("cromo_brillo")
    img[1, :] = img[:, 1] = c("cromo")
    img[H - 2, :] = img[:, W - 2] = c("cromo_oscuro")
    img[H - 1, :] = img[:, W - 1] = c("carbon")
    for x in range(8, W, 24):
        img[1, x] = img[H - 2, x] = c("carbon")
    plano[:2, :] = plano[-2:, :] = plano[:, :2] = plano[:, -2:] = True
    if k == 1:
        for t in range(5):                           # papel despegado arriba a la derecha
            img[2 + t, W - 3 - (4 - t):W - 2] = c("concreto")
            img[2 + t, W - 3 - (4 - t)] = c("hueso")
    # Mugre de la ciudad en la parte de abajo.
    sucio = (ruido(rng, H, W, 3) + grad[..., 0] * 2.2) > 2.3
    img[sucio & ~plano] = img[sucio & ~plano] * 0.8
    return img, plano


def vallas():
    rgb = np.zeros((64 * len(VALLAS), 128, 3), np.float32)
    plano = np.zeros((64 * len(VALLAS), 128), bool)
    for k, datos in enumerate(VALLAS):
        rgb[k * 64:(k + 1) * 64], plano[k * 64:(k + 1) * 64] = _valla(k, datos)
    guardar_mixto(rgb, TEX / "vallas.png", fuerza=10, plano=plano)


# --- calcomanías del piso (vistas desde arriba) -------------------------------------------------

def _mancha(rng, n, radio, rugosidad, suave=3):
    """Forma irregular: un círculo con el radio deformado por ruido angular."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    cy = cx = (n - 1) / 2
    ang = np.arctan2(yy - cy, xx - cx)
    r = np.hypot(yy - cy, xx - cx)
    deform = np.zeros_like(r)
    for k in range(2, 9):
        deform += rng.normal(0, 1) / k * np.cos(k * ang + rng.uniform(0, 6.28))
    return r / (radio * (1 + rugosidad * deform)), ang


def hueco():
    """Hueco visto desde arriba: placas de asfalto quebrado alrededor, la pared del hueco (con luz
    desde arriba a la izquierda: la pared de abajo a la derecha se ilumina, la otra queda en
    sombra), el fondo con piedras y barro, y agua empozada que refleja el cielo."""
    rng = np.random.default_rng(501)
    n = 64
    rr, ang = _mancha(rng, n, 25, 0.3)
    yy, xx = np.mgrid[0:n, 0:n]
    img = np.zeros((n, n, 3), np.float32)
    dentro = rr < 1.0
    lado = np.cos(ang - np.pi / 4)                        # 1 hacia abajo a la derecha
    # Placas quebradas: asfalto igual al de la calle, partido por grietas radiales.
    placas = dentro & (rr >= 0.74)
    img[:] = c("asfalto")
    grietas = placas & (np.abs(np.sin(ang * 9 + rng.uniform(0, 6))) < 0.12)
    img[grietas] = c("carbon")
    levantado = placas & (rr >= 0.93) & ~grietas & (ruido(rng, n, n, 2) > -0.4)
    img[levantado] = c("gris")                            # filo levantado de las placas
    # Pared del hueco.
    pared = dentro & (rr < 0.74) & (rr >= 0.6)
    img[pared & (lado > 0.1)] = c("concreto")
    img[pared & (lado > 0.1) & (rr < 0.66)] = c("gris")
    img[pared & (lado <= 0.1)] = c("negro")
    # Fondo: tierra oscura con piedritas.
    fondo = dentro & (rr < 0.6)
    img[fondo] = c("carbon")
    img[fondo & (ruido(rng, n, n, 2) > 0.4)] = c("guante_oscuro")
    piedras = fondo & (ruido(rng, n, n) > 1.8)
    img[piedras] = c("gris")
    img[recorrer(piedras, 1, 1) & fondo & ~piedras] = c("negro")
    # Sombra que proyecta la pared de arriba a la izquierda sobre el fondo.
    img[fondo & (lado < -0.3) & (rr > 0.45)] = c("negro")
    # Agua empozada, con el borde más claro y un reflejo del cielo en diagonal.
    rr_agua, _ = _mancha(rng, n, 11, 0.25)
    agua = fondo & (rr_agua < 1.0)
    img[agua] = c("vidrio_oscuro")
    img[agua & (rr_agua > 0.8)] = c("vidrio")
    reflejo = agua & (np.abs((xx - yy) - 3) < 1.0) & (rr_agua < 0.75)
    img[reflejo] = c("vidrio_brillo")
    img[agua & (np.abs((xx - yy) + 3) < 0.6) & (rr_agua < 0.5)] = c("vidrio")
    # Piedritas sueltas alrededor, con su sombrita.
    alfa = dentro.astype(np.float32)
    for _ in range(30):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(25, 31)
        y, x = int(31.5 + np.sin(a) * d), int(31.5 + np.cos(a) * d)
        if 0 <= y < n - 1 and 0 <= x < n - 1 and not dentro[y, x]:
            img[y, x] = c("concreto" if rng.random() < 0.5 else "gris")
            alfa[y, x] = 1
            if not dentro[y + 1, x + 1]:
                img[y + 1, x + 1] = c("carbon")
                alfa[y + 1, x + 1] = 1
    # Contorno oscuro donde se corta el asfalto.
    b = borde_de(dentro) & (alfa < 0.5)
    img[b] = c("asfalto_oscuro")
    alfa[b] = 1
    guardar_mixto(img, TEX / "hueco.png", alfa=alfa, fuerza=0)


def aceite():
    """Mancha de aceite: centro negro y espeso, película más delgada hacia afuera y vetas de
    tornasol (azul, verde, vinotinto) que siguen la forma, con el reflejo de una farola."""
    rng = np.random.default_rng(502)
    n = 64
    rr, ang = _mancha(rng, n, 20, 0.4)
    yy, xx = np.mgrid[0:n, 0:n]
    dentro = rr < 1.0
    for _ in range(7):                                    # gotas que saltaron
        a, d = rng.uniform(0, 6.28), rng.uniform(23, 29)
        cy, cx = 31.5 + np.sin(a) * d, 31.5 + np.cos(a) * d
        dentro |= np.hypot(yy - cy, xx - cx) < rng.uniform(1.0, 2.6)
    img = np.zeros((n, n, 3), np.float32) + c("asfalto_oscuro")   # película delgada del filo
    img[rr < 0.85] = c("carbon")
    img[rr < 0.5] = c("negro")
    # Tornasol: vetas finas y onduladas, cada color sigue al anterior como en un arcoíris.
    fase = rr * 4 + np.sin(ang * 2) * 0.35 + ruido(rng, n, n, 10) * 0.3
    tramos = np.sin(ang * 2 + ruido(rng, n, n, 10) * 0.8) > -0.2     # vetas cortadas, no anillos
    veta = ((fase % 1) < 0.3) & (rr > 0.3) & (rr < 0.85) & tramos
    colores = ["azul_sitp_oscuro", "verde_ninja_oscuro", "vinotinto_oscuro", "vidrio"]
    for b, nombre in enumerate(colores):
        img[veta & ((np.floor(fase) % len(colores)) == b)] = c(nombre)
    # Reflejo de la farola: óvalo claro con centro blanco.
    d = np.hypot(yy - 25, (xx - 27) * 0.6)
    img[dentro & (d < 3.2)] = c("vidrio")
    img[dentro & (d < 2.0)] = c("vidrio_brillo")
    img[dentro & (d < 0.9)] = c("cromo_brillo")
    guardar_mixto(img, TEX / "aceite.png", alfa=dentro.astype(np.float32), fuerza=0)


# --- perros callejeros: 3 pelajes × 4 cuadros de 32×24 --------------------------------------------

PERROS = [
    # pelaje café de perro mestizo, con el lomo más oscuro
    {"base": "guante", "claro": "guante_claro", "oscuro": "guante_oscuro", "manchas": None, "pecho": "guante_claro", "oreja": "guante_oscuro"},
    # blanco y negro, con parche en el ojo
    {"base": "blanco", "claro": "blanco", "oscuro": "concreto_claro", "manchas": "carbon", "pecho": "blanco", "oreja": "carbon"},
    # criollo caramelo, orejas paradas
    {"base": "amarillo_casa", "claro": "ventana_luz", "oscuro": "guante_claro", "manchas": None, "pecho": "hueso", "oreja": "guante_claro", "paradas": True},
]


def _perro(d, p, cuadro):
    """Perro de perfil mirando a la derecha, con las patas en y=22. Lo de atrás más oscuro."""
    base, claro, osc = col(p["base"]), col(p["claro"]), col(p["oscuro"])
    atras = oscuro(p["oscuro"], 0.8)
    dy = -4 if cuadro == 3 else 0
    if cuadro == 2:
        # Sentado: cola en el piso, anca abajo, patas delanteras rectas, cabeza en alto.
        d.line([(4, 21), (9, 20)], fill=osc, width=2)                           # cola moviéndose
        d.line([(3, 18), (5, 20)], fill=osc, width=1)
        d.ellipse([7, 12, 17, 22], fill=base)                                   # anca
        d.ellipse([8, 16, 16, 22], fill=osc)
        d.line([(14, 21), (18, 22)], fill=atras, width=2)                       # pata de atrás doblada
        d.polygon([(12, 12), (19, 7), (22, 10), (20, 18), (14, 20)], fill=base)  # pecho erguido
        d.line([(17, 8), (13, 13)], fill=claro)                                 # lomo con luz
        d.line([(18, 15), (18, 22)], fill=atras, width=2)                       # pata delantera de atrás
        d.line([(20, 14), (20, 22)], fill=base, width=2)
        d.rectangle([20, 21, 22, 22], fill=base)
        d.polygon([(19, 10), (21, 9), (21, 17), (19, 16)], fill=col(p["pecho"]))
        hx, hy = 21, 2
    else:
        if cuadro == 0:   # paso largo
            patas_a = [((10, 14), (7, 22)), ((22, 14), (26, 22))]
            patas_f = [((12, 14), (14, 22)), ((20, 14), (18, 22))]
        elif cuadro == 1:  # patas juntas
            patas_a = [((10, 14), (11, 22)), ((22, 14), (21, 22))]
            patas_f = [((12, 14), (10, 22)), ((20, 14), (23, 22))]
        else:             # salto del susto: patas estiradas hacia afuera
            patas_a = [((10, 14), (5, 19)), ((22, 14), (27, 18))]
            patas_f = [((12, 14), (7, 20)), ((20, 14), (26, 20))]
        for (a, b) in patas_a:
            d.line([(a[0], a[1] + dy), (b[0], b[1] + dy)], fill=atras, width=2)
        # Cola: arriba y curva (feliz al caminar, tiesa del susto).
        if cuadro == 3:
            d.line([(8, 10 + dy), (3, 4 + dy)], fill=osc, width=2)
        else:
            d.line([(8, 10), (4, 7), (4, 4)], fill=osc, width=2, joint="curve")
        # Cuerpo: barril con el lomo claro y la barriga oscura.
        d.ellipse([7, 8 + dy, 24, 17 + dy], fill=base)
        d.line([(10, 9 + dy), (20, 9 + dy)], fill=claro)
        d.chord([7, 11 + dy, 24, 17 + dy], 0, 180, fill=osc)
        if p["manchas"]:
            d.ellipse([11, 8 + dy, 17, 13 + dy], fill=col(p["manchas"]))
        for (a, b) in patas_f:
            d.line([(a[0], a[1] + dy), (b[0], b[1] + dy)], fill=base, width=2)
            d.point((b[0] + 1, b[1] + dy), fill=base)
        d.polygon([(20, 10 + dy), (24, 8 + dy), (25, 13 + dy), (21, 15 + dy)], fill=col(p["pecho"]))
        hx, hy = 21, 3 + dy
    # Cabeza: cráneo redondo, hocico hacia la derecha, oreja y ojo.
    d.ellipse([hx, hy, hx + 7, hy + 7], fill=base)
    d.polygon([(hx + 5, hy + 3), (hx + 10, hy + 4), (hx + 10, hy + 7), (hx + 5, hy + 7)], fill=base)
    d.line([(hx + 1, hy), (hx + 5, hy)], fill=claro)
    d.line([(hx + 6, hy + 7), (hx + 9, hy + 7)], fill=osc)
    if p["manchas"]:
        d.ellipse([hx + 2, hy + 1, hx + 6, hy + 5], fill=col(p["manchas"]))    # parche en el ojo
    d.point((hx + 10, hy + 4), fill=col("negro"))                            # nariz
    d.point((hx + 10, hy + 3), fill=col("negro"))
    ojo = col("blanco") if p["manchas"] else col("negro")
    if cuadro == 3:
        d.rectangle([hx + 5, hy + 1, hx + 6, hy + 2], fill=col("blanco"))     # ojo abierto del susto
        d.point((hx + 6, hy + 2), fill=col("negro"))
    elif cuadro == 2:
        d.line([(hx + 4, hy + 3), (hx + 5, hy + 2), (hx + 6, hy + 3)], fill=col("negro"))  # ojo feliz ^
    else:
        d.point((hx + 5, hy + 2), fill=col("negro") if not p["manchas"] else ojo)
        if p["manchas"]:
            d.point((hx + 5, hy + 2), fill=col("negro"))
    if cuadro == 2:
        d.rectangle([hx + 7, hy + 7, hx + 8, hy + 9], fill=col("rojo"))       # lengua afuera
        d.point((hx + 8, hy + 9), fill=col("rojo_oscuro"))
    oreja = col(p["oreja"])
    if p.get("paradas") or cuadro == 3:
        d.polygon([(hx + 1, hy + 2), (hx + 2, hy - 3), (hx + 4, hy + 1)], fill=oreja)
    else:
        d.polygon([(hx + 1, hy + 1), (hx + 4, hy), (hx + 3, hy + 6), (hx + 1, hy + 5)], fill=oreja)
    if cuadro == 3:
        # «¡!» del susto y rayitas de temblor.
        d.line([(hx + 9, hy - 4), (hx + 9, hy - 1)], fill=col("amarillo_via"))
        d.point((hx + 9, hy + 1), fill=col("amarillo_via"))
        d.line([(2, 16), (4, 15)], fill=col("hueso"))
        d.line([(2, 12), (4, 12)], fill=col("hueso"))


def perros():
    W, H = 32, 24
    rgb = np.zeros((H * len(PERROS), W * 4, 3), np.float32)
    alfa = np.zeros((H * len(PERROS), W * 4), np.float32)
    for r, p in enumerate(PERROS):
        for k in range(4):
            cuadro = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            _perro(ImageDraw.Draw(cuadro), p, k)
            a = np.array(cuadro).astype(np.float32)
            a[0, :, 3] = a[-1, :, 3] = 0          # margen para el contorno dentro del cuadro
            a[:, 0, 3] = a[:, -1, 3] = 0
            c_rgb, lleno = a[..., :3], a[..., 3] > 0
            b = borde_de(lleno)
            c_rgb[b] = c("negro")
            rgb[r * H:(r + 1) * H, k * W:(k + 1) * W] = c_rgb
            alfa[r * H:(r + 1) * H, k * W:(k + 1) * W] = lleno | b
    guardar_mixto(rgb, TEX / "perros.png", alfa=alfa, fuerza=0)


# --- hoja de revisión (no va al juego) ------------------------------------------------------------

def vista_previa(ruta, escala=3):
    """Todo ampliado sobre gris medio, para mirarlo antes de darlo por bueno."""
    piezas = [["avisos.png", "avisos_luz.png"], ["vallas.png", "hueco.png", "aceite.png", "perros.png"]]
    cols = []
    for grupo in piezas:
        ims = [Image.open(TEX / n).convert("RGBA") for n in grupo]
        w = sum(i.width for i in ims) * escala + 8 * (len(ims) + 1)
        h = max(i.height for i in ims) * escala + 16
        lienzo = Image.new("RGBA", (w, h), (120, 120, 124, 255))
        x = 8
        for i in ims:
            g = i.resize((i.width * escala, i.height * escala), Image.NEAREST)
            lienzo.alpha_composite(g, (x, 8))
            x += g.width + 8
        cols.append(lienzo)
    W = max(i.width for i in cols)
    total = Image.new("RGBA", (W, sum(i.height for i in cols)), (120, 120, 124, 255))
    y = 0
    for i in cols:
        total.alpha_composite(i, (0, y))
        y += i.height
    total.convert("RGB").save(ruta)


if __name__ == "__main__":
    import sys
    TEX.mkdir(parents=True, exist_ok=True)
    for f in (avisos, vallas, hueco, aceite, perros):
        f()
        print("generado:", f.__name__)
    if "--vista" in sys.argv:
        destino = sys.argv[sys.argv.index("--vista") + 1]
        vista_previa(destino)
        print("vista previa:", destino)
