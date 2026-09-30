"""Cinemática del choque (D9): la escena ilustrada que sale después de irse de lado en la curva.

    python tools/gen_cinematica.py

Deja assets/ui/cinematica_bws.png, cinematica_nkd.png y cinematica_ninja.png (320×180, opacas,
en la paleta del juego). Recrea la composición del meme (el domiciliario tirado en el andén junto
a su moto caída) con dibujo propio y a lo caricatura: sin sangre. El remate («Has muerto al entrar
demasiado rápido en la curva…») lo escribe el juego encima, en una franja oscura abajo, así que la
imagen no lleva texto y deja tranquilos los ~40 px de arriba y de abajo.

Cómo se hace:
  * El fondo (fachadas de ladrillo bogotano, la persiana del local, el andén, el sardinel y el
    asfalto con la línea amarilla) se pinta píxel a píxel a 1× con una perspectiva sencilla: la
    cámara está en la calle a 1,2 m de alto y mira de frente a la fachada; lo que se aleja
    (juntas del andén, la calle de la esquina) fuga hacia un punto a la derecha. Es el atardecer:
    cielo azul, luz ambiente azulada y el poste de sodio de la izquierda que ya alumbra el andén.
  * La moto es la del taller (assets/ui/motos_taller.png), volteada con las ruedas al aire: se
    agranda 4× sin suavizar, se gira, se reduce tomando el píxel del centro y se le repone el
    contorno negro.
  * El domiciliario, la caja térmica, la comida regada, las piezas sueltas, el polvo y las
    estrellitas se pintan a 4× con el mismo pintor de los puestos de mando (Lienzo de
    tools/gen_manubrios.py: volumen, luz de arriba a la izquierda y filo oscuro), se reducen y
    se les pone contorno.
  * Al final todo pasa por la paleta (tools/paleta.py). Semillas fijas: siempre sale igual.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import gen_manubrios as GM
from paleta import PALETA as P
from pixel import cuantizar

RAIZ = Path(__file__).resolve().parent.parent
UI = RAIZ / "assets" / "ui"
W, H = 320, 180
S = GM.S                        # el pintor trabaja a 4×

# Perspectiva: cámara a CAM_H m de alto, horizonte en HOR y punto de fuga en VPX (fuera de la
# fachada, a la derecha, hacia la calle de la esquina). F = distancia focal en píxeles.
HOR, VPX, F, CAM_H = 62.0, 300.0, 173.0, 1.22
Z_MURO, Z_BORDE = 6.19, 3.19    # profundidad de la fachada y del borde del sardinel (m)
Y_MURO = HOR + F * CAM_H / Z_MURO      # ≈ 96: pie de la fachada
Y_BORDE = HOR + F * CAM_H / Z_BORDE    # ≈ 128: borde del sardinel
X_ESQUINA = 262                  # donde acaba la fachada (la esquina)
X_POSTE = 12                     # poste de la luz de sodio

MOTOS = {  # cuadro en la hoja, giro, escala, centro y piso, color de la carenaza suelta y rueda al aire
    "bws": {"cuadro": 0, "giro": 162, "escala": 0.70, "pos": (242, 126), "panel": "azul_bwis", "rueda": (17, 13, 17)},
    "nkd": {"cuadro": 1, "giro": 166, "escala": 0.66, "pos": (242, 126), "panel": "cromo", "rueda": (16, 13, 17)},
    "ninja": {"cuadro": 2, "giro": 164, "escala": 0.68, "pos": (242, 126), "panel": "verde_ninja", "rueda": (15, 12, 16)},
}


def c(nombre, k=1.0):
    return np.array(P[nombre], np.float32) * k


def proy(X, z, Y=0.0):
    return VPX + F * X / z, HOR + F * (CAM_H - Y) / z


# ---------------------------------------------------------------------------------------------
# Pintor a 4× del tamaño de la escena (el de gen_manubrios es de 320×96).

class Capa(GM.Lienzo):
    def __init__(self):
        self.rgb = np.zeros((H * S, W * S, 3), np.float32)
        self.a = np.zeros((H * S, W * S), np.float32)
        self.semi = np.zeros((H * S, W * S), bool)

    def _mask(self, dibujar):
        im = Image.new("L", (W * S, H * S), 0)
        dibujar(ImageDraw.Draw(im))
        return np.array(im) > 127

    def estrella(self, cx, cy, r):
        pts = []
        for k in range(10):
            a = -np.pi / 2 + k * np.pi / 5
            rr = r if k % 2 == 0 else r * 0.45
            pts.append((cx + np.cos(a) * rr, cy + np.sin(a) * rr))
        return self.poly(pts)

    def reducir(self):
        """Pasa a 1×: color, cobertura y contorno negro alrededor de lo pintado."""
        a = self.a.reshape(H, S, W, S).mean(axis=(1, 3))
        pre = (self.rgb * self.a[..., None]).reshape(H, S, W, S, 3).mean(axis=(1, 3))
        rgb = pre / np.maximum(a, 1e-6)[..., None]
        umbral = np.tile(GM.BAYER4, (H // 4 + 1, W // 4 + 1))[:H, :W] + 0.5
        semi = self.semi.reshape(H, S, W, S).mean(axis=(1, 3)) > 0.5
        lleno = a > np.where(semi, umbral * 0.98 + 0.01, 0.5)
        m = np.pad(lleno & ~semi, 1)
        borde = (m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~lleno & ~semi
        rgb[borde] = P["negro"]
        return rgb, lleno | borde


# ---------------------------------------------------------------------------------------------
# Fondo a 1×

def ruido(rng, forma, sigma=0.0):
    n = rng.standard_normal(forma).astype(np.float32)
    if sigma:
        n = ndimage.gaussian_filter(n, sigma)
        n /= n.std() + 1e-6
    return n


def ladrillos(img, x0, x1, y0, y1, rng, oscuro=1.0):
    """Muro de ladrillo a la vista: hiladas de 2 px con 1 px de mortero, ladrillos de 7 px,
    trabados. Cada ladrillo con su tono (los hay más cocidos y más pálidos)."""
    tonos = [c("ladrillo"), c("ladrillo"), c("ladrillo_claro"), c("ladrillo_oscuro"), c("ladrillo", 0.9)]
    for y in range(y0, y1):
        fila = (y - y0) // 3
        if (y - y0) % 3 == 2:
            img[y, x0:x1] = c("mortero", 0.62 * oscuro)
            continue
        desfase = 4 if fila % 2 else 0
        for x in range(x0, x1):
            k = (x + desfase) // 8
            if (x + desfase) % 8 == 7:
                img[y, x] = c("mortero", 0.6 * oscuro)
                continue
            r = np.random.default_rng(k * 7919 + fila * 104729).integers(len(tonos))
            col = tonos[r] * oscuro
            if (y - y0) % 3 == 0:
                col = col * 1.08          # la arista de arriba del ladrillo coge luz
            img[y, x] = col


def fondo(rng):
    img = np.zeros((H, W, 3), np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

    # cielo del atardecer (solo se ve por la calle de la esquina): azul arriba, tibio en el horizonte
    t = np.clip(yy / HOR, 0, 1)[..., None]
    cielo = c("cielo_noche") * (1 - t) + c("azul_casa") * t
    tibio = np.clip((yy - (HOR - 16)) / 16, 0, 1)[..., None]
    img[:] = cielo * (1 - tibio * 0.6) + c("chaqueta_clara", 0.85) * tibio * 0.6

    # suelo: cada píxel bajo el horizonte se proyecta a la calle para saber qué hay ahí
    z = F * CAM_H / np.maximum(yy - HOR, 0.01)
    X = (xx - VPX) * z / F
    suelo = yy > HOR + 0.5
    x_bordillo_esq = 1.64                                   # sardinel de la calle de la esquina
    anden = suelo & (z >= Z_BORDE) & (X < x_bordillo_esq)
    via = suelo & ~anden

    # asfalto: grano fino, más oscuro abajo y con parches reparados
    g = ruido(rng, (H, W), 0.6)
    parche = ruido(rng, (H, W), 6.0)
    asf = c("asfalto")[None, None, :] * (1.0 + 0.05 * g[..., None] - 0.06 * (parche[..., None] > 0.9))
    img[via] = asf[via]
    # línea amarilla doble, gastada
    for zc in (1.95, 2.08):
        yl = HOR + F * CAM_H / zc
        banda = (np.abs(yy - yl) < 0.9) & via
        gasta = ruido(rng, (H, W), 1.2) > -0.9
        img[banda & gasta] = c("amarillo_via", 0.85)[None, :] * (1 + 0.04 * g[banda & gasta, None])
    # andén: baldosas de 0,6 m (juntas que fugan al punto de la derecha) y manchas
    bx = np.mod(X, 0.6) < 0.035 * z / 3
    bz = np.mod(z - Z_BORDE, 0.6) < 0.02 * z
    mancha = ruido(rng, (H, W), 3.0)
    base = c("concreto")[None, None, :] * (1.0 + 0.035 * g[..., None] - 0.05 * (mancha[..., None] > 1.1))
    base = np.where((bx | bz)[..., None], c("gris")[None, None, :], base)
    img[anden] = base[anden]
    # sardinel: arista de arriba clara, cara de concreto en sombra y la cuneta oscura
    for y in range(int(Y_BORDE), int(Y_BORDE) + 7):
        k = y - int(Y_BORDE)
        col = c("concreto_claro") if k < 2 else c("gris") if k < 6 else c("asfalto_oscuro")
        img[y, :] = col * (1 + 0.03 * g[y, :, None])
    for x in range(0, W, 23):                              # juntas del sardinel
        img[int(Y_BORDE):int(Y_BORDE) + 6, x] = c("asfalto")

    # --- fachadas ---
    y_m = int(round(Y_MURO))
    ladrillos(img, 0, 124, 0, y_m, rng)
    ladrillos(img, 124, X_ESQUINA, 0, y_m, rng, oscuro=0.95)
    # losa del segundo piso con su sombra (casas bogotanas)
    img[19:24, 0:X_ESQUINA] = c("concreto") * (1 + 0.03 * g[19:24, :X_ESQUINA, None])
    img[19, 0:X_ESQUINA] = c("concreto_claro")
    img[24:27, 0:X_ESQUINA] *= 0.62
    # ventana del segundo piso (oscura, refleja el cielo) y una con luz
    for (x0, x1, luz) in ((18, 52, False), (150, 190, True), (210, 246, False)):
        img[4:17, x0 - 2:x1 + 2] = c("concreto")
        img[16:18, x0 - 3:x1 + 3] = c("concreto_claro")
        vid = c("ventana_luz") if luz else c("vidrio_oscuro")
        img[5:16, x0:x1] = vid
        if luz:
            img[5:16, x0:x1] = c("sodio") * np.linspace(1.0, 0.85, 11)[:, None, None]
            img[5:16, x0 + 3:x0 + 12] = c("chaqueta_oscura")          # cortina
        else:
            img[6:9, x0 + 2:x1 - 6] = c("vidrio")
        for xb in range(x0, x1, 9):
            img[5:16, xb] = c("carbon")
        img[10, x0:x1] = c("carbon")

    # casa de la izquierda: ventana con reja y luz adentro, puerta metálica verde
    img[40:76, 12:56] = c("concreto")
    img[40, 12:56] = c("concreto_claro")
    img[74:77, 10:58] = c("concreto_claro")
    img[77:79, 10:58] = c("mortero", 0.5)
    tv = np.linspace(0, 1, 32)[:, None, None]
    img[42:74, 15:53] = c("ventana_luz") * (1 - tv) + c("sodio") * tv
    img[42:74, 15:26] = c("rojo_oscuro")                          # cortina recogida
    img[42:74, 26] = c("chaqueta_oscura")
    img[62:74, 34:46] = c("chaqueta_oscura", 0.8)                  # silueta de una matera
    for xb in range(17, 53, 5):
        img[42:74, xb] = c("negro")
    for yb in (44, 58, 72):
        img[yb, 15:53] = c("negro")
    img[34:y_m, 70:98] = c("concreto")
    img[34, 70:98] = c("concreto_claro")
    img[36:y_m, 73:95] = c("verde_casa", 0.8)
    for (a0, a1) in ((40, 62), (66, 92)):
        img[a0:a1, 76:92] = c("verde_casa", 0.95)
        img[a0, 76:92] = c("verde_casa", 1.2)
        img[a1 - 1, 76:92] = c("verde_casa", 0.55)
        img[a0:a1, 91] = c("verde_casa", 0.55)
    img[64:67, 90:93] = c("cromo")
    img[36:y_m, 73] = c("verde_casa", 1.15)

    # local de la derecha: letrero pintado sin letras y persiana metálica cerrada
    img[28:34, 128:X_ESQUINA - 8] = c("concreto")
    img[28, 128:X_ESQUINA - 8] = c("concreto_claro")
    img[33:35, 128:X_ESQUINA - 8] = c("mortero", 0.45)
    img[29:33, 132:X_ESQUINA - 12] = c("amarillo_casa")
    img[29:33, 150:170] = c("rojo")
    img[29:33, 222:236] = c("azul_casa")
    for y in range(35, y_m):
        k = (y - 35) % 4
        tono = (1.12, 1.0, 0.86, 0.55)[k]
        img[y, 134:X_ESQUINA - 14] = c("cromo", 0.78) * tono * (1 + 0.03 * g[y, 134:X_ESQUINA - 14, None])
    img[35:y_m, 132:134] = c("carbon")
    img[35:y_m, X_ESQUINA - 14:X_ESQUINA - 12] = c("carbon")
    img[y_m - 5:y_m - 3, 180:204] = c("cromo")                   # manija y candado
    img[y_m - 3:y_m - 1, 190:194] = c("amarillo_casa", 0.8)
    # grafiti borroso en la persiana (manchas de color, sin letras)
    graf = (np.abs(ruido(rng, (H, W), 2.5)) > 1.4) & (yy > 50) & (yy < 80) & (xx > 150) & (xx < 196)
    img[graf] = c("verde_casa", 1.1)

    # esquina del edificio y su muro lateral en sombra que fuga a la derecha
    for x in range(X_ESQUINA, 286):
        zz = F * 1.36 / (VPX - x)
        ytop = HOR - F * (7.0 - CAM_H) / zz
        ybot = HOR + F * CAM_H / zz
        y0, y1 = int(max(ytop, 0)), int(ybot)
        for y in range(y0, y1):
            fila = int((y - ybot) * zz / 0.075)
            col = c("ladrillo_oscuro") if fila % 3 else c("mortero", 0.4)
            img[y, x] = col * 0.9
    img[0:y_m, X_ESQUINA] = c("ladrillo_claro")               # arista de la esquina con luz
    # la calle de la esquina: fachadas que se alejan hasta el punto de fuga, con ventanas encendidas
    alturas = [9.0, 6.5, 8.0, 11.0, 6.0, 7.5, 9.5, 6.0]
    colores = ["azul_casa", "amarillo_casa", "ladrillo", "verde_casa", "concreto", "ladrillo", "azul_casa", "concreto"]
    for x in range(286, int(VPX)):
        zz = F * 1.36 / (VPX - x)
        tramo = int((zz - 16) / 7)
        alto = alturas[tramo % len(alturas)]
        ytop = HOR - F * (alto - CAM_H) / zz
        ybot = HOR + F * CAM_H / zz
        niebla = np.clip((zz - 16) / 90, 0, 0.7)
        base = c(colores[tramo % len(colores)], 0.55) * (1 - niebla) + c("vidrio", 1.0) * niebla
        for y in range(int(max(ytop, 0)), int(ybot) + 1):
            img[y, x] = base
            piso = ((HOR - y) * zz / F + CAM_H)
            if 1.0 < piso % 2.8 < 2.2 and (zz % 3.0) < 1.6 and piso < alto - 0.5:
                if (tramo * 3 + int(piso / 2.8)) % 3:
                    img[y, x] = c("ventana_luz") * (1 - niebla * 0.5)
    # al otro lado de la calle, fachadas lejanas pegadas al horizonte
    for x in range(int(VPX), W):
        zz = F * 12.6 / max(x - VPX, 0.5)
        ytop = HOR - F * (8.0 - CAM_H) / zz
        img[int(ytop):int(HOR) + 1, x] = c("vidrio_oscuro")
        if x % 4 == 1:
            img[int(ytop) + 2, x] = c("ventana_luz")
    # postes de sodio a lo lejos por la calle de la esquina
    for zz in (22, 34, 50):
        px, py = proy(-0.9, zz, 5.5)
        img[int(py), int(px)] = c("ventana_luz")

    # --- luz: ambiente azulado del atardecer, el poste de sodio y oscurecer arriba y abajo ---
    amb = np.array([0.74, 0.78, 0.95], np.float32)
    charco = np.exp(-(((xx - 70) / 95) ** 2 + ((yy - 112) / 42) ** 2))           # charco de luz
    haz = np.exp(-(((xx - 30 - (yy * 0.2)) / 60) ** 2)) * np.clip(yy / 110, 0, 1)   # luz que cae
    en_suelo = (yy > Y_MURO - 1).astype(np.float32)
    luz = charco * (0.45 * en_suelo + 0.25) + haz * 0.12
    arriba = np.clip(0.55 + 0.45 * yy / 50, 0.55, 1.0)
    abajo = np.clip(1.0 - (yy - 140) / 70, 0.5, 1.0)
    osc = (arriba * abajo)[..., None]
    img = img * amb * osc * (1 - 0.25 * luz[..., None]) + c("sodio")[None, None, :] * luz[..., None] * 0.55 * osc
    return img, anden, via


def marcas_derrape(img, rng):
    """Dos rayas negras de llanta que vienen de la calle, abajo a la derecha, y se suben al sardinel."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    lienzo = Image.new("L", (W * 4, H * 4), 0)
    d = ImageDraw.Draw(lienzo)
    for off in (0.0, 7.0):
        pts = []
        for t in np.linspace(0, 1, 40):
            x = 318 - 120 * t - off * (1 - t) * 0.6
            y = 176 - 44 * t ** 0.8 - off * (1 - t)
            y += 6 * np.sin(t * 7) * (1 - t) * 0.5          # se va culebreando
            pts.append((x * 4, y * 4))
        for i in range(len(pts) - 1):
            ancho = int(4 + 7 * (1 - i / len(pts)))
            d.line([pts[i], pts[i + 1]], fill=255, width=ancho)
    m = np.array(lienzo.resize((W, H), Image.BILINEAR), np.float32) / 255.0
    m *= np.clip(ruido(rng, (H, W), 0.7) * 0.25 + 0.95, 0, 1)
    img *= (1 - 0.62 * np.clip(m * 1.3, 0, 1))[..., None]
    # raspón en la arista del sardinel donde pegó la moto
    img[int(Y_BORDE):int(Y_BORDE) + 3, 196:214] *= 0.6
    return img


