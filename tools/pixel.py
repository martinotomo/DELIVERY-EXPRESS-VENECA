"""Utilidades de pixel art por código: cuantizar a la paleta con dithering ordenado Bayer 4×4."""
import numpy as np
from PIL import Image

from paleta import LISTA

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5
_PAL = np.array(LISTA, dtype=np.float32)


def cuantizar(rgb: np.ndarray, fuerza: float = 18.0) -> np.ndarray:
    """rgb: (h, w, 3) float 0-255. Devuelve uint8 cuantizado a la paleta con dithering."""
    h, w, _ = rgb.shape
    umbral = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w, None] * fuerza
    x = np.clip(rgb + umbral, 0, 255)
    d = ((x[:, :, None, :] - _PAL[None, None, :, :]) ** 2).sum(-1)
    return _PAL[d.argmin(-1)].astype(np.uint8)


def guardar(rgb: np.ndarray, ruta, alfa: np.ndarray | None = None, fuerza: float = 18.0) -> None:
    q = cuantizar(rgb.astype(np.float32), fuerza)
    if alfa is None:
        Image.fromarray(q, "RGB").save(ruta)
    else:
        a = (alfa > 0.5).astype(np.uint8) * 255
        Image.fromarray(np.dstack([q, a]), "RGBA").save(ruta)
