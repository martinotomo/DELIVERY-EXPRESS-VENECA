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
    "bws": {"cuadro": 0, "giro": 162, "escala": 0.70, "pos": (242, 126), "panel": "azul_bwis", "rueda": (20, 14, 17)},
    "nkd": {"cuadro": 1, "giro": 166, "escala": 0.66, "pos": (242, 126), "panel": "cromo", "rueda": (16, 13, 17)},
    "ninja": {"cuadro": 2, "giro": 164, "escala": 0.68, "pos": (242, 126), "panel": "verde_ninja", "rueda": (19, 15, 16)},
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


def fondo(rng, noche=False, z_borde=Z_BORDE):
    """noche=True: la misma calle de noche y bajo el aguacero (variante «lluvia»). z_borde: hasta
    dónde llega el andén (más grande = andén más angosto y más calle a la vista)."""
    y_borde = HOR + F * CAM_H / z_borde
    img = np.zeros((H, W, 3), np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

    # cielo del atardecer (solo se ve por la calle de la esquina): azul arriba, tibio en el horizonte
    t = np.clip(yy / HOR, 0, 1)[..., None]
    if noche:   # nubes bajas que devuelven el naranja del sodio de la ciudad
        img[:] = c("cielo_noche") * (1 - t) + c("guante_oscuro", 0.9) * t
    else:
        cielo = c("cielo_noche") * (1 - t) + c("azul_casa") * t
        tibio = np.clip((yy - (HOR - 16)) / 16, 0, 1)[..., None]
        img[:] = cielo * (1 - tibio * 0.6) + c("chaqueta_clara", 0.85) * tibio * 0.6

    # suelo: cada píxel bajo el horizonte se proyecta a la calle para saber qué hay ahí
    z = F * CAM_H / np.maximum(yy - HOR, 0.01)
    X = (xx - VPX) * z / F
    suelo = yy > HOR + 0.5
    x_bordillo_esq = 1.64                                   # sardinel de la calle de la esquina
    anden = suelo & (z >= z_borde) & (X < x_bordillo_esq)
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
    bz = np.mod(z - z_borde, 0.6) < 0.02 * z
    mancha = ruido(rng, (H, W), 3.0)
    base = c("concreto")[None, None, :] * (1.0 + 0.035 * g[..., None] - 0.05 * (mancha[..., None] > 1.1))
    base = np.where((bx | bz)[..., None], c("gris")[None, None, :], base)
    img[anden] = base[anden]
    # sardinel: arista de arriba clara, cara de concreto en sombra y la cuneta oscura
    for y in range(int(y_borde), int(y_borde) + 7):
        k = y - int(y_borde)
        col = c("concreto_claro") if k < 2 else c("gris") if k < 6 else c("asfalto_oscuro")
        img[y, :] = col * (1 + 0.03 * g[y, :, None])
    for x in range(0, W, 23):                              # juntas del sardinel
        img[int(y_borde):int(y_borde) + 6, x] = c("asfalto")

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
    if noche:
        return mojar(img, rng, anden, via, charco, haz, osc), anden, via
    img = img * amb * osc * (1 - 0.25 * luz[..., None]) + c("sodio")[None, None, :] * luz[..., None] * 0.55 * osc
    return img, anden, via


def marcas_derrape(img, rng, espejo=False, dx=0, k=0.62):
    """Dos rayas negras de llanta que vienen de la calle, abajo a la derecha, y se suben al sardinel.
    espejo=True las voltea (vienen de abajo a la izquierda) y dx las corre; k es lo oscuras."""
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
    x0, x1 = 196, 214
    if espejo:
        m = m[:, ::-1]
        x0, x1 = W - x1, W - x0
    if dx:
        m = np.roll(m, dx, axis=1)
        if dx > 0:
            m[:, :dx] = 0
        else:
            m[:, dx:] = 0
        x0, x1 = x0 + dx, x1 + dx
    img *= (1 - k * np.clip(m * 1.3, 0, 1))[..., None]
    # raspón en la arista del sardinel donde pegó la moto
    img[int(Y_BORDE):int(Y_BORDE) + 3, x0:x1] *= 0.6
    return img


def sombra(img, cx, cy, rx, ry, k=0.5):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    img *= (1 - k * np.clip(1.2 - d, 0, 1).clip(0, 1) ** 0.7)[..., None]


# ---------------------------------------------------------------------------------------------
# La moto del taller, patas arriba

def moto_volteada(clave):
    d = MOTOS[clave]
    return moto_girada(clave, d["giro"], d["escala"])


def moto_girada(clave, giro, escala, espejo=False, puntos=()):
    """La moto del taller girada `giro` grados (contra reloj) y escalada. espejo=True la voltea
    antes de girarla (queda mirando a la izquierda). Si se pasan `puntos` (x, y del cuadro de
    128×96 ya volteado), devuelve también dónde quedan en el sprite recortado."""
    d = MOTOS[clave]
    hoja = Image.open(UI / "motos_taller.png").convert("RGBA")
    cuadro = hoja.crop((d["cuadro"] * 128, 0, d["cuadro"] * 128 + 128, 96))
    if espejo:
        cuadro = cuadro.transpose(Image.FLIP_LEFT_RIGHT)
    grande = cuadro.resize((128 * 4, 96 * 4), Image.NEAREST).rotate(giro, Image.NEAREST, expand=True)
    w, h = grande.size
    fw, fh = int(w / 4 * escala), int(h / 4 * escala)
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
    rec = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    if not puntos:
        return rec
    th = np.radians(giro)
    sal = []
    for (px, py) in puntos:      # mismo giro que PIL (contra reloj, alrededor del centro)
        vx, vy = px * 4 - 256, py * 4 - 192
        gx = w / 2 + vx * np.cos(th) + vy * np.sin(th)
        gy = h / 2 - vx * np.sin(th) + vy * np.cos(th)
        sal.append((gx * fw / w - xs.min(), gy * fh / h - ys.min()))
    return rec, sal


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
    poste(img)

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
    return pegar_capa(q, L)


def poste(img, y_borde=Y_BORDE):
    """El poste de la luz de sodio (sube hasta salir del cuadro), con su cartel de papel."""
    yb = int(y_borde) - 4
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


def pegar_capa(q, L, noche=False):
    """Reduce la capa a 1×, le da la luz de la escena, la pasa a la paleta y la pega sobre q."""
    rgb, lleno = L.reducir()
    # el charco de luz de sodio también les da a ellos
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    charco = np.exp(-(((xx - 70) / 95) ** 2 + ((yy - 112) / 42) ** 2))[..., None]
    if noche:    # de noche casi solo alumbra el sodio
        rgb = rgb * (np.array([0.62, 0.66, 0.84]) * (1 - 0.1 * charco)) + c("sodio") * 0.3 * charco
    else:
        rgb = rgb * (np.array([0.92, 0.92, 1.0]) * (1 - 0.15 * charco)) + c("sodio") * 0.18 * charco
    fq = cuantizar(rgb, 4.0)
    q[lleno] = fq[lleno]
    return q


# ---------------------------------------------------------------------------------------------
# Variantes por causa del choque: hueco, perro y lluvia (una por moto).
#
#   hueco:  la rueda de adelante clavada en un hueco lleno de agua al pie del sardinel, la moto
#           de trompa con la cola al aire, un cono medio hundido y el asfalto cuarteado.
#   perro:  la moto patas arriba a la izquierda, el domiciliario a la derecha y en el medio un
#           perro callejero feliz, ileso, mirando a cámara con una papa del pedido en la boca.
#   lluvia: el mismo choque de noche y bajo el aguacero: asfalto mojado que refleja el sodio,
#           charcos, gotas y el agua que levantó la moto al deslizarse.

CAUSAS = ("hueco", "perro", "lluvia", "bus", "contravia")
# centro de cada rueda en el cuadro de 128×96 del taller (volteado): trasera y delantera
RUEDAS = {"bws": ((30, 76), (98, 76)), "nkd": ((24, 75), (105, 75)), "ninja": ((20, 75), (106, 75))}


class Capa2(Capa):
    """Capa que se puede correr y voltear después de pintada (para reacomodar la escena)."""

    def mover(self, dx=0.0, dy=0.0, espejo=None):
        """Corre la capa dx, dy píxeles. espejo=A la voltea antes: x → A - x."""
        arrs = [self.rgb, self.a, self.semi]
        if espejo is not None:
            arrs = [a[:, ::-1] for a in arrs]
            dx += espejo - W
        di, dj = int(round(dy * S)), int(round(dx * S))
        out = []
        for a in arrs:
            b = np.zeros_like(a)
            hs, ws = a.shape[:2]
            ys0, ys1 = max(0, -di), min(hs, hs - di)
            xs0, xs1 = max(0, -dj), min(ws, ws - dj)
            b[ys0 + di:ys1 + di, xs0 + dj:xs1 + dj] = a[ys0:ys1, xs0:xs1]
            out.append(b)
        self.rgb, self.a, self.semi = out
        return self

    def sobre(self, otra):
        """Pinta `otra` encima de esta."""
        m = otra.a > 0
        self.rgb[m] = otra.rgb[m]
        self.a[m] = otra.a[m]
        self.semi[m] = otra.semi[m]


def capa(*dibujos, dx=0.0, dy=0.0, espejo=None):
    L = Capa2()
    for d in dibujos:
        d(L)
    return L.mover(dx, dy, espejo) if (dx or dy or espejo is not None) else L


def pegar_sprite(q, spr, x0, y0):
    """Pega un sprite RGBA sobre q (lo que se sale del cuadro se recorta)."""
    mh, mw = spr.shape[:2]
    sx0, sy0 = max(0, -x0), max(0, -y0)
    sx1, sy1 = min(mw, W - x0), min(mh, H - y0)
    spr = spr[sy0:sy1, sx0:sx1]
    reg = q[y0 + sy0:y0 + sy1, x0 + sx0:x0 + sx1]
    m = spr[..., 3] > 0
    reg[m] = spr[..., :3][m]


def gotas(L, pts, col="hueso"):
    """Gotitas de agua volando (cada una una lágrima con su brillo)."""
    for (x, y, r) in pts:
        L.pieza(L.elipse(x, y, r, r * 1.15), c(col), bisel=1, luz=0.8, brillo=0.3, linea=False)


# --- hueco -----------------------------------------------------------------------------------

HUECO = (184.0, 144.0, 40.0, 10.0)       # centro, radio en x y en y (en perspectiva)
Y_AGUA = HUECO[1] + 0.5                  # nivel del agua dentro del hueco


def hueco_masks():
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy, rx, ry = HUECO
    ang = np.arctan2((yy - cy) / ry, (xx - cx) / rx)
    irreg = 1 + 0.10 * np.sin(ang * 5 + 1.3) + 0.06 * np.sin(ang * 11 + 0.4)   # borde roto
    d = np.hypot((xx - cx) / rx, (yy - cy) / ry) / irreg
    return d, yy, xx


def pintar_hueco(img, rng):
    """El hueco en el asfalto (a 1×, antes de cuantizar): pared de atrás con capas de asfalto y
    tierra, agua oscura que refleja el cielo y el sodio, labio roto adelante y grietas."""
    cx, cy, rx, ry = HUECO
    d, yy, xx = hueco_masks()
    dentro = d < 1.0
    # asfalto hundido y cuarteado alrededor (más oscuro cerca del borde)
    anillo = (d >= 1.0) & (d < 1.45)
    img[anillo] *= (0.72 + 0.28 * np.clip((d[anillo] - 1.0) / 0.45, 0, 1))[:, None]
    # el borde roto: un filo claro de asfalto levantado todo alrededor (con mellas)
    mella = ruido(rng, (H, W), 0.8) > -0.9
    filo = (d >= 1.0) & (d < 1.13) & mella
    img[filo] = c("concreto", 0.9)
    # pared de atrás: la cara cortada mira a la cámara (arriba asfalto, abajo tierra húmeda)
    pared = dentro & (yy < Y_AGUA)
    y_top = cy - ry
    t = np.clip((yy - y_top) / (Y_AGUA - y_top), 0, 1)
    col = c("asfalto_oscuro")[None, None] * (1 - t[..., None]) + c("guante_oscuro", 0.45)[None, None] * t[..., None]
    img[pared] = col[pared]
    # el filo de atrás: el borde roto del asfalto coge luz
    filo = (d >= 0.86) & (d < 1.04) & (yy < cy - ry * 0.35)
    img[filo] = c("concreto", 0.95)
    # agua: refleja el cielo oscuro, con ondas y la mancha tibia del sodio
    agua = dentro & (yy >= Y_AGUA)
    ond = np.sin(xx * 0.9 + yy * 2.1) * 0.5 + 0.5
    ref = c("vidrio")[None, None] * (1 - 0.6 * ond[..., None]) + c("vidrio_brillo")[None, None] * 0.6 * ond[..., None]
    ref = ref * np.clip(0.9 + 0.3 * (yy - Y_AGUA) / ry, 0.8, 1.2)[..., None]
    mancha = np.exp(-(((xx - (cx - 12)) / 7) ** 2 + ((yy - (cy + 1)) / 2.5) ** 2))
    ref = ref * (1 - 0.6 * mancha[..., None]) + c("sodio", 0.8)[None, None] * 0.6 * mancha[..., None]
    img[agua] = ref[agua]
    orilla = agua & (np.abs(yy - Y_AGUA) < 0.6)
    img[orilla] = c("vidrio_brillo", 0.8)
    # labio de adelante: el filo roto del asfalto, claro, con su sombra
    labio = (d >= 0.93) & (d < 1.08) & (yy > cy + 1)
    img[labio] = c("concreto", 0.85)
    # grietas que salen del hueco
    for k in range(9):
        a = k / 9 * 2 * np.pi + rng.uniform(-0.3, 0.3)
        x, y = cx + np.cos(a) * rx * 1.02, cy + np.sin(a) * ry * 1.02
        dirx, diry = np.cos(a) * 1.0, np.sin(a) * 0.35
        for paso in range(int(rng.integers(9, 20))):
            xi, yi = int(round(x)), int(round(y))
            if 0 <= xi < W and Y_BORDE + 7 <= yi < H:
                img[yi, xi] = c("negro", 1.6)
            dirx += rng.uniform(-0.35, 0.35)
            diry += rng.uniform(-0.12, 0.12)
            n = np.hypot(dirx, diry) + 1e-6
            x, y = x + dirx / n, y + diry / n * 0.45


def cono_hundido(L):
    """Cono de tránsito medio hundido y ladeado en el agua (alguien lo puso de aviso)."""
    base = Y_AGUA + 1.2
    cx = HUECO[0] - 24
    p = lambda pts: L.poly(pts)  # noqa: E731
    cuerpo = p([(cx - 6, base), (cx + 5, base), (cx + 7.5, base - 13), (cx + 5.5, base - 15.5), (cx + 3.5, base - 14.5)])
    L.pieza(cuerpo, c("naranja"), bisel=2.5, luz=0.8, grad=0.25, brillo=0.2)
    banda = p([(cx - 3.5, base - 6), (cx + 5.5, base - 6), (cx + 6.6, base - 9.5), (cx - 0.5, base - 9.5)]) & cuerpo
    L.pieza(banda, c("blanco"), bisel=1, luz=0.6, linea=False)
    # la base cuadrada del cono asoma de lado, medio sumergida
    L.pieza(p([(cx - 9, base), (cx - 6.5, base - 2.5), (cx + 7, base - 2.5), (cx + 8, base)]), c("naranja", 0.8), bisel=1, luz=0.6)
    for r in (7.5, 10.5):          # ondas en el agua alrededor del cono
        L.plano(L.elipse(cx + 1, base + 0.3, r, 1.3) & ~L.elipse(cx + 1, base + 0.3, r - 0.9, 0.7), c("vidrio_brillo"))


def escena_hueco(clave):
    rng = np.random.default_rng(20260931)
    img, anden, via = fondo(rng)
    pintar_hueco(img, rng)
    d = MOTOS[clave]
    moto, (trasera, delantera) = moto_girada(clave, 40, d["escala"] * 0.9, espejo=True,
                                             puntos=[(128 - x, y) for (x, y) in RUEDAS[clave]])
    mh, mw = moto.shape[:2]
    # la rueda de adelante (abajo a la izquierda) se clava en el agua hasta el eje
    x0 = int(round(HUECO[0] + 22 - delantera[0]))
    y0 = int(round(Y_AGUA + 1 - delantera[1]))
    sombra(img, 104, 116, 62, 13, 0.5)
    sombra(img, 180, 104, 18, 5, 0.4)
    sombra(img, x0 + mw * 0.55, Y_BORDE + 5, mw * 0.5, 4, 0.45)
    poste(img)
    # una raya corta de frenazo que muere en el hueco
    lienzo = Image.new("L", (W * 4, H * 4), 0)
    dd = ImageDraw.Draw(lienzo)
    dd.line([(318 * 4, 168 * 4), (270 * 4, 152 * 4), (HUECO[0] * 4 + 60, (HUECO[1] + 3) * 4)], fill=255, width=14, joint="curve")
    m = np.array(lienzo.resize((W, H), Image.BILINEAR), np.float32) / 255.0
    img *= (1 - 0.55 * m)[..., None]

    q = cuantizar(img, 7.0)
    q_agua = q.copy()

    # atrás: el domiciliario voló por encima y cayó en el andén; la caja y el reguero
    fondo_capa = capa(caja_termica, comida, domiciliario, lambda L: estrellas(L, 67, 92), dx=-6)
    q = pegar_capa(q, fondo_capa)

    # la moto de trompa en el hueco, con la cola al aire
    pegar_sprite(q, moto, x0, y0)
    dd_, yy, xx = hueco_masks()
    tapa = (dd_ < 1.0) & (yy >= Y_AGUA)          # lo que queda bajo el agua no se ve
    q[tapa] = q_agua[tapa]

    L = Capa2()
    cono_hundido(L)
    fx, fy = x0 + delantera[0], Y_AGUA + 0.5
    for r in (6.5, 10.0, 14.0):     # ondas alrededor de la rueda clavada
        L.plano(L.elipse(fx, fy, r, r * 0.2 + 0.4) & ~L.elipse(fx, fy, r - 1.0, r * 0.2 - 0.3), c("vidrio_brillo"))
    # salpicón: gotas que saltan del hueco
    gotas(L, [(fx - 16, fy - 9, 1.6), (fx - 21, fy - 5, 1.2), (fx - 11, fy - 15, 1.3), (fx + 12, fy - 12, 1.4),
              (fx + 17, fy - 6, 1.1), (fx - 26, fy - 1, 1.0), (fx + 6, fy - 18, 1.0)], "vidrio_brillo")
    # pedazos de asfalto que saltaron
    for (x, y, s) in ((HUECO[0] - 34, HUECO[1] - 2, 2.2), (HUECO[0] + 32, HUECO[1] + 1, 2.6), (HUECO[0] - 26, HUECO[1] + 5, 1.8)):
        L.pieza(L.poly([(x - s, y), (x - s * 0.3, y - s * 0.9), (x + s, y - s * 0.4), (x + s * 0.6, y + s * 0.5)]),
                c("asfalto", 1.1), bisel=0.8, luz=0.7)
    tr = (x0 + trasera[0], y0 + trasera[1])
    rr = MOTOS[clave]["rueda"][2]
    rayas_rueda(L, tr[0], tr[1], rr)
    for a0 in (0.2, 1.55):          # la rueda de atrás sigue girando en el aire
        pts = [(tr[0] + np.cos(a) * rr, tr[1] + np.sin(a) * rr) for a in np.linspace(a0, a0 + 0.95, 8)]
        L.plano(L.tubo(pts, 1.0), c("blanco"))
    return pegar_capa(q, L)


# --- perro -----------------------------------------------------------------------------------

def perro(L, cx, by):
    """Perro callejero criollo sentado de frente, feliz e ileso: lengua afuera, una oreja parada y
    la otra caída, parche en un ojo y una papa del pedido atravesada en la boca como un tabaco."""
    pelo, pelo_o, pelo_c = c("guante_claro"), c("guante"), c("guante_claro", 1.18)
    # cola batiéndose, con rayitas de movimiento
    L.pieza(L.tubo([(cx + 8, by - 3), (cx + 15, by - 6), (cx + 18, by - 12)], 3.4), pelo_o, bisel=1.3, luz=0.7)
    for k, (a, b) in enumerate((((cx + 20, by - 17), (cx + 23, by - 13)), ((cx + 22, by - 9), (cx + 24.5, by - 6.5)))):
        L.plano(L.tubo([a, b], 0.8), c("hueso"))
    # patas de atrás (ancas) y cuerpo
    for sx in (-1, 1):
        L.pieza(L.elipse(cx + sx * 7.5, by - 5, 6.5, 5.2), pelo_o, bisel=2.5, luz=0.8, grad=0.3)
        L.pieza(L.elipse(cx + sx * 10.5, by - 1, 3.4, 1.8), pelo_c, bisel=1, luz=0.6)
    L.pieza(L.poly([(cx - 8, by - 2), (cx - 9, by - 13), (cx - 6, by - 20), (cx + 6, by - 20), (cx + 9, by - 13), (cx + 8, by - 2)]),
            pelo, bisel=3.5, luz=0.85, grad=0.3, brillo=0.08)
    pecho = L.elipse(cx, by - 12, 4.8, 7.5)
    L.pieza(pecho, c("hueso"), bisel=2, luz=0.6, grad=0.3, linea=False)
    # patas de adelante
    for sx in (-1, 1):
        L.pieza(L.tubo([(cx + sx * 3.6, by - 12), (cx + sx * 3.9, by - 1.8)], 3.8), pelo, bisel=1.5, luz=0.8, grad=0.2)
        L.pieza(L.elipse(cx + sx * 4.1, by - 1.2, 2.8, 1.7), c("hueso"), bisel=1, luz=0.6)
        L.plano(L.tubo([(cx + sx * 4.1, by - 2.2), (cx + sx * 4.1, by - 0.4)], 0.5), c("guante_oscuro"))
    # orejas: la izquierda parada, la derecha doblada
    L.pieza(L.poly([(cx - 9.5, by - 29), (cx - 12, by - 40.5), (cx - 3, by - 33)]), pelo_o, bisel=1.6, luz=0.8)
    L.plano(L.poly([(cx - 9, by - 31), (cx - 10.8, by - 37.5), (cx - 5.5, by - 33.5)]), c("piel", 0.9))
    L.pieza(L.poly([(cx + 3.5, by - 35), (cx + 11, by - 37.5), (cx + 14.5, by - 30), (cx + 11, by - 29)]), c("guante_oscuro", 1.1), bisel=1.5, luz=0.8)
    # cabeza con el parche en el ojo derecho
    cabeza = L.elipse(cx, by - 28.5, 9.8, 8.2)
    L.pieza(cabeza, pelo, bisel=4, luz=0.9, grad=0.3, brillo=0.12)
    L.pieza(L.elipse(cx + 4.3, by - 31, 3.6, 3.2) & cabeza, c("guante_oscuro", 1.1), bisel=1.5, luz=0.6, linea=False)
    L.pieza(L.elipse(cx, by - 23.8, 6.4, 4.4), c("hueso"), bisel=2, luz=0.7, grad=0.25, linea=False)    # hocico
    # ojos mirando a cámara, con su brillito
    for sx in (-1, 1):
        L.plano(L.elipse(cx + sx * 4, by - 30.6, 1.5, 1.75), c("negro"))
        L.plano(L.elipse(cx + sx * 4 - 0.5, by - 31.2, 0.55, 0.55), c("blanco"))
    # nariz y la boca abierta en una sonrisa
    L.pieza(L.elipse(cx, by - 26.6, 2.4, 1.6), c("carbon"), bisel=1, luz=0.9, brillo=0.35, linea=False)
    L.plano(L.poly([(cx - 4.8, by - 23.6), (cx + 4.8, by - 23.6), (cx + 2.5, by - 20.6), (cx - 2.5, by - 20.6)]), c("rojo_oscuro", 0.7))
    L.plano(L.tubo([(cx - 5, by - 24), (cx, by - 22.8), (cx + 5, by - 24)], 0.7), c("guante_oscuro"))
    # la lengua afuera, colgando hacia un lado
    lengua = L.tubo([(cx + 0.8, by - 22.2), (cx + 1.8, by - 18.5), (cx + 1.2, by - 16.5)], 3.6)
    L.pieza(lengua, c("rojo"), bisel=1.2, luz=0.7, brillo=0.25)
    L.plano(L.tubo([(cx + 1.3, by - 21.5), (cx + 1.6, by - 18)], 0.45), c("rojo_oscuro"))
    # la papa del pedido atravesada en la boca
    L.pieza(L.tubo([(cx - 12, by - 25.2), (cx - 1.5, by - 22.8)], 2.1), c("ventana_luz"), bisel=0.8, luz=0.7, brillo=0.2)


def comida_perro(L):
    """El reguero del pedido alrededor del perro: la caja de papas volcada, papitas, la gaseosa
    rodando, la arepa mordisqueada y el tenis volado."""
    L.pieza(L.poly([(148, 116), (157, 111), (161, 118), (152, 122)]), c("rojo"), bisel=2, luz=0.75, brillo=0.15)
    L.plano(L.poly([(149.5, 116.5), (156, 112.8), (157.2, 114.6), (151, 118)]), c("hueso"))
    for (x, y, a) in ((143, 121, 0.4), (138, 118, -0.6), (146, 125, 1.1), (107, 122, 0.2), (112, 126, -0.9),
                      (100, 117, 0.7), (134, 125, 0.0)):
        dx, dy = np.cos(a) * 2.6, np.sin(a) * 2.6
        L.pieza(L.tubo([(x - dx, y - dy), (x + dx, y + dy)], 2.3), c("ventana_luz"), bisel=1.0, luz=0.7, linea=False)
    # arepa con un mordisco (el perro ya la probó)
    ar = L.elipse(166, 124, 6, 4.2) & ~L.elipse(171, 121.5, 2.6, 2.6)
    L.pieza(ar, c("amarillo_casa"), bisel=2.4, luz=0.8, grad=0.25, brillo=0.18)
    for k in (-2.5, 0, 2.5):
        L.plano(L.tubo([(163 + k, 121.5), (166 + k, 126.5)], 0.9) & ar, c("guante"))
    # gaseosa rodando hacia la calle
    L.pieza(L.caja(118, 128, 129, 134.5, r=3), c("rojo"), bisel=2, luz=0.8, grad=0.3, brillo=0.28)
    L.cromo(L.elipse(129, 131.25, 1.8, 3.2))
    L.plano(L.caja(121, 130.3, 126, 131.5), c("blanco"))
    for dy in (-1.8, 1.8):
        L.plano(L.tubo([(109 + abs(dy), 131 + dy), (115, 131 + dy)], 0.8), c("hueso"))


def piezas_perro(L, clave):
    """El espejo y el pedazo de carenaza, del lado de la moto (izquierda)."""
    col = c(MOTOS[clave]["panel"])
    if clave == "ninja":
        L.pieza(L.poly([(100, 131), (110, 126), (114, 129), (104, 134)]), c("carbon"), bisel=1.5, luz=0.8, brillo=0.2)
        L.plano(L.poly([(102.5, 130.8), (109.5, 127.3), (111.5, 128.8), (104.5, 132.3)]), c("vidrio_brillo"))
    else:
        L.cromo(L.tubo([(104, 133), (112, 128)], 1.4))
        L.pieza(L.elipse(100, 132, 4.6, 3.1), c("carbon"), bisel=1.5, luz=0.8, brillo=0.2)
        L.plano(L.elipse(100, 131.8, 3.0, 1.8), c("vidrio_brillo"))
    L.pieza(L.poly([(86, 104), (99, 100), (104, 104), (93, 111), (87, 110)]), col, bisel=2, luz=0.8, grad=0.3, brillo=0.2)
    L.plano(L.tubo([(89, 105.5), (99, 102.5)], 0.8), col * 1.25)
    for (x, y) in ((92, 127.5), (80, 129.5), (22, 130), (30, 127)):
        L.pieza(L.poly([(x, y), (x + 2.5, y - 1.2), (x + 3, y + 0.8)]), col * 0.9, bisel=0.6, luz=0.5)


def escena_perro(clave):
    rng = np.random.default_rng(20260932)
    img, anden, via = fondo(rng)
    img = marcas_derrape(img, rng, espejo=True, dx=-62)
    moto = moto_volteada(clave)[:, ::-1]
    mh, mw = moto.shape[:2]
    bx, piso = 56, 126
    x0, y0 = bx - mw // 2, piso - mh
    PX, PY = 118, 127                            # dónde se sienta el perro
    ESP = 332                                   # el domiciliario, volteado: cayó hacia la derecha
    sombra(img, bx, piso - 3, mw * 0.55, 7, 0.6)
    sombra(img, ESP - 104, 116, 62, 13, 0.5)
    sombra(img, PX + 4, PY - 1, 22, 4, 0.55)
    poste(img)
    q = cuantizar(img, 7.0)
    pegar_sprite(q, moto, x0, y0)

    L = capa(caja_termica, dx=-28)              # la maleta cayó contra la pared, detrás del perro
    L.sobre(capa(domiciliario, lambda L_: estrellas(L_, 67, 92), espejo=ESP))
    L.sobre(capa(lambda L_: tenis_volado(L_, 250, 90)))
    comida_perro(L)
    piezas_perro(L, clave)
    polvo(L, x0 + 6, x0 + mw - 6, piso - 2)
    rx, ry, rr = MOTOS[clave]["rueda"]
    rayas_rueda(L, x0 + mw - rx, y0 + ry, rr)
    perro(Escala(L, PX, PY, 1.3), PX, PY)
    return pegar_capa(q, L)


def tenis_volado(L, x, y):
    L.pieza(L.caja(x, y, x + 12, y + 7, r=3.5), c("blanco"), bisel=2.2, luz=0.6, grad=0.2)
    L.plano(L.caja(x + 0.5, y + 5.5, x + 11.5, y + 7), c("gris"))
    L.plano(L.caja(x + 2, y + 1, x + 5, y + 3), c("rojo"))


# --- lluvia ----------------------------------------------------------------------------------

def mojar(img, rng, anden, via, charco, haz, osc):
    """La calle de noche bajo el aguacero (fondo con noche=True): luz ambiente muy baja y
    azulada, el sodio mandando, el piso mojado y oscuro que refleja la fachada, las ventanas y el
    poste, y charcos."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    suelo = anden | via
    base = img.copy()
    # piso mojado: más oscuro y más saturado
    img[suelo] *= 0.62
    # reflejo de la fachada en el andén (espejo en el pie del muro), roto por las ondas
    onda = ruido(rng, (H, W), (0.4, 2.5))
    ys = np.clip((2 * Y_MURO - yy).astype(int), 0, H - 1)
    refl = base[ys, xx.astype(int)]
    k_and = np.clip(0.5 - (yy - Y_MURO) / 70, 0.1, 0.5) * (0.75 + 0.25 * onda)
    img[anden] = img[anden] * (1 - k_and[anden, None]) + refl[anden] * k_and[anden, None]
    # charcos (manchas alargadas en perspectiva) que reflejan el cielo y las ventanas
    ch = ruido(rng, (H, W), (1.2, 7.0)) > 1.0
    ch &= suelo & (yy > Y_MURO + 3)
    img[ch] = img[ch] * 0.35 + refl[ch] * 0.3 + c("vidrio", 0.9) * 0.35
    amb = np.array([0.46, 0.52, 0.74], np.float32)
    luz = charco * (0.6 * (yy > Y_MURO - 1) + 0.3) + haz * 0.2
    img = img * amb * osc * (1 - 0.3 * luz[..., None]) + c("sodio")[None, None, :] * luz[..., None] * 0.62 * osc
    # el reflejo del poste de sodio: una columna de luz temblorosa que baja por el piso mojado
    col = np.exp(-(((xx - 34 - 0.12 * (yy - 100)) / (6 + 0.18 * (yy - 96))) ** 2))
    temb = np.clip(0.55 + 0.6 * ruido(rng, (H, W), (0.3, 3.0)), 0, 1.2)
    fuerza = col * temb * np.clip((yy - Y_MURO) / 10, 0, 1) * np.clip(1.25 - (yy - 128) / 70, 0, 1)
    img = img * (1 - 0.5 * fuerza[..., None]) + c("sodio")[None, None] * 0.75 * fuerza[..., None] * suelo[..., None]
    # reflejos de las ventanas encendidas de la casa y del local, más débiles
    for (xc, ancho, k) in ((34, 16, 0.35), (170, 18, 0.18)):
        cc = np.exp(-(((xx - xc) / ancho) ** 2)) * temb * np.clip((yy - Y_MURO) / 6, 0, 1) * np.clip(1 - (yy - Y_MURO) / 40, 0, 1)
        img = img + c("ventana_luz")[None, None] * k * 0.4 * (cc * anden)[..., None]
    return img


def lluvia(q, rng, zona_calma=0.35):
    """Gotas del aguacero sobre todo el cuadro (después de cuantizar): rayas cortas inclinadas,
    más claras donde les da el sodio. Arriba y abajo (donde va el texto) llueve más suave."""
    out = q.astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    charco = np.exp(-(((xx - 60) / 90) ** 2 + ((yy - 90) / 70) ** 2))
    marca = np.zeros((H, W), bool)
    n = 900
    xs, ys = rng.uniform(-20, W, n), rng.uniform(-8, H, n)
    largos = rng.integers(4, 9, n)
    for x, y, lg in zip(xs, ys, largos):
        calma = y < 38 or y > 142
        if calma and rng.uniform() > zona_calma:
            continue
        for i in range(lg):
            xi, yi = int(x + i * 0.35), int(y + i)
            if 0 <= xi < W and 0 <= yi < H and not marca[yi, xi]:
                marca[yi, xi] = True
                w = charco[yi, xi]
                tinte = c("vidrio_brillo") * (1 - w) + c("ventana_luz") * w
                kk = 0.35 + 0.25 * w
                out[yi, xi] = out[yi, xi] * (1 - kk) + tinte * kk
    return cuantizar(out, 0.0)


def salpicones(L, rng, pts):
    """Coronitas de agua donde caen gotas en el piso (unas cuantas, en el andén y la calle)."""
    for (x, y) in pts:
        for s in (-1, 1):
            L.plano(L.tubo([(x + s * 0.6, y), (x + s * 2.0, y - 1.8)], 0.55), c("vidrio_brillo"))
        L.plano(L.elipse(x, y + 0.3, 2.4, 0.5) & ~L.elipse(x, y + 0.3, 1.6, 0.25), c("vidrio_brillo", 0.85))


def escena_lluvia(clave):
    rng = np.random.default_rng(20260930)
    img, anden, via = fondo(rng, noche=True)
    img = marcas_derrape(img, rng, k=0.5)
    moto = moto_volteada(clave)
    mh, mw = moto.shape[:2]
    bx, piso = MOTOS[clave]["pos"]
    x0, y0 = bx - mw // 2, piso - mh
    sombra(img, bx, piso - 3, mw * 0.55, 7, 0.6)
    sombra(img, 104, 116, 62, 13, 0.5)
    sombra(img, 180, 104, 18, 5, 0.4)
    poste(img)
    img[0:int(Y_BORDE) - 4, X_POSTE - 4:X_POSTE + 5] *= 0.7    # el poste, de noche, más oscuro
    # la estela de agua que abrió la moto al deslizarse: el piso queda más brillante en las rayas
    lienzo = Image.new("L", (W * 4, H * 4), 0)
    d = ImageDraw.Draw(lienzo)
    pts = [((318 - 120 * t) * 4, (176 - 44 * t ** 0.8 + 3 * np.sin(t * 7) * (1 - t)) * 4) for t in np.linspace(0, 1, 30)]
    d.line(pts, fill=255, width=34, joint="curve")
    m = np.array(lienzo.resize((W, H), Image.BILINEAR), np.float32) / 255.0
    m *= (ruido(rng, (H, W), (0.5, 2.0)) > -0.2)
    img = img * (1 - 0.35 * m[..., None]) + c("vidrio_brillo", 0.55)[None, None] * 0.35 * m[..., None]
    q = cuantizar(img, 7.0)
    pegar_sprite(q, moto, x0, y0)

    L = Capa2()
    caja_termica(L)
    comida(L)
    domiciliario(L)
    piezas_sueltas(L, clave)
    estrellas(L, 67, 92)
    rx, ry, rr = MOTOS[clave]["rueda"]
    rayas_rueda(L, x0 + rx, y0 + ry, rr)
    # el agua que levantó la moto al deslizarse: dos cortinas de gotas a los lados de la moto
    for (cx, lado) in ((x0 + 8, -1), (x0 + mw - 6, 1)):
        gs = []
        for k in range(9):
            t = k / 8
            gs.append((cx + lado * (4 + 16 * t), piso - 4 - 14 * np.sin(t * 2.6) - rng.uniform(0, 3), 0.9 + 0.7 * (1 - t)))
        gotas(L, gs, "vidrio_brillo")
    # salpicones en la estela y en el andén
    salpicones(L, rng, [(300, 170), (286, 160), (270, 151), (254, 143), (240, 137), (232, 133),
                        (30, 104), (150, 106), (118, 126), (46, 134), (100, 138), (190, 131)])
    q = pegar_capa(q, L, noche=True)
    return lluvia(q, rng)


# --- piezas comunes de las variantes nuevas ----------------------------------------------------

class Escala:
    """Envuelve una capa para pintar una figura agrandada k veces alrededor de (ox, oy): las
    formas escalan sus coordenadas y tamaños; el resto (pieza, plano, cromo) pasa derecho."""

    def __init__(self, L, ox, oy, k):
        self.L, self.ox, self.oy, self.k = L, ox, oy, k

    def _p(self, x, y):
        return self.ox + (x - self.ox) * self.k, self.oy + (y - self.oy) * self.k

    def poly(self, pts):
        return self.L.poly([self._p(x, y) for x, y in pts])

    def elipse(self, cx, cy, rx, ry):
        return self.L.elipse(*self._p(cx, cy), rx * self.k, ry * self.k)

    def caja(self, x0, y0, x1, y1, r=0):
        (a, b), (cc, d) = self._p(x0, y0), self._p(x1, y1)
        return self.L.caja(a, b, cc, d, r * self.k)

    def tubo(self, pts, ancho):
        return self.L.tubo([self._p(x, y) for x, y in pts], ancho * self.k)

    def estrella(self, cx, cy, r):
        return self.L.estrella(*self._p(cx, cy), r * self.k)

    def __getattr__(self, n):
        return getattr(self.L, n)


def aplastar(spr, fx=1.0, fy=1.0):
    """Encoge un sprite (la moto hecha acordeón contra lo que chocó) tomando píxeles enteros."""
    h, w = spr.shape[:2]
    nh, nw = max(1, int(h * fy)), max(1, int(w * fx))
    ys = ((np.arange(nh) + 0.5) * h / nh).astype(int)
    xs = ((np.arange(nw) + 0.5) * w / nw).astype(int)
    return spr[ys][:, xs].copy()


def raya_llanta(img, pts, ancho=2.2, k=0.55):
    """Raya negra de llanta (a 1×, con bordes suaves)."""
    lienzo = Image.new("L", (W * 4, H * 4), 0)
    ImageDraw.Draw(lienzo).line([(x * 4, y * 4) for x, y in pts], fill=255, width=int(ancho * 4), joint="curve")
    m = np.array(lienzo.resize((W, H), Image.BILINEAR), np.float32) / 255.0
    img *= (1 - k * m)[..., None]


def estallido(L, cx, cy, r, puntas=9, giro=0.2):
    """Estallido de choque de historieta (sin letras): estrella irregular amarilla con un halo."""
    for (rr, col, k) in ((r, "ventana_luz", 1.0), (r * 0.62, "blanco", 0.95)):
        pts = []
        for i in range(puntas * 2):
            a = giro + i * np.pi / puntas
            f = rr * (1.0 if i % 2 == 0 else 0.5) * (1 + 0.18 * np.sin(i * 2.7))
            pts.append((cx + np.cos(a) * f, cy + np.sin(a) * f * 0.8))
        L.pieza(L.poly(pts), c(col, k), bisel=1.5, luz=0.5, grad=0.2, linea=(col != "blanco"))


def vehiculo(modelo, yaw, ppm, fw, fh, elev):
    """Render de un vehículo de tools/gen_vehiculos.py a la escala de la escena (recortado)."""
    import gen_vehiculos as GV
    antes = GV.PPM
    GV.PPM = ppm
    try:
        spr = GV.render(modelo, fw, fh, yaw, elev)
    finally:
        GV.PPM = antes
    ys, xs = np.nonzero(spr[..., 3])
    return spr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def domiciliario_estampado(L, cx, cy):
    """El domiciliario pegado al parabrisas como calcomanía, de espaldas y a lo estrella de mar:
    brazos y piernas abiertos, manos abiertas contra el vidrio, un tenis puesto y el otro no."""
    chaq, chaq_o = c("chaqueta"), c("chaqueta_oscura")
    jean, jean_o = c("azul_casa", 0.95), c("azul_casa", 0.72)
    for sx in (-1, 1):
        # piernas abiertas hacia abajo
        L.pieza(L.tubo([(cx + sx * 3.5, cy + 5), (cx + sx * 9, cy + 12), (cx + sx * 12, cy + 19)], 5.2),
                jean if sx < 0 else jean_o * 1.1, bisel=2.2, luz=0.8, grad=0.25)
        # brazos abiertos hacia arriba
        L.pieza(L.tubo([(cx + sx * 6, cy - 5), (cx + sx * 12, cy - 9), (cx + sx * 15, cy - 16)], 4.4),
                chaq, bisel=1.8, luz=0.8, grad=0.2)
        L.plano(L.tubo([(cx + sx * 11, cy - 8.5), (cx + sx * 12.5, cy - 10.5)], 1.8), c("hueso", 0.9))
        # mano abierta, dedos estirados contra el vidrio
        L.pieza(L.elipse(cx + sx * 15.8, cy - 18.5, 2.7, 2.4), c("guante"), bisel=1, luz=0.7)
        for a in (-0.9, -0.35, 0.2, 0.75):
            ang = -np.pi / 2 + sx * a
            L.pieza(L.tubo([(cx + sx * 15.8 + np.cos(ang) * 2, cy - 18.5 + np.sin(ang) * 2),
                            (cx + sx * 15.8 + np.cos(ang) * 4.6, cy - 18.5 + np.sin(ang) * 4.6)], 1.1),
                    c("guante"), bisel=0.4, luz=0.5, linea=False)
    # tenis (izquierda) y media blanca (derecha)
    L.pieza(L.caja(cx - 15.5, cy + 18, cx - 8.5, cy + 23, r=2), c("blanco"), bisel=1.2, luz=0.6)
    L.plano(L.caja(cx - 15, cy + 21.8, cx - 9, cy + 23), c("gris"))
    L.pieza(L.elipse(cx + 12.5, cy + 20.5, 2.6, 2.3), c("hueso"), bisel=1, luz=0.6)
    # espalda de la chaqueta con la franja reflectiva y el pantalón
    L.pieza(L.caja(cx - 5.5, cy + 1, cx + 5.5, cy + 8, r=2.5), jean, bisel=2, luz=0.8, grad=0.3)
    L.pieza(L.poly([(cx - 8, cy - 7), (cx + 8, cy - 7), (cx + 7, cy + 3), (cx + 5, cy + 5), (cx - 5, cy + 5), (cx - 7, cy + 3)]),
            chaq, bisel=3, luz=0.85, grad=0.3, brillo=0.1)
    L.plano(L.caja(cx - 7.4, cy - 2.2, cx + 7.4, cy - 0.4), c("hueso"))
    L.plano(L.tubo([(cx, cy - 6.5), (cx, cy + 4)], 0.7), chaq_o)
    # casco por detrás, con su franja
    casco = L.elipse(cx, cy - 11, 6.2, 5.6)
    L.pieza(casco, c("carbon"), bisel=3, luz=0.95, grad=0.3, brillo=0.3)
    L.pieza(L.tubo([(cx, cy - 16.5), (cx, cy - 5.5)], 2.4) & casco, c("chaqueta_clara"), bisel=0.8, luz=0.4, linea=False)
    L.plano(L.elipse(cx - 3, cy - 13.5, 1.5, 0.9), c("blanco"))


def domiciliario_volando(L, cx, cy):
    """El domiciliario volando de lado por encima del capó, hacia la derecha: brazos al frente,
    piernas atrás abiertas y un tenis que se le sale."""
    chaq, chaq_c = c("chaqueta"), c("chaqueta_clara")
    jean, jean_o = c("azul_casa", 0.95), c("azul_casa", 0.72)
    # rayas de velocidad detrás
    for (dy, x0, x1) in ((-6, -44, -30), (0, -48, -34), (6, -42, -31)):
        L.plano(L.tubo([(cx + x0, cy + dy), (cx + x1, cy + dy)], 0.9), c("hueso"))
    # pierna de atrás (más oscura) y brazo de atrás
    L.pieza(L.tubo([(cx - 9, cy + 1), (cx - 18, cy - 5), (cx - 27, cy - 9)], 5.5), jean_o, bisel=2, luz=0.7, grad=0.2)
    L.pieza(L.elipse(cx - 29.5, cy - 9.5, 2.6, 2.2), c("hueso"), bisel=1, luz=0.6)          # media
    L.pieza(L.tubo([(cx + 5, cy - 3), (cx + 12, cy - 11), (cx + 17, cy - 17)], 4.2), chaq * 0.9, bisel=1.6, luz=0.7)
    L.pieza(L.elipse(cx + 18.5, cy - 18.5, 2.6, 2.2), c("guante"), bisel=1, luz=0.7)
    # cuerpo estirado
    L.pieza(L.elipse(cx - 7, cy + 1.5, 6.5, 5), jean, bisel=2.5, luz=0.85, grad=0.3)
    L.pieza(L.tubo([(cx - 9, cy + 3), (cx - 18, cy + 7), (cx - 27, cy + 5)], 5.5), jean, bisel=2.2, luz=0.85, grad=0.25)
    L.pieza(L.caja(cx - 33, cy + 1.5, cx - 25.5, cy + 7.5, r=2.4), c("blanco"), bisel=1.2, luz=0.6)
    L.plano(L.caja(cx - 33, cy + 6, cx - 25.5, cy + 7.5), c("gris"))
    torso = L.poly([(cx - 5, cy - 4.5), (cx + 7, cy - 6.5), (cx + 11, cy - 2), (cx + 9, cy + 4.5), (cx - 4, cy + 5.5)])
    L.pieza(torso, chaq, bisel=3, luz=0.85, grad=0.3, brillo=0.1)
    L.plano(L.poly([(cx + 1.5, cy - 6), (cx + 3.5, cy - 6.4), (cx + 4.5, cy + 5), (cx + 2.5, cy + 5.2)]) & torso, c("hueso"))
    # brazo de adelante estirado hacia el frente
    L.pieza(L.tubo([(cx + 7, cy + 1), (cx + 15, cy + 3), (cx + 22, cy + 1)], 4.4), chaq, bisel=1.8, luz=0.85, grad=0.2)
    L.plano(L.tubo([(cx + 13, cy + 2.6), (cx + 15.5, cy + 3)], 1.8), chaq_c)
    L.pieza(L.elipse(cx + 24, cy + 0.5, 2.8, 2.3), c("guante"), bisel=1, luz=0.75)
    # casco mirando a la derecha, con la visera
    L.pieza(L.elipse(cx + 15, cy - 6, 6.2, 5.6), c("carbon"), bisel=3, luz=0.95, grad=0.3, brillo=0.3)
    L.pieza(L.poly([(cx + 16, cy - 8), (cx + 21, cy - 7), (cx + 21, cy - 3), (cx + 17, cy - 3.5)]), c("vidrio_oscuro"), bisel=1, luz=0.9, brillo=0.3)
    L.plano(L.tubo([(cx + 11, cy - 11), (cx + 13, cy - 1)], 1.4) & L.elipse(cx + 15, cy - 6, 5.8, 5.2), chaq_c)
    L.plano(L.elipse(cx + 12.5, cy - 9, 1.3, 0.8), c("blanco"))


def reguero(L, x, y, n=7, abre=1.0, semilla=0):
    """Papitas regadas alrededor de (x, y)."""
    r = np.random.default_rng(semilla)
    for _ in range(n):
        px, py, a = x + r.uniform(-12, 12) * abre, y + r.uniform(-4, 4), r.uniform(-1.2, 1.2)
        dx, dy = np.cos(a) * 2.6, np.sin(a) * 2.6
        L.pieza(L.tubo([(px - dx, py - dy), (px + dx, py + dy)], 2.3), c("ventana_luz"), bisel=1.0, luz=0.7, linea=False)


# --- bus -------------------------------------------------------------------------------------

def escena_bus(clave):
    """El bus salió de la esquina: la moto quedó hecha acordeón contra la trompa y el domiciliario
    rebotó y quedó pegado en el parabrisas."""
    import gen_vehiculos as GV
    rng = np.random.default_rng(20260933)
    img, anden, via = fondo(rng)
    bus = vehiculo(GV.Bus().modelo(), 335.0, 27.0, 400, 116, 3.0)
    bh, bw = bus.shape[:2]
    bx0, by0 = 172, 142 - bh
    sombra(img, bx0 + 95, 140, 110, 5, 0.6)
    raya_llanta(img, [(2, 170), (60, 160), (110, 148), (140, 140)], 2.4)
    raya_llanta(img, [(0, 177), (58, 166), (108, 153), (136, 143)], 2.0)
    poste(img)
    q = cuantizar(img, 7.0)
    pegar_sprite(q, bus, bx0, by0)

    # parabrisas: el vidrio de la cara de adelante (azules del cielo) con grietas en telaraña
    reg = q[by0:by0 + bh, bx0:bx0 + bw].astype(int)
    vidrio = np.zeros((H, W), bool)
    es_vid = np.zeros(reg.shape[:2], bool)
    for n in ("vidrio_oscuro", "vidrio", "vidrio_brillo", "cielo_noche", "cromo_oscuro", "azul_casa", "gris", "asfalto", "asfalto_oscuro", "carbon", "cromo"):
        es_vid |= (reg == np.array(P[n])).all(-1)
    vidrio[by0:by0 + bh, bx0:bx0 + bw] = es_vid
    vidrio[:, :bx0] = False
    vidrio[:, bx0 + 65:] = False
    vidrio[:by0 + 27] = False
    vidrio[by0 + 76:] = False
    CX, CY = bx0 + 31, by0 + 51                   # centro del golpe en el parabrisas
    grieta = Image.new("L", (W, H), 0)
    dg = ImageDraw.Draw(grieta)
    r2 = np.random.default_rng(7)
    for k in range(11):
        a = k / 11 * 2 * np.pi + r2.uniform(-0.2, 0.2)
        pts, x, y = [(CX, CY)], CX, CY
        for paso in range(5):
            a += r2.uniform(-0.3, 0.3)
            x, y = x + np.cos(a) * 8, y + np.sin(a) * 8
            pts.append((x, y))
        dg.line(pts, fill=255, width=1)
    for rr in (9, 17, 26):
        dg.ellipse([CX - rr, CY - rr * 0.8, CX + rr, CY + rr * 0.8], outline=255, width=1)
    g = (np.array(grieta) > 0) & vidrio
    q[g] = P["vidrio_brillo"]

    # la moto: de perfil hacia la derecha, hecha acordeón contra la trompa, con la cola alzada
    d = MOTOS[clave]
    moto = aplastar(moto_girada(clave, -9, d["escala"] * 0.95), fx=0.62)
    mh, mw = moto.shape[:2]
    mx0, my0 = bx0 + 12 - mw, 143 - mh
    L = Capa2()
    estallido(L, bx0 + 6, 118, 17)
    q = pegar_capa(q, L)
    pegar_sprite(q, moto, mx0, my0)

    L = Capa2()
    domiciliario_estampado(L, CX, CY)
    estrellas(Escala(L, CX, CY - 12, 0.75), CX, CY - 24)
    polvo(L, mx0 + 2, bx0 + 16, 141)
    # la maleta cayó al andén y el pedido quedó regado; una papa se quedó pegada al vidrio
    L2 = capa(caja_termica, dx=-98, dy=6)
    L2.sobre(L)
    L = L2
    reguero(L, 100, 122, n=8, semilla=3)
    L.pieza(L.tubo([(CX + 20, CY - 16), (CX + 24, CY - 13)], 2.3), c("ventana_luz"), bisel=1, luz=0.7, linea=False)
    L.pieza(L.caja(52, 126, 63, 132.5, r=3), c("rojo"), bisel=2, luz=0.8, grad=0.3, brillo=0.28)   # gaseosa
    L.cromo(L.elipse(52, 129.25, 1.8, 3.2))
    col = c(d["panel"])
    for (x, y) in ((150, 132), (140, 136), (132, 128), (118, 138)):
        L.pieza(L.poly([(x, y), (x + 3, y - 1.4), (x + 3.5, y + 1)]), col * 0.9, bisel=0.6, luz=0.5)
    return pegar_capa(q, L)


# --- contravía -------------------------------------------------------------------------------

Z_BORDE_CONTRA = 4.1          # andén más angosto: se ve más calle (y la flecha pintada)


def flecha_via(img, rng, x_cola, x_punta, yc, alto, sesgo=-1.0):
    """Flecha blanca pintada en el carril apuntando a la izquierda (el sentido del carril: la
    moto venía al revés). Se dibuja en la pantalla con un sesgo suave hacia el punto de fuga (la
    perspectiva de verdad la estiraría tanto que no se leería) y gastada, como la pintura bogotana."""
    xh = x_punta + (x_cola - x_punta) * 0.36
    a, b = alto * 0.3, alto * 0.5
    pts = [(x_cola, yc - a), (xh, yc - a), (xh, yc - b), (x_punta, yc), (xh, yc + b), (xh, yc + a), (x_cola, yc + a)]
    pts = [(x + (y - yc) * sesgo, y) for x, y in pts]
    lienzo = Image.new("L", (W * 4, H * 4), 0)
    ImageDraw.Draw(lienzo).polygon([(x * 4, y * 4) for x, y in pts], fill=255)
    m = np.array(lienzo.resize((W, H), Image.BILINEAR), np.float32) / 255.0
    m *= ruido(rng, (H, W), 0.8) > -1.8
    img[:] = img * (1 - m[..., None]) + c("hueso", 0.92)[None, None] * m[..., None]


def escena_contravia(clave):
    """En contravía: la moto se estrelló de frente contra un taxi que venía por su carril (la
    flecha pintada dice para dónde era) y el domiciliario sale volando por encima del capó."""
    import gen_vehiculos as GV
    rng = np.random.default_rng(20260934)
    img, anden, via = fondo(rng, z_borde=Z_BORDE_CONTRA)
    yb = HOR + F * CAM_H / Z_BORDE_CONTRA
    flecha_via(img, rng, 120, 14, 131.5, 17.0, sesgo=-0.7)
    taxi = vehiculo(GV.Carro(color="amarillo_taxi", tipo="hatch", taxi=True, franja=True, largo=4.0, ejes=(1.2, -1.22)).modelo(),
                    270.0, 30.0, 160, 70, 8.0)
    th, tw = taxi.shape[:2]
    tx0, ty0 = 172, 145 - th
    sombra(img, tx0 + tw / 2, 143, tw * 0.55, 4, 0.6)
    raya_llanta(img, [(0, 150), (60, 147), (120, 145), (170, 143)], 2.2)
    poste(img, yb)
    q = cuantizar(img, 7.0)
    pegar_sprite(q, taxi, tx0, ty0)

    d = MOTOS[clave]
    moto = aplastar(moto_girada(clave, -13, d["escala"] * 0.9), fx=0.8)
    mh, mw = moto.shape[:2]
    mx0, my0 = tx0 + 10 - mw, 146 - mh
    L = Capa2()
    estallido(L, tx0 + 4, 124, 16)
    q = pegar_capa(q, L)
    pegar_sprite(q, moto, mx0, my0)

    L = Capa2()
    domiciliario_volando(L, 234, 74)
    # la maleta y el pedido vuelan detrás de él, soltando papas
    caja = Capa2()
    caja_termica(caja)
    caja.mover(-30, -36)
    caja.sobre(L)
    L = caja
    for (x, y, a) in ((174, 62, 0.4), (184, 58, -0.7), (194, 64, 1.2), (180, 68, -0.2), (200, 57, 0.3)):
        dx, dy = np.cos(a) * 2.6, np.sin(a) * 2.6
        L.pieza(L.tubo([(x - dx, y - dy), (x + dx, y + dy)], 2.3), c("ventana_luz"), bisel=1.0, luz=0.7, linea=False)
    col = c(d["panel"])
    for (x, y) in ((160, 110), (152, 104), (166, 100), (146, 115)):
        L.pieza(L.poly([(x, y), (x + 3, y - 1.4), (x + 3.5, y + 1)]), col * 0.9, bisel=0.6, luz=0.5)
    polvo(L, mx0 + 4, tx0 + 14, 144)
    return pegar_capa(q, L)


ESCENAS = {"hueco": escena_hueco, "perro": escena_perro, "lluvia": escena_lluvia,
           "bus": escena_bus, "contravia": escena_contravia}


def main():
    import sys
    solo = sys.argv[1:] or ["base", *CAUSAS]      # p. ej.: python tools/gen_cinematica.py perro
    for causa in solo:
        for clave in MOTOS:
            if causa == "base":
                q, ruta = escena(clave), UI / f"cinematica_{clave}.png"
            else:
                q, ruta = ESCENAS[causa](clave), UI / f"cinematica_{causa}_{clave}.png"
            Image.fromarray(q, "RGB").save(ruta)
            print("generado:", ruta.relative_to(RAIZ))


if __name__ == "__main__":
    main()
