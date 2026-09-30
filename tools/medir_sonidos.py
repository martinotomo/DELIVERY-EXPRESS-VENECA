"""Mide cada sonido de assets/sonidos/ contra los umbrales de SPEC (tools/gen_sonidos.py).

    python tools/medir_sonidos.py        # sale 0 solo si todos cumplen

Mide: duración, pico (sin saturar), RMS, energía por debajo de 80 Hz (los portátiles no la
suenan), que los efectos terminen en silencio y que los bucles empalmen sin clic.
"""
import sys
import wave

import numpy as np

from gen_sonidos import SALIDA, SPEC


def leer(nombre):
    with wave.open(str(SALIDA / f"{nombre}.wav")) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32767
    return x, sr


def medir(nombre, spec):
    x, sr = leer(nombre)
    fallas = []
    dur = len(x) / sr
    pico = np.max(np.abs(x))
    rms = np.sqrt(np.mean(x ** 2))
    X = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / sr)
    graves = X[f < 80].sum() / X.sum()
    if not spec["dur"][0] <= dur <= spec["dur"][1]:
        fallas.append(f"duración {dur:.2f} s fuera de {spec['dur']}")
    if pico > 0.95:
        fallas.append(f"satura (pico {pico:.2f})")
    if not spec["rms"][0] <= rms <= spec["rms"][1]:
        fallas.append(f"RMS {rms:.3f} fuera de {spec['rms']}")
    if graves > spec["graves"]:
        fallas.append(f"{graves:.1%} de energía bajo 80 Hz (máx. {spec['graves']:.0%})")
    if spec.get("cola"):
        cola = np.sqrt(np.mean(x[-int(0.02 * sr):] ** 2))
        if cola > 0.01:
            fallas.append(f"no termina en silencio (RMS final {cola:.3f})")
    if spec.get("bucle"):
        saltos = np.abs(np.diff(x))
        costura = abs(x[0] - x[-1])
        limite = np.percentile(saltos, 99.9) * 1.5
        if costura > limite:
            fallas.append(f"clic en la costura del bucle ({costura:.3f} > {limite:.3f})")
    linea = f"{nombre:15s} {dur:5.2f} s  pico {pico:.2f}  RMS {rms:.3f}  graves {graves:.1%}"
    return linea, fallas


def main():
    mal = 0
    for nombre, spec in SPEC.items():
        if not (SALIDA / f"{nombre}.wav").exists():
            print(f"FALTA {nombre}.wav")
            mal += 1
            continue
        linea, fallas = medir(nombre, spec)
        print(("MAL " if fallas else "ok  ") + linea)
        for fa in fallas:
            print("      " + fa)
        mal += len(fallas)
    print("medir_sonidos: todo en umbral" if mal == 0 else f"medir_sonidos: {mal} fallas")
    return 1 if mal else 0


if __name__ == "__main__":
    sys.exit(main())
