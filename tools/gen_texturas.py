"""Genera las texturas pixeladas de la ciudad y el manubrio de la BWS.

    python tools/gen_texturas.py

Todo sale de la paleta (tools/paleta.py) con ruido de numpy y dithering Bayer 4×4.
Semilla fija por archivo: regenerar da siempre lo mismo. Las texturas de la ciudad son
cíclicas (se repiten sin costura). Deja los PNG en assets/texturas/ y assets/ui/.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from paleta import PALETA as P
from pixel import guardar

RAIZ = Path(__file__).resolve().parent.parent
TEX = RAIZ / "assets" / "texturas"
UI = RAIZ / "assets" / "ui"


def c(nombre):
    return np.array(P[nombre], dtype=np.float32)


def ruido(rng, h, w, suave=0):
    """Ruido cíclico: suavizado con vecinos que dan la vuelta (sin costuras)."""
    n = rng.standard_normal((h, w)).astype(np.float32)
    for _ in range(suave):
        n = (n + np.roll(n, 1, 0) + np.roll(n, -1, 0) + np.roll(n, 1, 1) + np.roll(n, -1, 1)) / 5.0
    return n / (n.std() + 1e-6)


def lienzo(h, w, color):
    return np.ones((h, w, 3), np.float32) * c(color)


# --- suelo ----------------------------------------------------------------------------

def asfalto():
    rng = np.random.default_rng(101)
    img = lienzo(64, 64, "asfalto")
    img += ruido(rng, 64, 64)[..., None] * 7
    img += ruido(rng, 64, 64, 6)[..., None] * 9       # manchas grandes
    # Grietas: caminatas al azar oscuras.
    for _ in range(3):
        y, x = rng.integers(0, 64, 2)
        for _ in range(rng.integers(10, 22)):
            img[y % 64, x % 64] = c("asfalto_oscuro")
            y += rng.integers(-1, 2)
            x += 1
    guardar(img, TEX / "asfalto.png")


def anden():
    rng = np.random.default_rng(102)
    img = lienzo(64, 64, "concreto")
    img += ruido(rng, 64, 64)[..., None] * 6
    img += ruido(rng, 64, 64, 4)[..., None] * 8
    for k in range(0, 64, 16):              # juntas de las baldosas
        img[k, :] = c("gris")
        img[:, k] = c("gris")
        img[(k + 1) % 64, :] = c("concreto_claro") * 0.5 + img[(k + 1) % 64, :] * 0.5
    guardar(img, TEX / "anden.png")


def pasto():
    rng = np.random.default_rng(103)
    img = lienzo(64, 64, "pasto")
    img += ruido(rng, 64, 64)[..., None] * 14
    img += ruido(rng, 64, 64, 5)[..., None] * 12
    guardar(img, TEX / "pasto.png", fuerza=26)


def lineas():
    """Línea amarilla del centro de la vía, a trazos: una en u (calles) y otra en v (carreras)."""
    h = np.zeros((8, 32, 3), np.float32) + c("amarillo_via")
    a = np.zeros((8, 32), np.float32)
    a[:, :16] = 1.0
    guardar(h, TEX / "linea_h.png", alfa=a, fuerza=0)
    guardar(h.transpose(1, 0, 2), TEX / "linea_v.png", alfa=a.T, fuerza=0)


# --- fachadas: 128×128 px = 8 m de ancho × 6,4 m de alto (2 ventanas × 2 pisos) -------------

def ventana(img, emi, x, y, w, h, prendida, rng, marco="concreto_claro", reja=False):
    img[y:y + h, x:x + w] = c(marco)
    gx, gy, gw, gh = x + 2, y + 2, w - 4, h - 4
    vid = np.linspace(0, 1, gh)[:, None, None]
    img[gy:gy + gh, gx:gx + gw] = c("vidrio_oscuro") * (1 - vid) + c("vidrio") * vid
    for k in range(gw):                        # reflejo en diagonal
        yy = gy + gh - 1 - (k * 2) % gh
        if (k // 3) % 3 == 0:
            img[yy, gx + k] = c("vidrio_brillo")
    img[gy:gy + gh, gx + gw // 2] = c(marco)  # parteluz
    img[y + h:y + h + 2, x - 2:x + w + 2] = c("hueso")  # alféizar
    if reja:
        for k in range(gx, gx + gw, 4):
            img[gy:gy + gh, k] = c("carbon")
        img[gy + gh // 2, gx:gx + gw] = c("carbon")
    if prendida:
        luz = c("ventana_luz") if rng.random() < 0.7 else c("sodio")
        emi[gy:gy + gh, gx:gx + gw] = luz
        emi[gy:gy + gh, gx + gw // 2] = 0
        if reja:
            for k in range(gx, gx + gw, 4):
                emi[gy:gy + gh, k] = 0


def fachada_ladrillo():
    rng = np.random.default_rng(201)
    img = lienzo(128, 128, "mortero")
    emi = np.zeros_like(img)
    for fila in range(0, 128, 4):            # ladrillos de 8×3 con junta de 1 px, trabados
        desfase = 4 if (fila // 4) % 2 else 0
        for col in range(-8, 128, 8):
            tono = ["ladrillo", "ladrillo", "ladrillo_claro", "ladrillo_oscuro"][rng.integers(0, 4)]
            x0 = max(col + desfase, 0)
            x1 = min(col + desfase + 7, 128)
            if x1 > x0:
                img[fila:fila + 3, x0:x1] = c(tono) + rng.normal(0, 6)
    for piso in range(2):
        for v in range(2):
            ventana(img, emi, 14 + v * 64, 12 + piso * 64, 36, 38, rng.random() < 0.5, rng)
        img[piso * 64 + 62:piso * 64 + 64, :] = c("concreto")   # cornisa entre pisos
    guardar(img, TEX / "fachada_ladrillo.png", fuerza=10)
    guardar(emi, TEX / "fachada_ladrillo_luz.png", fuerza=0)


def fachada_concreto():
    rng = np.random.default_rng(202)
    img = lienzo(128, 128, "concreto")
    img += ruido(rng, 128, 128, 3)[..., None] * 8
    emi = np.zeros_like(img)
    for piso in range(2):
        y = piso * 64
        img[y + 50:y + 64, :] = c("concreto_claro") + ruido(rng, 14, 128)[..., None] * 4
        for v in range(4):                   # ventanas corridas
            ventana(img, emi, 4 + v * 32, y + 10, 26, 36, rng.random() < 0.45, rng, marco="gris")
    guardar(img, TEX / "fachada_concreto.png", fuerza=12)
    guardar(emi, TEX / "fachada_concreto_luz.png", fuerza=0)


def fachada_vidrio():
    rng = np.random.default_rng(203)
    img = lienzo(128, 128, "carbon")
    emi = np.zeros_like(img)
    grad = np.linspace(0, 1, 128)[:, None, None]
    for fy in range(0, 128, 32):
        for fx in range(0, 128, 16):
            y0, x0 = fy + 2, fx + 1
            panel = c("vidrio_oscuro") * (1 - grad[y0:y0 + 29]) + c("vidrio") * grad[y0:y0 + 29]
            img[y0:y0 + 29, x0:x0 + 14] = panel
            if rng.random() < 0.3:
                emi[y0:y0 + 29, x0:x0 + 14] = c("ventana_luz") * 0.8
    for k in range(128):                      # brillo del cielo reflejado
        if (k // 5) % 4 == 0:
            img[(127 - k) % 128, k] = c("vidrio_brillo")
    guardar(img, TEX / "fachada_vidrio.png", fuerza=10)
    guardar(emi, TEX / "fachada_vidrio_luz.png", fuerza=0)


def fachada_casa():
    """Casa pintada (el color lo pone el tinte de cada edificio), con rejas en las ventanas."""
    rng = np.random.default_rng(204)
    img = lienzo(128, 128, "hueso")
    img += ruido(rng, 128, 128, 2)[..., None] * 6
    img += ruido(rng, 128, 128, 6)[..., None] * 8  # pintura sucia
    emi = np.zeros_like(img)
    for piso in range(2):
        for v in range(2):
            ventana(img, emi, 18 + v * 64, 14 + piso * 64, 28, 30, rng.random() < 0.5, rng, marco="blanco", reja=True)
        img[piso * 64 + 60:piso * 64 + 64, :] = c("concreto_claro")
    guardar(img, TEX / "fachada_casa.png", fuerza=10)
    guardar(emi, TEX / "fachada_casa_luz.png", fuerza=0)


def cebras():
    """Franjas blancas de la cebra, gastadas por las llantas: 32 px = 4 m, franjas de 0,5 m.
    cebra_h para las cebras que cruzan calles (franjas a lo largo de x), cebra_v para las carreras."""
    rng = np.random.default_rng(104)
    img = lienzo(32, 32, "blanco")
    img += ruido(rng, 32, 32)[..., None] * 10
    a = np.zeros((32, 32), np.float32)
    for f in range(32):
        if (f // 4) % 2 == 0:
            a[f, :] = 1.0
    gasto = ruido(rng, 32, 32, 2)                 # pintura gastada: se ve el asfalto
    a[gasto < -1.3] = 0.0
    img[gasto < -0.6] = img[gasto < -0.6] * 0.8 + c("concreto") * 0.2
    guardar(img, TEX / "cebra_h.png", alfa=a, fuerza=6)
    guardar(img.transpose(1, 0, 2), TEX / "cebra_v.png", alfa=a.T, fuerza=6)


# --- peatones: hoja de 4 cuadros (camina, camina, en el piso, gritando) × 3 ropas, 40×40 px ------

ROPAS = [
    {"piel": "piel", "pelo": "negro", "camisa": "azul_casa", "pantalon": "carbon"},
    {"piel": "piel_clara", "pelo": "ladrillo_oscuro", "camisa": "verde_casa", "pantalon": "azul_casa", "melena": True, "bolso": "rojo"},
    {"piel": "piel_oscura", "pelo": "carbon", "camisa": "amarillo_casa", "pantalon": "gris", "gorra": "rojo"},
]


def _oscuro(nombre, k=0.68):
    return tuple(int(v * k) for v in P[nombre]) + (255,)


def _peaton(d, ropa, cuadro):
    """Un peatón de perfil mirando a la derecha, con los pies en y=39. Formas continuas, con sombra
    en el lado de atrás para que tenga volumen."""
    col = lambda n: P[n] + (255,)
    piel, camisa, pantalon = ropa["piel"], ropa["camisa"], ropa["pantalon"]
    if cuadro == 2:  # en el piso, boca arriba y con estrellitas de mareo (a lo caricatura)
        d.line([(22, 35), (27, 29), (32, 33)], fill=col(pantalon), width=3)          # pierna levantada
        d.line([(21, 37), (30, 37), (35, 36)], fill=_oscuro(pantalon), width=3)      # la otra, estirada
        d.rectangle([32, 32, 33, 33], fill=col("negro"))                             # zapatos
        d.rectangle([35, 35, 36, 36], fill=col("negro"))
        d.polygon([(9, 33), (22, 32), (23, 38), (9, 38)], fill=col(camisa))          # torso
        d.line([(9, 38), (22, 38)], fill=_oscuro(camisa), width=1)
        d.line([(13, 33), (15, 27), (13, 24)], fill=col(camisa), width=2)            # brazo al aire
        d.point((13, 23), fill=col(piel))
        d.ellipse([2, 31, 9, 38], fill=col(ropa["pelo"]))                            # cabeza
        d.ellipse([3, 30, 9, 36], fill=col(piel))
        d.point((5, 33), fill=col("negro"))                                          # ojo en X
        d.point((7, 33), fill=col("negro"))
        for x, y in ((4, 25), (10, 22), (15, 26)):                                   # estrellitas
            d.point((x, y), fill=col("amarillo_via"))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                d.point((x + dx, y + dy), fill=col("ventana_luz"))
        return
    if cuadro == 0:    # paso largo
        pierna_f, pierna_a = [(20, 22), (22, 30), (24, 37)], [(20, 22), (18, 30), (15, 37)]
        mano_f, mano_a = (16, 21), (24, 20)
    elif cuadro == 1:  # piernas juntas
        pierna_f, pierna_a = [(20, 22), (21, 30), (21, 37)], [(20, 22), (19, 30), (19, 37)]
        mano_f, mano_a = (21, 22), (19, 22)
    else:              # gritando: firme, puño en alto
        pierna_f, pierna_a = [(20, 22), (22, 30), (23, 37)], [(20, 22), (18, 30), (17, 37)]
        mano_f, mano_a = (26, 2), (17, 20)
    # Atrás (más oscuro): pierna y brazo del otro lado.
    d.line(pierna_a, fill=_oscuro(pantalon), width=3, joint="curve")
    d.rectangle([pierna_a[-1][0] - 1, 37, pierna_a[-1][0] + 2, 39], fill=col("negro"))
    d.line([(20, 12), mano_a], fill=_oscuro(camisa), width=2)
    d.point(mano_a, fill=_oscuro(piel))
    if ropa.get("bolso"):
        d.rectangle([15, 18, 18, 23], fill=col(ropa["bolso"]))
    # Torso con la espalda en sombra.
    d.polygon([(17, 11), (23, 11), (24, 23), (16, 23)], fill=col(camisa))
    d.polygon([(17, 11), (18, 11), (17, 23), (16, 23)], fill=_oscuro(camisa))
    d.line(pierna_f, fill=col(pantalon), width=3, joint="curve")
    d.rectangle([pierna_f[-1][0] - 1, 37, pierna_f[-1][0] + 3, 39], fill=col("negro"))
    if cuadro == 3:
        d.line([(21, 12), (25, 7), mano_f], fill=col(camisa), width=2, joint="curve")
        d.rectangle([mano_f[0] - 1, mano_f[1], mano_f[0] + 1, mano_f[1] + 2], fill=col(piel))  # puño
        for x, y in ((29, 5), (31, 8)):                                                      # rabia
            d.line([(x, y), (x + 2, y - 2)], fill=col("rojo"), width=1)
    else:
        d.line([(21, 12), mano_f], fill=col(camisa), width=2)
        d.point(mano_f, fill=col(piel))
    # Cabeza: pelo detrás, cara de perfil con nariz.
    d.rectangle([19, 9, 21, 11], fill=col(piel))
    if ropa.get("melena"):
        d.polygon([(16, 4), (20, 3), (19, 16), (15, 15)], fill=col(ropa["pelo"]))
    d.ellipse([16, 2, 23, 9], fill=col(ropa["pelo"]))
    d.ellipse([18, 3, 24, 10], fill=col(piel))
    d.point((24, 7), fill=col(piel))
    d.point((22, 5), fill=col("negro"))
    if cuadro == 3:
        d.rectangle([22, 8, 23, 9], fill=col("negro"))  # boca abierta
    if ropa.get("gorra"):
        d.rectangle([17, 2, 23, 4], fill=col(ropa["gorra"]))
        d.line([(23, 4), (26, 4)], fill=_oscuro(ropa["gorra"]), width=1)


def peatones():
    W = H = 40
    rgb = np.zeros((H * len(ROPAS), W * 4, 3), np.float32)
    alfa = np.zeros((H * len(ROPAS), W * 4), np.float32)
    for r, ropa in enumerate(ROPAS):
        for k in range(4):
            cuadro = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            _peaton(ImageDraw.Draw(cuadro), ropa, k)
            a = np.array(cuadro).astype(np.float32)
            c_rgb, lleno = a[..., :3], a[..., 3] > 0
            # Contorno oscuro de 1 px, como los sprites de Doom: se lee sobre cualquier fondo.
            # Se calcula en cada cuadro con margen, para que no se cuele en el cuadro vecino.
            m = np.pad(lleno, 1)
            borde = (m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~lleno
            c_rgb[borde] = c("negro")
            rgb[r * H:(r + 1) * H, k * W:(k + 1) * W] = c_rgb
            alfa[r * H:(r + 1) * H, k * W:(k + 1) * W] = lleno | borde
    guardar(rgb, TEX / "peatones.png", alfa=alfa, fuerza=4)


# --- motos de perfil para el taller: 120×72 px cada una, mirando a la derecha ----------------
# Evocan las motos de las imágenes de referencia de Tomás (Bwis 125 azul claro, NKD 125 negra,
# Ninja 300 verde) solo por silueta y color: sin logos ni marcas.

MOTO_W, MOTO_H = 120, 72


def _rueda(d, cx, cy, r, rin, tacos=False, radios=False):
    col = lambda n: P[n] + (255,)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col("negro"))
    d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], fill=col("carbon"))
    if tacos:  # llanta de tacos de la Bwis
        for k in range(16):
            a = 2 * np.pi * k / 16
            d.point((round(cx + np.cos(a) * r), round(cy + np.sin(a) * r)), fill=col("asfalto_oscuro"))
    ri = r * 0.58
    d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=col(rin))
    if radios:
        for k in range(12):
            a = 2 * np.pi * k / 12
            d.line([(cx, cy), (cx + np.cos(a) * ri, cy + np.sin(a) * ri)], fill=col("cromo_oscuro"), width=1)
        d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], outline=col("cromo"))
    else:
        d.ellipse([cx - ri + 2, cy - ri + 2, cx + ri - 2, cy + ri - 2], fill=col("carbon"))
        for k in range(5):  # rin de rayos gruesos
            a = 2 * np.pi * k / 5 + 0.3
            d.line([(cx, cy), (cx + np.cos(a) * (ri - 1), cy + np.sin(a) * (ri - 1))], fill=col(rin), width=2)
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=col("cromo_brillo"))


def _moto_bwis(d):
    """Scooter de ruedas gordas: escudo alto con dos farolas, piso plano y cola ancha."""
    col = lambda n: P[n] + (255,)
    _rueda(d, 30, 57, 13, "cromo_oscuro", tacos=True)
    _rueda(d, 92, 57, 13, "cromo_oscuro", tacos=True)
    d.polygon([(10, 50), (28, 50), (30, 55), (12, 56)], fill=col("cromo_oscuro"))           # exosto
    d.line([(12, 51), (27, 51)], fill=col("cromo"), width=1)
    d.polygon([(26, 44), (50, 42), (50, 52), (32, 54)], fill=col("gris"))                   # motor y CVT
    d.line([(30, 48), (48, 47)], fill=col("asfalto"), width=1)
    d.polygon([(12, 36), (16, 30), (26, 27), (50, 25), (58, 31), (58, 42), (46, 45), (18, 44), (12, 40)], fill=col("azul_bwis"))  # cola
    d.polygon([(13, 40), (58, 37), (58, 42), (46, 45), (18, 44)], fill=col("azul_bwis_oscuro"))
    d.line([(18, 31), (50, 28)], fill=col("blanco"), width=1)                              # brillo
    d.polygon([(18, 28), (50, 25), (54, 28), (22, 32)], fill=col("negro"))                  # sillín
    d.line([(10, 28), (24, 27)], fill=col("cromo"), width=2)                               # parrilla
    d.rectangle([9, 35, 12, 39], fill=col("rojo"))                                         # stop
    d.rectangle([56, 44, 74, 49], fill=col("carbon"))                                      # piso
    d.line([(88, 20), (95, 57)], fill=col("cromo_oscuro"), width=4)                         # barras
    d.line([(89, 20), (96, 56)], fill=col("cromo"), width=1)
    d.polygon([(70, 49), (72, 30), (78, 15), (90, 13), (96, 20), (94, 30), (84, 49)], fill=col("azul_bwis"))  # escudo
    d.polygon([(72, 30), (78, 15), (82, 15), (77, 32), (74, 49), (70, 49)], fill=col("azul_bwis_oscuro"))
    d.polygon([(88, 16), (97, 19), (97, 23), (89, 21)], fill=col("ventana_luz"))            # farolas dobles
    d.polygon([(89, 24), (97, 26), (96, 30), (89, 28)], fill=col("ventana_luz"))
    d.polygon([(84, 44), (100, 41), (106, 46), (101, 47), (92, 45), (86, 48)], fill=col("azul_bwis"))  # guardabarros
    d.line([(80, 13), (78, 4)], fill=col("cromo_oscuro"), width=2)                          # manubrio
    d.line([(72, 4), (86, 5)], fill=col("negro"), width=3)
    d.line([(76, 4), (70, 0)], fill=col("cromo_oscuro"), width=1)                           # espejo
    d.rectangle([68, 0, 71, 1], fill=col("vidrio_brillo"))


def _moto_nkd(d):
    """Naked de calle: tanque negro, farola redonda, motor a la vista y exosto cromado."""
    col = lambda n: P[n] + (255,)
    _rueda(d, 26, 56, 14, "cromo", radios=True)
    _rueda(d, 95, 56, 14, "cromo", radios=True)
    d.line([(26, 56), (52, 50)], fill=col("carbon"), width=4)                               # tijera
    d.line([(34, 36), (30, 54)], fill=col("rojo_oscuro"), width=3)                          # amortiguador
    d.line([(34, 36), (30, 54)], fill=col("cromo"), width=1)
    d.polygon([(46, 40), (66, 40), (68, 56), (50, 58)], fill=col("gris"))                   # motor
    for y in (44, 48, 52):
        d.line([(48, y), (66, y)], fill=col("asfalto"), width=1)                           # aletas
    d.line([(62, 50), (54, 59), (36, 58), (22, 50)], fill=col("cromo"), width=3, joint="curve")  # exosto
    d.polygon([(8, 42), (26, 44), (28, 51), (10, 49)], fill=col("cromo"))
    d.line([(9, 44), (26, 46)], fill=col("cromo_brillo"), width=1)
    d.polygon([(12, 30), (26, 28), (50, 33), (48, 42), (26, 41)], fill=col("carbon"))        # tapas y cola
    d.rectangle([9, 29, 13, 32], fill=col("rojo"))                                         # stop
    d.line([(10, 26), (24, 26)], fill=col("cromo"), width=2)                               # parrilla
    d.polygon([(22, 28), (52, 27), (52, 31), (26, 33)], fill=col("negro"))                  # sillín
    d.line([(84, 20), (64, 42)], fill=col("carbon"), width=3)                              # chasis
    d.polygon([(50, 29), (58, 21), (78, 21), (84, 29), (76, 38), (52, 38)], fill=col("carbon"))  # tanque
    d.polygon([(56, 23), (76, 23), (80, 27), (58, 27)], fill=col("gris"))                   # brillo del tanque
    d.line([(56, 32), (78, 30)], fill=col("rojo"), width=2)                                # franja
    d.line([(84, 18), (95, 56)], fill=col("cromo_oscuro"), width=4)                         # barras
    d.line([(85, 18), (96, 55)], fill=col("cromo_brillo"), width=1)
    d.polygon([(86, 44), (104, 42), (108, 46), (102, 47), (90, 47)], fill=col("carbon"))     # guardabarros
    d.ellipse([86, 16, 97, 27], fill=col("cromo"))                                         # farola redonda
    d.ellipse([90, 18, 98, 26], fill=col("ventana_luz"))
    d.line([(80, 14), (82, 6)], fill=col("cromo_oscuro"), width=2)                          # manubrio alto
    d.line([(74, 6), (88, 7)], fill=col("negro"), width=3)
    d.line([(78, 6), (72, 1)], fill=col("cromo_oscuro"), width=1)
    d.rectangle([70, 0, 73, 1], fill=col("vidrio_brillo"))


def _moto_ninja(d):
    """Deportiva: carenado verde afilado, parabrisas, cola levantada y ruedas negras."""
    col = lambda n: P[n] + (255,)
    _rueda(d, 26, 56, 14, "negro")
    _rueda(d, 96, 56, 14, "negro")
    d.ellipse([22, 52, 30, 60], outline=col("verde_ninja"))                               # filete de rin
    d.ellipse([92, 52, 100, 60], outline=col("verde_ninja"))
    d.line([(26, 56), (54, 48)], fill=col("carbon"), width=4)                               # basculante
    d.line([(88, 26), (96, 56)], fill=col("cromo_oscuro"), width=4)                         # barras
    d.line([(89, 26), (97, 55)], fill=col("ventana_luz"), width=1)                          # barras doradas
    d.polygon([(54, 52), (72, 53), (70, 58), (56, 58)], fill=col("cromo_oscuro"))           # exosto corto
    d.line([(56, 54), (70, 55)], fill=col("cromo"), width=1)
    d.polygon([(6, 18), (22, 22), (36, 28), (34, 34), (20, 30), (10, 24)], fill=col("verde_ninja"))  # cola arriba
    d.polygon([(10, 24), (20, 30), (34, 34), (34, 36), (18, 33)], fill=col("negro"))
    d.rectangle([5, 18, 9, 21], fill=col("rojo"))                                          # stop
    d.polygon([(28, 30), (46, 30), (52, 46), (36, 42)], fill=col("carbon"))                 # subchasis
    d.polygon([(16, 40), (32, 40), (36, 44), (20, 44)], fill=col("negro"))                  # guardabarros trasero
    d.polygon([(30, 26), (56, 26), (58, 30), (34, 31)], fill=col("negro"))                  # sillín
    d.polygon([(44, 36), (84, 28), (104, 32), (100, 40), (78, 50), (52, 52), (44, 46)], fill=col("verde_ninja"))  # carenado
    d.polygon([(50, 48), (78, 50), (74, 55), (54, 55)], fill=col("negro"))                  # quilla
    d.polygon([(52, 44), (70, 38), (90, 36), (76, 46), (54, 48)], fill=col("verde_ninja_oscuro"))  # entrada de aire
    d.line([(48, 38), (84, 30), (100, 33)], fill=col("blanco"), width=1)                   # brillo
    d.polygon([(56, 26), (72, 21), (84, 24), (82, 31), (58, 33)], fill=col("verde_ninja"))   # tanque
    d.line([(58, 28), (80, 24)], fill=col("verde_ninja_oscuro"), width=2)
    d.polygon([(84, 24), (96, 28), (106, 34), (100, 36), (88, 32)], fill=col("verde_ninja"))  # nariz
    d.polygon([(96, 31), (104, 34), (101, 35), (95, 33)], fill=col("ventana_luz"))          # faro afilado
    d.polygon([(82, 16), (90, 18), (98, 27), (88, 25)], fill=col("vidrio"))                 # parabrisas
    d.line([(83, 17), (96, 26)], fill=col("vidrio_brillo"), width=1)
    d.polygon([(86, 44), (104, 41), (108, 45), (100, 47), (90, 47)], fill=col("verde_ninja"))  # guardabarros
    d.line([(78, 22), (84, 20)], fill=col("negro"), width=3)                                # semimanubrios
    d.line([(88, 22), (92, 18)], fill=col("cromo_oscuro"), width=1)                         # espejo
    d.rectangle([91, 16, 94, 17], fill=col("negro"))


def motos_taller():
    rgb = np.zeros((MOTO_H, MOTO_W * 3, 3), np.float32)
    alfa = np.zeros((MOTO_H, MOTO_W * 3), np.float32)
    for k, dibujar in enumerate((_moto_bwis, _moto_nkd, _moto_ninja)):
        cuadro = Image.new("RGBA", (MOTO_W, MOTO_H), (0, 0, 0, 0))
        dibujar(ImageDraw.Draw(cuadro))
        a = np.array(cuadro).astype(np.float32)
        c_rgb, lleno = a[..., :3], a[..., 3] > 0
        m = np.pad(lleno, 1)
        borde = (m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~lleno
        c_rgb[borde] = c("negro")
        rgb[:, k * MOTO_W:(k + 1) * MOTO_W] = c_rgb
        alfa[:, k * MOTO_W:(k + 1) * MOTO_W] = lleno | borde
    guardar(rgb, UI / "motos_taller.png", alfa=alfa, fuerza=4)


# --- manubrio de la BWS, 320×90 px a 1× (se dibuja a 2× sobre la pantalla de 640×360) ---------

# Cada moto tiene su puesto de mando (la aguja del velocímetro siempre va en (160, 66)):
# Bwis con carenado negro de scooter, NKD sin carenado (tanque y reloj redondo en su soporte),
# Ninja con la cúpula verde y semimanubrios más bajos.
PUESTOS = {
    "bws": {"archivo": "manubrio.png", "dy": 0},
    "nkd": {"archivo": "manubrio_nkd.png", "dy": -4},
    "ninja": {"archivo": "manubrio_ninja.png", "dy": 6},
}


def manubrio(id_moto="bws"):
    puesto = PUESTOS[id_moto]
    dy = puesto["dy"]
    W, H = 320, 90
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    col = lambda n: P[n] + (255,)

    # Brazos (mangas de la chaqueta) desde abajo hasta las muñecas, con el borde exterior en sombra.
    for s in (-1, 1):
        cx = 160 + s * 118
        d.polygon([(cx - 12, 48 + dy), (cx + 12, 48 + dy), (cx + s * 30 + 24, H), (cx + s * 30 - 24, H)], fill=col("chaqueta"))
        d.polygon([(cx + s * 12, 48 + dy), (cx + s * 6, 48 + dy), (cx + s * 30 + s * 16, H), (cx + s * 30 + s * 24, H)], fill=col("chaqueta_oscura"))
        d.line([(cx + s * 16 - 20, 74), (cx + s * 16 + 20, 74)], fill=col("hueso"), width=2)   # franja reflectiva

    # Tablero con velocímetro (la aguja la dibuja el juego).
    if id_moto == "bws":    # carenado negro de scooter
        d.polygon([(112, H), (208, H), (194, 44), (126, 44)], fill=col("carbon"))
        d.polygon([(126, 44), (194, 44), (191, 48), (129, 48)], fill=col("gris"))
    elif id_moto == "nkd":  # sin carenado: tanque negro abajo y el reloj en su soporte cromado
        d.polygon([(104, H), (216, H), (204, 76), (116, 76)], fill=col("carbon"))
        d.polygon([(126, 78), (194, 78), (190, 81), (130, 81)], fill=col("gris"))
        d.line([(128, 86), (192, 86)], fill=col("rojo"), width=2)
        d.line([(146, 76), (140, 40)], fill=col("cromo_oscuro"), width=3)   # barras de la suspensión
        d.line([(174, 76), (180, 40)], fill=col("cromo_oscuro"), width=3)
        d.rectangle([150, 58, 170, 78], fill=col("cromo_oscuro"))           # soporte del reloj
        d.ellipse([140, 46, 180, 86], fill=col("cromo"))
    else:                   # cúpula verde de deportiva
        d.polygon([(92, H), (228, H), (214, 46), (106, 46)], fill=col("verde_ninja"))
        d.polygon([(106, 46), (214, 46), (211, 50), (109, 50)], fill=col("verde_ninja_oscuro"))
        d.polygon([(92, H), (108, H), (116, 52), (106, 46)], fill=col("verde_ninja_oscuro"))
        d.polygon([(212, H), (228, H), (214, 46), (204, 52)], fill=col("verde_ninja_oscuro"))
        d.line([(108, 45), (122, 30)], fill=col("vidrio_brillo"), width=1)  # filo del parabrisas
        d.line([(212, 45), (198, 30)], fill=col("vidrio_brillo"), width=1)
        d.rounded_rectangle([132, 48, 188, 86], radius=4, fill=col("carbon"))
    d.ellipse([144, 50, 176, 82], fill=col("cromo"))
    d.ellipse([146, 52, 174, 80], fill=col("hueso"))
    for k in range(9):
        a = np.pi * (0.8 + 1.4 * k / 8)
        x0, y0 = 160 + np.cos(a) * 10, 66 + np.sin(a) * 10
        x1, y1 = 160 + np.cos(a) * 13, 66 + np.sin(a) * 13
        d.line([(x0, y0), (x1, y1)], fill=col("negro") if k < 7 else col("rojo"), width=1)
    d.ellipse([180, 60, 190, 70], fill=col("asfalto_oscuro"))              # gasolina
    d.rectangle([183, 63, 187, 66], fill=col("naranja"))
    d.rectangle([130, 62, 138, 67], fill=col("pasto_claro"))               # testigo verde

    # Barra del manubrio en cromo con brillo.
    barra = [(50, 40 + dy), (100, 44 + dy), (160, 41 + dy), (220, 44 + dy), (270, 40 + dy)]
    if id_moto == "ninja":  # semimanubrios: dos tubos que bajan hacia afuera, sin barra en el centro
        barra = [(50, 40 + dy), (100, 42 + dy), (124, 46)]
    d.line(barra, fill=col("cromo_oscuro"), width=6, joint="curve")
    d.line(barra, fill=col("cromo"), width=4, joint="curve")
    d.line([(x, y - 2) for x, y in barra], fill=col("cromo_brillo"), width=1)
    if id_moto == "ninja":
        otra = [(320 - x, y) for x, y in barra]
        d.line(otra, fill=col("cromo_oscuro"), width=6, joint="curve")
        d.line(otra, fill=col("cromo"), width=4, joint="curve")
    if id_moto != "ninja":
        d.rectangle([148, 36 + dy, 172, 48 + dy], fill=col("negro"))       # abrazadera
        d.rectangle([150, 38 + dy, 170, 39 + dy], fill=col("gris"))

    # Espejos redondos, pequeños y bien afuera para no tapar la calle.
    for s in (-1, 1):
        bx = 160 + s * (56 if id_moto == "ninja" else 78)   # la Ninja los lleva en la cúpula
        mx = 160 + s * 102
        d.line([(bx, 42 + dy), (mx, 16)], fill=col("cromo_oscuro"), width=2)
        d.ellipse([mx - 12, 2, mx + 12, 22], fill=col("negro"))
        d.ellipse([mx - 10, 4, mx + 10, 20], fill=col("vidrio"))
        d.ellipse([mx - 8, 5, mx + 4, 13], fill=col("vidrio_brillo"))
        d.ellipse([mx - 6, 7, mx + 1, 11], fill=col("cielo_noche"))

    # Manetas de freno, puños negros y manos con guante agarrando.
    for s in (-1, 1):
        gx = 160 + s * 118
        d.line([(gx - s * 26, 38 + dy), (gx + s * 14, 33 + dy)], fill=col("cromo"), width=2)
        d.rounded_rectangle([gx - 22, 35 + dy, gx + 22, 46 + dy], radius=4, fill=col("negro"))
        for k in range(-20, 22, 3):
            d.point((gx + k, 36 + dy), fill=col("carbon"))
        d.rounded_rectangle([gx - 13, 31 + dy, gx + 13, 50 + dy], radius=6, fill=col("guante"))
        for k in range(4):                                                   # nudillos
            fx = gx - 10 + k * 7
            d.rectangle([fx, 31 + dy, fx + 4, 33 + dy], fill=col("guante_claro"))
            d.line([(fx + 5, 33 + dy), (fx + 5, 48 + dy)], fill=col("negro"), width=1)
        d.ellipse([gx - s * 16 - 6, 34 + dy, gx - s * 16 + 6, 44 + dy], fill=col("guante_claro"))  # pulgar

    a = np.array(im).astype(np.float32)
    guardar(a[..., :3], UI / puesto["archivo"], alfa=a[..., 3] / 255.0, fuerza=8)


def manubrios():
    for id_moto in PUESTOS:
        manubrio(id_moto)


if __name__ == "__main__":
    TEX.mkdir(parents=True, exist_ok=True)
    UI.mkdir(parents=True, exist_ok=True)
    for f in (asfalto, anden, pasto, lineas, cebras, fachada_ladrillo, fachada_concreto, fachada_vidrio, fachada_casa, manubrios, peatones, motos_taller):
        f()
        print("generado:", f.__name__)
