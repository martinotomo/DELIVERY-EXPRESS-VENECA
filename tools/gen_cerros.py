"""Panorama de los cerros orientales de Bogotá para el fondo del cielo.

    python tools/gen_cerros.py

Deja en assets/texturas/:
- cerros.png (1024×160, RGBA): tres filas de cerros vistos desde la ciudad, cielo transparente.
  La de atrás, azulada por la bruma y con los dos picos más altos (uno con su capillita); la del
  medio, verde con quebradas, derrumbes de tierra pelada y una carretera que sube en zigzag; la de
  adelante, monte oscuro con copas de árboles y casitas de los barrios en las faldas.
- cerros_luz.png (mismo tamaño): máscara de emisión para la noche. Negro, salvo las lucecitas de
  las casas en las faldas y la capilla iluminada en el pico.

Es cíclico a lo ancho (el borde izquierdo empalma con el derecho): todo el ruido y las crestas se
calculan con funciones que dan la vuelta. Semilla fija: regenerar da siempre lo mismo.
"""
from pathlib import Path

import numpy as np
from scipy import ndimage

from paleta import PALETA as P
from pixel import BAYER4, guardar

RAIZ = Path(__file__).resolve().parent.parent
TEX = RAIZ / "assets" / "texturas"
W, H = 1024, 160
X = np.arange(W, dtype=np.float32)


def c(nombre, k=1.0):
    return np.array(P[nombre], np.float32) * k


def cresta(rng, alto, rugosidad=1.25, kmax=90, k0=2):
    """Línea de cresta cíclica: suma de senos con frecuencias enteras (dan la vuelta exacta)."""
    y = np.zeros(W, np.float32)
    for k in range(k0, kmax):
        y += (k ** -rugosidad) * np.sin(2 * np.pi * k * X / W + rng.uniform(0, 2 * np.pi))
    return y / np.abs(y).max() * alto


def pico(centro, alto, ancho):
    """Pico en forma de campana que da la vuelta por los bordes."""
    d = (X - centro + W / 2) % W - W / 2
    return alto * np.exp(-(d / ancho) ** 2)


def ruido2d(rng, sy, sx):
    """Ruido suave, cíclico en x (en y no hace falta: la imagen no se repite hacia arriba)."""
    n = rng.standard_normal((H, W)).astype(np.float32)
    n = ndimage.gaussian_filter(n, (sy, sx), mode=("nearest", "wrap"))
    return n / (n.std() + 1e-6)


def bajo(y_cresta):
    """Máscara de lo que queda por debajo de una cresta."""
    return np.arange(H)[:, None] >= y_cresta[None, :]


