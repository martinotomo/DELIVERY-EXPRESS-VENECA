"""Carros, buses y camiones de la ciudad como sprites a lo Doom: 8 vistas por vehículo.

    python tools/gen_vehiculos.py

Cómo funciona (sin programas de dibujo, todo por código y siempre igual):

1. Cada vehículo se arma con pocos sólidos en 3D, medidos en metros: la carrocería es un perfil
   lateral «estirado» a lo ancho (con los huecos de las ruedas), la cabina es un tronco de pirámide
   (parabrisas, vidrio de atrás, costados y techo), y aparte van las ruedas (cilindros de 12 caras),
   los espejos, el aviso del taxi, etc. Nada de logos ni letras: la placa es un rectángulo liso.
2. Un rasterizador pequeño hecho aquí (proyección ortográfica, cámara 10° por encima del horizonte
   en los carros y 6° en los grandes, para que quepan en su cuadro) pinta cada cara con un búfer de
   profundidad (lo que está más cerca tapa a lo que está detrás). Cada píxel sabe en qué punto del
   vehículo cae, así que los «materiales» son funciones: vidrios, franja de cuadros del taxi,
   farolas, stops, puertas y placas se dibujan según la altura y la posición sobre la carrocería.
3. Luz desde arriba a la izquierda del que mira (como en las motos del taller); los vidrios reflejan
   el cielo con un degradé y una raya de brillo; farolas y stops no se sombrean (se ven prendidos).
4. Se pinta a 4×, se reduce, se pone una línea oscura donde una pieza tapa a otra y el contorno negro
   de 1 px, y se cuantiza a la paleta (tools/paleta.py) con un tramado Bayer suave.

Convención de giro (el juego depende de ella): la columna k muestra el vehículo girado φ = k·45°.
φ = 0: la trompa mira al que ve (farolas). φ = 90°: la trompa apunta a la DERECHA de la pantalla
(se ve su costado derecho, el de las puertas del bus). φ = 180°: se ve la cola (stops rojos).
φ = 270°: la trompa apunta a la izquierda (se ve el costado izquierdo).

Salidas (14 px por metro, píxeles cuadrados; la rueda más cercana toca el suelo en la penúltima fila
del cuadro y el centro del vehículo va centrado a lo ancho):
    assets/texturas/vehiculos.png          filas [taxi, carro, carro_rojo], cuadros de 80×40
    assets/texturas/vehiculos_grandes.png  filas [bus, camion], cuadros de 176×64
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from paleta import PALETA as P
from pixel import BAYER4, cuantizar

RAIZ = Path(__file__).resolve().parent.parent
TEX = RAIZ / "assets" / "texturas"
PREVIA = Path("/tmp/claude-0/vehiculos_preview.png")
S = 4                 # se pinta a 4× y se reduce
PPM = 14.0            # píxeles por metro en el sprite final
VISTAS = 8

# Luz en el mundo (x: derecha de la pantalla, y: hacia el fondo, z: arriba): viene de arriba,
# de la izquierda y un poco de delante del que mira.
LUZ = np.array([-0.55, -0.45, 0.75])
LUZ = LUZ / np.linalg.norm(LUZ)

# Tipos de píxel: pintura (se sombrea), vidrio (refleja el cielo) y luz (no se sombrea).
PINTURA, VIDRIO, LUZ_PROPIA = 0, 1, 2


def c(nombre, k=1.0):
    return np.array(P[nombre], np.float32) * k


# ---------------------------------------------------------------------------------------------
# Geometría: cada cara es un polígono plano en coordenadas del vehículo
#   a = hacia la trompa, b = hacia su izquierda, h = hacia arriba (metros; el centro en 0, 0, 0)
# con su normal hacia afuera, el material y el número del sólido al que pertenece.

class Modelo:
    def __init__(self):
        self.caras = []        # (vértices Nx3, normal 3, material, sólido)
        self.solidos = 0
        self.contactos = []    # puntos donde las ruedas tocan el suelo

    def _nuevo(self):
        self.solidos += 1
        return self.solidos

    def cara(self, pts, normal, mat, sid):
        self.caras.append((np.asarray(pts, np.float64), np.asarray(normal, np.float64), mat, sid))

    def extruir(self, perfil, b0, b1, mat):
        """Perfil lateral (a, h) estirado a lo ancho entre b0 (derecha) y b1 (izquierda)."""
        sid = self._nuevo()
        p = np.asarray(perfil, np.float64)
        area = 0.5 * np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1])
        if area < 0:
            p = p[::-1]                     # antihorario: la normal de cada borde sale hacia afuera
        self.cara([(a, b1, h) for a, h in p], (0, 1, 0), mat, sid)
        self.cara([(a, b0, h) for a, h in p[::-1]], (0, -1, 0), mat, sid)
        for i in range(len(p)):
            (a0, h0), (a1, h1) = p[i], p[(i + 1) % len(p)]
            da, dh = a1 - a0, h1 - h0
            n = np.array([dh, 0.0, -da])
            if np.hypot(da, dh) < 1e-6:
                continue
            self.cara([(a0, b0, h0), (a1, b0, h1), (a1, b1, h1), (a0, b1, h0)], n / np.linalg.norm(n), mat, sid)
        return sid

    def caja(self, a0, a1, b0, b1, h0, h1, mat):
        return self.extruir([(a0, h0), (a1, h0), (a1, h1), (a0, h1)], b0, b1, mat)

    def cabina(self, a0, a1, a2, a3, hb, ht, wb, wr, mat):
        """Tronco: base (a0 adelante … a3 atrás, media anchura wb) a la altura hb y techo
        (a1 … a2, media anchura wr) a la altura ht."""
        sid = self._nuevo()
        B = [(a0, -wb, hb), (a0, wb, hb), (a3, wb, hb), (a3, -wb, hb)]
        T = [(a1, -wr, ht), (a1, wr, ht), (a2, wr, ht), (a2, -wr, ht)]

        def normal(q):
            q = np.asarray(q)
            n = np.cross(q[1] - q[0], q[2] - q[0])
            n = n / np.linalg.norm(n)
            centro = q.mean(0)
            if np.dot(n, centro - np.array([(a0 + a3) / 2, 0, (hb + ht) / 2])) < 0:
                n = -n
            return n

        for q in ([B[0], B[1], T[1], T[0]],   # parabrisas
                  [B[2], B[3], T[3], T[2]],   # vidrio de atrás
                  [B[1], B[2], T[2], T[1]],   # costado izquierdo
                  [B[3], B[0], T[0], T[3]],   # costado derecho
                  T):                         # techo
            self.cara(q, normal(q), mat, sid)
        return sid

    def rueda(self, a, b_centro, r, ancho, mat, lados=12):
        sid = self._nuevo()
        ang = np.pi / lados + np.arange(lados) * 2 * np.pi / lados - np.pi / 2
        # con este desfase la cara de abajo queda plana y tocando el suelo
        k = r / np.cos(np.pi / lados)
        pts = [(a + k * np.cos(t), r + k * np.sin(t)) for t in ang]
        b0, b1 = b_centro - ancho / 2, b_centro + ancho / 2
        self.cara([(x, b1, h) for x, h in pts], (0, 1, 0), mat, sid)
        self.cara([(x, b0, h) for x, h in pts[::-1]], (0, -1, 0), mat, sid)
        for i in range(lados):
            (x0, h0), (x1, h1) = pts[i], pts[(i + 1) % lados]
            m = np.array([(x0 + x1) / 2 - a, 0, (h0 + h1) / 2 - r])
            self.cara([(x0, b0, h0), (x1, b0, h1), (x1, b1, h1), (x0, b1, h0)], m / np.linalg.norm(m), mat, sid)
        for bb in (b0, b1):
            self.contactos.append((a, bb, 0.0))
        return sid


# ---------------------------------------------------------------------------------------------
# Materiales: función (a, b, h, normal) -> (color Nx3, tipo N). a, b, h son arrays de píxeles.

def pintado(color, tipo=PINTURA):
    col = c(color) if isinstance(color, str) else np.asarray(color, np.float32)

    def f(a, b, h, n):
        return np.broadcast_to(col, (len(a), 3)).copy(), np.full(len(a), tipo)
    return f


def mat_rueda(r, a_centro_de, llanta="cromo"):
    """Llanta negra con el rin gris y la tuerca central; la banda de rodadura, negra."""
    def f(a, b, h, n):
        col = np.broadcast_to(c("carbon"), (len(a), 3)).copy()
        if abs(n[1]) > 0.9:
            d = np.hypot(a - a_centro_de(a), h - r) / r
            col[d < 0.62] = c(llanta)
            col[d < 0.5] = c(llanta, 0.8)
            col[d < 0.2] = c("cromo_oscuro")
            col[(d > 0.62) & (d < 0.7)] = c("negro")
        return col, np.zeros(len(a), int)
    return f


def mezclar(k, c0, c1):
    k = np.clip(k, 0, 1)[:, None]
    return c0[None, :] * (1 - k) + c1[None, :] * k


def vidrio_col(u, v):
    """Color de un vidrio: u = altura relativa dentro del vidrio (0 abajo, 1 arriba),
    v = coordenada a lo largo, para la raya diagonal de brillo."""
    col = mezclar(u, c("vidrio_oscuro"), c("vidrio_brillo") * 0.95)
    raya = np.mod(v * 0.9 + u * 0.7, 1.6)
    col[(raya > 0.2) & (raya < 0.34)] = c("vidrio_brillo")
    return col


class Carro:
    """Carro pequeño de cuatro puertas. Todas las medidas en metros."""

    def __init__(self, largo=4.2, ancho=1.7, alto=1.5, color="gris", claro=None, oscuro=None,
                 tipo="hatch", r=0.29, ejes=(1.25, -1.25), piso=0.2, cintura=0.9, taxi=False,
                 franja=False):
        self.L, self.W, self.Hm = largo, ancho, alto
        self.col = color
        self.taxi = taxi
        self.franja = franja
        self.tipo = tipo
        self.r = r
        self.ejes = ejes
        self.piso = piso
        self.cintura = cintura
        self.w = ancho / 2

    # --- materiales de la carrocería ---
    def mat_cuerpo(self, a, b, h, n):
        L2, w = self.L / 2, self.w
        col = np.broadcast_to(c(self.col), (len(a), 3)).copy()
        tipo = np.zeros(len(a), int)
        abajo = h < self.piso + 0.17
        col[abajo] = c("asfalto")                       # bómper y faldón de plástico
        if abs(n[1]) > 0.7:                             # costados
            # moldura y franja de cuadros del taxi
            if self.franja:
                fr = (h > 0.6) & (h < 0.7)
                cuadro = (np.floor((a + 5) / 0.15).astype(int) % 2) == 0
                col[fr & cuadro] = c("negro")
                col[fr & ~cuadro] = c("blanco")
            else:
                col[(h > 0.62) & (h < 0.66)] = c(self.col, 0.7)
            # uniones de las puertas y manijas
            for x in self.puertas():
                col[(np.abs(a - x) < 0.03) & (h > self.piso + 0.17)] = c(self.col, 0.55)
            for x in self.puertas()[:2]:
                col[(np.abs(a - (x - 0.2)) < 0.07) & (h > 0.74) & (h < 0.79)] = c("negro")
            # la parte de atrás del guardabarros un poco más oscura: da volumen
        if n[0] > 0.6:                                  # trompa
            fb = np.abs(b)
            farola = (h > self.cintura - 0.28) & (h < self.cintura - 0.1) & (fb > w - 0.42) & (fb < w - 0.06)
            col[farola] = c("ventana_luz")
            col[farola & (fb > w - 0.3) & (fb < w - 0.18)] = c("blanco")
            tipo[farola] = LUZ_PROPIA
            rejilla = (h > self.piso + 0.2) & (h < self.cintura - 0.3) & (fb < w - 0.5)
            col[rejilla] = c("carbon")
            col[rejilla & (np.mod(h * 25, 1) < 0.5)] = c("negro")
            placa = (h > self.piso + 0.02) & (h < self.piso + 0.15) & (fb < 0.22)
            col[placa] = c("amarillo_via")
        if n[0] < -0.6:                                 # cola
            fb = np.abs(b)
            stop = (h > self.cintura - 0.3) & (h < self.cintura - 0.08) & (fb > w - 0.34) & (fb < w - 0.04)
            col[stop] = c("rojo")
            col[stop & (h > self.cintura - 0.2) & (h < self.cintura - 0.14)] = c("naranja")
            tipo[stop] = LUZ_PROPIA
            placa = (h > self.cintura - 0.34) & (h < self.cintura - 0.2) & (fb < 0.22)
            col[placa] = c("amarillo_via")
        return col, tipo

    def puertas(self):
        # uniones: bisagra delantera, entre puertas y detrás de la puerta trasera
        return [0.75, -0.25, -1.15]

    def mat_cabina(self, a, b, h, n, g):
        a0, a1, a2, a3, hb, ht, wb, wr = g
        col = np.broadcast_to(c(self.col), (len(a), 3)).copy()
        tipo = np.zeros(len(a), int)
        u = (h - hb) / (ht - hb)
        if n[2] > 0.9:                                   # techo
            return col, tipo
        if abs(n[1]) > 0.5:                              # costados: ventanas con parales
            af = a0 + (a1 - a0) * u
            ar = a3 + (a2 - a3) * u
            v = (u > 0.07) & (u < 0.86) & (a < af - 0.12) & (a > ar + 0.14)
            v &= np.abs(a - self.puertas()[1]) > 0.06     # paral del medio
            col[v] = vidrio_col((u[v] - 0.07) / 0.79, a[v] * 0.6)
            tipo[v] = VIDRIO
            col[(np.abs(a - self.puertas()[1]) <= 0.06) & (u > 0.07) & (u < 0.86)] = c("carbon")
        else:                                            # parabrisas y vidrio de atrás
            ancho = wb + (wr - wb) * u
            v = (u > 0.06) & (u < 0.9) & (np.abs(b) < ancho - 0.08)
            col[v] = vidrio_col((u[v] - 0.06) / 0.84, b[v] * 0.6)
            tipo[v] = VIDRIO
            if n[0] < 0:                                 # tercer stop arriba del vidrio de atrás
                s3 = (u > 0.9) & (u < 0.97) & (np.abs(b) < 0.18)
                col[s3] = c("rojo")
                tipo[s3] = LUZ_PROPIA
        return col, tipo

    def modelo(self):
        M = Modelo()
        L2, w, r, pi = self.L / 2, self.w, self.r, self.piso
        cin = self.cintura
        ra = r + 0.07                                   # radio del hueco de la rueda
        perfil = [(-L2 + 0.08, pi)]
        for e in sorted(self.ejes):
            perfil.append((e - ra, pi))
            for t in np.linspace(np.pi, 0, 9):
                perfil.append((e + ra * np.cos(t), max(r + ra * np.sin(t), pi)))
            perfil.append((e + ra, pi))
        # trompa: bómper, capó redondeado; cola según el tipo
        perfil += [(L2 - 0.1, pi), (L2, pi + 0.1), (L2, cin - 0.3), (L2 - 0.04, cin - 0.12),
                   (L2 - 0.2, cin - 0.03), (L2 - 0.6, cin)]
        if self.tipo == "sedan":
            perfil += [(-L2 + 0.5, cin + 0.04), (-L2 + 0.1, cin + 0.02), (-L2, cin - 0.1), (-L2, pi + 0.1)]
        else:
            perfil += [(-L2 + 0.1, cin), (-L2, cin - 0.08), (-L2, pi + 0.1)]
        M.extruir(perfil, -w, w, self.mat_cuerpo)
        # cabina
        if self.tipo == "sedan":
            g = (L2 - 1.35, L2 - 2.05, -L2 + 1.25, -L2 + 0.55, cin, self.Hm, w - 0.06, w - 0.2)
        elif self.tipo == "suv":
            g = (L2 - 1.15, L2 - 1.75, -L2 + 0.2, -L2 + 0.08, cin, self.Hm, w - 0.05, w - 0.15)
        else:
            g = (L2 - 1.2, L2 - 2.0, -L2 + 0.45, -L2 + 0.12, cin, self.Hm, w - 0.06, w - 0.2)
        M.cabina(*g, lambda a, b, h, n: self.mat_cabina(a, b, h, n, g))
        # espejos a los lados, en la base del parabrisas
        for s in (-1, 1):
            M.caja(g[0] - 0.22, g[0] - 0.06, s * (w - 0.02), s * (w + 0.14), cin + 0.06, cin + 0.2, pintado("carbon"))
        # ruedas
        for e in self.ejes:
            for s in (-1, 1):
                M.rueda(e, s * (w - 0.14), r, 0.2, mat_rueda(r, lambda a, e=e: e))
        # aviso del taxi en el techo (liso, sin letras) y parrilla de la camioneta
        if self.taxi:
            M.caja(-0.35, 0.0, -0.3, 0.3, self.Hm, self.Hm + 0.14, self.mat_aviso)
        if self.tipo == "suv":
            for s in (-1, 1):
                M.caja(g[2] + 0.1, g[1] - 0.1, s * (w - 0.26), s * (w - 0.2), self.Hm, self.Hm + 0.05, pintado("carbon"))
        return M

    def mat_aviso(self, a, b, h, n):
        col = np.broadcast_to(c("blanco"), (len(a), 3)).copy()
        tipo = np.zeros(len(a), int)
        if abs(n[0]) > 0.6:
            col[:] = c("ventana_luz")
            tipo[:] = LUZ_PROPIA
        col[h < self.Hm + 0.035] = c("carbon")
        return col, tipo


# ---------------------------------------------------------------------------------------------
# Bus urbano (tipo SITP): azul, franja clara en el techo, fila de ventanas, dos puertas a la
# derecha, parabrisas grande y el tablero de ruta prendido (sin letras).

class Bus:
    L, W, Hm = 11.0, 2.5, 3.1
    r = 0.5
    ejes = (3.2, -2.5)
    piso = 0.3

    def mat(self, a, b, h, n):
        L2, w = self.L / 2, self.W / 2
        col = np.broadcast_to(c("azul_sitp"), (len(a), 3)).copy()
        tipo = np.zeros(len(a), int)
        col[h > 2.62] = c("blanco")
        col[(h > 2.55) & (h <= 2.62)] = c("azul_sitp_oscuro")
        col[h < 0.62] = c("azul_sitp_oscuro")
        col[h < 0.4] = c("asfalto")
        if n[2] > 0.9:
            col[:] = c("concreto_claro")
            return col, tipo
        if abs(n[1]) > 0.7:
            u = (h - 1.35) / (2.45 - 1.35)
            vent = (u > 0) & (u < 1) & (a > -L2 + 0.35) & (a < L2 - 0.25)
            vent &= np.mod(a + 0.3, 1.45) > 0.13         # parales entre ventanas
            ventana = vidrio_col(np.clip(u, 0, 1), a * 0.5)
            col[vent] = ventana[vent]
            tipo[vent] = VIDRIO
            if n[1] < 0:                                   # costado derecho: puertas
                for p0, p1 in ((3.85, 4.95), (-0.55, 0.65)):
                    pu = (a > p0) & (a < p1) & (h > 0.42) & (h < 2.5)
                    marco = pu & ((a < p0 + 0.07) | (a > p1 - 0.07) | (np.abs(a - (p0 + p1) / 2) < 0.04) | (h > 2.43))
                    vid = pu & ~marco
                    col[vid] = vidrio_col((h[vid] - 0.42) / 2.08, a[vid] * 0.5)
                    tipo[vid] = VIDRIO
                    col[marco] = c("carbon")
            # luces laterales ámbar abajo
            lat = (h > 0.5) & (h < 0.56) & (np.mod(a, 2.4) < 0.12)
            col[lat] = c("naranja")
            tipo[lat] = LUZ_PROPIA
        elif n[0] > 0.5:                                    # frente
            fb = np.abs(b)
            pb = (h > 0.95) & (h < 2.5) & (fb < w - 0.1)
            col[pb] = vidrio_col((h[pb] - 0.95) / 1.55, b[pb] * 0.5)
            tipo[pb] = VIDRIO
            col[pb & (fb < 0.04)] = c("carbon")
            ruta = (h > 2.62) & (h < 2.9) & (fb < w - 0.35)
            col[ruta] = c("carbon")
            led = ruta & (h > 2.68) & (h < 2.84) & (fb < w - 0.45)
            col[led] = c("sodio")
            tipo[led] = LUZ_PROPIA
            far = (h > 0.5) & (h < 0.7) & (fb > w - 0.5) & (fb < w - 0.1)
            col[far] = c("ventana_luz")
            col[far & (fb > w - 0.25)] = c("blanco")
            tipo[far] = LUZ_PROPIA
            placa = (h > 0.44) & (h < 0.58) & (fb < 0.25)
            col[placa] = c("amarillo_via")
        elif n[0] < -0.5:                                   # cola
            fb = np.abs(b)
            vt = (h > 1.8) & (h < 2.45) & (fb < w - 0.35)
            col[vt] = vidrio_col((h[vt] - 1.8) / 0.65, b[vt] * 0.5) * 0.8
            tipo[vt] = VIDRIO
            motor = (h > 0.7) & (h < 1.4) & (fb < w - 0.55)
            col[motor] = c("azul_sitp_oscuro")
            col[motor & (np.mod(h * 12, 1) < 0.45)] = c("carbon")
            stop = (h > 0.6) & (h < 1.35) & (fb > w - 0.3) & (fb < w - 0.08)
            col[stop] = c("rojo")
            col[stop & (h > 1.1)] = c("naranja")
            tipo[stop] = LUZ_PROPIA
            placa = (h > 0.45) & (h < 0.59) & (fb < 0.25)
            col[placa] = c("amarillo_via")
        return col, tipo

    def modelo(self):
        M = Modelo()
        L2, w, r, pi = self.L / 2, self.W / 2, self.r, self.piso
        ra = r + 0.08
        perfil = [(-L2 + 0.05, pi)]
        for e in sorted(self.ejes):
            perfil.append((e - ra, pi))
            for t in np.linspace(np.pi, 0, 11):
                perfil.append((e + ra * np.cos(t), max(r + ra * np.sin(t), pi)))
            perfil.append((e + ra, pi))
        perfil += [(L2 - 0.05, pi), (L2, pi + 0.15), (L2, 2.55), (L2 - 0.06, 2.95), (L2 - 0.25, self.Hm),
                   (-L2 + 0.25, self.Hm), (-L2 + 0.04, 2.95), (-L2, 2.6), (-L2, pi + 0.15)]
        M.extruir(perfil, -w, w, self.mat)
        # espejos grandes adelante, colgados de un brazo
        for s in (-1, 1):
            M.caja(L2 - 0.05, L2 + 0.25, s * (w - 0.1), s * (w + 0.02), 2.55, 2.63, pintado("carbon"))
            M.caja(L2 + 0.1, L2 + 0.25, s * (w + 0.02), s * (w + 0.2), 1.9, 2.6, pintado("carbon"))
        # aire acondicionado en el techo
        M.caja(-1.0, 1.4, -0.8, 0.8, self.Hm, self.Hm + 0.14, pintado("concreto_claro"))
        for e in self.ejes:
            for s in (-1, 1):
                M.rueda(e, s * (w - 0.22), r, 0.32, mat_rueda(r, lambda a, e=e: e, llanta="concreto"))
        return M


# ---------------------------------------------------------------------------------------------
# Camión pequeño de furgón (zona industrial): cabina roja, furgón blanco con puertas atrás.

class Camion:
    L, W, Hm = 7.0, 2.3, 3.0
    r = 0.45
    ejes = (2.45, -1.9)

    def mat_cab(self, a, b, h, n):
        col = np.broadcast_to(c("rojo"), (len(a), 3)).copy()
        tipo = np.zeros(len(a), int)
        col[h < 0.62] = c("asfalto")
        fb = np.abs(b)
        if n[0] > 0.3 and h.size and n[2] > 0.2:             # parabrisas inclinado
            u = (h - 1.45) / (2.35 - 1.45)
            v = (u > 0.05) & (u < 0.92) & (fb < 1.0)
            col[v] = vidrio_col(u[v], b[v] * 0.5)
            tipo[v] = VIDRIO
        elif n[0] > 0.6:                                     # frente
            far = (h > 0.72) & (h < 0.92) & (fb > 0.62) & (fb < 1.0)
            col[far] = c("ventana_luz")
            col[far & (fb > 0.75) & (fb < 0.88)] = c("blanco")
            tipo[far] = LUZ_PROPIA
            rej = (h > 0.7) & (h < 1.3) & (fb < 0.5)
            col[rej] = c("carbon")
            col[rej & (np.mod(h * 14, 1) < 0.5)] = c("negro")
            placa = (h > 0.44) & (h < 0.58) & (fb < 0.24)
            col[placa] = c("amarillo_via")
        elif abs(n[1]) > 0.7:                                 # puertas de la cabina
            u = (h - 1.5) / (2.25 - 1.5)
            ventana = (u > 0) & (u < 1) & (a > 2.25) & (a < 3.05 + 0.2 * (1 - u))
            col[ventana] = vidrio_col(u[ventana], a[ventana] * 0.6)
            tipo[ventana] = VIDRIO
            col[(np.abs(a - 2.15) < 0.03) & (h > 0.62)] = c("rojo", 0.55)
            col[(a > 2.3) & (a < 2.5) & (h > 1.3) & (h < 1.36)] = c("negro")
        return col, tipo

    def mat_caja(self, a, b, h, n):
        col = np.broadcast_to(c("hueso"), (len(a), 3)).copy()
        tipo = np.zeros(len(a), int)
        if n[2] > 0.9:
            col[:] = c("concreto_claro")
            return col, tipo
        col[(h > 1.02) & (h < 1.1)] = c("concreto")         # refuerzos del furgón
        col[(h > 2.85)] = c("concreto_claro")
        if abs(n[1]) > 0.7:
            col[np.mod(a + 3.5, 1.1) < 0.05] = c("concreto")
        if n[0] < -0.6:                                     # puertas de atrás
            fb = np.abs(b)
            col[fb < 0.03] = c("carbon")
            col[(fb > 1.05)] = c("concreto")
            for hh in (1.3, 2.4):
                col[(np.abs(h - hh) < 0.05) & (fb > 0.12) & (fb < 0.32)] = c("cromo")
            col[(fb > 0.08) & (fb < 0.12) & (h > 1.2) & (h < 2.6)] = c("cromo_oscuro")
        return col, tipo

    def mat_chasis(self, a, b, h, n):
        col = np.broadcast_to(c("carbon"), (len(a), 3)).copy()
        tipo = np.zeros(len(a), int)
        if n[0] < -0.6:
            fb = np.abs(b)
            stop = (h > 0.62) & (h < 0.82) & (fb > 0.72) & (fb < 1.05)
            col[stop] = c("rojo")
            col[stop & (fb < 0.84)] = c("naranja")
            tipo[stop] = LUZ_PROPIA
            placa = (h > 0.6) & (h < 0.75) & (fb < 0.24)
            col[placa] = c("amarillo_via")
        return col, tipo

    def modelo(self):
        M = Modelo()
        L2, w, r = self.L / 2, self.W / 2, self.r
        ra = r + 0.08
        fe = self.ejes[0]
        # cabina con el hueco de la rueda delantera
        perfil = [(2.05, 0.45), (fe - ra, 0.45)]
        for t in np.linspace(np.pi, 0, 11):
            perfil.append((fe + ra * np.cos(t), max(r + ra * np.sin(t), 0.45)))
        perfil += [(fe + ra, 0.45), (L2 - 0.05, 0.45), (L2, 0.55), (L2, 1.35), (L2 - 0.05, 1.45),
                   (L2 - 0.4, 2.35), (L2 - 0.5, 2.45), (2.1, 2.5), (2.05, 2.4)]
        M.extruir(perfil, -(w - 0.05), w - 0.05, self.mat_cab)
        # furgón
        M.caja(-L2, 1.95, -w, w, 0.95, self.Hm, self.mat_caja)
        # chasís y bómper de atrás
        M.caja(-L2 + 0.1, 2.1, -0.55, 0.55, 0.5, 0.95, self.mat_chasis)
        M.caja(-L2 + 0.02, -L2 + 0.2, -w + 0.1, w - 0.1, 0.55, 0.85, self.mat_chasis)
        # guardabarros de atrás
        re = self.ejes[1]
        for s in (-1, 1):
            M.caja(re - 0.6, re + 0.6, s * (w - 0.55), s * (w - 0.02), 0.9, 0.97, pintado("carbon"))
        # espejos
        for s in (-1, 1):
            M.caja(2.95, 3.05, s * (w - 0.1), s * (w + 0.2), 1.55, 2.1, pintado("carbon"))
        for s in (-1, 1):
            M.rueda(fe, s * (w - 0.3), r, 0.28, mat_rueda(r, lambda a: fe, llanta="concreto"))
            M.rueda(re, s * (w - 0.33), r, 0.5, mat_rueda(r, lambda a: re, llanta="concreto"))  # doble
        return M


# ---------------------------------------------------------------------------------------------
# Rasterizador: proyección ortográfica con la cámara inclinada `elev` grados hacia abajo.

def render(M, fw, fh, yaw_deg, elev_deg):
    phi, e = np.radians(yaw_deg), np.radians(elev_deg)
    f = np.array([np.sin(phi), -np.cos(phi), 0.0])     # trompa en el mundo
    l = np.array([np.cos(phi), np.sin(phi), 0.0])      # izquierda del vehículo
    z = np.array([0.0, 0.0, 1.0])
    se, ce = np.sin(e), np.cos(e)
    k = PPM * S
    W, H = fw * S, fh * S

    def mundo(p):
        p = np.atleast_2d(p)
        return p[:, :1] * f + p[:, 1:2] * l + p[:, 2:3] * z

    def proy(pw):
        sx = pw[:, 0]
        su = pw[:, 1] * se + pw[:, 2] * ce
        dep = pw[:, 1] * ce - pw[:, 2] * se
        return sx, su, dep

    # la rueda más cercana toca la penúltima fila del cuadro
    _, su_c, _ = proy(mundo(np.array(M.contactos)))
    base = (fh - 1) * S + su_c.min() * k

    rgb = np.zeros((H, W, 3), np.float32)
    zbuf = np.full((H, W), np.inf, np.float32)
    sid_buf = np.zeros((H, W), np.int32)
    V = np.array([0.0, -ce, se])                       # hacia la cámara
    for pts, n, mat, sid in M.caras:
        nw = mundo(n)[0]
        if np.dot(nw, V) <= 1e-4:
            continue
        pw = mundo(pts)
        sx, su, dep = proy(pw)
        px = W / 2 + sx * k
        py = base - su * k
        x0, x1 = int(np.floor(px.min())), int(np.ceil(px.max())) + 1
        y0, y1 = int(np.floor(py.min())), int(np.ceil(py.max())) + 1
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, W), min(y1, H)
        if x1 <= x0 or y1 <= y0:
            continue
        im = Image.new("L", (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(im).polygon([(x - x0, y - y0) for x, y in zip(px, py)], fill=255)
        m = np.array(im) > 127
        if not m.any():
            continue
        A = np.column_stack([px, py, np.ones_like(px)])
        coef = np.linalg.lstsq(A, dep, rcond=None)[0]
        yy, xx = np.nonzero(m)
        cx, cy = xx + x0 + 0.5, yy + y0 + 0.5
        d = coef[0] * cx + coef[1] * cy + coef[2]
        cerca = d < zbuf[yy + y0, xx + x0]
        if not cerca.any():
            continue
        cx, cy, d, yy, xx = cx[cerca], cy[cerca], d[cerca], yy[cerca] + y0, xx[cerca] + x0
        # punto del vehículo en cada píxel
        sxp = (cx - W / 2) / k
        sup = (base - cy) / k
        X = sxp
        Y = sup * se + d * ce
        Z = sup * ce - d * se
        a = X * f[0] + Y * f[1]
        b = X * l[0] + Y * l[1]
        col, tipo = mat(a, b, Z, n)
        # sombreado: luz difusa + ambiente, un poco más oscuro abajo (volumen)
        luz = 0.62 + 0.48 * max(np.dot(nw, LUZ), 0.0)
        luz = luz * (0.86 + 0.14 * np.clip(Z / 1.6, 0, 1))
        sh = col * luz[:, None]
        if n[2] > 0.9:
            sh = sh * 1.04
        vid = tipo == VIDRIO
        sh[vid] = col[vid] * (0.8 + 0.3 * max(n[2], 0) + 0.15 * max(np.dot(nw, LUZ), 0))
        prop = tipo == LUZ_PROPIA
        sh[prop] = col[prop]
        rgb[yy, xx] = np.clip(sh, 0, 255)
        zbuf[yy, xx] = d
        sid_buf[yy, xx] = sid

    lleno = np.isfinite(zbuf)
    # línea oscura donde una pieza tapa a otra que está bastante más atrás
    zz = np.where(lleno, zbuf, 1e9)
    borde = np.zeros_like(lleno)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        for paso in (1, 2, 3):
            vec = np.roll(np.roll(zz, dy * paso, 0), dx * paso, 1)
            vs = np.roll(np.roll(sid_buf, dy * paso, 0), dx * paso, 1)
            borde |= lleno & (vec < zz - 0.12) & (vs != sid_buf)
    rgb[borde] *= 0.25
    return reducir(rgb, lleno, fw, fh)


def reducir(rgb, lleno, fw, fh):
    """De 4× al tamaño final, contorno negro de 1 px y paleta."""
    a = lleno.astype(np.float32).reshape(fh, S, fw, S).mean(axis=(1, 3))
    pre = (rgb * lleno[..., None]).reshape(fh, S, fw, S, 3).mean(axis=(1, 3))
    col = pre / np.maximum(a, 1e-6)[..., None]
    m = a >= 0.5
    mp = np.pad(m, 1)
    borde = (mp[:-2, 1:-1] | mp[2:, 1:-1] | mp[1:-1, :-2] | mp[1:-1, 2:]) & ~m
    col[borde] = P["negro"]
    q = cuantizar(col, 4.0)
    alfa = ((m | borde) * 255).astype(np.uint8)
    return np.dstack([q, alfa])


# ---------------------------------------------------------------------------------------------

def hoja(modelos, fw, fh, elev):
    img = np.zeros((fh * len(modelos), fw * VISTAS, 4), np.uint8)
    for fila, M in enumerate(modelos):
        for kk in range(VISTAS):
            img[fila * fh:(fila + 1) * fh, kk * fw:(kk + 1) * fw] = render(M, fw, fh, kk * 45.0, elev)
    return img


def main():
    taxi = Carro(color="amarillo_taxi", tipo="hatch", taxi=True, franja=True, largo=4.0, ejes=(1.2, -1.22))
    carro = Carro(color="concreto_claro", tipo="sedan", largo=4.3, ejes=(1.3, -1.3))
    rojo = Carro(color="vinotinto", tipo="suv", largo=4.2, alto=1.65, r=0.32, piso=0.26,
                 cintura=0.98, ejes=(1.3, -1.28))
    chicos = hoja([taxi.modelo(), carro.modelo(), rojo.modelo()], 80, 40, 10.0)
    grandes = hoja([Bus().modelo(), Camion().modelo()], 176, 64, 6.0)
    TEX.mkdir(parents=True, exist_ok=True)
    Image.fromarray(chicos, "RGBA").save(TEX / "vehiculos.png")
    print("generado: assets/texturas/vehiculos.png", chicos.shape[1], "x", chicos.shape[0])
    Image.fromarray(grandes, "RGBA").save(TEX / "vehiculos_grandes.png")
    print("generado: assets/texturas/vehiculos_grandes.png", grandes.shape[1], "x", grandes.shape[0])

    # hoja de revisión: las dos hojas a 3× sobre gris medio
    esc = 3
    ancho = max(chicos.shape[1], grandes.shape[1]) * esc + 20
    alto = (chicos.shape[0] + grandes.shape[0]) * esc + 30
    prev = Image.new("RGBA", (ancho, alto), (110, 110, 116, 255))
    for i, (h, y) in enumerate(((chicos, 10), (grandes, 20 + chicos.shape[0] * esc))):
        im = Image.fromarray(h, "RGBA").resize((h.shape[1] * esc, h.shape[0] * esc), Image.NEAREST)
        prev.alpha_composite(im, (10, y))
    PREVIA.parent.mkdir(parents=True, exist_ok=True)
    prev.convert("RGB").save(PREVIA)
    print("previa:", PREVIA)


if __name__ == "__main__":
    main()
