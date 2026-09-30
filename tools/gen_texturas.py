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


def fachada_bodega():
    """Bodega industrial de un piso: lámina acanalada con zócalo de concreto pintado, una franja
    amarilla desteñida, cortina metálica enrollable, ventanitas altas con reja y óxido. De noche
    solo se prenden dos ventanitas y el bombillo de sodio encima de la cortina."""
    rng = np.random.default_rng(205)
    # Lámina acanalada: costillas verticales cada 8 px (0,5 m), luz desde la izquierda. Cada
    # columna es un color de la paleta: así la lámina se lee limpia y no como ruido.
    perfil = ["concreto_claro", "concreto", "concreto", "concreto", "gris", "asfalto", "gris", "concreto"]
    img = np.stack([c(perfil[x % 8]) for x in range(128)])[None, :, :].repeat(128, 0)
    emi = np.zeros_like(img)
    mugre = ruido(rng, 128, 128, 6)                                   # lámina sucia, a parches
    img *= 1.0 - np.clip(mugre, 0, None)[..., None] * 0.07
    # Traslapo de las láminas con su fila de remaches.
    img[64, :] = c("asfalto")
    img[65, :] = c("concreto_claro")
    img[62, 2::8] = c("carbon")
    # Franja amarilla pintada, desteñida y descascarada.
    franja = np.zeros((128, 128), bool)
    franja[38:44, :] = True
    pelado = ruido(rng, 128, 128, 2) < -1.0
    img[franja & ~pelado] = img[franja & ~pelado] * 0.25 + c("amarillo_casa") * 0.75
    img[44, :] *= 0.75
    # Zócalo de concreto pintado (1,5 m), con barro salpicado al pie.
    img[104:128, :] = c("concreto_claro") + ruido(rng, 24, 128, 3)[..., None] * 4
    img[104, :] = c("hueso")
    img[105, :] = c("gris")
    barro = (np.linspace(0, 1, 24)[:, None] ** 4) * (ruido(rng, 24, 128, 2) > -0.3)
    img[104:128] = img[104:128] * (1 - 0.5 * barro[..., None]) + c("guante_oscuro") * 0.5 * barro[..., None]
    # Ventanitas altas con reja: solo se prenden dos.
    for k, x in enumerate((6, 38, 70, 102)):
        ventana(img, emi, x, 8, 20, 14, k in (0, 2), rng, marco="gris", reja=True)
        for gx in rng.choice(np.arange(x + 1, x + 19), 2, replace=False):   # chorreones de óxido
            largo = int(rng.integers(5, 14))
            for y in range(24, 24 + largo):
                f = 0.65 * (1 - (y - 24) / largo)
                img[y, gx] = img[y, gx] * (1 - f) + c("ladrillo") * f
    # Cortina metálica enrollable (3,75 m de ancho), con su caja arriba y guías a los lados.
    x0, x1, y0 = 34, 94, 56
    img[y0 - 8:y0, x0 - 4:x1 + 4] = c("cromo_oscuro")
    img[y0 - 8, x0 - 4:x1 + 4] = c("cromo_brillo")
    img[y0 - 7, x0 - 4:x1 + 4] = c("cromo")
    img[y0 - 1, x0 - 4:x1 + 4] = c("carbon")
    img[y0 - 5, x0 - 1:x1 + 1:6] = c("carbon")                        # tornillos de la caja
    for y in range(y0, 121):
        fase = (y - y0) % 4                       # tablillas de 4 px (25 cm) con su pliegue
        img[y, x0:x1] = c(["cromo_oscuro", "cromo_brillo", "cromo", "cromo"][fase])
    img[y0:121, x0:x1] *= 1.0 - np.clip(ruido(rng, 121 - y0, x1 - x0, 5), 0, None)[..., None] * 0.08
    img[y0:128, x0 - 4:x0] = c("carbon")          # guías
    img[y0:128, x1:x1 + 4] = c("carbon")
    img[y0:128, x0 - 3] = c("cromo_oscuro")
    img[y0:128, x1 + 1] = c("cromo_oscuro")
    img[121, x0:x1] = c("cromo_brillo")           # barra de abajo con manija y candado
    img[122:126, x0:x1] = c("cromo_oscuro")
    img[126:128, x0:x1] = c("carbon")
    img[119:124, 62:66] = c("carbon")
    img[120:123, 63:65] = c("amarillo_via")
    # Óxido: manchas al pie de la cortina (lo que le salpica la lluvia) y bajo la caja.
    alto = np.zeros((128, 128), np.float32)
    alto[106:121] = np.linspace(0, 1, 15)[:, None] ** 2
    alto[y0:y0 + 3] = 0.6
    oxido = (ruido(rng, 128, 128, 3) * 0.5 + alto * 1.4 > 1.0) & (alto > 0)
    oxido[:, :x0] = False
    oxido[:, x1:] = False
    img[oxido] = img[oxido] * 0.35 + c("ladrillo") * 0.65
    # Bombillo de sodio con su pantalla, encima de la cortina.
    img[y0 - 13:y0 - 11, 60:68] = c("carbon")
    img[y0 - 11, 61:67] = c("ventana_luz")
    emi[y0 - 11, 61:67] = c("sodio")
    emi[y0 - 10, 62:66] = c("sodio") * 0.6
    guardar(img, TEX / "fachada_bodega.png", fuerza=6)
    guardar(emi, TEX / "fachada_bodega_luz.png", fuerza=0)

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
    {"piel": "piel_clara", "pelo": "carbon", "camisa": "rojo", "pantalon": "carbon", "gorra": "azul_casa"},
    {"piel": "piel", "pelo": "negro", "camisa": "blanco", "pantalon": "azul_casa", "melena": True},
    {"piel": "piel_oscura", "pelo": "negro", "camisa": "naranja", "pantalon": "gris", "bolso": "carbon"},
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


