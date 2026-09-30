"""Comprueba las voces de assets/voces/ (sintéticas o grabadas por Tomás).

    python tools/medir_voces.py            # sale 0 solo si todas cumplen
    python tools/medir_voces.py CARPETA    # mide otra carpeta

Para cada archivo que el juego espera (según scripts/voces.gd): que exista, que sea WAV mono
44,1 kHz 16 bits, RMS a ±2 dB de −20 dBFS, pico ≤ −1 dBFS, duración razonable y que los
primeros y los últimos 0,08 s estén casi en silencio (≤ −45 dBFS de RMS).
"""
import sys
from pathlib import Path

import numpy as np

from gen_voces import (PICO_MAX_DB, RMS_OBJETIVO_DB, SALIDA, SR, db, leer_wav, lista_esperada,
                       rms)

TOLERANCIA_DB = 2.0
BORDE_S = 0.08
BORDE_MAX_DB = -45.0
DURACION = (0.5, 8.0)


def revisar(ruta):
    """Lista de problemas del archivo (vacía si está bien) y sus medidas."""
    if not ruta.exists():
        return ["no existe"], {}
    try:
        x, sr, info = leer_wav(ruta)
    except Exception as e:  # noqa: BLE001 - cualquier WAV ilegible es una falla
        return [f"no se puede leer ({e})"], {}
    fallas = []
    if info["canales"] != 1:
        fallas.append(f"{info['canales']} canales (debe ser mono)")
    if sr != SR:
        fallas.append(f"{sr} Hz (debe ser {SR})")
    if info["bits"] != 16:
        fallas.append(f"{info['bits']} bits (debe ser 16)")
    dur = len(x) / sr
    m = {"dur": dur, "rms": db(rms(x)), "pico": db(np.max(np.abs(x)) if len(x) else 0)}
    n = int(BORDE_S * sr)
    m["ini"] = db(rms(x[:n]))
    m["fin"] = db(rms(x[-n:]))
    if not DURACION[0] <= dur <= DURACION[1]:
        fallas.append(f"dura {dur:.2f} s (entre {DURACION[0]} y {DURACION[1]})")
    if abs(m["rms"] - RMS_OBJETIVO_DB) > TOLERANCIA_DB:
        fallas.append(f"RMS {m['rms']:.1f} dBFS (objetivo {RMS_OBJETIVO_DB:.0f} ± {TOLERANCIA_DB:.0f})")
    if m["pico"] > PICO_MAX_DB + 0.05:
        fallas.append(f"pico {m['pico']:.1f} dBFS (máx. {PICO_MAX_DB:.0f})")
    if m["ini"] > BORDE_MAX_DB:
        fallas.append(f"no empieza en silencio ({m['ini']:.0f} dBFS)")
    if m["fin"] > BORDE_MAX_DB:
        fallas.append(f"no termina en silencio ({m['fin']:.0f} dBFS)")
    return fallas, m


def main(argv):
    carpeta = Path(argv[0]) if argv else SALIDA
    esperados = lista_esperada()
    mal = 0
    rmss, picos, durs = [], [], []
    for nombre, *_ in esperados:
        fallas, m = revisar(carpeta / nombre)
        if fallas:
            mal += 1
            print(f"MAL  {nombre}: {'; '.join(fallas)}")
        if m:
            rmss.append(m["rms"])
            picos.append(m["pico"])
            durs.append(m["dur"])
    extra = sorted({p.name for p in carpeta.glob("*.wav")} - {n for n, *_ in esperados})
    for e in extra:
        print(f"AVISO  {e}: el juego no lo usa (¿nombre mal escrito?)")
    if rmss:
        print(f"medir_voces: {len(esperados) - mal}/{len(esperados)} bien · RMS {min(rmss):.1f} a "
              f"{max(rmss):.1f} dBFS · pico máx. {max(picos):.1f} dBFS · duración "
              f"{min(durs):.2f}–{max(durs):.2f} s")
    if mal == 0:
        print("medir_voces: todo bien")
    return 1 if mal else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
