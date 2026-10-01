"""Genera todos los sonidos del juego por síntesis (numpy + scipy). Nada descargado.

    python tools/gen_sonidos.py          # escribe assets/sonidos/*.wav
    python tools/medir_sonidos.py        # comprueba los umbrales de SPEC

Reglas (CLAUDE.md §7): capas sumadas, paso-alto a ~90 Hz, fundido de coseno de 0,15 s al final
de los efectos, semilla fija por archivo. Los bucles (motor, ambiente, viento, lluvia) se hacen
con filtros circulares (por FFT), así el final empalma con el principio sin clic.
Los umbrales de cada sonido están en SPEC, escritos antes de generar.
"""
from pathlib import Path
import wave

import numpy as np
from scipy import signal

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "assets" / "sonidos"
SR = 44100

# Umbrales escritos antes de generar. dur en s; pico y rms sobre 1.0; graves = fracción de energía
# por debajo de 80 Hz (máximo); bucle = empalma sin clic; cola = el final queda en silencio.
SPEC = {
    # bucles
    "ambiente_dia":   {"dur": (10.0, 14.0), "rms": (0.06, 0.25), "graves": 0.08, "bucle": True},
    "ambiente_noche": {"dur": (10.0, 14.0), "rms": (0.03, 0.20), "graves": 0.08, "bucle": True},
    "viento":         {"dur": (3.0, 5.0), "rms": (0.08, 0.30), "graves": 0.05, "bucle": True},
    "lluvia":         {"dur": (5.0, 7.0), "rms": (0.08, 0.30), "graves": 0.03, "bucle": True},
    # efectos
    "choque":    {"dur": (1.2, 2.0), "rms": (0.08, 0.35), "graves": 0.10, "cola": True},
    "golpe":     {"dur": (0.25, 0.6), "rms": (0.05, 0.35), "graves": 0.10, "cola": True},
    "casi":      {"dur": (0.5, 0.9), "rms": (0.08, 0.35), "graves": 0.05, "cola": True},
    "fundido":   {"dur": (1.4, 2.2), "rms": (0.06, 0.35), "graves": 0.10, "cola": True},
    "entregado": {"dur": (0.7, 1.2), "rms": (0.05, 0.30), "graves": 0.05, "cola": True},
    "recogido":  {"dur": (0.25, 0.5), "rms": (0.05, 0.30), "graves": 0.05, "cola": True},
    "reparado":  {"dur": (0.5, 0.9), "rms": (0.04, 0.30), "graves": 0.05, "cola": True},
    "charco":    {"dur": (0.4, 0.8), "rms": (0.05, 0.35), "graves": 0.05, "cola": True},
    # atropello: chillido corto de llanta, golpe blando (no metálico) y la caja del domicilio rodando
    "atropello": {"dur": (0.8, 1.3), "rms": (0.06, 0.35), "graves": 0.08, "cola": True},
    # choque contra un carro (F3): golpe de lata y vidrio de farola, más corto que la caída
    "choque_carro": {"dur": (0.5, 1.0), "rms": (0.06, 0.35), "graves": 0.10, "cola": True},
    # pito del carro: dos pitazos de bocina de dos tonos (el segundo largo, de rabia)
    "pito": {"dur": (0.9, 1.5), "rms": (0.08, 0.35), "graves": 0.03, "cola": True},
    # F4 (D27). agudos = fracción mínima de energía por encima de 1 kHz.
    # frenazo en seco: chillido de llanta que tiembla (ruido agudo, no un tono)
    "frenazo": {"dur": (0.4, 1.0), "rms": (0.06, 0.35), "graves": 0.03, "cola": True, "agudos": 0.5},
    # pito de la moto (tecla H): corneta chillona y ridícula, corta
    "pito_moto": {"dur": (0.2, 0.5), "rms": (0.08, 0.35), "graves": 0.03, "cola": True, "agudos": 0.3},
    # hueco: «tras» seco de la suspensión que toca fondo y la caja del domicilio que brinca
    "bache": {"dur": (0.3, 0.7), "rms": (0.06, 0.35), "graves": 0.10, "cola": True},
    # perro: dos ladridos asustados (formantes de ladrido, no un tono puro)
    "ladrido": {"dur": (0.4, 0.9), "rms": (0.06, 0.35), "graves": 0.05, "cola": True, "agudos": 0.2},
}