def sombra(img, cx, cy, rx, ry, k=0.5):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    img *= (1 - k * np.clip(1.2 - d, 0, 1).clip(0, 1) ** 0.7)[..., None]


# ---------------------------------------------------------------------------------------------
# La moto del taller, patas arriba

def moto_volteada(clave):
    d = MOTOS[clave]
    hoja = Image.open(UI / "motos_taller.png").convert("RGBA")
    cuadro = hoja.crop((d["cuadro"] * 128, 0, d["cuadro"] * 128 + 128, 96))
    grande = cuadro.resize((128 * 4, 96 * 4), Image.NEAREST).rotate(d["giro"], Image.NEAREST, expand=True)
    w, h = grande.size
    fw, fh = int(w / 4 * d["escala"]), int(h / 4 * d["escala"])
    # se reduce tomando el píxel del centro de cada celda: sin mezclar colores
    a = np.array(grande)
    ys = ((np.arange(fh) + 0.5) * h / fh).astype(int)
    xs = ((np.arange(fw) + 0.5) * w / fw).astype(int)
    a = a[ys][:, xs].copy()
    lleno = a[..., 3] > 127
    # se quitan píxeles sueltos que deja el giro y se repone el contorno
    lleno = ndimage.binary_opening(lleno, np.ones((2, 2))) | (lleno & ndimage.binary_erosion(lleno))
    m = np.pad(lleno, 1)
    borde = (m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~lleno
    a[borde, :3] = P["negro"]
    a[..., 3] = ((lleno | borde) * 255).astype(np.uint8)
    ys, xs = np.nonzero(a[..., 3])
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# ---------------------------------------------------------------------------------------------
# El domiciliario, la caja y el reguero

def domiciliario(L):
    """Tirado boca abajo a lo estrella de mar (brazos y piernas abiertos), con el casco puesto y un
    tenis volado. Se ve un poco desde arriba para que se lea la pose."""
    chaq, chaq_o, chaq_c = c("chaqueta"), c("chaqueta_oscura"), c("chaqueta_clara")
    jean, jean_o = c("azul_casa", 0.95), c("azul_casa", 0.72)
    # brazo de atrás: estirado hacia arriba, más allá del casco
    L.pieza(L.tubo([(84, 104), (70, 100), (54, 101)], 7), chaq * 0.92, bisel=3, luz=0.7, grad=0.2)
    L.plano(L.tubo([(73, 101), (69, 100)], 2.6), c("hueso", 0.9))
    L.plano(L.tubo([(57, 101), (53.5, 101)], 3.4), c("carbon"))                       # puño de la manga
    L.pieza(L.elipse(48, 101, 4.8, 3.4), c("guante"), bisel=2, luz=0.75, brillo=0.12)
    for k in range(4):
        L.pieza(L.caja(40.5, 98 + k * 1.6, 45, 99.4 + k * 1.6, r=0.7), c("guante"), bisel=0.7, luz=0.6)
    # pierna de atrás: abierta hacia arriba a la derecha, con el tenis (se le ve la suela)
    L.pieza(L.tubo([(120, 106), (134, 99), (148, 95)], 9), jean_o * 1.1, bisel=3.5, luz=0.7, grad=0.2)
    L.plano(L.tubo([(128, 103.5), (138, 98)], 0.8), jean * 1.2)
    L.pieza(L.caja(147, 88.5, 160, 97.5, r=4), c("blanco"), bisel=2.5, luz=0.55, grad=0.2)
    L.plano(L.caja(149, 95.5, 158.5, 97), c("gris"))
    L.plano(L.caja(158.2, 90, 160.2, 96.5, r=1), c("rojo"))
    # cadera y nalgas (cayó de bruces y quedaron un poco levantadas)
    L.pieza(L.elipse(119, 111, 11.5, 9.5), jean, bisel=5.5, luz=0.85, grad=0.3, brillo=0.12)
    L.plano(L.tubo([(119, 102.5), (119.5, 119)], 0.8), jean_o)
    # pierna de adelante: la rodilla doblada hacia afuera y el pie sin tenis (media blanca)
    L.pieza(L.tubo([(122, 117), (134, 128), (148, 126)], 9.5), jean, bisel=4, luz=0.8, grad=0.25, brillo=0.08)
    L.plano(L.tubo([(126, 121), (133, 126.5)], 0.8), jean * 1.25)
    L.pieza(L.elipse(153, 125, 5.5, 3.6), c("blanco"), bisel=2, luz=0.6)
    L.plano(L.caja(147, 122.5, 148.8, 127.5), c("gris"))
    # torso con la chaqueta: hombros anchos, cintura más angosta
    torso = L.poly([(76, 106), (80, 101), (90, 99.5), (104, 101), (116, 104), (121, 110), (118, 118),
                    (104, 122), (90, 123.5), (80, 121.5), (75, 116)])
    L.pieza(torso, chaq, bisel=7, luz=0.85, grad=0.35, brillo=0.14)
    # franja reflectiva que da la vuelta al pecho, pliegues y el cuello
    fr = L.poly([(95, 98), (100, 98), (101.5, 125), (96.5, 125)]) & torso
    L.pieza(fr, c("hueso"), bisel=1.4, luz=0.6, grad=0.35, linea=False)
    L.plano(L.tubo([(104, 106), (114, 108.5)], 0.9) & torso, chaq_o)
    L.plano(L.tubo([(84, 104), (93, 102.5)], 0.9) & torso, chaq_c)
    L.plano(L.tubo([(106, 116), (115, 114)], 0.9) & torso, chaq_o)
    # brazo de adelante: el codo hacia afuera y la mano abierta sobre el sardinel
    L.pieza(L.tubo([(84, 118), (80, 127), (70, 130)], 7.5), chaq, bisel=3, luz=0.8, grad=0.25, brillo=0.1)
    L.plano(L.tubo([(81, 123), (79, 127)], 2.6), c("hueso"))
    L.plano(L.tubo([(73, 129.5), (69.5, 130.5)], 3.4), c("carbon"))
    L.pieza(L.elipse(64, 130.5, 5, 3.4), c("guante"), bisel=2, luz=0.75, brillo=0.12)
    for k in range(4):
        L.pieza(L.caja(56.5, 127.6 + k * 1.6, 61, 129 + k * 1.6, r=0.7), c("guante"), bisel=0.7, luz=0.6)
    # casco: cáscara negra brillante con su franja; la visera da contra el piso
    L.pieza(L.elipse(66, 111, 11, 10), c("carbon"), bisel=6, luz=0.95, grad=0.3, brillo=0.32)
    L.pieza(L.poly([(56, 115), (62, 120.5), (71, 120.5), (66, 117), (59, 112)]), c("vidrio_oscuro"), bisel=1.5, luz=0.9, brillo=0.3)
    franja = L.tubo([(68, 101), (63.5, 110), (66, 120.5)], 3.0) & L.elipse(66, 111, 10.6, 9.6)
    L.pieza(franja, chaq_c, bisel=1, luz=0.4, linea=False)
    L.plano(L.elipse(61.5, 105.5, 2.6, 1.5), c("blanco"))                  # brillo del casco
    L.plano(L.elipse(58.8, 108.5, 0.9, 0.9), c("cromo_brillo"))


def caja_termica(L):
    """Maleta térmica cuadrada que salió volando: quedó de lado contra la pared, con la tapa
    abierta, el forro plateado y el pedido regándose."""
    nar, nar_o = c("naranja"), c("chaqueta", 0.95)
    ox, oy = 164, 82
    p = lambda pts: L.poly([(ox + x, oy + y) for x, y in pts])  # noqa: E731
    L.pieza(p([(20, 2), (26, -2), (27, 16), (21, 20)]), nar_o, bisel=2, luz=0.5)                # cara de lado
    L.pieza(p([(0, 3), (6, -1.5), (26, -2), (20, 2)]), c("chaqueta_clara"), bisel=1.5, luz=0.6)  # arriba
    L.pieza(p([(0, 3), (20, 2), (21, 20), (1, 21)]), nar, bisel=2.5, luz=0.75, grad=0.3, brillo=0.12)
    L.plano(p([(0.5, 13), (20.4, 12), (20.5, 14.2), (0.7, 15.2)]), c("hueso"))                    # franja reflectiva
    # la boca, abierta hacia la derecha: se ve el forro plateado
    L.pieza(p([(22, 2), (33, 6), (34, 22), (23, 19)]), c("cromo_oscuro"), bisel=2, luz=-0.4, grad=-0.2)
    L.pieza(p([(23.5, 4), (31.5, 7.5), (32, 19.5), (24, 17.5)]), c("cromo"), bisel=2, luz=-0.6, brillo=0.1)
    # tapa abierta, caída al piso
    L.pieza(p([(-15, 22), (0, 21.5), (3, 25.5), (-12, 26.5)]), nar, bisel=1.5, luz=0.7, grad=0.25)
    L.plano(L.tubo([(ox - 13, oy + 23.2), (ox - 1, oy + 22.8)], 1.0), c("chaqueta_clara"))
    L.plano(L.tubo([(ox - 11.5, oy + 26), (ox + 2.5, oy + 25.2)], 0.9), c("chaqueta_oscura"))


def comida(L):
    """El pedido regado: papas en su caja volcada, una arepa que se fue rodando hasta el poste y
    una gaseosa rumbo a la calle."""
    # papas: caja roja volcada saliendo de la maleta y papitas regadas por el andén
    L.pieza(L.poly([(196, 103), (206, 99), (210, 106), (201, 110)]), c("rojo"), bisel=2, luz=0.75, brillo=0.15)
    L.plano(L.poly([(197.5, 104), (205, 100.8), (206.3, 102.6), (199, 105.8)]), c("hueso"))
    for (x, y, a) in ((192, 110, 0.5), (186, 114, -0.4), (199, 114, 0.9), (180, 110, -0.1), (206, 112, 0.2),
                      (190, 118, -0.8), (176, 116, 1.2), (198, 119, 0.1)):
        dx, dy = np.cos(a) * 2.6, np.sin(a) * 2.6
        L.pieza(L.tubo([(x - dx, y - dy), (x + dx, y + dy)], 2.3), c("ventana_luz"), bisel=1.0, luz=0.7, linea=False)
    # arepa de canto que se fue rodando hasta el poste (con las marcas de la parrilla)
    L.pieza(L.elipse(26, 119, 6.5, 5.5), c("amarillo_casa"), bisel=2.6, luz=0.8, grad=0.25, brillo=0.18)
    for k in (-2.5, 0, 2.5):
        L.plano(L.tubo([(23 + k, 116), (26.5 + k, 122)], 0.9), c("guante"))
    L.plano(L.elipse(23.5, 116.5, 1.8, 1.0), c("hueso"))
    for dy in (-2, 0.5, 3):
        L.plano(L.tubo([(34 + abs(dy), 119 + dy), (42, 119 + dy)], 0.8), c("hueso"))
    # gaseosa rodando hacia el sardinel, con rayitas de movimiento
    L.pieza(L.caja(170, 121, 181, 127.5, r=3), c("rojo"), bisel=2, luz=0.8, grad=0.3, brillo=0.28)
    L.cromo(L.elipse(181, 124.25, 1.8, 3.2))
    L.plano(L.caja(173, 123.3, 178, 124.5), c("blanco"))
    for dy in (-1.8, 1.8):
        L.plano(L.tubo([(161 + abs(dy), 124 + dy), (167, 124 + dy)], 0.8), c("hueso"))
    # el tenis que se le voló, allá contra la pared
    L.pieza(L.caja(118, 90, 130, 97, r=3.5), c("blanco"), bisel=2.2, luz=0.6, grad=0.2)
    L.plano(L.caja(118.5, 95.5, 129.5, 97), c("gris"))
    L.plano(L.caja(120, 91, 123, 93), c("rojo"))
    L.plano(L.tubo([(125, 90.5), (128, 87), (130.5, 88)], 0.8), c("hueso"))       # cordón


def piezas_sueltas(L, clave):
    """Un espejo arrancado y un pedazo de carenaza del color de la moto."""
    if clave == "ninja":        # espejo anguloso de carenado
        L.pieza(L.poly([(214, 131), (224, 126), (228, 129), (218, 134)]), c("carbon"), bisel=1.5, luz=0.8, brillo=0.2)
        L.plano(L.poly([(216.5, 130.8), (223.5, 127.3), (225.5, 128.8), (218.5, 132.3)]), c("vidrio_brillo"))
    else:                       # espejo redondo en su tallo
        L.cromo(L.tubo([(222, 133), (230, 128)], 1.4))
        L.pieza(L.elipse(218, 132, 4.6, 3.1), c("carbon"), bisel=1.5, luz=0.8, brillo=0.2)
        L.plano(L.elipse(218, 131.8, 3.0, 1.8), c("vidrio_brillo"))
    col = c(MOTOS[clave]["panel"])
    L.pieza(L.poly([(290, 104), (303, 100), (308, 104), (297, 111), (291, 110)]), col, bisel=2, luz=0.8, grad=0.3, brillo=0.2)
    L.plano(L.tubo([(293, 105.5), (303, 102.5)], 0.8), col * 1.25)
    for (x, y) in ((212, 128), (206, 125.5), (282, 127), (274, 129.5)):                     # pedacitos
        L.pieza(L.poly([(x, y), (x + 2.5, y - 1.2), (x + 3, y + 0.8)]), col * 0.9, bisel=0.6, luz=0.5)


def polvo(L, x0, x1, y):
    """Dos nubecitas de polvo de caricatura (cada una, bolas pegadas en una sola forma)."""
    for (cx, lado) in ((x0, -1), (x1, 1)):
        bolas = [(0, 0, 5), (lado * 6, -2, 6.5), (lado * 12, 0.5, 4.5), (lado * 3, -6, 4.5), (lado * 9, -7, 3.5)]
        m = np.zeros_like(L.a, bool)
        for (dx, dy, r) in bolas:
            m |= L.elipse(cx + dx, y + dy, r, r * 0.8)
        L.pieza(m, c("hueso", 0.92), bisel=3, luz=0.7, grad=0.35, linea=False)
        for (dx, dy, r) in bolas[1:3]:
            L.plano(L.elipse(cx + dx - 1.5, y + dy - 2, r * 0.35, r * 0.25), c("blanco"))


def estrellas(L, cx, cy):
    """Estrellitas del mareo girando sobre el casco, con su órbita punteada."""
    for k in range(20):
        a = k / 20 * 2 * np.pi
        if k % 2 == 0:
            L.plano(L.elipse(cx + np.cos(a) * 17, cy + np.sin(a) * 5, 0.6, 0.6), c("ventana_luz"))
    for (a, r) in ((0.25, 5.4), (1.9, 4.2), (3.35, 5.0), (4.9, 3.8)):
        L.pieza(L.estrella(cx + np.cos(a) * 17, cy + np.sin(a) * 5, r), c("ventana_luz"), bisel=1.0, luz=0.6, brillo=0.3)


def rayas_rueda(L, cx, cy, r):
    for a0 in (-3.1, -1.75):
        pts = [(cx + np.cos(a) * r, cy + np.sin(a) * r) for a in np.linspace(a0, a0 + 0.95, 8)]
        L.plano(L.tubo(pts, 1.0), c("blanco"))


# ---------------------------------------------------------------------------------------------

def escena(clave):
    rng = np.random.default_rng(20260930)
    img, anden, via = fondo(rng)
    img = marcas_derrape(img, rng)
    moto = moto_volteada(clave)
    mh, mw = moto.shape[:2]
    bx, piso = MOTOS[clave]["pos"]
    x0, y0 = bx - mw // 2, piso - mh
    sombra(img, bx, piso - 3, mw * 0.55, 7, 0.6)
    sombra(img, 104, 116, 62, 13, 0.5)
    sombra(img, 180, 104, 18, 5, 0.4)
    # el poste de la luz (sube hasta salir del cuadro)
    yb = int(Y_BORDE) - 4
    for x in range(X_POSTE - 4, X_POSTE + 5):
        t = (x - X_POSTE) / 4.0
        img[0:yb, x] = c("cromo_oscuro") * (1.25 - 0.55 * (t + 1) / 2)
    img[0:yb, X_POSTE - 5] = c("negro")
    img[0:yb, X_POSTE + 5] = c("negro")
    img[yb - 6:yb, X_POSTE - 6:X_POSTE + 7] = c("concreto")        # base del poste
    img[yb - 6, X_POSTE - 6:X_POSTE + 7] = c("concreto_claro")
    img[yb:yb + 1, X_POSTE - 7:X_POSTE + 8] = c("negro") * 2
    img[40:52, X_POSTE - 3:X_POSTE + 4] = c("amarillo_casa", 0.75)  # cartel de papel pegado
    img[43:44, X_POSTE - 2:X_POSTE + 3] = c("gris")
    img[46:47, X_POSTE - 2:X_POSTE + 3] = c("gris")

    q = cuantizar(img, 7.0)

    # moto patas arriba
    reg = q[y0:y0 + mh, x0:x0 + mw]
    m = moto[..., 3] > 0
    reg[m] = moto[..., :3][m]

    # personaje y reguero
    L = Capa()
    caja_termica(L)
    comida(L)
    domiciliario(L)
    piezas_sueltas(L, clave)
    polvo(L, x0 + 6, x0 + mw - 6, piso - 2)
    estrellas(L, 67, 92)
    rx, ry, rr = MOTOS[clave]["rueda"]
    rayas_rueda(L, x0 + rx, y0 + ry, rr)
    rgb, lleno = L.reducir()
    # el charco de luz de sodio también les da a ellos
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    charco = np.exp(-(((xx - 70) / 95) ** 2 + ((yy - 112) / 42) ** 2))[..., None]
    rgb = rgb * (np.array([0.92, 0.92, 1.0]) * (1 - 0.15 * charco)) + c("sodio") * 0.18 * charco
    fq = cuantizar(rgb, 4.0)
    q[lleno] = fq[lleno]
    return q


def main():
    for clave in MOTOS:
        q = escena(clave)
        ruta = UI / f"cinematica_{clave}.png"
        Image.fromarray(q, "RGB").save(ruta)
        print("generado:", ruta.relative_to(RAIZ))


if __name__ == "__main__":
    main()
