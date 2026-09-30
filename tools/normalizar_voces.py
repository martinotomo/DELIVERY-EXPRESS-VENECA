"""Deja las grabaciones de Tomás en el formato del juego.

    python tools/normalizar_voces.py              # arregla los WAV de assets/voces/
    python tools/normalizar_voces.py CARPETA      # toma los WAV de CARPETA y los deja en assets/voces/
    python tools/normalizar_voces.py --forzar     # procesa también los que ya están bien

Para cada WAV: lo pasa a mono 44,1 kHz 16 bits, recorta el silencio del principio y del final,
quita los graves por debajo de ~90 Hz (los portátiles no los suenan y solo meten retumbe),
iguala el volumen (RMS ≈ −20 dBFS, pico ≤ −1 dBFS) y deja 0,10 s de silencio a cada lado.

Avisa si una grabación satura (se grabó demasiado fuerte), es muy bajita o muy larga, y dice
qué archivos esperados (según scripts/voces.gd) faltan. Es idempotente: un archivo que ya
cumple (medir_voces.py no le encuentra nada) no se toca, así que se puede correr las veces
que se quiera.
"""
import sys
from pathlib import Path

import numpy as np

from gen_voces import (SALIDA, SR, a_44k, db, escribir_wav, leer_wav, lista_esperada,
                       paso_alto, terminar)
from medir_voces import revisar

MUY_BAJO_DB = -45.0     # pico de la grabación original
MUY_LARGO_S = 6.0       # después de recortar silencios


def satura(x):
    """Más de 3 muestras seguidas pegadas al máximo = la grabación se recortó."""
    tope = np.abs(x) >= 0.999
    if tope.sum() < 3:
        return False
    corridas = np.diff(np.flatnonzero(np.diff(np.concatenate([[0], tope.astype(int), [0]]))))[::2]
    return bool(len(corridas) and corridas.max() >= 3)


def procesar(origen, destino, forzar=False):
    avisos = []
    if not forzar and not revisar(origen)[0]:
        if origen.resolve() != destino.resolve():
            destino.write_bytes(origen.read_bytes())
        return "ya estaba bien", avisos
    x, sr, info = leer_wav(origen)
    if satura(x):
        avisos.append("SATURA: se grabó demasiado fuerte, mejor repetirla")
    if len(x) and db(np.max(np.abs(x))) < MUY_BAJO_DB:
        avisos.append(f"muy bajita (pico {db(np.max(np.abs(x))):.0f} dBFS): acércate al micrófono")
    x = a_44k(x - np.mean(x), sr)
    x = paso_alto(x)
    y = terminar(x)
    dur = len(y) / SR
    if dur > MUY_LARGO_S:
        avisos.append(f"muy larga ({dur:.1f} s): ¿quedaron varias tomas en el mismo archivo?")
    escribir_wav(destino, y, marcar=info["marca"])
    return f"{info['canales']} can., {sr} Hz, {info['bits']} bits → mono 44,1 kHz ({dur:.2f} s)", avisos


def main(argv):
    forzar = "--forzar" in argv
    args = [a for a in argv if not a.startswith("--")]
    origen = Path(args[0]) if args else SALIDA
    SALIDA.mkdir(parents=True, exist_ok=True)
    archivos = sorted({p for p in origen.iterdir() if p.suffix.lower() == ".wav"})
    esperados = {n for n, *_ in lista_esperada()}
    hechos = 0
    for f in archivos:
        destino = SALIDA / f.name.lower()
        try:
            estado, avisos = procesar(f, destino, forzar)
        except Exception as e:  # noqa: BLE001
            print(f"ERROR  {f.name}: no se pudo leer ({e}). ¿Es WAV PCM? Expórtalo otra vez.")
            continue
        marca = "" if destino.name in esperados else "  (el juego no usa este nombre)"
        if estado != "ya estaba bien":
            hechos += 1
            print(f"{f.name}: {estado}{marca}")
        elif marca:
            print(f"{f.name}:{marca}")
        for a in avisos:
            print(f"   AVISO {a}")
    faltan = sorted(esperados - {p.name for p in SALIDA.glob("*.wav")})
    print(f"normalizar_voces: {hechos} procesados, {len(archivos) - hechos} ya estaban bien")
    if faltan:
        print(f"Faltan {len(faltan)}: {', '.join(faltan)}")
    else:
        print("No falta ninguno.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
