"""Icono del juego (F7): la caja térmica del logo con su estela, sobre un cuadro de asfalto.

    python tools/gen_icono.py

Deja:
- assets/ui/icono.png   64×64, el dibujo a tamaño nativo (Godot lo usa como icono de la ventana).
- assets/ui/icono.ico   16, 32, 48, 64, 128 y 256 px (vecino más cercano) para el .exe de Windows.

Reutiliza la caja y la estela de tools/gen_logo.py (mismo dibujo, misma paleta), así el icono de la
barra de tareas y el logo del menú se reconocen como la misma cosa.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from gen_logo import Logo, caja_termica, estela, dilatar, c
from paleta import PALETA as P

RAIZ = Path(__file__).resolve().parent.parent
UI = RAIZ / "assets" / "ui"
N = 64
TAMANOS = [16, 32, 48, 64, 128, 256]


def main():
    fondo = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(fondo)
    # Cuadro de asfalto con esquinas recortadas en escalera (sin curvas suaves) y filo claro arriba.
    d.rounded_rectangle([1, 1, N - 2, N - 2], radius=9, fill=P["asfalto"] if "asfalto" in P else P["carbon"])
    d.line([(10, 2), (N - 11, 2)], fill=P["concreto_claro"])
    # Línea amarilla de la vía, cortada.
    for x in range(4, N - 4, 14):
        d.rectangle([x, 50, x + 7, 52], fill=P["amarillo_via"])
    a = np.array(fondo)
    lleno = a[..., 3] > 0
    borde = dilatar(lleno, 1) & ~lleno
    a[borde] = P["negro"] + (255,)

    L = Logo()
    for yy, x0, x1, g, col in ((24, 0, 12, 2, "sodio"), (34, -2, 10, 3, "amarillo_via"), (44, 0, 12, 2, "naranja")):
        estela(L, x0 + 4, x1 + 4, yy, g, col)
    caja_termica(L, 7, 4)
    dibujo = np.array(L.guardar())[:N, :N]
    tapa = dibujo[..., 3] > 0
    a[tapa] = dibujo[tapa]
    icono = Image.fromarray(a, "RGBA")

    UI.mkdir(parents=True, exist_ok=True)
    icono.save(UI / "icono.png")
    grande = icono.resize((256, 256), Image.NEAREST)
    grande.save(UI / "icono.ico", sizes=[(t, t) for t in TAMANOS])
    usados = {tuple(px[:3]) for px in a.reshape(-1, 4) if px[3] > 0}
    fuera = [u for u in usados if u not in {tuple(v) for v in P.values()}]
    print(f"generado: icono.png ({N}×{N}), icono.ico {TAMANOS}; colores fuera de la paleta: {len(fuera)}")


if __name__ == "__main__":
    main()
