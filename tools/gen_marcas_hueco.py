"""Lo que la gente clava en los huecos para avisar (F4, D27): una rama con hojas y un cono.

Como en Bogotá: el hueco casi no se ve desde la moto, la rama sí. Hoja de 2 cuadros de 24×32
(0 = rama, 1 = cono), vistos de frente para usarlos como sprite plano a lo Doom.

    python tools/gen_marcas_hueco.py      # escribe assets/texturas/marcas_hueco.png
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from paleta import PALETA
import pixel

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "assets" / "texturas" / "marcas_hueco.png"
W, H = 24, 32
ESC = 4  # se pinta a 4× con volumen y se reduce


def _contorno(alfa):
    """Borde de 1 px por fuera de la silueta."""
    a = alfa > 0.5
    borde = np.zeros_like(a)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        borde |= np.roll(np.roll(a, dy, 0), dx, 1)
    return borde & ~a


def _reducir(img):
    return img.resize((W, H), Image.NEAREST)


def rama():
    rng = np.random.default_rng(71)
    img = Image.new("RGBA", (W * ESC, H * ESC), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cafe = (104, 70, 44, 255)
    cafe_luz = (150, 108, 70, 255)
    # Palo principal, un poco torcido, clavado abajo al centro.
    pts = [(48, 126), (46, 100), (50, 78), (44, 52), (48, 30)]
    d.line(pts, fill=cafe, width=7)
    d.line([(p[0] - 2, p[1]) for p in pts], fill=cafe_luz, width=2)
    for (x0, y0), (x1, y1) in (((47, 80), (70, 60)), ((45, 58), (24, 40)), ((48, 40), (64, 22))):
        d.line([(x0, y0), (x1, y1)], fill=cafe, width=4)
    # Hojas: manchas verdes con luz arriba a la izquierda.
    for cx, cy, r in ((70, 56, 13), (24, 38, 13), (64, 20, 12), (46, 26, 12), (34, 60, 9), (58, 40, 10)):
        for k in range(40):
            ang = rng.uniform(0, 2 * np.pi)
            rr = r * np.sqrt(rng.uniform(0, 1))
            x, y = cx + rr * np.cos(ang), cy + rr * np.sin(ang)
            luz = (x - cx) * -0.5 + (y - cy) * -0.7
            col = PALETA["pasto_claro"] if luz > 3 else PALETA["pasto"] if luz > -4 else PALETA["pasto_oscuro"]
            d.ellipse((x - 3, y - 2, x + 3, y + 2), fill=tuple(col) + (255,))
    # Tierra del hueco donde está clavada.
    d.ellipse((30, 118, 66, 128), fill=(70, 58, 50, 255))
    return _reducir(img)


def cono():
    img = Image.new("RGBA", (W * ESC, H * ESC), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base_y = 124
    d.rectangle((8, base_y - 8, 88, base_y), fill=tuple(PALETA["naranja"]) + (255,))
    d.rectangle((8, base_y - 8, 88, base_y - 6), fill=(255, 170, 90, 255))
    # Cuerpo: trapecio naranja con dos franjas blancas reflectivas; luz desde la izquierda.
    for y in range(20, base_y - 8):
        t = (y - 20) / (base_y - 28)
        medio = 5 + 29 * t
        for x in range(int(48 - medio), int(48 + medio) + 1):
            u = (x - (48 - medio)) / (2 * medio)
            franja = 0.33 < t < 0.45 or 0.62 < t < 0.74
            if franja:
                col = PALETA["blanco"] if u < 0.6 else PALETA["concreto_claro"]
            else:
                col = (255, 150, 70) if u < 0.3 else PALETA["naranja"] if u < 0.72 else PALETA["rojo"]
            d.point((x, y), fill=tuple(col) + (255,))
    d.ellipse((42, 16, 54, 23), fill=(255, 150, 70, 255))
    return _reducir(img)


def main():
    hoja = Image.new("RGBA", (W * 2, H), (0, 0, 0, 0))
    for k, cuadro in enumerate((rama(), cono())):
        hoja.paste(cuadro, (k * W, 0))
    arr = np.array(hoja).astype(np.float32)
    alfa = arr[:, :, 3] / 255.0
    rgb = arr[:, :, :3]
    borde = _contorno(alfa)
    rgb[borde] = PALETA["negro"]
    alfa = np.where(borde, 1.0, alfa)
    pixel.guardar(rgb, SALIDA, alfa, fuerza=10.0)
    print("generado:", SALIDA.relative_to(RAIZ))


if __name__ == "__main__":
    main()
