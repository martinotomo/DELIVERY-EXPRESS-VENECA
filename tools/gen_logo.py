"""Logo del juego: «DELIVERY EXPRESS» en letras de arcade gordas, con volumen y líneas de velocidad.

    python tools/gen_logo.py

Deja:
- assets/ui/logo.png        640×360, fondo transparente (para la interfaz a 640×360).
- assets/ui/logo_1280.png   1280×720, el mismo dibujo al doble (vecino más cercano).
- docs/direccion_visual/logo_preview.png   el logo sobre fondo oscuro, para mirarlo.

Las letras salen de la fuente Press Start 2P (OFL, assets/fuentes/) a 8 px, cada píxel se vuelve un
bloque y el texto se inclina en escalera (cursiva de píxel, sin suavizado). Luego se les pone cara
con degradé cálido por franjas, brillo arriba a la izquierda, fondo extruido hacia abajo a la
derecha y contorno negro. «EXPRESS» va en una cinta roja inclinada, con la caja térmica del
domiciliario (genérica, sin marca) dejando estela de velocidad. Solo colores de tools/paleta.py.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from paleta import PALETA as P
from pixel import BAYER4

RAIZ = Path(__file__).resolve().parent.parent
UI = RAIZ / "assets" / "ui"
DOCS = RAIZ / "docs" / "direccion_visual"
FUENTE = RAIZ / "assets" / "fuentes" / "PressStart2P-Regular.ttf"
W, H = 640, 360
INCLINA = 4          # cursiva: 1 px a la derecha cada 4 px hacia arriba


def c(nombre):
    return np.array(P[nombre], np.float32)


# Letras redibujadas para el logo: la V de la fuente tiene el fondo lleno y, inclinada y con
# volumen, se leía como Y («DELIYERY»). Esta deja abierta la muesca hasta abajo.
PROPIAS = {
    "V": ["XX...XX.",
          "XX...XX.",
          "XX...XX.",
          ".XX.XX..",
          ".XX.XX..",
          "..XXX...",
          "...X...."],
}


def bitmap(texto):
    """El texto en la fuente pixelada a su tamaño nativo (8 px): matriz de 0/1."""
    if texto in PROPIAS:
        return np.array([[c == "X" for c in fila] for fila in PROPIAS[texto]])
    f = ImageFont.truetype(str(FUENTE), 8)
    ancho = f.getbbox(texto)[2]
    im = Image.new("L", (ancho, 8), 0)
    ImageDraw.Draw(im).text((0, 0), texto, font=f, fill=255)
    a = np.array(im) > 127
    return a[: np.nonzero(a.any(1))[0].max() + 1]         # sin la fila vacía de abajo


def bloques(bits, n):
    """Cada píxel de la fuente se vuelve un bloque de n×n."""
    return np.kron(bits.astype(np.uint8), np.ones((n, n), np.uint8)).astype(bool)


def texto_gordo(texto, n, extra=0):
    """El texto con cada píxel hecho bloque de n×n y extra px de aire entre letras (para que el fondo
    extruido de una letra no se monte sobre la siguiente)."""
    letras = [bloques(bitmap(ch), n) for ch in texto]
    alto = max(m.shape[0] for m in letras)
    partes = []
    for m in letras:
        partes += [np.pad(m, ((0, alto - m.shape[0]), (0, 0))), np.zeros((alto, extra), bool)]
    return np.hstack(partes[:-1])


def inclinar(m, paso=INCLINA):
    """Cursiva en escalera: las filas de arriba corren más a la derecha."""
    h, w = m.shape
    extra = (h - 1) // paso
    out = np.zeros((h, w + extra), bool)
    for y in range(h):
        d = (h - 1 - y) // paso
        out[y, d:d + w] = m[y]
    return out


def vecinos(m):
    p = np.pad(m, 1)
    return p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]   # arriba, abajo, izq, der


def dilatar(m, r=1):
    out = m.copy()
    for _ in range(r):
        a, b, i, d = vecinos(out)
        out = out | a | b | i | d
    return out


def franjas(h, paradas, alto_trama=3):
    """Degradé vertical por franjas de color con una costura tramada (Bayer) entre franja y franja.
    paradas: [(fracción donde empieza, color), ...]. Devuelve (h, 1, 3) listo para difundir."""
    col = np.zeros((h, 3), np.float32)
    ys = np.arange(h) / max(h - 1, 1)
    idx = np.zeros(h, int)
    for k, (t, _) in enumerate(paradas):
        idx[ys >= t] = k
    for y in range(h):
        col[y] = c(paradas[idx[y]][1])
    return col, idx


class Logo:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3), np.float32)
        self.a = np.zeros((H, W), bool)

    def poner(self, m, x, y, color):
        """Pinta la máscara m (o una imagen del mismo tamaño) en (x, y)."""
        h, w = m.shape
        zona = (slice(y, y + h), slice(x, x + w))
        col = np.broadcast_to(color, (h, w, 3)) if np.ndim(color) < 3 else color
        self.rgb[zona][m] = col[m]
        self.a[zona] |= m

    def letras(self, gordo, x, y, paradas, fondo, profundo=6):
        """Texto gordo con cara de franjas, brillo, extrusión hacia abajo a la derecha y contorno."""
        cara = inclinar(gordo)
        h, w = cara.shape
        pad = profundo + 3
        lienzo = np.zeros((h + pad * 2, w + pad * 2), bool)
        lienzo[pad:pad + h, pad:pad + w] = cara
        cara = lienzo
        # Extrusión: la cara corrida 1 px en diagonal, una y otra vez.
        cuerpo = np.zeros_like(cara)
        for k in range(1, profundo + 1):
            cuerpo |= np.roll(np.roll(cara, k, 0), k, 1)
        cuerpo &= ~cara
        silueta = cara | cuerpo
        borde = dilatar(silueta, 2) & ~silueta
        hh, ww = cara.shape
        rgb = np.zeros((hh, ww, 3), np.float32)
        rgb[borde] = c("negro")
        # El fondo: más claro pegado a la letra, más oscuro al fondo; filo negro donde se quiebra.
        prof = np.zeros((hh, ww), np.int16)
        for k in range(profundo, 0, -1):
            prof[np.roll(np.roll(cara, k, 0), k, 1)] = k
        rgb[cuerpo] = c(fondo[0])
        rgb[cuerpo & (prof > profundo // 2)] = c(fondo[1])
        # La cara: franjas de arriba abajo, medidas por bloque de la fuente (se ven parejas en todas
        # las letras), con una costura tramada entre franjas.
        col, idx = franjas(gordo.shape[0], paradas)
        trama = np.tile(BAYER4, (hh // 4 + 1, ww // 4 + 1))[:hh, :ww] + 0.5
        ys = np.arange(hh) - pad
        for fy in range(hh):
            if not 0 <= ys[fy] < len(col):
                continue
            fila = cara[fy]
            rgb[fy, fila] = col[ys[fy]]
            # costura: las 2 filas de arriba de cada franja se mezclan con la anterior en trama
            k = idx[ys[fy]]
            if k > 0 and idx[max(ys[fy] - 2, 0)] != k:
                usar = fila & (trama[fy] < 0.5)
                rgb[fy, usar] = c(paradas[k - 1][1])
        # Brillo: filo de arriba y de la izquierda de la cara en claro; filo de abajo en sombra.
        arr, aba, izq, der = vecinos(cara)
        rgb[cara & ~arr] = c("blanco")
        rgb[cara & ~izq & arr] = c(paradas[0][1])
        rgb[cara & ~aba] = c(fondo[0])
        self.poner(silueta | borde, x - pad, y - pad, rgb)
        return w, h

    def guardar(self):
        rgba = np.dstack([self.rgb, self.a * 255.0]).astype(np.uint8)
        rgba[~self.a] = 0
        return Image.fromarray(rgba, "RGBA")


def caja_termica(L, x, y):
    """Caja térmica de domiciliario vista de tres cuartos: frente, costado y tapa, con su franja
    reflectiva, la correa y humito de comida caliente. Sin marca."""
    im = Image.new("RGBA", (64, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    col = lambda n: P[n] + (255,)
    fx0, fy0, fx1, fy1 = 4, 22, 38, 54          # frente
    px, py = 14, 10                             # fondo de la caja: a la derecha y hacia arriba
    d.polygon([(fx0, fy0), (fx0 + px, fy0 - py), (fx1 + px, fy0 - py), (fx1, fy0)], fill=col("chaqueta_clara"))   # tapa
    d.polygon([(fx1, fy0), (fx1 + px, fy0 - py), (fx1 + px, fy1 - py), (fx1, fy1)], fill=col("chaqueta_oscura"))  # costado
    d.rectangle([fx0, fy0, fx1, fy1], fill=col("chaqueta"))                                                       # frente
    d.line([(fx0 + 1, fy0 + 1), (fx1 - 1, fy0 + 1)], fill=col("naranja"))                                          # filo con luz
    d.line([(fx0 + 1, fy0 + 1), (fx0 + 1, fy1 - 1)], fill=col("naranja"))
    d.line([(fx0 + 3, fy0 - 2), (fx0 + px - 1, fy0 - py + 1), (fx1 + px - 3, fy0 - py + 1)], fill=col("ventana_luz"))
    d.line([(fx0 + 2, fy1 - 1), (fx1, fy1 - 1)], fill=col("chaqueta_oscura"))
    # Tapa con su cierre y la manija.
    d.line([(fx0 + px // 2 + 2, fy0 - py // 2), (fx1 + px // 2 - 2, fy0 - py // 2)], fill=col("chaqueta_oscura"))
    d.rectangle([fx0 + 13, fy0 - 7, fx0 + 25, fy0 - 6], fill=col("carbon"))
    # Franja reflectiva que da la vuelta.
    fr0, fr1 = fy0 + 13, fy0 + 18
    d.rectangle([fx0, fr0, fx1, fr1], fill=col("amarillo_via"))
    d.line([(fx0, fr0), (fx1, fr0)], fill=col("ventana_luz"))
    d.polygon([(fx1, fr0), (fx1 + px, fr0 - py), (fx1 + px, fr1 - py), (fx1, fr1)], fill=col("sodio"))
    # Correa de la espalda asomada por el costado.
    d.line([(fx1 + 6, fy0 - 4), (fx1 + 6, fy1 - 4)], fill=col("carbon"), width=2)
    # Humito de comida caliente.
    for hx, hy in ((20, 8), (28, 5), (36, 8)):
        d.line([(hx, hy + 3), (hx + 1, hy + 1), (hx, hy - 1), (hx + 1, hy - 3)], fill=col("hueso"))
    a = np.array(im).astype(np.float32)
    lleno = a[..., 3] > 0
    borde = dilatar(lleno, 2) & ~lleno
    rgb = a[..., :3]
    rgb[borde] = c("negro")
    L.poner(lleno | borde, x, y, rgb)


def estela(L, x0, x1, y, grosor, color):
    """Línea de velocidad: se adelgaza hacia la cola (izquierda), con contorno negro."""
    largo = x1 - x0
    m = np.zeros((grosor + 4, largo + 4), bool)
    for k in range(largo):
        t = k / largo                                 # 0 en la cola, 1 en la punta
        g = max(1, int(round(grosor * min(1.0, 0.25 + t))))
        m[2 + (grosor - g) // 2: 2 + (grosor - g) // 2 + g, 2 + k] = True
    borde = dilatar(m, 1) & ~m
    rgb = np.zeros(m.shape + (3,), np.float32)
    rgb[m] = c(color)
    rgb[borde] = c("negro")
    L.poner(m | borde, x0 - 2, y - 2, rgb)


def cinta(L, x0, y0, x1, y1, n_esp=2):
    """Cinta roja inclinada (paralelogramo con la misma cursiva de las letras) con su sombra."""
    alto = y1 - y0
    corre = alto // INCLINA
    for capa, (dx, dy, col) in enumerate(((5, 5, "rojo_oscuro"), (0, 0, "rojo"))):
        pts = [(x0 + corre + dx, y0 + dy), (x1 + corre + dx, y0 + dy), (x1 + dx, y1 + dy), (x0 + dx, y1 + dy)]
        im = Image.new("L", (W, H), 0)
        ImageDraw.Draw(im).polygon(pts, fill=255)
        m = np.array(im) > 127
        rgb = np.zeros((H, W, 3), np.float32) + c(col)
        if capa == 1:
            arr, aba, izq, der = vecinos(m)
            rgb[m & ~arr] = c("naranja")
            rgb[m & ~arr & np.roll(~arr, 1, 0)] = c("naranja")
            rgb[m & ~aba] = c("rojo_oscuro")
        borde = dilatar(m, 2) & ~m & ~L.a
        L.poner(m, 0, 0, rgb)
        L.poner(borde, 0, 0, np.zeros((H, W, 3), np.float32) + c("negro"))


def nombre_del_juego():
    """El nombre vive solo en project.godot (D14): el logo se dibuja para ese nombre."""
    for linea in (RAIZ / "project.godot").read_text(encoding="utf-8").splitlines():
        if linea.startswith("config/name="):
            return linea.split("=", 1)[1].strip().strip('"')
    return ""


def main():
    nombre = nombre_del_juego()
    if nombre.upper() != "DELIVERY EXPRESS":
        # El dibujo está compuesto a mano para estas dos palabras; con otro nombre hay que rehacerlo.
        raise SystemExit(f"project.godot dice «{nombre}»: el logo está hecho para «Delivery Express». Rehacer main().")
    L = Logo()
    CALIDO = [(0.0, "ventana_luz"), (0.2, "amarillo_via"), (0.45, "sodio"), (0.7, "naranja"), (0.88, "chaqueta_clara")]
    X0, Y0 = 64, 110             # esquina de arriba a la izquierda de DELIVERY
    # Cinta de EXPRESS primero (queda detrás), luego la caja con su estela y encima DELIVERY.
    exp = texto_gordo("EXPRESS", 5, 1)
    xe, ye = X0 + 178, Y0 + 80
    cinta(L, xe - 22, ye - 9, xe + exp.shape[1] + exp.shape[0] // INCLINA + 14, ye + exp.shape[0] + 9)
    for yy, x0, x1, g, col in ((ye + 4, X0 + 40, X0 + 118, 4, "sodio"), (ye + 16, X0 + 4, X0 + 116, 6, "amarillo_via"),
                               (ye + 30, X0 + 52, X0 + 120, 3, "naranja")):
        estela(L, x0, x1, yy, g, col)
    L.letras(exp, xe, ye, [(0.0, "blanco"), (0.55, "hueso")], ("rojo_oscuro", "negro"), profundo=3)
    caja_termica(L, X0 + 108, Y0 + 52)
    # DELIVERY grande arriba.
    L.letras(texto_gordo("DELIVERY", 7, 3), X0, Y0, CALIDO, ("rojo", "rojo_oscuro"), profundo=6)

    img = L.guardar()
    UI.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)
    img.save(UI / "logo.png")
    img.resize((W * 2, H * 2), Image.NEAREST).save(UI / "logo_1280.png")
    fondo = Image.new("RGBA", (W, H), P["cielo_noche"] + (255,))
    fondo.alpha_composite(img)
    fondo.convert("RGB").resize((W * 2, H * 2), Image.NEAREST).save(DOCS / "logo_preview.png")
    caja = np.argwhere(np.array(img)[..., 3] > 0)
    (y0, x0), (y1, x1) = caja.min(0), caja.max(0)
    print(f"generado: logo.png, logo_1280.png, logo_preview.png  (logo {x1 - x0 + 1}×{y1 - y0 + 1} px en {x0},{y0})")


if __name__ == "__main__":
    main()