# --- señales de tránsito: 32×32 px cada una (se ven a 0,8 m en un poste) ---------------------------

# Letras y números de 3×5 px para las señales.
LETRAS = {
    "P": ["111", "101", "111", "100", "100"], "A": ["010", "101", "111", "101", "101"],
    "R": ["110", "101", "110", "101", "101"], "E": ["111", "100", "110", "100", "111"],
    "5": ["111", "100", "111", "001", "111"], "0": ["111", "101", "101", "101", "111"],
}


def _letras(d, texto, x, y, escala, color):
    for k, ch in enumerate(texto):
        for fy, fila in enumerate(LETRAS[ch]):
            for fx, bit in enumerate(fila):
                if bit == "1":
                    x0 = x + (k * 4 + fx) * escala
                    d.rectangle([x0, y + fy * escala, x0 + escala - 1, y + (fy + 1) * escala - 1], fill=color)


def senales():
    col = lambda n: P[n] + (255,)
    # PARE: octágono rojo con filo blanco.
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    oct_ = lambda r: [(16 + r * np.cos(np.pi / 8 + k * np.pi / 4), 16 + r * np.sin(np.pi / 8 + k * np.pi / 4)) for k in range(8)]
    d.polygon(oct_(15.8), fill=col("blanco"))
    d.polygon(oct_(13.8), fill=col("rojo"))
    _letras(d, "PARE", 9, 13, 1, col("blanco"))
    # Peatones: rombo amarillo con filo negro y una persona caminando.
    im2 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(im2)
    d2.polygon([(16, 0), (31, 16), (16, 31), (1, 16)], fill=col("negro"))
    d2.polygon([(16, 2), (29, 16), (16, 29), (3, 16)], fill=col("amarillo_via"))
    d2.ellipse([15, 7, 18, 10], fill=col("negro"))
    d2.line([(16, 11), (15, 17)], fill=col("negro"), width=2)
    d2.line([(15, 17), (12, 22)], fill=col("negro"), width=2)
    d2.line([(15, 17), (18, 22)], fill=col("negro"), width=2)
    d2.line([(16, 12), (12, 15)], fill=col("negro"), width=1)
    d2.line([(16, 12), (19, 15)], fill=col("negro"), width=1)
    # Velocidad máxima 50: círculo blanco con aro rojo.
    im3 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d3 = ImageDraw.Draw(im3)
    d3.ellipse([0, 0, 31, 31], fill=col("rojo"))
    d3.ellipse([4, 4, 27, 27], fill=col("blanco"))
    _letras(d3, "50", 9, 11, 2, col("negro"))
    for nombre, img in (("pare", im), ("peatones", im2), ("velocidad", im3)):
        a = np.array(img).astype(np.float32)
        lleno = a[..., 3] > 0
        m = np.pad(lleno, 1)
        borde = (m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~lleno
        rgb = a[..., :3]
        rgb[borde] = c("negro")
        guardar(rgb, TEX / f"senal_{nombre}.png", alfa=(lleno | borde).astype(np.float32), fuerza=0)


# (El puesto de mando de cada moto, lo que se ve al manejar, sale de tools/gen_manubrios.py.)


if __name__ == "__main__":
    TEX.mkdir(parents=True, exist_ok=True)
    UI.mkdir(parents=True, exist_ok=True)
    for f in (asfalto, anden, pasto, lineas, cebras, fachada_ladrillo, fachada_concreto, fachada_vidrio, fachada_casa, fachada_bodega, peatones, senales):
        f()
        print("generado:", f.__name__)
