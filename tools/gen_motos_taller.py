"""Motos del taller dibujadas por código: la Bwis, la NKD y la Ninja vistas de perfil.

    python tools/gen_motos_taller.py

Deja assets/ui/motos_taller.png (384×96, transparente: 3 cuadros de 128×96 en el orden bws, nkd,
ninja, mirando a la derecha) y una vista previa a 4× en docs/direccion_visual/motos_taller_preview.png.

Dibujo propio (sustituye a tools/recortar_motos.py, que recortaba memes de terceros: D21). Se hace
igual que los puestos de mando (tools/gen_manubrios.py): cada pieza se pinta a 4× con volumen y luz
de arriba a la izquierda, con siluetas continuas (curvas suaves que pasan por puntos de control, no
figuras perfectas pegadas), se reduce, se le pone contorno negro y se pasa a la paleta. Sin logos
ni letras: la moto se reconoce por su forma y su color.

Se ve el lado derecho de cada moto (el del exosto). Las ruedas quedan donde las espera
tools/gen_cinematica.py (RUEDAS y «rueda» de MOTOS): la de adelante en x≈98-106, y≈75, apoyadas
en y≈94, igual que la hoja anterior, para que la cinemática y el taller sigan sin cambios.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import gen_manubrios as GM
from paleta import PALETA as P
from pixel import BAYER4, cuantizar

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "assets" / "ui" / "motos_taller.png"
PREVIA = RAIZ / "docs" / "direccion_visual" / "motos_taller_preview.png"
W, H = 128, 96          # un cuadro de la hoja
S = GM.S                # se pinta a 4×
ORDEN = ("bws", "nkd", "ninja")


def c(nombre, k=1.0):
    return np.array(P[nombre], np.float32) * k


def spline(pts, cerrada=True, n=10):
    """Curva de Catmull-Rom que pasa por los puntos: silueta continua, sin esquinas de polígono."""
    p = np.array(pts, np.float32)
    if cerrada:
        p = np.vstack([p[-1:], p, p[:2]])
    else:
        p = np.vstack([p[:1], p, p[-1:]])
    sal = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            sal.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    if not cerrada:
        sal.append(p[-2])
    return [tuple(q) for q in sal]


class Lienzo(GM.Lienzo):
    """El pintor de los puestos de mando, en un cuadro de 128×96."""

    def __init__(self):
        self.rgb = np.zeros((H * S, W * S, 3), np.float32)
        self.a = np.zeros((H * S, W * S), np.float32)
        self.semi = np.zeros((H * S, W * S), bool)

    def _mask(self, dibujar):
        im = Image.new("L", (W * S, H * S), 0)
        dibujar(ImageDraw.Draw(im))
        return np.array(im) > 127

    def curva(self, pts):
        return self.poly(spline(pts))

    def trazo(self, pts, ancho):
        """Tubo que sigue una curva suave por los puntos."""
        return self.tubo(spline(pts, cerrada=False, n=6), ancho)

    def anillo(self, cx, cy, r0, r1):
        return self.elipse(cx, cy, r1, r1) & ~self.elipse(cx, cy, r0, r0)

    def reducir(self):
        """A 1×: color, cobertura y contorno negro de 1 px alrededor de lo pintado."""
        a = self.a.reshape(H, S, W, S).mean(axis=(1, 3))
        pre = (self.rgb * self.a[..., None]).reshape(H, S, W, S, 3).mean(axis=(1, 3))
        rgb = pre / np.maximum(a, 1e-6)[..., None]
        umbral = np.tile(BAYER4, (H // 4 + 1, W // 4 + 1))[:H, :W] + 0.5
        semi = self.semi.reshape(H, S, W, S).mean(axis=(1, 3)) > 0.5
        lleno = a > np.where(semi, umbral * 0.98 + 0.01, 0.5)
        m = np.pad(lleno & ~semi, 1)
        borde = (m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~lleno & ~semi
        rgb[borde] = P["negro"]
        q = cuantizar(rgb, 5.0)
        alfa = ((lleno | borde) * 255).astype(np.uint8)
        return np.dstack([q, alfa])


# ---------------------------------------------------------------------------------------------
# Piezas comunes

def rueda(L, cx, cy, r, rin, tipo, aro="cromo", tacos=False, disco=False, franja=None):
    """Llanta con volumen, rin y lo de adentro. tipo: 'radios' (alambre), 'aleacion' (5 brazos)
    o 'scooter' (rin de 12" con brazos gruesos)."""
    # llanta: caucho negro con el costado más claro arriba a la izquierda
    L.pieza(L.elipse(cx, cy, r, r), c("carbon"), bisel=3.2, luz=0.8, grad=0.2, brillo=0.08)
    L.plano(L.anillo(cx, cy, rin + 2.2, rin + 2.9), c("asfalto_oscuro"))          # costado
    if tacos:   # tacos del labrado que asoman por el borde (la Bwis es medio todoterreno)
        for k in range(20):
            g = 2 * np.pi * k / 20
            for (r0, r1, d) in ((r - 3.0, r - 0.8, 0.0), (rin + 2.9, r - 3.6, np.pi / 20)):
                L.plano(L.tubo([(cx + np.cos(g + d) * r0, cy + np.sin(g + d) * r0),
                                (cx + np.cos(g + d) * r1, cy + np.sin(g + d) * r1)], 1.5), c("asfalto"))
            L.plano(L.tubo([(cx + np.cos(g + 0.16) * (r - 2.6), cy + np.sin(g + 0.16) * (r - 2.6)),
                            (cx + np.cos(g + 0.16) * (r - 0.2), cy + np.sin(g + 0.16) * (r - 0.2))], 0.7), c("negro"))
    else:
        L.plano(L.anillo(cx, cy, r - 1.6, r - 1.1), c("negro"))
    # rin
    if aro == "cromo":
        L.cromo(L.anillo(cx, cy, rin - 1.6, rin))
    else:
        L.pieza(L.anillo(cx, cy, rin - 1.6, rin), c(aro), bisel=0.9, luz=0.8, brillo=0.15)
    if franja:
        L.plano(L.anillo(cx, cy, rin - 1.3, rin - 0.6), c(franja))
    fondo = L.elipse(cx, cy, rin - 1.6, rin - 1.6)
    L.plano(fondo, c("negro"))
    if tipo == "radios":
        for k in range(18):
            a0 = 2 * np.pi * k / 18
            a1 = a0 + (0.5 if k % 2 else -0.5)
            L.plano(L.tubo([(cx + np.cos(a0) * 2.2, cy + np.sin(a0) * 2.2),
                            (cx + np.cos(a1) * (rin - 1.4), cy + np.sin(a1) * (rin - 1.4))], 0.45), c("cromo"))
    else:
        n, ancho = (5, 2.6) if tipo == "aleacion" else (6, 3.2)
        col = c(aro if aro != "cromo" else "cromo")
        for k in range(n):
            a = 2 * np.pi * k / n - 0.3
            L.pieza(L.tubo([(cx + np.cos(a) * 2, cy + np.sin(a) * 2),
                            (cx + np.cos(a) * (rin - 1.5), cy + np.sin(a) * (rin - 1.5))], ancho),
                    col, bisel=1.0, luz=0.9, brillo=0.2, linea=False)
    if disco:   # disco de freno con perforaciones y la mordaza atrás arriba
        rd = rin * 0.72
        L.cromo(L.elipse(cx, cy, rd, rd))
        L.plano(L.elipse(cx, cy, rd - 1.8, rd - 1.8), c("cromo_oscuro"))
        for k in range(8):
            a = 2 * np.pi * k / 8
            L.plano(L.elipse(cx + np.cos(a) * (rd - 0.9), cy + np.sin(a) * (rd - 0.9), 0.45, 0.45), c("asfalto_oscuro"))
    L.cromo(L.elipse(cx, cy, 2.4, 2.4))                                               # buje
    L.plano(L.elipse(cx, cy, 0.9, 0.9), c("asfalto_oscuro"))


def mordaza(L, cx, cy, r, ang=-2.3):
    """Mordaza del freno de disco sobre el borde del disco."""
    x, y = cx + np.cos(ang) * r, cy + np.sin(ang) * r
    L.pieza(L.curva([(x - 2.4, y - 1.2), (x + 1.4, y - 2.6), (x + 2.8, y + 0.4), (x - 0.6, y + 2.8), (x - 2.8, y + 1.2)]),
            c("asfalto"), bisel=1.2, luz=0.8, brillo=0.2)


def espejo(L, base, cabeza, rx, ry, lejano=False):
    """Espejo en su tallo; la cabeza se ve de canto (óvalo negro con el filo del vidrio)."""
    k = 0.7 if lejano else 1.0
    L.pieza(L.trazo([base, ((base[0] + cabeza[0]) / 2 + 1, (base[1] + cabeza[1]) / 2), cabeza], 1.1),
            c("cromo", k), bisel=0.6, luz=0.8, brillo=0.3 * k)
    L.pieza(L.elipse(cabeza[0], cabeza[1] - ry * 0.6, rx, ry), c("carbon", k), bisel=1.4, luz=0.9, brillo=0.25 * k)
    if not lejano:
        L.plano(L.elipse(cabeza[0] + rx * 0.35, cabeza[1] - ry * 0.6, rx * 0.35, ry * 0.7), c("vidrio_brillo"))


def mano_puño(L, x, y, lejano=False):
    k = 0.65 if lejano else 1.0
    L.pieza(L.tubo([(x - 3.2, y + 0.6), (x + 1.8, y - 0.4)], 2.8), c("carbon", k), bisel=1.2, luz=0.8, brillo=0.1)


# ---------------------------------------------------------------------------------------------
# Bwis (Yamaha BWS 125): scooter de ruedas gordas. Frente alto y cuadrado con los dos faros
# redondos (ojos de sapo), manubrio alto al aire con espejos redondos, piso plano, cola alta con
# parrilla y el exosto con su tapa negra por el lado derecho, sobre la rueda de atrás.

def bws():
    L = Lienzo()
    R, F, r, rin = (30, 76), (98, 76), 18, 10.5
    # --- lo del lado de allá (más oscuro) ---
    espejo(L, (88, 20), (82.5, 6), 4.2, 3.4, lejano=True)
    mano_puño(L, 81, 18.5, lejano=True)
    # --- ruedas gordas de tacos ---
    rueda(L, *R, r, rin, "scooter", aro="cromo_oscuro", tacos=True)
    rueda(L, *F, r, rin, "scooter", aro="cromo_oscuro", tacos=True, disco=True)
    # motor y basculante (el bloque del variador asoma bajo la carrocería)
    L.pieza(L.curva([(42, 64), (62, 63), (68, 70), (64, 79), (48, 80), (36, 78), (34, 70)]),
            c("asfalto"), bisel=2.5, luz=0.7, grad=0.3, brillo=0.12)
    for k in range(4):   # aletas del cilindro
        L.plano(L.tubo([(56 + k * 2.4, 67.5), (55 + k * 2.4, 76)], 0.6), c("asfalto_oscuro"))
    # amortiguador trasero con su resorte
    L.plano(L.trazo([(37, 70), (33, 52)], 3.2), c("carbon"))
    for k in range(6):
        y = 55 + k * 2.3
        L.plano(L.tubo([(32.5 + (y - 52) * 0.2, y), (37 + (y - 52) * 0.2, y - 0.6)], 0.7), c("rojo"))
    # exosto: tubo que baja del motor y la lata en diagonal junto a la rueda, con tapa negra
    L.cromo(L.trazo([(66, 74), (62, 82), (52, 83), (44, 78)], 2.6), oscuro=True)
    lata = L.curva([(50, 79.5), (46, 73.5), (28, 66.5), (15, 63), (12.5, 67), (15, 71.5), (32, 76.5), (46, 82)])
    L.cromo(lata, bisel=3.0)
    tapa = L.curva([(47, 74.5), (30, 67.5), (18, 64.5), (19, 67.5), (33, 72), (46, 77.5)])
    L.pieza(tapa, c("carbon"), bisel=1.5, luz=0.9, brillo=0.2)
    for k in range(5):
        x = 22 + k * 5
        L.plano(L.elipse(x, 67.4 + (x - 22) * 0.4, 1.0, 0.6), c("negro"))
    L.pieza(L.elipse(14, 67, 2.4, 3.6), c("cromo_oscuro"), bisel=1, luz=0.8, brillo=0.3)
    L.plano(L.elipse(13.6, 67, 1.2, 2.2), c("negro"))
    # --- horquilla (barras con fuelles negros) ---
    L.pieza(L.trazo([(98, 76), (93.5, 62)], 4.4), c("asfalto_oscuro"), bisel=1.8, luz=0.8, brillo=0.2)
    for k in range(4):
        y = 64 + k * 2.6
        L.plano(L.tubo([(93.3 + (y - 62) * 0.3, y), (97.5 + (y - 62) * 0.3, y)], 0.6), c("negro"))
    L.cromo(L.trazo([(94, 63), (90, 50)], 3.0))
    mordaza(L, *F, rin * 0.72, ang=-2.0)
    # guardabarros delantero pegado a la llanta
    t = np.linspace(-2.75, -0.55, 9)
    arco = [(F[0] + np.cos(a) * (r + 2.2), F[1] + np.sin(a) * (r + 2.2)) for a in t]
    L.pieza(L.trazo(arco, 3.4), c("carbon"), bisel=1.5, luz=0.9, brillo=0.2)
    # --- carrocería de atrás: costado negro bajo el sillín, que sube hasta la cola ---
    cola = L.curva([(66, 47), (64, 57), (59, 65), (50, 67), (42, 64), (32, 58.5), (20, 55.5), (12, 51.5),
                    (9.5, 46.5), (13, 43.5), (36, 44), (54, 45)])
    L.pieza(cola, c("asfalto_oscuro"), bisel=3.5, luz=0.8, grad=0.35, brillo=0.22)
    falda = L.curva([(60, 61), (58, 66), (50, 68), (40, 65), (28, 59.5), (18, 56.5), (12, 53), (16, 52.6),
                     (28, 56.5), (42, 61), (52, 63)])
    L.pieza(falda, c("carbon"), bisel=1.8, luz=0.6)
    L.plano(L.trazo([(50, 48.5), (32, 48), (16, 47.5)], 0.9), c("gris"))                 # filo de luz
    # panel azul del costado (el color de la Bwis), afilado hacia atrás
    L.pieza(L.curva([(50, 50), (34, 49.5), (20, 50.5), (14, 52), (22, 54.5), (36, 57.5), (48, 60)]),
            c("azul_sitp"), bisel=1.8, luz=0.9, grad=0.3, brillo=0.3)
    toma = L.curva([(60, 50), (63, 52), (60, 58), (53, 59), (51, 55)])                   # toma de aire
    L.pieza(toma, c("carbon"), bisel=1.5, luz=-0.4)
    for k in range(3):
        L.plano(L.tubo([(53 + k * 2.8, 55.5), (54.5 + k * 2.8, 52.5)], 0.7), c("asfalto"))
    # piso plano entre el escudo y el sillín
    L.pieza(L.curva([(58, 63), (80, 62.5), (85, 65), (82, 70), (62, 70), (55, 67)]), c("carbon"), bisel=2, luz=0.8, grad=0.3)
    L.plano(L.tubo([(62, 63.4), (80, 63)], 0.7), c("asfalto"))
    # --- sillín: la parte del piloto más baja, la del parrillero más alta ---
    sillin = L.curva([(68, 45.5), (64, 41.5), (54, 40.5), (44, 39.8), (33, 38), (21, 38), (14, 40.5), (14, 44.5),
                      (34, 45.5), (58, 47.5)])
    L.pieza(sillin, c("carbon"), bisel=2.8, luz=0.9, grad=0.3, brillo=0.18)
    L.plano(L.trazo([(60, 41.8), (46, 41), (36, 39.6)], 0.6), c("asfalto"))               # costura
    # parrilla y agarradera de atrás
    L.pieza(L.trazo([(35, 44.5), (27, 38.5), (13, 37), (8.5, 38.8), (9.5, 43)], 1.8), c("carbon"), bisel=0.9, luz=0.9, brillo=0.3)
    L.pieza(L.curva([(23, 36.6), (10, 35.6), (8.2, 37.6), (23, 38.5)]), c("asfalto"), bisel=0.8, luz=0.9, brillo=0.25)
    # stop y direccional
    L.pieza(L.curva([(13, 45), (9.8, 45.3), (8.6, 48.5), (11.4, 50.6), (14, 48.5)]), c("rojo"), bisel=1.2, luz=0.9, brillo=0.35)
    L.pieza(L.elipse(12, 52.8, 1.6, 1.2), c("naranja"), bisel=0.8, brillo=0.35)
    # --- frente: escudo alto y cuadrado, azul, con el interior negro hacia el piloto ---
    frente = L.curva([(78, 66), (77, 52), (78.5, 40), (82, 30), (88, 25.5), (100, 26), (108, 29.5), (112.5, 36),
                      (113, 46), (110, 53), (103, 57.5), (94, 59), (88, 63), (84, 67)])
    L.pieza(frente, c("azul_sitp"), bisel=3.5, luz=0.9, grad=0.35, brillo=0.3)
    interior = L.curva([(78, 66), (77.3, 52), (78.8, 40), (82.5, 31), (85.5, 33), (83, 42), (82.4, 54), (84, 62), (84, 67)])
    L.pieza(interior, c("carbon"), bisel=1.8, luz=0.6)
    # la «nariz» negra que baja entre los faros hasta la rejilla
    nariz = L.curva([(96, 45), (107, 47), (111, 51), (104, 56), (95, 57.5), (91, 53)])
    L.pieza(nariz, c("carbon"), bisel=1.8, luz=0.8, brillo=0.15)
    for k in range(3):
        L.plano(L.tubo([(97 + k * 3, 50.5), (98.5 + k * 3, 54.5)], 0.7), c("asfalto"))
    L.plano(L.trazo([(87, 29), (98, 28.4), (107, 31.6)], 0.9), c("azul_bwis"))
    # faros redondos (el de allá asoma detrás del de acá), cada uno con su ceja negra
    for (x, y, rr, k) in ((106.5, 38.5, 4.4, 0.6), (109.4, 40.6, 5.0, 1.0)):
        L.pieza(L.elipse(x, y, rr, rr), c("carbon", k), bisel=1.4, luz=0.9, brillo=0.25 * k)
        L.cromo(L.elipse(x + 0.6, y, rr - 1.0, rr - 1.0))
        L.pieza(L.elipse(x + 0.8, y + 0.2, rr - 2.0, rr - 2.0), c("hueso", k), bisel=1.2, luz=-0.3, linea=False)
        L.plano(L.elipse(x - 0.2, y - 1.0, rr * 0.28, rr * 0.22), c("blanco"))
    L.pieza(L.curva([(103.5, 34.3), (110, 34.6), (114, 37.8), (111.5, 37.4), (105.5, 36.6)]), c("carbon"), bisel=0.8, luz=0.9, brillo=0.3)
    # direccional de adelante
    L.pieza(L.curva([(95, 41), (99.5, 40.5), (100, 43), (96, 43.8)]), c("naranja"), bisel=0.8, luz=0.9, brillo=0.35)
    # --- manubrio: la cubierta negra sobre el escudo, la barra al aire, puño, maneta y espejo ---
    cub = L.curva([(83, 27.5), (84.5, 21.5), (90, 18.5), (95.5, 19.5), (96, 24), (93, 27.5)])
    L.pieza(cub, c("carbon"), bisel=1.8, luz=0.9, grad=0.25, brillo=0.25)
    L.plano(L.trazo([(86, 22), (90, 20.2), (94, 20.6)], 0.6), c("azul_bwis_oscuro"))
    L.cromo(L.trazo([(86, 22.5), (82, 20.6), (78, 20)], 2.2))
    L.cromo(L.trazo([(86, 19), (80, 18), (77, 18.6)], 0.9))                              # maneta
    mano_puño(L, 78.5, 20.2)
    espejo(L, (85, 21), (80, 7.5), 4.6, 3.6)
    return L


# ---------------------------------------------------------------------------------------------
# NKD 125 (AKT): moto de calle pelada. Farola redonda, manubrio de tubo cromado, tanque gris con
# rodilleras, el motor monocilíndrico a la vista con su tubo de escape, ruedas de radios, sillín
# plano, dos amortiguadores y la agarradera cromada atrás.

def nkd():
    L = Lienzo()
    R, F, r, rin = (24, 75), (105, 75), 19, 14
    espejo(L, (92, 22), (86, 6), 3.6, 3.0, lejano=True)
    mano_puño(L, 83, 22, lejano=True)
    rueda(L, *R, r, rin, "radios")
    rueda(L, *F, r, rin, "radios", disco=True)
    # basculante y amortiguadores (dos, se ve el de este lado)
    L.pieza(L.trazo([(24, 75), (40, 72.5), (56, 70)], 3.6), c("carbon"), bisel=1.5, luz=0.9, brillo=0.2)
    L.pieza(L.trazo([(30, 73), (35, 49)], 3.4), c("asfalto_oscuro"), bisel=1.2, luz=0.8)
    for k in range(7):
        y = 53 + k * 2.4
        x = 30 + (73 - y) * (5 / 24)
        L.cromo(L.tubo([(x - 2.2, y + 0.4), (x + 2.2, y - 0.5)], 0.9))
    L.cromo(L.elipse(30, 73, 1.6, 1.6))
    # chasís: cuna negra que baja de la pipa y abraza el motor
    L.pieza(L.trazo([(90, 34), (80, 48), (74, 62), (72, 76), (62, 82), (48, 80)], 3.0), c("carbon"), bisel=1.2, luz=0.9, brillo=0.2)
    L.pieza(L.trazo([(86, 36), (62, 44), (40, 46), (22, 45)], 2.8), c("carbon"), bisel=1.2, luz=0.9, brillo=0.2)
    # motor: cárter de aluminio con la tapa del clutch redonda y el cilindro de aletas inclinado
    carter = L.curva([(50, 64), (60, 60), (72, 62), (76, 70), (72, 79), (60, 82), (48, 80), (44, 72)])
    L.pieza(carter, c("concreto"), bisel=2.5, luz=0.8, grad=0.3, brillo=0.25)
    L.pieza(L.elipse(60, 71, 7.0, 6.3), c("concreto_claro"), bisel=2, luz=0.8, brillo=0.3)
    L.pieza(L.elipse(60, 71, 3.2, 2.8), c("cromo"), bisel=1, luz=0.9, brillo=0.3)
    L.pieza(L.elipse(69, 76.5, 3.0, 2.4), c("concreto_claro"), bisel=1, luz=0.8)
    cil = L.curva([(62, 61), (64, 49), (77, 48.5), (79, 55), (75, 63)])
    L.pieza(cil, c("asfalto"), bisel=1.8, luz=0.7, grad=0.2)
    for k in range(6):   # aletas de enfriamiento
        y = 50 + k * 2.2
        L.pieza(L.tubo([(63.2 + k * 0.25, y), (78 - k * 0.5, y - 0.3)], 1.2), c("concreto"), bisel=0.5, luz=0.9, brillo=0.25, linea=False)
    L.pieza(L.curva([(64, 49), (66, 45.5), (76, 45.5), (77.5, 49)]), c("concreto_claro"), bisel=1, luz=0.9, brillo=0.3)  # culata
    # escape: sale del cilindro, baja, pasa bajo el motor y termina en la lata junto a la rueda
    L.cromo(L.trazo([(77, 58), (81, 66), (78, 80), (66, 85), (48, 84), (42, 81)], 2.8))
    lata = L.curva([(46, 83), (42, 77.5), (26, 69.5), (12, 65), (8.5, 68), (10.5, 73), (24, 78.5), (40, 85)])
    L.cromo(lata, bisel=3.2)
    L.pieza(L.curva([(40, 77), (26, 70.5), (18, 68), (19, 71.5), (28, 75), (40, 80.5)]), c("carbon"), bisel=1.2, luz=0.9, brillo=0.2)
    L.pieza(L.elipse(10, 69.5, 2.2, 3.5), c("cromo_oscuro"), bisel=1, luz=0.8, brillo=0.3)
    L.plano(L.elipse(9.6, 69.5, 1.0, 2.0), c("negro"))
    # pedal de freno y estribo
    L.pieza(L.trazo([(66, 80), (72, 82), (78, 79.5)], 1.6), c("cromo_oscuro"), bisel=0.8, luz=0.9, brillo=0.3)
    L.pieza(L.curva([(58, 76), (66, 75.5), (66.5, 78.5), (58, 79)]), c("carbon"), bisel=1, luz=0.8)
    # tapa lateral bajo el sillín
    L.pieza(L.curva([(40, 47), (54, 47), (52, 58), (44, 60), (38, 55)]), c("carbon"), bisel=1.8, luz=0.8, brillo=0.15)
    L.plano(L.trazo([(41, 50), (51, 50)], 0.8), c("rojo"))
    # guardabarros y cola: salpicadera negra, colín gris, stop y la agarradera cromada
    L.pieza(L.curva([(20, 47), (8, 49), (3, 55), (2.5, 60), (5, 60), (8, 53), (18, 50)]), c("carbon"), bisel=1.2, luz=0.8)
    colin = L.curva([(40, 46.5), (24, 43.5), (10, 43), (5, 45), (7, 48.5), (22, 49.5), (38, 50)])
    L.pieza(colin, c("concreto"), bisel=2, luz=0.8, grad=0.3, brillo=0.25)
    L.cromo(L.trazo([(34, 43), (26, 39.2), (12, 39.5), (8, 42)], 1.6))
    L.pieza(L.curva([(7.5, 44.5), (4, 45), (3.4, 48), (6.5, 48.8)]), c("rojo"), bisel=1, luz=0.9, brillo=0.35)
    L.pieza(L.elipse(5.2, 53, 1.8, 1.2), c("naranja"), bisel=0.8, brillo=0.35)
    # sillín plano
    sillin = L.curva([(62, 43), (56, 38.6), (40, 38.2), (24, 38.8), (14, 40), (12, 43), (30, 44), (50, 44.6)])
    L.pieza(sillin, c("carbon"), bisel=2.4, luz=0.9, grad=0.3, brillo=0.2)
    L.plano(L.trazo([(56, 39.8), (40, 39.4), (20, 40.3)], 0.6), c("asfalto"))
    # tanque gris plata con rodillera negra, franja roja y la tapa cromada
    tanque = L.curva([(58, 44.5), (60, 36), (68, 31), (82, 29.5), (91, 32), (90, 38), (82, 45), (70, 48.5), (60, 49)])
    L.pieza(tanque, c("concreto"), bisel=3.6, luz=0.85, grad=0.35, brillo=0.35)
    L.pieza(L.curva([(62, 40), (70, 38), (72, 45), (64, 48), (60, 46)]), c("carbon"), bisel=1.4, luz=0.8)
    L.plano(L.trazo([(69, 33.8), (80, 32.6), (88, 34)], 0.9), c("rojo"))
    L.cromo(L.elipse(72, 30.4, 3.0, 1.0))
    # horquilla: barras cromadas con las botellas negras abajo
    L.cromo(L.trazo([(96.5, 47), (91.5, 30)], 3.2))
    L.pieza(L.trazo([(105, 75), (97, 48)], 4.0), c("asfalto_oscuro"), bisel=1.5, luz=0.9, brillo=0.25)
    mordaza(L, *F, rin * 0.72, ang=-2.1)
    t = np.linspace(-2.6, -0.95, 8)   # guardabarros delantero corto
    L.pieza(L.trazo([(F[0] + np.cos(a) * (r + 1.8), F[1] + np.sin(a) * (r + 1.8)) for a in t], 2.4),
            c("carbon"), bisel=1.2, luz=0.9, brillo=0.25)
    # farola redonda con aro cromado, direccional y el velocímetro encima
    L.pieza(L.trazo([(94, 33), (99, 34)], 1.6), c("cromo_oscuro"), bisel=0.8)
    # farola: la taza negra redonda (vista de lado) y el aro cromado con el vidrio mirando adelante
    L.pieza(L.curva([(97, 30), (101.5, 27.6), (105.5, 29), (106.5, 34.5), (105, 40), (100.5, 41), (97, 38.5), (95.8, 34)]),
            c("carbon"), bisel=2.2, luz=0.9, grad=0.2, brillo=0.35)
    L.cromo(L.elipse(105.6, 34.4, 2.6, 6.4))
    L.pieza(L.elipse(106.4, 34.4, 1.4, 5.0), c("hueso"), bisel=0.8, luz=-0.3, linea=False)
    L.plano(L.elipse(106.6, 32.2, 0.6, 1.4), c("blanco"))
    L.pieza(L.elipse(95.5, 38, 2.4, 1.6), c("naranja"), bisel=0.8, brillo=0.35)
    L.pieza(L.curva([(89, 23), (94, 21.5), (96, 24.5), (93, 27), (89, 26.5)]), c("carbon"), bisel=1.2, luz=0.9, brillo=0.25)
    L.plano(L.elipse(93.8, 23.8, 1.2, 1.6), c("hueso"))
    # manubrio de tubo cromado que sube y se echa para atrás, puño, maneta y espejo ovalado
    L.cromo(L.trazo([(92, 29), (91, 25), (87, 22.5), (81, 22)], 2.2))
    L.cromo(L.trazo([(89, 20.8), (82, 20), (79, 20.6)], 0.9))
    mano_puño(L, 81, 22.2)
    espejo(L, (88, 22.5), (82, 6.5), 4.0, 3.2)
    return L


# ---------------------------------------------------------------------------------------------
# Ninja 300 (Kawasaki): deportiva de carenado completo, verde lima sin letras. Trompa afilada con
# los faros rasgados, parabrisas, semimanubrios bajo la tijera, carenado lateral con las tomas de
# aire, panza negra, colín alto y afilado, basculante y la lata del escape al lado derecho.

def ninja():
    L = Lienzo()
    R, F, r, rin = (20, 75), (106, 75), 19, 13.5

    rueda(L, *R, r, rin, "aleacion", aro="carbon", franja="verde_ninja")
    rueda(L, *F, r, rin, "aleacion", aro="carbon", franja="verde_ninja", disco=True)
    # basculante plateado y el pedal/estribo de atrás
    L.pieza(L.curva([(18, 72.5), (40, 68), (58, 65), (60, 70), (40, 74.5), (20, 78)]), c("cromo_oscuro"), bisel=1.5, luz=0.9, brillo=0.3)
    # motor bicilíndrico oscuro bajo el carenado
    L.pieza(L.curva([(56, 60), (78, 56), (86, 64), (80, 78), (62, 80), (54, 72)]), c("asfalto"), bisel=2, luz=0.7, grad=0.3, brillo=0.12)
    # escape: la lata negra con punta cromada que sube hacia atrás bajo el colín
    L.cromo(L.trazo([(80, 76), (70, 82), (54, 80)], 2.6), oscuro=True)
    lata = L.curva([(58, 79), (52, 73.5), (34, 63), (26, 60), (22.5, 63), (24.5, 67.5), (34, 71), (52, 81)])
    L.pieza(lata, c("carbon"), bisel=2.4, luz=0.9, grad=0.2, brillo=0.3)
    L.cromo(L.curva([(27, 60.6), (22.8, 62.8), (24.6, 67.4), (28.8, 67)]))
    L.plano(L.elipse(25.5, 64.3, 1.1, 2.0), c("negro"))
    L.cromo(L.curva([(44, 67.5), (47, 68.5), (40, 72.5), (37, 71)]), oscuro=True)     # abrazadera
    # estribos
    L.pieza(L.trazo([(46, 60), (49, 66), (54, 68)], 2.0), c("cromo_oscuro"), bisel=0.9, luz=0.9, brillo=0.3)
    L.pieza(L.curva([(50, 66.5), (57, 66.5), (57, 69), (50, 69)]), c("carbon"), bisel=0.8)
    # horquilla (dorada no: plateada) bajo el carenado
    L.cromo(L.trazo([(106, 75), (98, 47)], 3.8))
    L.pieza(L.trazo([(106, 75), (102.5, 63)], 4.4), c("asfalto_oscuro"), bisel=1.5, luz=0.9, brillo=0.25)
    mordaza(L, *F, rin * 0.72, ang=-2.2)
    t = np.linspace(-2.55, -0.9, 8)   # guardabarros delantero verde
    L.pieza(L.trazo([(F[0] + np.cos(a) * (r + 1.6), F[1] + np.sin(a) * (r + 1.6)) for a in t], 2.8),
            c("verde_ninja"), bisel=1.2, luz=0.9, brillo=0.3)
    # colín: sube afilado hacia atrás, con el guardabarros de la placa colgando
    L.pieza(L.trazo([(14, 46), (8, 52), (6, 58)], 1.6), c("carbon"), bisel=0.8)
    colin = L.curva([(58, 47), (42, 44.5), (26, 38), (12, 31), (5, 29.5), (5.5, 33), (12, 41), (20, 49), (32, 55), (46, 57), (58, 56)])
    L.pieza(colin, c("verde_ninja"), bisel=3, luz=0.85, grad=0.3, brillo=0.35)
    L.pieza(L.curva([(44, 49), (28, 44), (16, 37.5), (16, 44), (24, 51), (36, 55.5), (48, 56.5)]), c("carbon"), bisel=1.4, luz=0.7)
    L.plano(L.trazo([(46, 52), (34, 50), (22, 45)], 0.8), c("asfalto"))
    L.pieza(L.curva([(7, 30.2), (4.2, 30), (4.8, 33.4), (8.2, 33.8)]), c("rojo"), bisel=0.8, luz=0.9, brillo=0.35)
    L.pieza(L.elipse(7, 50, 1.6, 1.1), c("naranja"), bisel=0.8, brillo=0.35)
    # sillines: el del piloto bajo y el del parrillero más alto
    L.pieza(L.curva([(62, 44), (56, 41.6), (42, 41.4), (36, 43.5), (44, 45.5), (60, 46)]), c("carbon"), bisel=1.8, luz=0.9, brillo=0.2)
    L.pieza(L.curva([(38, 41.8), (30, 37.4), (20, 33.6), (17, 35.2), (26, 40.5), (34, 43.4)]), c("carbon"), bisel=1.4, luz=0.9, brillo=0.2)
    # tanque verde con la parte de arriba negra
    tanque = L.curva([(60, 45), (62, 38), (72, 33), (86, 31.5), (92, 35), (88, 44), (74, 49), (62, 49.5)])
    L.pieza(tanque, c("verde_ninja"), bisel=3.4, luz=0.85, grad=0.35, brillo=0.35)
    L.pieza(L.curva([(64, 37.2), (72, 33.2), (86, 31.8), (89, 33.6), (76, 35.2), (66, 38.8)]), c("carbon"), bisel=1, luz=0.9, brillo=0.25)
    # carenado: panza negra abajo, flanco verde con las tomas de aire y la trompa afilada
    panza = L.curva([(60, 66), (74, 70), (92, 68), (98, 62), (90, 60), (70, 61)])
    L.pieza(panza, c("carbon"), bisel=1.8, luz=0.8, grad=0.2, brillo=0.15)
    flanco = L.curva([(66, 50), (80, 44), (94, 38), (106, 36), (116, 39.5), (125, 47.5), (121, 49.5), (110, 53),
                      (102, 60), (92, 66), (78, 64), (70, 60), (64, 55)])
    L.pieza(flanco, c("verde_ninja"), bisel=3.6, luz=0.85, grad=0.35, brillo=0.4)
    # panel negro del medio y las rejillas de las tomas
    L.pieza(L.curva([(72, 52), (84, 48), (96, 47), (92, 55), (84, 60), (74, 58)]), c("carbon"), bisel=1.5, luz=0.7)
    for k in range(3):
        L.plano(L.trazo([(78 + k * 4, 52.5 + k * 0.2), (86 + k * 3.2, 50)], 0.8), c("verde_ninja_oscuro"))
    L.plano(L.trazo([(68, 58), (82, 62.5), (96, 60)], 0.9), c("verde_ninja_claro"))           # filo de luz abajo
    L.plano(L.trazo([(96, 39.6), (110, 38), (120, 42)], 0.8), c("verde_ninja_claro"))
    # faros rasgados en la trompa y direccional
    L.pieza(L.curva([(108, 41.5), (117, 42), (124, 47.4), (116, 47), (109, 44.5)]), c("carbon"), bisel=0.8, luz=0.9, brillo=0.3)
    L.pieza(L.curva([(110.5, 42.6), (117, 43.2), (122, 46.4), (116, 46), (110.8, 44)]), c("blanco"), bisel=0.8, luz=0.9, brillo=0.3, linea=False)
    L.pieza(L.curva([(104, 44), (108, 44), (107.5, 46), (104, 46.2)]), c("naranja"), bisel=0.6, brillo=0.3)
    # parabrisas ahumado encima de la trompa
    L.pieza(L.curva([(96, 38), (97, 30.5), (101, 25.5), (106, 26.5), (112, 32), (118, 40), (107, 37.5)]), c("vidrio"), bisel=1.4, luz=0.9, brillo=0.35)
    L.plano(L.trazo([(100.5, 28), (104, 28.4), (110, 33.5)], 0.6), c("vidrio_brillo"))
    # espejo del carenado
    L.pieza(L.trazo([(102, 38), (99, 33)], 1.4), c("carbon"))
    L.pieza(L.curva([(94, 30), (101, 29.2), (102.5, 32.2), (96, 33.4)]), c("carbon"), bisel=1, luz=0.9, brillo=0.3)
    # semimanubrio y puño asomando detrás del parabrisas
    L.pieza(L.trazo([(96, 36.5), (90, 37.5)], 2.6), c("carbon"), bisel=1, luz=0.9, brillo=0.2)
    L.cromo(L.trazo([(95, 34.5), (89, 35.2)], 0.8))
    return L


def main():
    hoja = np.zeros((H, W * 3, 4), np.uint8)
    for i, id_moto in enumerate(ORDEN):
        hoja[:, i * W:(i + 1) * W] = {"bws": bws, "nkd": nkd, "ninja": ninja}[id_moto]().reducir()
    Image.fromarray(hoja, "RGBA").save(SALIDA)
    print("generado:", SALIDA.relative_to(RAIZ))
    # vista previa a 4× sobre el gris de la tarima
    fondo = Image.new("RGBA", (W * 3, H), P["asfalto"] + (255,))
    fondo.alpha_composite(Image.fromarray(hoja, "RGBA"))
    PREVIA.parent.mkdir(parents=True, exist_ok=True)
    fondo.resize((W * 3 * 4, H * 4), Image.NEAREST).save(PREVIA)
    print("generado:", PREVIA.relative_to(RAIZ))


if __name__ == "__main__":
    main()