def cuantizar_capa(rgb, nombres, fuerza):
    """Cuantiza a un subconjunto de la paleta (Bayer 4×4): cada fila de cerros usa solo sus
    colores, para que la bruma no se llene de grises cafés ni el monte de azules."""
    pal = np.array([P[n] for n in nombres], np.float32)
    umbral = np.tile(BAYER4, (H // 4 + 1, W // 4 + 1))[:H, :W, None] * fuerza
    x = np.clip(rgb + umbral, 0, 255)
    d = ((x[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
    return pal[d.argmin(-1)]


def copa(rgb, mascara, cx, cy, r):
    """Copa de árbol redonda con luz arriba a la izquierda: tres tonos, sin ruido."""
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r + r * 0.6:
                continue
            y, x = cy + dy, (cx + dx) % W
            if not 0 <= y < H:
                continue
            luz = -(dx * 0.5 + dy * 0.85) / r
            tono = "pasto" if luz > 0.5 else ("pasto_oscuro" if luz > -0.45 else "monte_oscuro")
            rgb[y, x] = c(tono)
            mascara[y, x] = True


def main():
    rng = np.random.default_rng(301)
    capa = np.zeros((H, W), np.int8)                 # 0 cielo, 1 atrás, 2 medio, 3 adelante
    rgb = np.zeros((H, W, 3), np.float32)
    exacto = np.zeros((H, W), bool)                  # píxeles ya en la paleta (no se traman)
    emi = np.zeros((H, W, 3), np.float32)
    filas = np.arange(H, dtype=np.float32)[:, None]

    def quebradas(sy, sx):
        """Ruido estirado hacia abajo; su pendiente en x da luz (a la izquierda) y sombra."""
        gx = np.gradient(ruido2d(rng, sy, sx), axis=1)
        return -gx / (np.abs(gx).std() + 1e-6)

    # --- crestas ---------------------------------------------------------------------------
    MONSERRATE, GUADALUPE = 300, 610
    y_lejos = 58 + cresta(rng, 18) - pico(MONSERRATE, 44, 34) - pico(GUADALUPE, 32, 48) - pico(860, 12, 60)
    y_lejos = np.maximum(y_lejos, 10)
    y_medio = 92 + cresta(rng, 14, 1.35) - pico(470, 12, 50)
    y_cerca = 126 + cresta(rng, 8, 1.5)
    m_lejos, m_medio = bajo(y_lejos), bajo(y_medio)

    # --- fila de atrás: bruma azulada con quebradas suaves y filo claro -----------------------
    prof = filas - y_lejos[None, :]
    k = 1.0 + quebradas(14, 6) * 0.05 + np.clip(prof / 70, 0, 1) * 0.12   # más bruma abajo
    lejos = c("cerro_lejano")[None, None, :] * k[..., None]
    lejos[prof < 1.5] = c("cerro_bruma")
    capa[m_lejos] = 1
    rgb[m_lejos] = lejos[m_lejos]

    # --- fila del medio: verde con quebradas, monte a manchas, derrumbes y carretera ----------
    prof = filas - y_medio[None, :]
    k = 1.0 + quebradas(12, 4) * 0.12 - np.clip(prof / 60, 0, 1) * 0.12
    medio = c("cerro_medio")[None, None, :] * k[..., None]
    monte = ruido2d(rng, 1.4, 1.8)
    medio[monte > 1.1] = c("pasto_oscuro")
    medio[(monte < -1.3) & (prof > 4)] = c("verde_casa")
    medio[prof < 1] = c("verde_casa")
    ex_m = np.zeros((H, W), bool)
    # Derrumbes: vetas de tierra que nacen finas bajo la cresta y se abren hacia abajo.
    borde = ruido2d(rng, 1.0, 1.0)
    for cx, largo, ancho in ((330, 24, 5), (395, 18, 4), (860, 28, 6)):
        top = y_medio[cx] + 4
        d = (X - cx + W / 2) % W - W / 2
        t = np.clip((filas - top) / largo, 0, 1)
        dentro = (filas >= top) & (filas <= top + largo) & (np.abs(d)[None, :] < 0.8 + ancho * t ** 1.3 + borde * 0.8)
        tierra = np.where(t < 0.4, 1, 0)[..., None] * c("guante_claro") + np.where(t >= 0.4, 1, 0)[..., None] * c("guante")
        tierra = np.where(((np.abs(d)[None, :] < 1) & (t > 0.3))[..., None], c("guante_oscuro"), tierra)
        medio = np.where(dentro[..., None], tierra, medio)
        ex_m |= dentro
    # Carretera en zigzag (la subida al páramo), con la sombra del talud debajo.
    for x0, x1, base, vueltas in ((40, 250, 15, 3), (640, 810, 12, 2)):
        xs = np.arange(x0, x1)
        u = (xs - x0) / (x1 - x0)
        zig = np.abs(((u * vueltas * 2) % 2) - 1)
        ys = np.round(y_medio[xs % W] + base + zig * 13).astype(int)
        for x, y in zip(xs % W, ys):
            if 0 <= y < H - 1:
                medio[y, x] = c("concreto_claro")
                medio[y + 1, x] = c("monte_oscuro")
                ex_m[y:y + 2, x] = True
    capa[m_medio] = 2
    rgb[m_medio] = medio[m_medio]
    exacto |= ex_m & m_medio

    # --- fila de adelante: bosque de copas redondas y barrios en la falda ----------------------
    cerca = np.zeros((H, W), bool)
    rgb_c = np.zeros((H, W, 3), np.float32)
    base = bajo(y_cerca + 3)
    rgb_c[base] = c("monte_oscuro")
    cerca |= base
    BARRIOS = ((90, 70), (520, 110), (800, 55))       # (centro x, ancho): ahí casi no hay árboles

    def en_barrio(x):
        return max(np.exp(-(((x - bx + W / 2) % W - W / 2) / (bw / 2)) ** 2) for bx, bw in BARRIOS)

    # Copas: de arriba abajo, para que las de adelante tapen a las de atrás.
    arboles = []
    for _ in range(2600):
        x = int(rng.integers(0, W))
        y = int(y_cerca[x] + rng.integers(-1, 36) ** 1.0)
        if rng.random() < en_barrio(x) * np.clip((y - y_cerca[x]) / 14, 0, 1):
            continue
        arboles.append((y, x, int(rng.integers(2, 5))))
    for y, x, r in sorted(arboles):
        copa(rgb_c, cerca, x, y, r)
    # Casitas de los barrios: filas escalonadas ladera abajo, casi todas de ladrillo, con techo de
    # zinc o de teja; más apretadas abajo y ralas arriba, donde las alcanza el monte.
    luces = []
    for bx, bw in BARRIOS:
        for y in range(H - 3, 0, -3):
            x = bx - bw
            while x < bx + bw:
                w = int(rng.integers(3, 6))
                xx = x % W
                arriba = y - (y_cerca[xx] + 7)
                dens = np.exp(-((x - bx) / (bw / 2)) ** 2) * np.clip(arriba / 16, 0, 1)
                if arriba > 0 and rng.random() < dens * 1.4:
                    techo = ["concreto", "gris", "ladrillo_oscuro", "gris"][rng.integers(0, 4)]
                    pared = ["ladrillo", "ladrillo", "ladrillo_claro", "ladrillo_oscuro", "hueso"][rng.integers(0, 5)]
                    for dx in range(w):
                        xc = (x + dx) % W
                        rgb_c[y, xc] = c(techo)
                        rgb_c[y + 1:y + 3, xc] = c(pared)
                        cerca[y:y + 3, xc] = True
                        exacto[y:y + 3, xc] = True
                    rgb_c[y + 1:y + 3, (x + w - 1) % W] = c(pared) * 0.72     # costado en sombra
                    vx = (x + int(rng.integers(0, w - 1))) % W
                    rgb_c[y + 2, vx] = c("carbon")
                    if rng.random() < 0.55:
                        luces.append((vx, y + 2))
                x += w + int(rng.integers(0, 3))
    capa[cerca] = 3
    rgb[cerca] = rgb_c[cerca]
    exacto[cerca & (capa == 3)] = True

    # --- capillita en Monserrate: blanca, techo rojo y torre -------------------------------------
    cx = MONSERRATE
    cy = int(np.round(y_lejos[cx - 6:cx + 7].min()))
    for dx in range(-7, 8):                               # la cresta se aplana bajo la capilla
        x = (cx + dx) % W
        for y in range(cy + 1, int(y_lejos[x]) + 2):
            if capa[y, x] <= 1:
                capa[y, x] = 1
                rgb[y, x] = c("cerro_bruma")
    capilla = [
        *[(dx, dy, "hueso") for dx in range(-4, 5) for dy in range(-3, 1)],     # nave
        *[(dx, -4, "ladrillo") for dx in range(-4, 5)],                        # techo
        *[(dx, dy, "blanco") for dx in range(-2, 1) for dy in range(-8, -3)],  # torre
        (-1, -9, "ladrillo"), (-1, -10, "blanco"),
    ]
    for dx, dy, col in capilla:
        y, x = cy + dy, (cx + dx) % W
        rgb[y, x] = c(col)
        capa[y, x] = 1
        exacto[y, x] = True
        emi[y, x] = c("hueso") * 0.9                     # de noche la iluminan con reflectores
    for dx, dy in ((-3, -2), (1, -2), (3, -2), (-1, -6)):
        rgb[cy + dy, cx + dx] = c("carbon")
        emi[cy + dy, cx + dx] = c("ventana_luz")

    # --- luces de noche --------------------------------------------------------------------------
    for x, y in luces:
        emi[y, x] = c("ventana_luz" if rng.random() < 0.6 else "sodio")
    for x0, x1 in ((40, 250), (640, 810)):               # postes de la carretera, uno cada tanto
        for x in range(x0, x1, 23):
            ys = np.nonzero(exacto[:, x % W] & (capa[:, x % W] == 2))[0]
            if len(ys):
                emi[ys[0], x % W] = c("sodio") * 0.8

    # --- cuantizar cada fila con sus colores ---------------------------------------------------
    PAL_CAPA = {
        1: ["cerro_bruma", "cerro_lejano"],
        2: ["verde_casa", "cerro_medio", "pasto_oscuro", "monte_oscuro"],
        3: ["pasto", "pasto_oscuro", "monte_oscuro"],
    }
    final = np.zeros_like(rgb)
    for k, nombres in PAL_CAPA.items():
        q = cuantizar_capa(rgb, nombres, 14 if k < 3 else 6)
        final[capa == k] = q[capa == k]
    final[exacto] = rgb[exacto]
    alfa = (capa > 0).astype(np.float32)

    TEX.mkdir(parents=True, exist_ok=True)
    guardar(final, TEX / "cerros.png", alfa=alfa, fuerza=0)
    guardar(emi, TEX / "cerros_luz.png", fuerza=0)
    print("generado: cerros.png, cerros_luz.png")


if __name__ == "__main__":
    main()
