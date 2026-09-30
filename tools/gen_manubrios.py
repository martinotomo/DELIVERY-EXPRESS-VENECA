"""Puesto de mando de cada moto visto desde el asiento (lo que se ve mientras se maneja).

    python tools/gen_manubrios.py

Dibujo propio a partir de cómo se ven las motos de verdad desde el puesto del conductor
(referencias en docs/referencias/puestos.md), al estilo de las motos del taller: formas con volumen,
luz desde arriba a la izquierda, contorno oscuro y la paleta del juego. Sin logos.

Cada pieza se pinta a 4× (con sombreado en los bordes según hacia dónde mira) y al final todo se
reduce a 320×96, se le pone contorno y se cuantiza a la paleta. La aguja y los números de las
pantallas los dibuja el juego (scripts/manubrio.gd, TABLEROS): las posiciones de aquí y de allá
tienen que coincidir (lo comprueba test_escenas).
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

from paleta import PALETA as P
from pixel import BAYER4, cuantizar

RAIZ = Path(__file__).resolve().parent.parent
UI = RAIZ / "assets" / "ui"
W, H = 320, 96
S = 4                      # se pinta a 4× y se reduce: bordes limpios y sombras suaves
LUZ = np.array([-0.45, -0.9])  # la luz viene de arriba a la izquierda
LUZ = LUZ / np.linalg.norm(LUZ)

ARCHIVOS = {"bws": "manubrio.png", "nkd": "manubrio_nkd.png", "ninja": "manubrio_ninja.png"}


def c(nombre, k=1.0):
    return np.array(P[nombre], np.float32) * k


class Lienzo:
    def __init__(self):
        self.rgb = np.zeros((H * S, W * S, 3), np.float32)
        self.a = np.zeros((H * S, W * S), np.float32)
        self.semi = np.zeros((H * S, W * S), bool)   # piezas medio transparentes (parabrisas)

    # --- máscaras (coordenadas en píxeles del sprite final) ---
    def _mask(self, dibujar):
        im = Image.new("L", (W * S, H * S), 0)
        dibujar(ImageDraw.Draw(im))
        return np.array(im) > 127

    def poly(self, pts):
        return self._mask(lambda d: d.polygon([(x * S, y * S) for x, y in pts], fill=255))

    def elipse(self, cx, cy, rx, ry):
        return self._mask(lambda d: d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=255))

    def caja(self, x0, y0, x1, y1, r=0):
        return self._mask(lambda d: d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=255))

    def tubo(self, pts, ancho):
        """Tubo que pasa por pts (con puntas redondas)."""
        def dib(d):
            q = [(x * S, y * S) for x, y in pts]
            d.line(q, fill=255, width=int(ancho * S), joint="curve")
            for x, y in q:
                r = ancho * S / 2
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        return self._mask(dib)

    # --- pintura ---
    def pieza(self, m, base, bisel=2.5, luz=0.55, grad=0.25, linea=True, brillo=0.0, alfa=1.0):
        """Rellena la máscara con volumen: degradé de arriba abajo, bordes iluminados o en sombra
        según miran a la luz, un filo oscuro que separa la pieza y, si se pide, un brillo."""
        if not m.any():
            return
        base = np.asarray(base, np.float32)
        ys, xs = np.nonzero(m)
        y0, y1 = ys.min(), ys.max() + 1
        t = np.zeros(m.shape, np.float32)
        t[y0:y1] = np.linspace(-1.0, 1.0, y1 - y0)[:, None]
        d = ndimage.distance_transform_edt(m)
        b = bisel * S
        dd = ndimage.gaussian_filter(np.minimum(d, b), S * 0.8)
        gy, gx = np.gradient(dd)
        n = np.hypot(gx, gy) + 1e-6
        mira = -(gx * LUZ[0] + gy * LUZ[1]) / n                       # >0: el borde mira a la luz
        cerca = np.clip(1.0 - d / b, 0.0, 1.0)
        k = 1.0 - grad * t + luz * mira * cerca
        col = base[None, None, :] * k[..., None]
        if brillo > 0:
            col = col + brillo * 255.0 * np.clip(mira * cerca, 0, 1)[..., None] ** 2
        if linea:
            filo = d < S * 0.9
            col[filo] = base * 0.28
        col = np.clip(col, 0, 255)
        self.rgb[m] = col[m]
        self.a[m] = alfa
        self.semi[m] = alfa < 1.0

    def plano(self, m, color, alfa=1.0):
        self.rgb[m] = np.asarray(color, np.float32)
        self.a[m] = alfa
        self.semi[m] = alfa < 1.0

    def cromo(self, m, bisel=None, oscuro=False):
        """Metal pulido: contraste fuerte, brillo blanco arriba y reflejo oscuro abajo."""
        if not m.any():
            return
        d = ndimage.distance_transform_edt(m)
        ancho = d.max() / S
        self.pieza(m, c("cromo_oscuro" if oscuro else "cromo"), bisel=bisel or max(ancho, 1.0), luz=0.9, grad=0.35, brillo=0.55)

    # --- final: reducir a 320×96, contorno y paleta ---
    def guardar(self, ruta):
        a = self.a.reshape(H, S, W, S).mean(axis=(1, 3))
        pre = (self.rgb * self.a[..., None]).reshape(H, S, W, S, 3).mean(axis=(1, 3))
        rgb = pre / np.maximum(a, 1e-6)[..., None]
        umbral = np.tile(BAYER4, (H // 4 + 1, W // 4 + 1))[:H, :W] + 0.5
        semi = self.semi.reshape(H, S, W, S).mean(axis=(1, 3)) > 0.5
        lleno = a > np.where(semi, umbral * 0.98 + 0.01, 0.5)   # lo semitransparente, tramado
        m = np.pad(lleno & ~semi, 1)     # lo tramado no lleva contorno (se vería negro entero)
        borde = (m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~lleno & ~semi
        rgb[borde] = P["negro"]
        q = cuantizar(rgb, 5.0)
        alfa = ((lleno | borde) * 255).astype(np.uint8)
        Image.fromarray(np.dstack([q, alfa]), "RGBA").save(ruta)
        print("generado:", Path(ruta).relative_to(RAIZ))


# ---------------------------------------------------------------------------------------------
# Piezas comunes: espejo, puño con guante y manga de la chaqueta.

def espejo_redondo(L, cx, cy, rx, ry, pie, tallo_ancho=2.2):
    """Espejo redondo clásico en su tallo cromado (Bwis y NKD)."""
    L.cromo(L.tubo([pie, (cx + (4 if cx < 160 else -4), cy + ry - 1)], tallo_ancho))
    L.pieza(L.elipse(cx, cy, rx, ry), c("carbon"), bisel=2.5, luz=0.8, brillo=0.2)
    vidrio(L, L.elipse(cx, cy, rx - 2.2, ry - 2.2), cy)


def vidrio(L, m, cy):
    """El vidrio del espejo refleja la calle de atrás: cielo arriba, andenes y asfalto abajo."""
    ys, xs = np.nonzero(m)
    y0, y1 = ys.min(), ys.max()
    t = (np.arange(m.shape[0], dtype=np.float32) - y0) / max(y1 - y0, 1)
    cielo = c("vidrio_brillo")[None, :] * (1 - t[:, None]) + c("vidrio")[None, :] * t[:, None]
    suelo = c("asfalto_oscuro")[None, :] * np.ones_like(t)[:, None]
    fila = np.where((t < 0.55)[:, None], cielo, suelo)
    img = np.broadcast_to(fila[:, None, :], m.shape + (3,)).copy()
    # reflejo diagonal de la luz
    yy, xx = np.nonzero(m)
    x0 = xs.min()
    diag = ((xx - x0) + (yy - y0) * 0.8) / S
    brillo = (diag > 3) & (diag < 5.5)
    img[yy[brillo], xx[brillo]] = c("cromo_brillo")
    L.rgb[m] = img[m]
    L.a[m] = 1.0
    L.semi[m] = False


def mano(L, gx, gy, lado, inclina=0.0):
    """Puño negro con la maneta de freno por delante y la mano con guante agarrándolo.
    lado = -1 izquierda, 1 derecha; (gx, gy) = centro de la mano. Desde el asiento se ve el dorso
    de la mano, los nudillos arriba y los dedos que se doblan por delante del puño."""
    s = lado
    dy = lambda x: inclina * s * (x - gx)   # noqa: E731
    # puño de caucho que sale por fuera de la mano, con la punta del manubrio
    L.pieza(L.tubo([(gx - s * 18, gy + dy(gx - s * 18)), (gx + s * 24, gy + dy(gx + s * 24))], 9), c("carbon"), bisel=4, luz=0.7, brillo=0.1)
    for k in range(3):
        x = gx + s * (17 + k * 2.4)
        L.plano(L.tubo([(x, gy - 3 + dy(x)), (x, gy + 3 + dy(x))], 0.9), c("negro"))
    L.cromo(L.elipse(gx + s * 26, gy + dy(gx + s * 26), 2.2, 4.2), oscuro=True)
    # maneta (va por delante del puño: más arriba en pantalla)
    L.cromo(L.tubo([(gx - s * 16, gy - 8 + dy(gx - s * 16)), (gx + s * 18, gy - 10 + dy(gx + s * 18)), (gx + s * 22, gy - 8.5 + dy(gx + s * 22))], 2.2))
    # manga: puño elástico de la chaqueta en la muñeca
    L.pieza(L.poly([(gx - s * 14, gy + 5), (gx + s * 12, gy + 3), (gx + s * 16, gy + 13), (gx - s * 14, gy + 15)]), c("carbon"), bisel=2.5, luz=0.5)
    # dorso de la mano: un bulto con volumen
    L.pieza(L.caja(gx - 14, gy - 8, gx + 14, gy + 9, r=8), c("guante"), bisel=6, luz=0.75, grad=0.3, brillo=0.12)
    # refuerzo de nudillos (cuero más oscuro) y los cuatro nudillos que asoman arriba
    L.pieza(L.caja(gx - 11, gy - 4.5, gx + 11, gy - 0.5, r=2), c("guante_oscuro"), bisel=1.5, luz=0.6)
    for k in range(4):
        fx = gx - 11.5 + k * 5.9
        L.pieza(L.caja(fx, gy - 10, fx + 5.6, gy - 4, r=2.6), c("guante"), bisel=2.4, luz=0.8, brillo=0.15)
        L.plano(L.caja(fx + 1.4, gy - 9.2, fx + 4.0, gy - 8.2), c("guante_claro"))
    # pulgar por dentro, doblado sobre el puño
    px = gx - s * 14
    L.pieza(L.elipse(px, gy - 2.5, 6.5, 4.5), c("guante"), bisel=3, luz=0.8, brillo=0.12)
    L.plano(L.elipse(px - s * 1.5, gy - 4.5, 2.5, 1.2), c("guante_claro"))


def brazo(L, gx, gy, lado):
    """Antebrazo con la manga de la chaqueta de domiciliario, de la muñeca a la esquina de abajo."""
    s = lado
    ex = gx + s * 30           # el codo sale por fuera y abajo
    pts = [(gx - s * 14, gy + 8), (gx + s * 14, gy + 6), (ex + s * 40, H + 2), (ex - s * 34, H + 2)]
    L.pieza(L.poly(pts), c("chaqueta"), bisel=10, luz=0.6, grad=0.25, brillo=0.1)
    # pliegues de la tela
    for f, off in ((0.3, -4), (0.55, 6), (0.75, -8)):
        ax, ay = gx + (ex - gx) * f + s * off, gy + 8 + (H - gy - 8) * f
        L.plano(L.tubo([(ax - s * 7, ay - 2.5), (ax + s * 6, ay + 1)], 1.3), c("chaqueta_oscura"))
        L.plano(L.tubo([(ax - s * 6, ay - 4), (ax + s * 4, ay - 1.5)], 0.9), c("chaqueta_clara"))
    # franja reflectiva
    fy = gy + 8 + (H - gy - 8) * 0.5
    fx = gx + (ex - gx) * 0.5
    L.pieza(L.poly([(fx - s * 24, fy), (fx + s * 26, fy - 4), (fx + s * 27, fy + 1), (fx - s * 23, fy + 5)]), c("hueso"), bisel=1.2, luz=0.4)


def piloto(L, gx, gy, inclina=0.0):
    for s in (-1, 1):
        x = 160 + s * (160 - gx)
        brazo(L, x, gy, s)
        mano(L, x, gy, s, inclina=inclina)


# ---------------------------------------------------------------------------------------------
# Bwis (Yamaha BWS 125 FI): scooter. Manubrio corto con cubierta negra y la pantalla digital en el
# centro, el frente plateado asomando adelante, el tapizado interno (escudo de rodillas) con el
# encendido a la izquierda y la guantera sin tapa a la derecha. Espejos redondos clásicos.

def bws():
    L = Lienzo()
    for s in (-1, 1):
        espejo_redondo(L, 160 + s * 112, 11, 15, 10.5, (160 + s * 72, 44))
    # frente plateado-azul (el «trompo» del escudo) que asoma más allá del manubrio
    frente = L.poly([(112, 44), (120, 30), (136, 24), (184, 24), (200, 30), (208, 44)])
    L.pieza(frente, c("azul_bwis"), bisel=3, luz=0.7, grad=0.3, brillo=0.25)
    L.pieza(L.poly([(132, 28), (188, 28), (182, 34), (138, 34)]), c("carbon"), bisel=1.5)          # rejilla
    for x in range(140, 182, 6):
        L.plano(L.caja(x, 29.5, x + 3, 32.5), c("asfalto"))
    for s in (-1, 1):                                                                                # direccionales
        L.pieza(L.poly([(160 + s * 44, 34), (160 + s * 50, 38), (160 + s * 46, 42), (160 + s * 40, 38)]), c("naranja"), bisel=1.5, brillo=0.3)
    # barra del manubrio que asoma por los lados
    for s in (-1, 1):
        L.pieza(L.tubo([(160 + s * 74, 52), (160 + s * 106, 55)], 6), c("asfalto_oscuro"), bisel=3, luz=0.8, brillo=0.2)
        # mandos: caja de interruptores negra con botones
        L.pieza(L.caja(160 + s * 92 - 6, 49, 160 + s * 92 + 6, 60, r=2), c("carbon"), bisel=2, luz=0.6)
        L.plano(L.caja(160 + s * 92 - 2, 51.5, 160 + s * 92 + 2, 54), c("rojo" if s > 0 else "amarillo_via"))
        L.plano(L.caja(160 + s * 92 - 3, 56, 160 + s * 92 + 3, 57.5), c("gris"))
    # cubierta del manubrio: negra, angulosa, con el filo azul del diseño de la Bwis
    cub = L.poly([(84, 47), (112, 40), (136, 37), (184, 37), (208, 40), (236, 47), (240, 56), (212, 62), (160, 64), (108, 62), (80, 56)])
    L.pieza(cub, c("carbon"), bisel=4, luz=0.7, grad=0.25, brillo=0.12)
    for s in (-1, 1):
        L.pieza(L.poly([(160 + s * 44, 41), (160 + s * 74, 46), (160 + s * 76, 49), (160 + s * 46, 45)]), c("azul_bwis_oscuro"), bisel=1, luz=0.6, linea=False)
    # tablero análogo (Tomás, 30/09): velocímetro redondo en una cápsula negra en el centro de la
    # cubierta (la aguja la pone el juego), con la gasolina en una esfera chiquita al lado
    L.pieza(L.elipse(160, 48, 18, 14.5), c("negro"), bisel=3, luz=0.9, brillo=0.25)
    L.cromo(L.elipse(160, 48, 15.5, 12.5), oscuro=True)
    L.pieza(L.elipse(160, 48, 13.5, 10.8), c("hueso"), bisel=2, luz=-0.25, grad=0.1, linea=False)
    for k in range(11):
        a = np.pi * (0.8 + 1.4 * k / 10)
        r0, r1 = (8.5, 11.8) if k % 2 == 0 else (10.2, 11.8)
        L.plano(L.tubo([(160 + np.cos(a) * r0, 48 + np.sin(a) * r0 * 0.8), (160 + np.cos(a) * r1, 48 + np.sin(a) * r1 * 0.8)], 0.9),
                c("rojo") if k >= 9 else c("negro"))
    L.plano(L.caja(155, 52.5, 165, 55), c("lcd_oscuro"))                                             # cuentakilómetros
    for s in (-1, 1):                                                                                # testigos de direccional
        L.plano(L.poly([(160 + s * 24, 48), (160 + s * 21, 46), (160 + s * 21, 50)]), c("pasto_claro"))
    # escudo interno (el tapizado de las rodillas), con encendido y guantera
    esc = L.poly([(102, 63), (218, 63), (240, H + 2), (80, H + 2)])
    L.pieza(esc, c("asfalto_oscuro"), bisel=5, luz=0.45, grad=0.35)
    L.plano(L.tubo([(160, 66), (160, H + 2)], 1.2), c("negro"))
    L.cromo(L.elipse(124, 76, 6, 4.5))                                                               # encendido
    L.pieza(L.elipse(124, 76, 3.2, 2.3), c("negro"), bisel=1, linea=False)
    L.plano(L.caja(123.5, 74.5, 124.6, 77.5), c("cromo_brillo"))
    L.pieza(L.caja(184, 70, 214, 86, r=3), c("negro"), bisel=3, luz=-0.5, grad=-0.3)                 # guantera sin tapa
    L.pieza(L.caja(106, 86, 132, 92, r=2), c("carbon"), bisel=1.5, luz=0.5)                          # tapa de la gasolina
    piloto(L, 56, 56)
    return L


# ---------------------------------------------------------------------------------------------
# NKD 125 (AKT): moto de calle sin carenado. Manubrio de tubo cromado de lado a lado, el velocímetro
# redondo (análogo, con cuentakilómetros digital) sobre la farola redonda, las barras de la
# suspensión con sus tapas, el encendido en la tijera y el tanque gris con su tapa. Espejos ovalados.

def nkd():
    L = Lienzo()
    for s in (-1, 1):
        cx = 160 + s * 114
        L.cromo(L.tubo([(160 + s * 78, 50), (cx - s * 3, 17)], 2.2))
        L.pieza(L.caja(cx - 15, 3, cx + 15, 19, r=7), c("carbon"), bisel=2.5, luz=0.8, brillo=0.2)
        vidrio(L, L.caja(cx - 12.5, 5.3, cx + 12.5, 16.7, r=5), 11)
    # farola redonda (se ve su casco negro y el aro cromado por encima del reloj) y direccionales
    L.pieza(L.elipse(160, 34, 26, 11), c("carbon"), bisel=4, luz=0.8, brillo=0.25)
    L.cromo(L.poly([(136, 30), (148, 25), (172, 25), (184, 30), (178, 28), (142, 28)]))
    for s in (-1, 1):
        L.cromo(L.tubo([(160 + s * 24, 38), (160 + s * 38, 34)], 1.8), oscuro=True)
        L.pieza(L.elipse(160 + s * 41, 33, 4.5, 3.5), c("naranja"), bisel=2, brillo=0.35)
    # tijera superior con las tapas de las barras y el encendido
    L.pieza(L.poly([(118, 50), (202, 50), (206, 62), (114, 62)]), c("asfalto_oscuro"), bisel=3, luz=0.6)
    for s in (-1, 1):
        L.cromo(L.elipse(160 + s * 34, 54, 7, 5))
        L.pieza(L.elipse(160 + s * 34, 54, 3, 2), c("cromo_oscuro"), bisel=1, linea=False)
    L.cromo(L.elipse(160, 61, 6, 4))
    L.pieza(L.elipse(160, 61, 3, 2), c("negro"), bisel=1, linea=False)
    # velocímetro: taza negra, aro cromado, carátula clara con marcas y cuentakilómetros
    L.pieza(L.elipse(160, 42, 19, 17), c("negro"), bisel=3, luz=0.9, brillo=0.3)
    L.cromo(L.elipse(160, 42, 16.5, 14.8))
    L.pieza(L.elipse(160, 42, 14.2, 12.6), c("hueso"), bisel=2, luz=-0.25, grad=0.1, linea=False)
    for k in range(11):
        a = np.pi * (0.8 + 1.4 * k / 10)
        r0, r1 = (9.0, 12.2) if k % 2 == 0 else (10.6, 12.2)
        L.plano(L.tubo([(160 + np.cos(a) * r0, 42 + np.sin(a) * r0 * 0.9), (160 + np.cos(a) * r1, 42 + np.sin(a) * r1 * 0.9)], 0.9),
                c("rojo") if k >= 9 else c("negro"))
    L.plano(L.caja(154, 47.5, 166, 51), c("lcd_oscuro"))
    for s, col in ((-1, "pasto_claro"), (1, "azul_casa")):                                          # testigos
        L.plano(L.elipse(160 + s * 7, 56.8, 1.6, 1.3), c(col))
    # manubrio cromado de lado a lado con su abrazadera
    barra = [(28, 55), (70, 52), (118, 55), (160, 57), (202, 55), (250, 52), (292, 55)]
    L.cromo(L.tubo(barra, 5.5))
    L.pieza(L.caja(146, 52, 174, 62, r=2), c("negro"), bisel=2, luz=0.8, brillo=0.2)
    L.plano(L.caja(148, 54, 172, 55), c("gris"))
    for s in (-1, 1):
        L.pieza(L.caja(160 + s * 94 - 7, 50, 160 + s * 94 + 7, 61, r=2), c("carbon"), bisel=2, luz=0.6)
        L.plano(L.caja(160 + s * 94 - 3, 52.5, 160 + s * 94 + 3, 55), c("rojo" if s > 0 else "gris"))
        L.plano(L.tubo([(160 + s * 90, 62), (160 + s * 60, 76), (160 + s * 44, H)], 1.4), c("negro"))  # cables
    # tanque gris plata con franja roja, rodilleras negras y tapa cromada
    tanque = L.poly([(98, H + 2), (112, 74), (130, 66), (190, 66), (208, 74), (222, H + 2)])
    L.pieza(tanque, c("concreto"), bisel=10, luz=0.75, grad=0.35, brillo=0.3)
    for s in (-1, 1):
        L.pieza(L.poly([(160 + s * 50, 72), (160 + s * 62, H + 2), (160 + s * 46, H + 2), (160 + s * 40, 76)]), c("carbon"), bisel=2, luz=0.5)
    L.plano(L.poly([(128, 68), (192, 68), (194, 70), (126, 70)]), c("rojo"))
    L.cromo(L.elipse(160, 82, 11, 6.5))
    L.pieza(L.elipse(160, 82, 7, 4), c("cromo_oscuro"), bisel=2, luz=0.6, linea=False)
    piloto(L, 50, 54)
    return L


# ---------------------------------------------------------------------------------------------
# Ninja 300 (Kawasaki): deportiva. Cúpula verde con parabrisas ahumado (se ve la calle a través),
# tablero con tacómetro análogo redondo y pantalla LCD a la derecha, semimanubrios negros bajo la
# tijera, el tanque verde y negro, y los espejos anchos y angulosos montados en el carenado.

def ninja():
    L = Lienzo()
    # espejos del carenado: cuerpo negro anguloso, sale del carenado por un pie corto
    for s in (-1, 1):
        f = lambda x: 160 + s * (x - 160)   # noqa: E731  (refleja al lado derecho)
        L.pieza(L.tubo([(f(104), 34), (f(94), 26)], 3.5), c("carbon"), bisel=2, luz=0.6)
        cuerpo = L.poly([(f(52), 17), (f(84), 8), (f(100), 12), (f(102), 24), (f(92), 29), (f(58), 27)])
        L.pieza(cuerpo, c("carbon"), bisel=3, luz=0.9, brillo=0.25)
        vidrio(L, L.poly([(f(57), 18), (f(84), 11), (f(97), 14), (f(98), 23), (f(90), 26), (f(61), 24)]), 18)
    # parabrisas ahumado: medio transparente (tramado), con un reflejo y su borde
    # Muy transparente (Tomás, 30/09: con el vidrio oscuro no se veía la calle y uno se estrellaba):
    # apenas un tramado ralo del tinte, dos reflejos finos y el marco.
    pb = L.poly([(124, 8), (196, 8), (214, 30), (106, 30)])
    L.pieza(pb, c("vidrio"), bisel=2, luz=0.6, grad=-0.2, linea=False, alfa=0.1)
    L.plano(L.tubo([(132, 12), (124, 23)], 1.0), c("vidrio_brillo"), alfa=0.8)
    L.plano(L.tubo([(137, 12), (131, 20)], 0.7), c("vidrio_brillo"), alfa=0.6)
    for x0, x1 in ((124, 106), (196, 214)):
        L.plano(L.tubo([(x0, 8), (x1, 30)], 1.0), c("carbon"))
    L.plano(L.tubo([(124, 8), (196, 8)], 1.2), c("negro"))
    # cúpula verde: se abre hacia los lados y hacia abajo como una proa (trazada con curvas)
    t = np.linspace(0, 1, 12)
    izq = [(106 - 30 * u ** 1.6, 29 + 31 * u) for u in t]
    borde = izq[::-1] + [(124, 26), (196, 26)] + [(320 - x, y) for x, y in izq]
    cupula = L.poly(borde + [(236, 62), (84, 62)])
    L.pieza(cupula, c("verde_ninja"), bisel=7, luz=0.85, grad=0.3, brillo=0.35)
    for s in (-1, 1):
        # paneles negros de los flancos (tomas de aire) y el filo claro de la pintura
        f = lambda x: 160 + s * (x - 160)   # noqa: E731
        L.pieza(L.poly([(f(98), 44), (f(106), 36), (f(112), 56), (f(96), 60), (f(88), 56)]), c("carbon"), bisel=2, luz=0.4)
        L.plano(L.tubo([(f(118), 27.5), (f(104), 30), (f(92), 42)], 1.0), c("verde_ninja_claro"))
    interior = L.poly([(114, 34), (206, 34), (214, 54), (106, 54)])
    L.pieza(interior, c("carbon"), bisel=3, luz=0.4, grad=0.2)
    # tablero: tacómetro redondo a la izquierda (la aguja la pone el juego) y LCD a la derecha
    L.pieza(L.caja(126, 27, 196, 49, r=5), c("negro"), bisel=2.5, luz=0.9, brillo=0.2)
    L.cromo(L.elipse(145, 38, 11.5, 10.2), oscuro=True)
    L.pieza(L.elipse(145, 38, 9.8, 8.8), c("hueso"), bisel=2, luz=-0.25, grad=0.1, linea=False)
    for k in range(13):
        a = np.pi * (0.8 + 1.4 * k / 12)
        r0, r1 = (6.4, 8.8) if k % 2 == 0 else (7.6, 8.8)
        L.plano(L.tubo([(145 + np.cos(a) * r0, 38 + np.sin(a) * r0 * 0.9), (145 + np.cos(a) * r1, 38 + np.sin(a) * r1 * 0.9)], 0.8),
                c("rojo") if k >= 10 else c("negro"))
    L.pieza(L.caja(159, 30, 191, 46, r=1.5), c("lcd_oscuro"), bisel=1.2, luz=0.3, linea=False)
    for k, col in enumerate(("pasto_claro", "naranja", "rojo")):                                   # testigos
        L.plano(L.caja(162 + k * 5, 47, 164.5 + k * 5, 48.5), c(col))
    # tijera superior con tapas de barras y encendido, y semimanubrios que bajan hacia afuera
    L.pieza(L.poly([(112, 54), (208, 54), (214, 66), (106, 66)]), c("cromo_oscuro"), bisel=3, luz=0.7, brillo=0.2)
    for s in (-1, 1):
        L.cromo(L.elipse(160 + s * 38, 60, 7, 4.8), oscuro=True)
        L.pieza(L.elipse(160 + s * 38, 60, 3, 2), c("carbon"), bisel=1, linea=False)
        L.pieza(L.tubo([(160 + s * 40, 64), (160 + s * 82, 67), (160 + s * 104, 69)], 6), c("carbon"), bisel=3, luz=0.8, brillo=0.25)
        L.pieza(L.caja(160 + s * 106 - 6, 62, 160 + s * 106 + 6, 73, r=2), c("carbon"), bisel=2, luz=0.6)
        L.plano(L.caja(160 + s * 106 - 2, 64.5, 160 + s * 106 + 2, 67), c("rojo" if s > 0 else "gris"))
    L.cromo(L.elipse(160, 61, 6, 4))
    L.pieza(L.elipse(160, 61, 3, 2), c("negro"), bisel=1, linea=False)
    # tanque verde con el centro negro y la tapa
    tanque = L.poly([(96, H + 2), (112, 76), (132, 68), (188, 68), (208, 76), (224, H + 2)])
    L.pieza(tanque, c("verde_ninja"), bisel=10, luz=0.8, grad=0.35, brillo=0.35)
    L.pieza(L.poly([(140, 69), (180, 69), (190, H + 2), (130, H + 2)]), c("carbon"), bisel=3, luz=0.5)
    L.cromo(L.elipse(160, 80, 9, 5.5), oscuro=True)
    L.pieza(L.elipse(160, 80, 5, 3), c("negro"), bisel=1, linea=False)
    piloto(L, 52, 70, inclina=0.05)
    return L


def main():
    UI.mkdir(parents=True, exist_ok=True)
    for id_moto, f in (("bws", bws), ("nkd", nkd), ("ninja", ninja)):
        f().guardar(UI / ARCHIVOS[id_moto])


if __name__ == "__main__":
    main()
