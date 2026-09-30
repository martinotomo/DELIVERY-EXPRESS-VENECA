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


# --- manubrio de la BWS, 320×90 px a 1× (se dibuja a 2× sobre la pantalla de 640×360) ---------

def manubrio():
    W, H = 320, 90
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    col = lambda n: P[n] + (255,)

    # Brazos (mangas de la chaqueta) desde abajo hasta las muñecas, con el borde exterior en sombra.
    for s in (-1, 1):
        cx = 160 + s * 118
        d.polygon([(cx - 12, 48), (cx + 12, 48), (cx + s * 30 + 24, H), (cx + s * 30 - 24, H)], fill=col("chaqueta"))
        d.polygon([(cx + s * 12, 48), (cx + s * 6, 48), (cx + s * 30 + s * 16, H), (cx + s * 30 + s * 24, H)], fill=col("chaqueta_oscura"))
        d.line([(cx + s * 16 - 20, 74), (cx + s * 16 + 20, 74)], fill=col("hueso"), width=2)   # franja reflectiva

    # Tablero: carenado negro con velocímetro (la aguja la dibuja el juego).
    d.polygon([(112, H), (208, H), (194, 44), (126, 44)], fill=col("carbon"))
    d.polygon([(126, 44), (194, 44), (191, 48), (129, 48)], fill=col("gris"))
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
    barra = [(50, 40), (100, 44), (160, 41), (220, 44), (270, 40)]
    d.line(barra, fill=col("cromo_oscuro"), width=6, joint="curve")
    d.line(barra, fill=col("cromo"), width=4, joint="curve")
    d.line([(x, y - 2) for x, y in barra], fill=col("cromo_brillo"), width=1)
    d.rectangle([148, 36, 172, 48], fill=col("negro"))                     # abrazadera
    d.rectangle([150, 38, 170, 39], fill=col("gris"))

    # Espejos redondos, pequeños y bien afuera para no tapar la calle.
    for s in (-1, 1):
        bx = 160 + s * 78
        mx = 160 + s * 102
        d.line([(bx, 42), (mx, 16)], fill=col("cromo_oscuro"), width=2)
        d.ellipse([mx - 12, 2, mx + 12, 22], fill=col("negro"))
        d.ellipse([mx - 10, 4, mx + 10, 20], fill=col("vidrio"))
        d.ellipse([mx - 8, 5, mx + 4, 13], fill=col("vidrio_brillo"))
        d.ellipse([mx - 6, 7, mx + 1, 11], fill=col("cielo_noche"))

    # Manetas de freno, puños negros y manos con guante agarrando.
    for s in (-1, 1):
        gx = 160 + s * 118
        d.line([(gx - s * 26, 38), (gx + s * 14, 33)], fill=col("cromo"), width=2)
        d.rounded_rectangle([gx - 22, 35, gx + 22, 46], radius=4, fill=col("negro"))
        for k in range(-20, 22, 3):
            d.point((gx + k, 36), fill=col("carbon"))
        d.rounded_rectangle([gx - 13, 31, gx + 13, 50], radius=6, fill=col("guante"))
        for k in range(4):                                                   # nudillos
            fx = gx - 10 + k * 7
            d.rectangle([fx, 31, fx + 4, 33], fill=col("guante_claro"))
            d.line([(fx + 5, 33), (fx + 5, 48)], fill=col("negro"), width=1)
        d.ellipse([gx - s * 16 - 6, 34, gx - s * 16 + 6, 44], fill=col("guante_claro"))  # pulgar

    a = np.array(im).astype(np.float32)
    guardar(a[..., :3], UI / "manubrio.png", alfa=a[..., 3] / 255.0, fuerza=8)


if __name__ == "__main__":
    TEX.mkdir(parents=True, exist_ok=True)
    UI.mkdir(parents=True, exist_ok=True)
    for f in (asfalto, anden, pasto, lineas, fachada_ladrillo, fachada_concreto, fachada_vidrio, fachada_casa, manubrio):
        f()
        print("generado:", f.__name__)