# Motores (Tomás, 30/09: «suena a nave espacial»). Ahora cada explosión es un golpe de presión
# irregular que pasa por un exosto de resonancias muy amortiguadas y ruido (no tonos puros), y hay
# un bucle por cada rpm de RPM_MUESTRAS: el juego mezcla los dos más cercanos y casi no cambia el
# tono, así el timbre del exosto no se deforma (el «chipmunk» que sonaba a ciencia ficción).
# cil: fases de explosión dentro del ciclo de 720°; res: (Hz, ms de caída) del exosto; ruido: banda
# y caída del «soplido»; paso_bajo: silenciador; jitter y var: irregularidad entre explosiones.
MOTORES = {
    # BWS 125: monocilíndrica 4T de scooter, silenciador cerrado, zumbido de la correa (CVT).
    "bws": {"cil": (0.0,), "res": ((170, 3.0), (430, 2.2), (950, 1.5)), "ruido": (250, 2600, 5.0),
            "paso_bajo": 2800, "jitter": 0.03, "var": 0.2, "mec": 0.10, "correa": 0.10, "semilla": 11, "brillo": 3.2, "centroide": (450, 800),
            "rpm": (1700, 2350, 3240, 4470, 6160, 8500)},
    # NKD 125: monocilíndrica de calle, golpe grave y largo («pum-pum»), más irregular.
    "nkd": {"cil": (0.0,), "res": ((105, 7.0), (250, 4.5), (600, 2.5)), "ruido": (120, 1800, 9.0),
            "paso_bajo": 2200, "jitter": 0.035, "var": 0.25, "mec": 0.07, "correa": 0.0, "semilla": 12, "brillo": 0.25, "centroide": (200, 450),
            "rpm": (1500, 2170, 3140, 4540, 6570, 9500)},
    # Ninja 300: bicilíndrica en paralelo a 180° (explota a 180° y 540°), más aguda y pareja.
    "ninja": {"cil": (0.0, 0.25), "res": ((240, 1.8), (620, 1.4), (1500, 1.0)), "ruido": (300, 5000, 3.5),
              "paso_bajo": 5200, "jitter": 0.02, "var": 0.16, "mec": 0.09, "correa": 0.0, "semilla": 13, "brillo": 5.0, "centroide": (700, 1300),
              "rpm": (1800, 2670, 3970, 5890, 8750, 13000)},
}
for _id, _m in MOTORES.items():
    for _rpm in _m["rpm"]:
        # tonal: los armónicos de las explosiones son normales en un motor de verdad; lo que sonaba
        # «a nave» eran resonancias que timbraban (38–46 dB en la versión anterior). Primero puse
        # 26 dB, pero a altas rpm los armónicos de explosión quedan en 26–28 dB: se deja en 30.
        SPEC[f"motor_{_id}_{_rpm}"] = {"dur": (0.9, 1.2), "rms": (0.08, 0.30), "graves": 0.05,
                                        "bucle": True, "tonal": 30.0, "centroide": _m["centroide"]}


# --- utilidades -------------------------------------------------------------------------

def t_de(dur):
    return np.arange(int(dur * SR)) / SR


