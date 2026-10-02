"""Letra del juego: Press Start 2P con las mayúsculas con tilde de tamaño completo.

    python tools/gen_fuente.py

En Press Start 2P las mayúsculas con tilde (Á É Í Ó Ú Ü Ñ) se encogen a 5 píxeles de alto para
que la tilde quepa en el cuadro de 8, y al lado de las demás letras (7 de alto) se ven más
pequeñas («CRÉDITOS», Tomás 02/10/2026). Aquí cada una se rehace con la letra base completa y la
tilde de un píxel de alto justo encima, en la fila vacía que deja la línea de arriba.

La licencia (SIL OFL 1.1) deja modificarla, pero la versión modificada no puede llamarse
«Press Start 2P» (nombre reservado): se llama «Delivery Press». Sale en
assets/fuentes/DeliveryPress-Regular.ttf, junto a la original y su OFL.txt.
"""
from pathlib import Path

from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

RAIZ = Path(__file__).resolve().parent.parent
ORIGINAL = RAIZ / "assets" / "fuentes" / "PressStart2P-Regular.ttf"
SALIDA = RAIZ / "assets" / "fuentes" / "DeliveryPress-Regular.ttf"
NOMBRE = "Delivery Press"
P = 125  # un píxel en unidades de la letra (1000 por cuadro de 8)
TOPE = 1000  # techo de las mayúsculas

# Tilde de 1 píxel de alto (filas de píxeles de izquierda a derecha, en columnas 0..6).
ACENTOS = {
    "agudo": [4, 5],
    "dieresis": [1, 2, 4, 5],
    "virgulilla": [1, 2, 3, 4, 5],
}
LETRAS = {
    "Á": ("A", "agudo"), "É": ("E", "agudo"), "Í": ("I", "agudo"), "Ó": ("O", "agudo"),
    "Ú": ("U", "agudo"), "Ü": ("U", "dieresis"), "Ñ": ("N", "virgulilla"),
}


def main():
    f = TTFont(ORIGINAL)
    cmap = f.getBestCmap()
    glyf = f["glyf"]
    gs = f.getGlyphSet()
    for letra, (base, acento) in LETRAS.items():
        nombre = cmap[ord(letra)]
        grabado = DecomposingRecordingPen(gs)
        gs[cmap[ord(base)]].draw(grabado)
        pluma = TTGlyphPen(gs)
        grabado.replay(pluma)
        for col in ACENTOS[acento]:
            x0, y0 = col * P, TOPE
            pluma.moveTo((x0, y0))
            pluma.lineTo((x0, y0 + P))
            pluma.lineTo((x0 + P, y0 + P))
            pluma.lineTo((x0 + P, y0))
            pluma.closePath()
        glyf[nombre] = pluma.glyph()
    # La caja de cada glifo cambió: que maxp y head se recalculen al guardar.
    for registro in f["name"].names:
        texto = registro.toUnicode()
        if "Press Start 2P" in texto or "PressStart2P" in texto:
            registro.string = texto.replace("Press Start 2P", NOMBRE).replace("PressStart2P", NOMBRE.replace(" ", ""))
    f["head"].yMax = max(f["head"].yMax, TOPE + P)
    f.save(SALIDA)
    print("generado:", SALIDA.relative_to(RAIZ))


if __name__ == "__main__":
    main()
