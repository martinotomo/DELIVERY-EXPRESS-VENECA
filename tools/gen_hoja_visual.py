"""Hoja de dirección visual (F2): todas las piezas del juego en una sola imagen para revisarlas.

Arma docs/direccion_visual/hoja.png con la paleta (nombre y hex), la fuente, el logo, los tres
puestos de mando, las motos del taller, las caídas dibujadas, el tráfico, las fachadas, los cerros,
la gente y las señales. Si existen capturas del juego en docs/direccion_visual/capturas/ (las copia
tools/capturas.gd o se ponen a mano), se agregan como maqueta del HUD.

    python tools/gen_hoja_visual.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from paleta import PALETA

RAIZ = Path(__file__).resolve().parent.parent
A = RAIZ / "assets"
DOCS = RAIZ / "docs" / "direccion_visual"
FUENTE = A / "fuentes" / "PressStart2P-Regular.ttf"
ANCHO = 1920
FONDO = PALETA["carbon"]
TEXTO = PALETA["blanco"]
GRIS = PALETA["concreto_claro"]


class Hoja:
    def __init__(self):
        self.img = Image.new("RGB", (ANCHO, 8000), FONDO)
        self.d = ImageDraw.Draw(self.img)
        self.f8 = ImageFont.truetype(str(FUENTE), 8)
        self.f16 = ImageFont.truetype(str(FUENTE), 16)
        self.f24 = ImageFont.truetype(str(FUENTE), 24)
        self.y = 24

    def titulo(self, texto, sub=""):
        self.y += 16
        self.d.text((24, self.y), texto, font=self.f16, fill=PALETA["amarillo_via"] if "amarillo_via" in PALETA else TEXTO)
        if sub:
            self.d.text((24, self.y + 24), sub, font=self.f8, fill=GRIS)
        self.y += 44 if sub else 32

    def fila(self, imagenes, escala=1, sep=16, rotulos=None, fondo=None):
        x = 24
        alto = 0
        for k, im in enumerate(imagenes):
            im = im.convert("RGBA")
            if escala != 1:
                im = im.resize((im.width * escala, im.height * escala), Image.NEAREST)
            if x + im.width > ANCHO - 24:
                self.y += alto + sep + (14 if rotulos else 0)
                x, alto = 24, 0
            if fondo is not None:
                self.d.rectangle((x, self.y, x + im.width - 1, self.y + im.height - 1), fill=fondo)
            self.img.paste(im, (x, self.y), im)
            if rotulos:
                self.d.text((x, self.y + im.height + 4), rotulos[k], font=self.f8, fill=GRIS)
            x += im.width + sep
            alto = max(alto, im.height)
        self.y += alto + sep + (14 if rotulos else 0)

    def recortar(self):
        return self.img.crop((0, 0, ANCHO, self.y + 16))


def cargar(ruta):
    return Image.open(ruta)


def main():
    h = Hoja()
    h.d.text((24, h.y), "DELIVERY EXPRESS - DIRECCION VISUAL (F2)", font=h.f24, fill=TEXTO)
    h.d.text((24, h.y + 36), "Tomás Ardila Marín  ·  Escuela Colombiana de Ingeniería Julio Garavito  ·  todo generado por código (tools/)",
             font=h.f8, fill=GRIS)
    h.y += 60

    h.titulo("PALETA", f"{len(PALETA)} colores en tools/paleta.py: única fuente del color; todo se cuantiza contra ella")
    x = 24
    for nombre, rgb in PALETA.items():
        if x + 140 > ANCHO - 24:
            x = 24
            h.y += 76
        h.d.rectangle((x, h.y, x + 131, h.y + 40), fill=rgb, outline=PALETA["negro"])
        h.d.text((x, h.y + 46), nombre[:16], font=h.f8, fill=TEXTO)
        h.d.text((x, h.y + 58), "#%02x%02x%02x" % rgb, font=h.f8, fill=GRIS)
        x += 140
    h.y += 90

    h.titulo("FUENTE", "Press Start 2P (SIL OFL 1.1), a 8, 16 y 32 px enteros")
    for tam in (8, 16, 32):
        h.d.text((24, h.y), "Has muerto al entrar demasiado rapido en la curva 0123456789 $", font=ImageFont.truetype(str(FUENTE), tam), fill=TEXTO)
        h.y += tam + 12
    h.y += 8

    h.titulo("LOGO", "tools/gen_logo.py  (assets/ui/logo.png, 640x360)")
    h.fila([cargar(DOCS / "logo_preview.png").resize((1280, 720), Image.NEAREST).crop((0, 160, 1280, 560))])

    h.titulo("PUESTOS DE MANDO (D24)", "tools/gen_manubrios.py: Bwis, NKD y Ninja, a 2x")
    h.fila([cargar(A / "ui" / f) for f in ("manubrio.png", "manubrio_nkd.png", "manubrio_ninja.png")], escala=2,
           rotulos=["Bwis", "NKD 125", "Ninja 300"], fondo=PALETA["cielo_dia"] if "cielo_dia" in PALETA else GRIS)

    h.titulo("MOTOS DEL TALLER (D21, solo uso privado)", "assets/ui/motos_taller.png")
    h.fila([cargar(A / "ui" / "motos_taller.png")], escala=2)

    h.titulo("CAIDA DIBUJADA (cinematica)", "tools/gen_cinematica.py: una por moto, 320x180 a 2x")
    h.fila([cargar(A / "ui" / f"cinematica_{m}.png") for m in ("bws", "nkd", "ninja")], escala=2, sep=8,
           rotulos=["Bwis", "NKD 125", "Ninja 300"])

    h.titulo("TRAFICO", "tools/gen_vehiculos.py: 8 direcciones por vehiculo (0 = de frente), 14 px/m, a 2x")
    h.fila([cargar(A / "texturas" / "vehiculos.png")], escala=2, fondo=PALETA["gris"])
    h.fila([cargar(A / "texturas" / "vehiculos_grandes.png").resize((1408, 128))], escala=1, fondo=PALETA["gris"])

    h.titulo("FACHADAS POR ZONA (D26)", "tools/gen_texturas.py: 128x128 = 8 x 6,4 m, a 2x; abajo, su mascara de noche")
    tipos = ("casa", "ladrillo", "concreto", "vidrio", "bodega")
    h.fila([cargar(A / "texturas" / f"fachada_{t}.png") for t in tipos], escala=2, rotulos=list(tipos))
    h.fila([cargar(A / "texturas" / f"fachada_{t}_luz.png") for t in tipos], escala=1)

    h.titulo("CERROS ORIENTALES", "tools/gen_cerros.py: panorama que empalma a lo ancho")
    cerros = cargar(A / "texturas" / "cerros.png").convert("RGBA")
    cielo = Image.new("RGBA", cerros.size, PALETA.get("cielo_dia", (120, 160, 200)) + (255,))
    cielo.alpha_composite(cerros)
    h.fila([cielo.resize((1792, 280), Image.NEAREST)])

    h.titulo("GENTE Y SENALES", "peatones (6 ropas x 4 cuadros) y senales de transito, a 3x")
    h.fila([cargar(A / "texturas" / "peatones.png")] + [cargar(A / "texturas" / f"senal_{s}.png") for s in ("pare", "peatones", "velocidad")],
           escala=3, fondo=PALETA["gris"])

    capturas = sorted((DOCS / "capturas").glob("*.png")) if (DOCS / "capturas").exists() else []
    if capturas:
        h.titulo("MAQUETA DEL HUD Y ESCENAS (capturas del juego)", "640x360: mundo a 320x180 escalado entero, interfaz aparte")
        h.fila([cargar(c) for c in capturas], rotulos=[c.stem for c in capturas])

    h.recortar().save(DOCS / "hoja.png")
    print("generado: docs/direccion_visual/hoja.png")


if __name__ == "__main__":
    main()