def banda_circular(x, lo=None, hi=None):
    """Filtro pasa-banda por FFT: circular, no rompe la costura de un bucle."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.ones_like(f)
    if lo:
        m *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 8)
    if hi:
        m *= 1 / (1 + (f / hi) ** 8)
    return np.fft.irfft(X * m, len(x))


def banda(x, lo=None, hi=None, orden=4):
    if lo and hi:
        sos = signal.butter(orden, [lo, hi], "bandpass", fs=SR, output="sos")
    elif lo:
        sos = signal.butter(orden, lo, "highpass", fs=SR, output="sos")
    else:
        sos = signal.butter(orden, hi, "lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def envolvente(t, ataque, caida):
    return (1 - np.exp(-t / max(ataque, 1e-4))) * np.exp(-t / caida)


def fundido_final(x, seg=0.15):
    n = int(seg * SR)
    x = x.copy()
    x[-n:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, n)))
    return x


def normalizar(x, pico):
    return x / (np.max(np.abs(x)) + 1e-9) * pico


def poner(destino, sonido, inicio):
    """Suma `sonido` en `destino` desde `inicio` (s), dando la vuelta si se pasa (bucles)."""
    i = int(inicio * SR) % len(destino)
    idx = (np.arange(len(sonido)) + i) % len(destino)
    np.add.at(destino, idx, sonido)


def guardar(nombre, x):
    SALIDA.mkdir(parents=True, exist_ok=True)
    datos = np.clip(x, -1, 1)
    with wave.open(str(SALIDA / f"{nombre}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((datos * 32767).astype("<i2").tobytes())
    print(f"{nombre}.wav  {len(x) / SR:.2f} s")


# --- bucles -----------------------------------------------------------------------------

def motor(id_moto, rpm):
    m = MOTORES[id_moto]
    rng = np.random.default_rng(m["semilla"] * 100003 + rpm)
    ciclo = rpm / 120.0                       # ciclos de 4 tiempos por segundo
    n_ciclos = max(int(round(1.0 * ciclo)), 4)
    L = int(round(n_ciclos * SR / ciclo))
    # 1) Explosiones: pulsos de presión cortos, cada uno distinto (fuerza y momento).
    x = np.zeros(L)
    ancho = int(0.0012 * SR)
    for k in range(n_ciclos):
        for fz in m["cil"]:
            # irregularidad: parte proporcional al ciclo y parte fija (≈0,3 ms), que a altas rpm
            # evita un tono perfecto
            pos = (k + fz + rng.normal(0, m["jitter"])) / ciclo + rng.normal(0, 0.0003)
            fuerza = max(1.0 + rng.normal(0, m["var"]), 0.2)
            if rpm < 2500 and rng.random() < 0.04:
                fuerza *= 0.35  # en ralentí a veces una explosión sale floja
            pulso = np.sin(np.linspace(0, np.pi, ancho)) * fuerza
            pulso += rng.normal(0, 0.35, ancho) * fuerza   # la explosión no es limpia
            poner(x, pulso, pos)
    # 2) Exosto: resonancias muy amortiguadas + soplido de ruido que se apaga rápido.
    tr = t_de(0.05)
    ir = sum(np.sin(2 * np.pi * f * tr) * np.exp(-tr / (ms / 1000.0)) / (1 + i * 0.5)
             for i, (f, ms) in enumerate(m["res"]))
    lo, hi, ms = m["ruido"]
    soplido = banda(rng.standard_normal(len(tr)), lo, hi) * np.exp(-tr / (ms / 1000.0))
    ir = ir / np.max(np.abs(ir)) + 0.8 * soplido / np.max(np.abs(soplido))
    y = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, L), L)
    # 3) Mecánica: taqués (dos golpecitos por ciclo) y, en la BWS, la correa del CVT.
    fase = (np.arange(L) / SR * ciclo) % 1.0
    tique = banda_circular(rng.standard_normal(L), 3000, 8000) * (np.exp(-((fase * 2) % 1.0) * 40))
    y = y / np.std(y) + m["mec"] * tique / (np.std(tique) + 1e-9)
    if m["correa"]:
        correa = banda_circular(rng.standard_normal(L), 500, 1400)
        y += m["correa"] * min(rpm / 5000.0, 1.0) * correa / np.std(correa)  # en ralentí casi no suena
    # Timbre de cada moto: la BWS zumba (medios), la NKD retumba (graves), la Ninja rasga (agudos).
    y = y + m["brillo"] * banda_circular(y, 700, None)
    y = banda_circular(y, 110, m["paso_bajo"])
    y = y / np.sqrt(np.mean(y ** 2)) * 0.2          # todas al mismo volumen: lo decide el juego
    y = np.tanh(y * 2.5) / 2.5                       # el silenciador redondea los picos
    return y if np.max(np.abs(y)) < 0.9 else normalizar(y, 0.9)


def trafico(noche):
    rng = np.random.default_rng(21 if not noche else 22)
    dur = 12.0
    L = int(dur * SR)
    t = np.arange(L) / SR
    # Zumbido de la ciudad: ruido grave-medio, con carros que pasan (subidas lentas, circulares).
    rumor = banda_circular(rng.standard_normal(L), 90, 500)
    pasos = np.zeros(L)
    for _ in range(4 if noche else 9):
        c = rng.uniform(0, dur)
        d = np.minimum(np.abs(t - c), dur - np.abs(t - c))
        pasos += np.exp(-(d / rng.uniform(0.6, 1.5)) ** 2)
    y = rumor / np.std(rumor) * (0.35 + 0.65 * pasos / pasos.max()) * (0.5 if noche else 1.0)
    # Pitos a lo lejos (dos tonos, apagados por la distancia).
    for _ in range(1 if noche else 3):
        f0 = rng.uniform(380, 480)
        tp = t_de(rng.uniform(0.2, 0.45))
        pito = signal.square(2 * np.pi * f0 * tp) + 0.7 * signal.square(2 * np.pi * f0 * 1.26 * tp)
        pito = banda(pito, hi=1500) * envolvente(tp, 0.01, 0.5) * 0.35
        poner(y, pito, rng.uniform(0, dur))
    if noche:
        # Grillos del parque: chirridos cortos en grupos.
        for _ in range(14):
            tc = t_de(0.05)
            chirrido = np.sin(2 * np.pi * rng.uniform(4200, 4800) * tc) * envolvente(tc, 0.003, 0.015)
            inicio = rng.uniform(0, dur)
            for k in range(3):
                poner(y, chirrido * 0.25, inicio + k * 0.07)
    y = banda_circular(y, 90, 8000)
    return normalizar(y, 0.5)


def viento():
    rng = np.random.default_rng(31)
    L = int(4.0 * SR)
    t = np.arange(L) / SR
    ruido = banda_circular(rng.standard_normal(L), 180, 2200)
    rafagas = 0.6 + 0.4 * np.sin(2 * np.pi * t / 4.0) * np.sin(2 * np.pi * 3 * t / 4.0)
    return normalizar(ruido * rafagas, 0.6)


def lluvia():
    rng = np.random.default_rng(41)
    dur = 6.0
    L = int(dur * SR)
    fondo = banda_circular(rng.standard_normal(L), 900, 9000)
    y = fondo / np.std(fondo) * 0.6
    for _ in range(900):  # gotas sueltas encima
        tg = t_de(0.012)
        gota = np.sin(2 * np.pi * rng.uniform(1500, 5000) * tg) * envolvente(tg, 0.0005, 0.003)
        poner(y, gota * rng.uniform(0.3, 1.2), rng.uniform(0, dur))
    y = banda_circular(y, 400, 12000)
    return normalizar(y, 0.6)


# --- efectos ------------------------------------------------------------------------------

def efecto(y, pico=0.85):
    y = banda(y, lo=90)
    return normalizar(fundido_final(y), pico)


def choque():
    rng = np.random.default_rng(51)
    t = t_de(1.6)
    golpe = np.sin(2 * np.pi * (120 - 40 * t) * t) * envolvente(t, 0.002, 0.12)
    crujido = banda(rng.standard_normal(len(t)), 300, 3000) * envolvente(t, 0.001, 0.25)
    raspon = banda(rng.standard_normal(len(t)), 2000, 7000) * envolvente(t, 0.05, 0.45)
    raspon *= 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 23 * t))
    y = 1.4 * golpe + 0.9 * crujido + 0.35 * raspon
    for _ in range(6):  # pedazos de plástico que rebotan
        tp = t_de(0.03)
        poner(y, np.sin(2 * np.pi * rng.uniform(900, 2500) * tp) * envolvente(tp, 0.0005, 0.006) * 0.5,
              rng.uniform(0.15, 1.0))
    return efecto(y)


def golpe():
    rng = np.random.default_rng(52)
    t = t_de(0.4)
    y = np.sin(2 * np.pi * (140 - 60 * t) * t) * envolvente(t, 0.002, 0.07)
    y += 0.4 * banda(rng.standard_normal(len(t)), 500, 3000) * envolvente(t, 0.001, 0.04)
    return efecto(y, 0.7)


def casi():
    rng = np.random.default_rng(53)
    t = t_de(0.7)
    f = 1150 + 90 * np.sin(2 * np.pi * 17 * t) - 250 * t
    chirrido = np.sin(2 * np.pi * np.cumsum(f) / SR)
    llanta = banda(rng.standard_normal(len(t)), 1500, 5000)
    env = envolvente(t, 0.03, 0.35)
    return efecto((chirrido * 0.6 + llanta * 0.5) * env, 0.75)


def fundido():
    rng = np.random.default_rng(54)
    t = t_de(1.8)
    y = 1.3 * banda(rng.standard_normal(len(t)), 150, 2500) * envolvente(t, 0.001, 0.08)
    for k in range(9):  # petardeos que se van apagando
        tp = t_de(0.06)
        petardo = banda(rng.standard_normal(len(tp)), 120, 1200) * envolvente(tp, 0.001, 0.02)
        poner(y, petardo * (1.0 - k / 10), 0.18 + k * 0.09 + rng.uniform(0, 0.05))
    vapor = banda(rng.standard_normal(len(t)), 3000, 9000) * envolvente(t - 0.2, 0.2, 0.6) * (t > 0.2)
    return efecto(y + 0.4 * vapor)


def campana(f, dur, caida):
    t = t_de(dur)
    return sum(np.sin(2 * np.pi * f * r * t) * a for r, a in ((1, 1.0), (2.76, 0.45), (5.4, 0.2))) \
        * envolvente(t, 0.001, caida)


def entregado():
    rng = np.random.default_rng(55)
    t = t_de(1.0)
    y = np.zeros(len(t))
    poner(y, banda(rng.standard_normal(int(0.05 * SR)), 2000, 8000) * 0.5, 0.0)  # «cha»
    poner(y, campana(1568, 0.9, 0.25), 0.08)                                      # «ching»
    poner(y, campana(2093, 0.8, 0.3) * 0.8, 0.14)
    return efecto(y, 0.7)


def recogido():
    t = t_de(0.35)
    y = np.zeros(len(t))
    poner(y, campana(660, 0.15, 0.05), 0.0)
    poner(y, campana(990, 0.2, 0.07), 0.1)
    return efecto(y, 0.6)


def reparado():
    rng = np.random.default_rng(56)
    t = t_de(0.7)
    y = np.zeros(len(t))
    for k in range(3):  # llave contra el motor: «clin, clin, clin»
        poner(y, campana(rng.uniform(2400, 3200), 0.25, 0.04), 0.05 + k * 0.17)
    return efecto(y, 0.6)


def charco():
    rng = np.random.default_rng(57)
    t = t_de(0.6)
    y = banda(rng.standard_normal(len(t)), 500, 4000) * envolvente(t, 0.004, 0.12)
    for _ in range(10):  # gotitas que caen después
        tg = t_de(0.02)
        poner(y, np.sin(2 * np.pi * rng.uniform(1200, 3000) * tg) * envolvente(tg, 0.0005, 0.004) * 0.4,
              rng.uniform(0.08, 0.45))
    return efecto(y, 0.75)


def atropello():
    """Atropello de caricatura: chillido de llanta, «pum» blando contra la persona y la caja rodando."""
    rng = np.random.default_rng(58)
    t = t_de(1.1)
    y = np.zeros(len(t))
    tf = t_de(0.3)  # frenazo: ruido de llanta con temblor, no un tono puro
    frenazo = banda(rng.standard_normal(len(tf)), 1800, 4200) * envolvente(tf, 0.01, 0.12)
    frenazo *= 0.7 + 0.3 * np.sin(2 * np.pi * 31 * tf)
    poner(y, 0.45 * frenazo, 0.0)
    tg = t_de(0.35)  # golpe blando: grave que cae rápido + cuerpo de ruido apagado
    pum = np.sin(2 * np.pi * (170 - 90 * tg) * tg) * envolvente(tg, 0.003, 0.06)
    pum += 0.6 * banda(rng.standard_normal(len(tg)), 200, 1200) * envolvente(tg, 0.002, 0.05)
    poner(y, 1.2 * pum, 0.22)
    for k in range(5):  # la caja del domicilio rebota y rueda, cada vez más suave
        tc = t_de(0.05)
        caja = banda(rng.standard_normal(len(tc)), 400, 2500) * envolvente(tc, 0.001, 0.012)
        poner(y, caja * 0.55 * (1.0 - k / 6), 0.42 + k * 0.1 + rng.uniform(0, 0.03))
    return efecto(y, 0.8)


def choque_carro():
    """Moto contra carro: «tong» de lámina que resuena, crujido de plástico y vidrio que cae."""
    rng = np.random.default_rng(59)
    t = t_de(0.8)
    lamina = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((310, 1.0), (523, 0.6), (871, 0.35), (1390, 0.2)))
    lamina *= envolvente(t, 0.001, 0.09) * (1 + 0.3 * rng.standard_normal(len(t)).clip(-1, 1))
    pum = np.sin(2 * np.pi * (130 - 50 * t) * t) * envolvente(t, 0.002, 0.06)
    crujido = banda(rng.standard_normal(len(t)), 600, 4000) * envolvente(t, 0.001, 0.07)
    y = 1.1 * pum + 0.7 * lamina + 0.6 * crujido
    for _ in range(7):  # vidrio de la farola
        tp = t_de(0.02)
        poner(y, np.sin(2 * np.pi * rng.uniform(3000, 6000) * tp) * envolvente(tp, 0.0003, 0.004) * 0.35,
              rng.uniform(0.1, 0.6))
    return efecto(y, 0.8)


def pito():
    """Bocina de carro: dos tonos a la vez (tercera mayor), con cuerpo de corneta; «pi, piiiii»."""
    t = t_de(1.2)
    y = np.zeros(len(t))
    for inicio, largo in ((0.0, 0.16), (0.26, 0.8)):
        tp = t_de(largo)
        tono = sum(np.tanh(3.0 * np.sin(2 * np.pi * f * tp)) for f in (415.0, 523.0))
        tono = banda(tono, 300, 3500) * envolvente(tp, 0.01, largo) * np.clip((largo - tp) / 0.03, 0, 1)
        poner(y, tono, inicio)
    return efecto(y, 0.7)


def frenazo():
    """Frenazo en seco: chillido de llanta (ruido agudo en dos bandas) que tiembla y se apaga."""
    rng = np.random.default_rng(60)
    t = t_de(0.7)
    chillido = banda(rng.standard_normal(len(t)), 1900, 3600) + 0.6 * banda(rng.standard_normal(len(t)), 3800, 6500)
    temblor = 0.65 + 0.35 * np.sin(2 * np.pi * (38 - 14 * t) * t)
    y = chillido * temblor * envolvente(t, 0.015, 0.35) * np.clip((0.7 - t) / 0.2, 0, 1)
    y += 0.25 * banda(rng.standard_normal(len(t)), 300, 1200) * envolvente(t, 0.01, 0.2)
    return efecto(y, 0.75)


def pito_moto():
    """Pito de moto barata: «mii» nasal y chillón (onda cuadrada suave en ~1 kHz con vibrato)."""
    t = t_de(0.35)
    f = 1050 + 20 * np.sin(2 * np.pi * 9 * t)
    fase = 2 * np.pi * np.cumsum(f) / SR
    tono = np.tanh(4.0 * np.sin(fase)) + 0.4 * np.tanh(4.0 * np.sin(1.5 * fase))
    tono = banda(tono, 500, 6000) * envolvente(t, 0.008, 0.5) * np.clip((0.35 - t) / 0.05, 0, 1)
    return efecto(tono, 0.7)


def bache():
    """Hueco: «tras» de la suspensión que toca fondo, lámina que vibra y la caja que brinca."""
    rng = np.random.default_rng(61)
    t = t_de(0.5)
    tras = np.sin(2 * np.pi * (140 - 70 * t) * t) * envolvente(t, 0.002, 0.05)
    tras += 0.7 * banda(rng.standard_normal(len(t)), 250, 2000) * envolvente(t, 0.001, 0.04)
    lamina = sum(np.sin(2 * np.pi * fr * t) * a for fr, a in ((460, 0.5), (780, 0.3))) * envolvente(t, 0.002, 0.08)
    y = 1.2 * tras + 0.5 * lamina
    tc = t_de(0.06)
    caja = banda(rng.standard_normal(len(tc)), 400, 2500) * envolvente(tc, 0.001, 0.015)
    poner(y, 0.6 * caja, 0.18)
    return efecto(y, 0.8)


def ladrido():
    """Dos ladridos asustados: pulso de glotis con dos formantes que caen («¡guau, guau!»)."""
    rng = np.random.default_rng(62)
    y = np.zeros(len(t_de(0.65)))
    for inicio, f0 in ((0.0, 520.0), (0.28, 480.0)):
        tl = t_de(0.18)
        f = f0 * (1.25 - 0.45 * tl / 0.18)
        fase = 2 * np.pi * np.cumsum(f) / SR
        pulso = np.sign(np.sin(fase)) * 0.5 + 0.5 * rng.standard_normal(len(tl))
        voz = banda(pulso, 800, 1400, 2) + 0.8 * banda(pulso, 1800, 3200, 2)
        voz *= envolvente(tl, 0.006, 0.06)
        poner(y, voz, inicio)
    return efecto(y, 0.75)


def main():
    for id_moto, m in MOTORES.items():
        for rpm in m["rpm"]:
            guardar(f"motor_{id_moto}_{rpm}", motor(id_moto, rpm))
    guardar("ambiente_dia", trafico(False))
    guardar("ambiente_noche", trafico(True))
    guardar("viento", viento())
    guardar("lluvia", lluvia())
    for fn in (choque, golpe, casi, fundido, entregado, recogido, reparado, charco, atropello, choque_carro, pito,
               frenazo, pito_moto, bache, ladrido):
        guardar(fn.__name__, fn())


if __name__ == "__main__":
    main()
