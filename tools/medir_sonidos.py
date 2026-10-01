"""Mide cada sonido de assets/sonidos/ contra los umbrales de SPEC (tools/gen_sonidos.py).

    python tools/medir_sonidos.py        # sale 0 solo si todos cumplen

Mide: duración, pico (sin saturar), RMS, energía por debajo de 80 Hz (los portátiles no la
suenan), que los efectos terminen en silencio, que los bucles empalmen sin clic y, en los
motores, que no haya un tono puro que sobresalga (lo que sonaba «a nave espacial»).
También mide la música de assets/musica/ contra SPEC de tools/gen_musica.py: pico ≤ 0,9 y, en
los bucles, que los últimos 10 ms peguen con los primeros 10 ms sin un salto que destaque.
"""
import sys
import wave

import numpy as np

from gen_sonidos import SALIDA, SPEC
import gen_musica


def leer(nombre, carpeta=SALIDA):
    with wave.open(str(carpeta / f"{nombre}.wav")) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32767
    return x, sr


def medir(nombre, spec, carpeta=SALIDA):
    x, sr = leer(nombre, carpeta)
    fallas = []
    dur = len(x) / sr
    pico = np.max(np.abs(x))
    rms = np.sqrt(np.mean(x ** 2))
    X = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / sr)
    graves = X[f < 80].sum() / X.sum()
    if not spec["dur"][0] <= dur <= spec["dur"][1]:
        fallas.append(f"duración {dur:.2f} s fuera de {spec['dur']}")
    if pico > spec.get("pico", 0.95):
        fallas.append(f"satura (pico {pico:.2f} > {spec.get('pico', 0.95)})")
    if not spec["rms"][0] <= rms <= spec["rms"][1]:
        fallas.append(f"RMS {rms:.3f} fuera de {spec['rms']}")
    if graves > spec["graves"]:
        fallas.append(f"{graves:.1%} de energía bajo 80 Hz (máx. {spec['graves']:.0%})")
    if spec.get("agudos"):
        agudos = X[f > 1000].sum() / X.sum()
        if agudos < spec["agudos"]:
            fallas.append(f"poco agudo: {agudos:.0%} de energía sobre 1 kHz (mín. {spec['agudos']:.0%})")
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
        if spec.get("pico"):
            # música: pegar los últimos 10 ms con los primeros 10 ms; el salto en la unión no
            # puede destacar sobre los saltos de esos mismos 20 ms, ni la energía cambiar de golpe
            m = int(0.01 * sr)
            union = np.concatenate([x[-m:], x[:m]])
            d = np.abs(np.diff(union))
            junto = d[m - 3:m + 2].max()
            resto = np.concatenate([d[:m - 3], d[m + 2:]]).max()
            if junto > resto * 1.2 + 1e-3:
                fallas.append(f"salto en la unión de 10 ms ({junto:.4f} > {resto:.4f})")
            r_fin = np.sqrt(np.mean(x[-m:] ** 2))
            r_ini = np.sqrt(np.mean(x[:m] ** 2))
            if max(r_fin, r_ini) > 0.02 and not 0.25 <= (r_fin + 1e-6) / (r_ini + 1e-6) <= 4.0:
                fallas.append(f"la energía cambia en la costura (RMS {r_fin:.3f} → {r_ini:.3f})")
    if spec.get("tonal"):
        from scipy.ndimage import median_filter
        P = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
        b = (f > 100) & (f < 4000)
        P = P[b]
        tonal = 10 * np.log10(np.max(P / (median_filter(P, size=401) + 1e-12)))
        if tonal > spec["tonal"]:
            fallas.append(f"demasiado tonal, suena a sintetizador ({tonal:.1f} dB > {spec['tonal']} dB)")
    if spec.get("centroide"):
        # «centro de gravedad» del espectro: qué tan grave o brillante suena (distingue las motos)
        c = (X * f).sum() / X.sum()
        if not spec["centroide"][0] <= c <= spec["centroide"][1]:
            fallas.append(f"timbre {c:.0f} Hz fuera de {spec['centroide']}")
    linea = f"{nombre:20s} {dur:5.2f} s  pico {pico:.2f}  RMS {rms:.3f}  graves {graves:.1%}"
    return linea, fallas


def main():
    mal = 0
    todos = [(n, s, SALIDA) for n, s in SPEC.items()]
    todos += [(n, s, gen_musica.SALIDA) for n, s in gen_musica.SPEC.items()]
    for nombre, spec, carpeta in todos:
        if not (carpeta / f"{nombre}.wav").exists():
            print(f"FALTA {nombre}.wav")
            mal += 1
            continue
        linea, fallas = medir(nombre, spec, carpeta)
        print(("MAL " if fallas else "ok  ") + linea)
        for fa in fallas:
            print("      " + fa)
        mal += len(fallas)
    print("medir_sonidos: todo en umbral" if mal == 0 else f"medir_sonidos: {mal} fallas")
    return 1 if mal else 0


if __name__ == "__main__":
    sys.exit(main())
