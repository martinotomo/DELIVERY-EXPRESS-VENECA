"""Genera la música del juego por síntesis (numpy + scipy), estilo 8 bits. Nada descargado.

    python tools/gen_musica.py           # escribe assets/musica/*.wav
    python tools/medir_sonidos.py        # comprueba también los umbrales de SPEC de aquí

Tres piezas, todas compuestas aquí (ninguna melodía copiada):
- conduccion: cumbia chiptune en La menor a 100 pulsos por minuto, 8 compases (19,2 s) que dan la
  vuelta sin costura. Güiro «largo-corto-corto», bajo en 1 y 3, acordes a contratiempo y una
  melodía de onda cuadrada con eco; la segunda mitad es una variación (otro timbre y una segunda
  voz a la tercera).
- menu: la misma idea más tranquila, a lo salsa: 90 pulsos, clave 3-2, bajo «tumbao» (anticipa el
  acorde siguiente), montuno de pulso fino y la melodía con onda triangular (suena a flauta).
- muerte: exageradamente épica y trágica (el contraste es el chiste): golpe de timbal, acordes
  menores enormes de «orquesta» sintética (Re menor → Si bemol → La mayor → Re menor), redoble
  que crece y un último golpe con platillo; termina en silencio.

Reglas (CLAUDE.md §7): paso-alto a ~90 Hz, poca energía bajo 80 Hz, pico ≤ 0,9, fundido de coseno
de 0,15 s al final de lo que no es bucle, semilla fija por archivo. Los bucles se arman sobre un
búfer circular (las colas de las notas del final caen al principio) y se filtran por FFT, así el
final empalma con el principio sin clic. Los umbrales de cada pieza están en SPEC, escritos antes
de generar, y los mide tools/medir_sonidos.py.
"""
from pathlib import Path
import wave

import numpy as np
from scipy import signal

from gen_sonidos import SR, banda, banda_circular, fundido_final, normalizar, poner

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "assets" / "musica"

# Umbrales escritos antes de generar (mismo formato que SPEC de gen_sonidos). dur en s; rms sobre
# 1.0; graves = fracción máxima de energía bajo 80 Hz; pico = máximo permitido; bucle = empalma
# sin clic (y los últimos 10 ms pegan con los primeros 10 ms); cola = el final queda en silencio.
# La música de conducción va debajo del motor: poca energía grave, más medios.
SPEC = {
    "conduccion": {"dur": (16.0, 24.0), "rms": (0.08, 0.25), "graves": 0.04, "pico": 0.9, "bucle": True},
    "menu":       {"dur": (12.0, 20.0), "rms": (0.06, 0.22), "graves": 0.04, "pico": 0.9, "bucle": True},
    "muerte":     {"dur": (5.0, 8.0), "rms": (0.06, 0.30), "graves": 0.06, "pico": 0.9, "cola": True},
}

NOTAS = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
         "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def hz(nota):
    """'A4' → 440 Hz; 'G#4', 'Bb2'…"""
    nombre, octava = nota[:-1], int(nota[-1])
    midi = 12 * (octava + 1) + NOTAS[nombre]
    return 440.0 * 2 ** ((midi - 69) / 12)


# --- osciladores (sumas de armónicos: sin aliasing, que en 8 bits crudo suena a lija) ----------

def fase(f, n, vibrato=0.0, vib_hz=5.5, vib_desde=0.15):
    """Fase acumulada (rad) de una nota de n muestras, con vibrato opcional que entra tarde."""
    t = np.arange(n) / SR
    prof = vibrato * np.clip((t - vib_desde) / 0.2, 0, 1)
    finst = f * (1 + prof * np.sin(2 * np.pi * vib_hz * t))
    return 2 * np.pi * np.cumsum(finst) / SR


def pulso(f, n, ciclo=0.5, techo=9000, **kw):
    """Onda de pulso (ciclo 0,5 = cuadrada; 0,25 y 0,125 = los timbres finos del NES)."""
    ph = fase(f, n, **kw)
    y = np.zeros(n)
    for k in range(1, int(techo / f) + 1):
        y += np.sin(np.pi * k * ciclo) / k * np.cos(k * ph)
    return y * (4 / np.pi) * 0.5


def triangular(f, n, techo=8000, **kw):
    ph = fase(f, n, **kw)
    y = np.zeros(n)
    for k in range(1, int(techo / f) + 1, 2):
        y += (-1) ** ((k - 1) // 2) / k ** 2 * np.sin(k * ph)
    return y * 8 / np.pi ** 2


def serrucho(f, n, brillo, techo=7000, **kw):
    """Sierra con brillo variable en el tiempo: brillo (array o número) = armónico donde cae a 1/e.
    Con el brillo siguiendo a la envolvente suena a metal que «abre» (lo típico de los bronces)."""
    ph = fase(f, n, **kw)
    y = np.zeros(n)
    for k in range(1, int(techo / f) + 1):
        y += np.exp(-(k - 1) / brillo) * np.sin(k * ph) / k
    return y


def adsr(n, ataque, caida, sostén, suelta, dur_nota):
    """Envolvente de n muestras: sube en `ataque`, cae a `sostén` en `caida`, suelta al acabar la
    nota (`dur_nota` s) en `suelta` s. Todo en segundos."""
    t = np.arange(n) / SR
    e = np.where(t < ataque, t / max(ataque, 1e-4),
                 sostén + (1 - sostén) * np.exp(-(t - ataque) / max(caida, 1e-4)))
    e = np.where(t > dur_nota, e * np.exp(-(t - dur_nota) / max(suelta, 1e-4)), e)
    return e


def eco(x, retardo, fb=0.35, veces=3):
    """Eco circular (para bucles): copias retrasadas que dan la vuelta."""
    y = x.copy()
    for i in range(1, veces + 1):
        y += np.roll(x, int(retardo * i * SR)) * fb ** i
    return y


def reverb(x, largo, mezcla, semilla, circular):
    """Reverberación de ruido que decae (una «sala»). En bucles se aplica por FFT circular."""
    rng = np.random.default_rng(semilla)
    n = int(largo * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / (largo / 6.9))
    ir = banda(ir, 300, 6000, orden=2)
    ir /= np.sqrt(np.sum(ir ** 2))
    if circular:
        h = np.zeros(len(x))
        h[:n] = ir
        mojada = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h), len(x))
    else:
        mojada = signal.fftconvolve(x, ir)[: len(x)]
    return x + mojada * mezcla


def mezclar_bucle(y, pico=0.85):
    """Cierre de un bucle: paso-alto circular a 90 Hz (no rompe la costura) y normalizar."""
    y = banda_circular(y, lo=90)
    y -= np.mean(y)
    return normalizar(y, pico)


# --- instrumentos de percusión -------------------------------------------------------------

def guiro(rng, dur):
    """Raspado: ruido agudo modulado por las estrías (~70 golpecitos por segundo)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    estrias = 0.45 + 0.55 * np.abs(np.sin(np.pi * 70 * t)) ** 3
    env = np.minimum(t / 0.006, 1) * np.exp(-t / (dur * 0.6)) * (1 - t / dur) ** 0.5
    return banda(rng.standard_normal(n), 2200, 7500) * estrias * env


def tambora(f, n=None):
    """Golpe de tambor afinado alto (sobre 90 Hz): tono que baja un poco y cae rápido."""
    n = n or int(0.35 * SR)
    t = np.arange(n) / SR
    finst = f * (1 + 0.5 * np.exp(-t / 0.02))
    ph = 2 * np.pi * np.cumsum(finst) / SR
    return (np.sin(ph) + 0.3 * np.sin(2.3 * ph)) * np.minimum(t / 0.002, 1) * np.exp(-t / 0.09)


def aro(rng):
    """Golpe de aro / palito: ruido medio muy corto."""
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    return banda(rng.standard_normal(n), 1200, 4500) * np.minimum(t / 0.001, 1) * np.exp(-t / 0.018)


def clave_madera(f=1900):
    """Clave / bloque de madera: dos parciales inarmónicos que se apagan en ~30 ms."""
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.7 * t)) \
        * np.minimum(t / 0.0008, 1) * np.exp(-t / 0.03)


def maraca(rng):
    n = int(0.07 * SR)
    t = np.arange(n) / SR
    return banda(rng.standard_normal(n), 4000, 10000) * np.minimum(t / 0.004, 1) * np.exp(-t / 0.02)


# --- notas melódicas ----------------------------------------------------------------------

def nota_pulso(f, dur, ciclo, vol, suelta=0.06, vibrato=0.0):
    n = int((dur + suelta * 5) * SR)
    return pulso(f, n, ciclo, vibrato=vibrato) * adsr(n, 0.004, 0.25, 0.6, suelta, dur) * vol


def nota_triangular(f, dur, vol, suelta=0.08, vibrato=0.0):
    n = int((dur + suelta * 5) * SR)
    return triangular(f, n, vibrato=vibrato) * adsr(n, 0.006, 0.4, 0.7, suelta, dur) * vol


def tocar(y, notas, compas_ini, paso, pasos_compas, instrumento, swing=0.0, desfase=0.0):
    """Pone una lista [(paso, largo_en_pasos, 'nota'), …] del compás `compas_ini`.
    swing: retrasa los dieciseisavos impares esa fracción de paso (el «lilt» de la cumbia)."""
    for p, largo, nota in notas:
        inicio = (compas_ini * pasos_compas + p + (swing if p % 2 else 0.0)) * paso + desfase
        poner(y, instrumento(hz(nota), largo * paso), inicio)


# --- conducción: cumbia chiptune --------------------------------------------------------

# Acordes de los 8 compases (i–V–i–V–iv–i–V–i en La menor) con sus notas de acorde y de bajo.
ACORDES = {
    "Am": {"triada": ("A3", "C4", "E4"), "raiz": "A2", "quinta": "E3", "octava": "A3"},
    "E":  {"triada": ("G#3", "B3", "E4"), "raiz": "E3", "quinta": "B2", "octava": "E3"},
    "Dm": {"triada": ("A3", "D4", "F4"), "raiz": "D3", "quinta": "A2", "octava": "D3"},
}
PROG_CONDUCCION = ["Am", "E", "Am", "E", "Dm", "Am", "E", "Am"]

# Melodía (paso en dieciseisavos, largo, nota). Frase A (compases 1–4) y frase B (5–8, variación).
MELODIA_CONDUCCION = [
    [(0, 2, "A4"), (3, 1, "C5"), (4, 3, "E5"), (7, 1, "D5"), (8, 2, "C5"), (10, 2, "B4"), (12, 4, "A4")],
    [(0, 2, "G#4"), (2, 2, "B4"), (4, 3, "E5"), (7, 1, "D5"), (8, 4, "B4"), (12, 2, "G#4"), (14, 2, "B4")],
    [(0, 2, "C5"), (2, 2, "E5"), (4, 3, "A5"), (7, 1, "G5"), (8, 2, "E5"), (10, 2, "C5"), (12, 2, "D5"), (14, 2, "E5")],
    [(0, 3, "F5"), (3, 1, "E5"), (4, 2, "D5"), (6, 2, "B4"), (8, 4, "G#4"), (14, 2, "E4")],
    [(0, 2, "F4"), (2, 2, "A4"), (4, 3, "D5"), (7, 1, "C5"), (8, 2, "D5"), (10, 2, "F5"), (12, 2, "E5"), (14, 2, "D5")],
    [(0, 3, "C5"), (3, 1, "B4"), (4, 2, "A4"), (6, 2, "C5"), (8, 4, "E5"), (12, 2, "C5"), (14, 2, "E5")],
    [(0, 2, "D5"), (2, 1, "C5"), (3, 1, "B4"), (4, 2, "G#4"), (6, 2, "B4"), (8, 3, "E5"), (11, 1, "D5"), (12, 2, "B4"), (14, 2, "G#4")],
    [(0, 6, "A4"), (8, 2, "E5"), (10, 2, "D5"), (12, 2, "C5"), (14, 2, "B4")],
]
# Segunda voz de la frase B: una tercera (diatónica) por debajo en las notas largas.
SEGUNDA_VOZ = [
    [(4, 3, "A4"), (8, 2, "A4"), (10, 2, "D5"), (12, 2, "C5")],
    [(0, 3, "A4"), (8, 4, "C5")],
    [(8, 3, "B4"), (12, 2, "G#4")],
    [(0, 6, "E4"), (8, 2, "C5")],
]


def conduccion():
    rng = np.random.default_rng(301)
    bpm, compases = 100, 8
    paso = 60 / bpm / 4                     # dieciseisavo
    total = compases * 16 * paso            # 19,2 s exactos
    n = int(round(total * SR))
    lead, acomp, bajo, perc = (np.zeros(n) for _ in range(4))

    for c, nombre in enumerate(PROG_CONDUCCION):
        a = ACORDES[nombre]
        base = c * 16 * paso
        # bajo de cumbia: raíz en el 1, quinta en el 3 y un golpecito de raíz al final del compás
        for p, largo, nota, vol in ((0, 4, a["raiz"], 1.0), (8, 4, a["quinta"], 0.9),
                                    (14, 1, a["octava"], 0.55)):
            poner(bajo, nota_triangular(hz(nota), largo * paso * 0.85, vol, suelta=0.03),
                  base + p * paso)
        # acordes a contratiempo («chaca» del teclado/acordeón), pulso fino y corto
        for p in (2, 6, 10, 14):
            for nota in a["triada"]:
                poner(acomp, nota_pulso(hz(nota), paso * 0.8, 0.25, 0.33, suelta=0.02),
                      base + (p + 0.12) * paso)
        # güiro: largo en el pulso, dos cortos después (un poco atrasados: el «lilt»)
        for pulso_i in range(4):
            b = base + pulso_i * 4 * paso
            poner(perc, guiro(rng, paso * 1.8) * 0.55, b)
            poner(perc, guiro(rng, paso * 0.7) * 0.45, b + 2.12 * paso)
            poner(perc, guiro(rng, paso * 0.7) * 0.40, b + 3.12 * paso)
        # tambora en 1 y 3 (grave-medio), aro en 2 y 4, y un repique en el último compás
        poner(perc, tambora(140) * 0.6, base)
        poner(perc, tambora(155) * 0.6, base + 8 * paso)
        poner(perc, tambora(185) * 0.45, base + 11 * paso)
        for p in (4, 12):
            poner(perc, aro(rng) * 0.6, base + p * paso)
        if c == compases - 1:
            for p, f in ((12, 230), (13, 205), (14, 185), (15, 165)):
                poner(perc, tambora(f) * 0.5, base + p * paso)

        # melodía: frase A con cuadrada; frase B (variación) con pulso 0,25 y segunda voz
        ciclo = 0.5 if c < 4 else 0.25
        tocar(lead, MELODIA_CONDUCCION[c], c, paso, 16,
              lambda f, d, ci=ciclo: nota_pulso(f, d * 0.92, ci, 0.5, vibrato=0.006), swing=0.1)
        if c >= 4:
            tocar(lead, SEGUNDA_VOZ[c - 4], c, paso, 16,
                  lambda f, d: nota_pulso(f, d * 0.9, 0.125, 0.22), swing=0.1)

    lead = eco(lead, 3 * paso, fb=0.28)     # eco de corchea con puntillo, muy de consola
    y = 1.0 * lead + 0.6 * acomp + 0.42 * bajo + 0.6 * perc
    y = reverb(y, 0.9, 0.12, 311, circular=True)
    return mezclar_bucle(y, 0.85)


# --- menú: salsa/cumbia tranquila ------------------------------------------------------------

PROG_MENU = ["Am", "Dm", "E", "Am", "Dm", "E"]
MELODIA_MENU = [
    [(2, 2, "A4"), (4, 2, "C5"), (6, 4, "E5"), (10, 1, "D5"), (11, 1, "C5"), (12, 2, "B4"), (14, 2, "C5")],
    [(0, 4, "D5"), (4, 2, "F5"), (6, 4, "A5"), (10, 2, "G5"), (12, 2, "F5"), (14, 2, "E5")],
    [(0, 3, "D5"), (3, 1, "C5"), (4, 4, "B4"), (8, 2, "G#4"), (10, 2, "B4"), (12, 4, "E5")],
    [(0, 6, "C5"), (6, 2, "A4"), (8, 2, "E5"), (10, 4, "A5"), (14, 2, "G5")],
    [(0, 3, "F5"), (3, 1, "E5"), (4, 2, "D5"), (6, 2, "A4"), (8, 2, "D5"), (10, 2, "F5"), (12, 2, "E5"), (14, 2, "D5")],
    [(0, 6, "B4"), (6, 2, "G#4"), (8, 4, "E4"), (12, 2, "G#4"), (14, 2, "B4")],
]
# Montuno: patrón de 16 pasos que salta entre notas del acorde (índices 0–2 de la tríada,
# 3 = raíz una octava arriba), sincopado.
MONTUNO = [(0, 0), (2, 1), (3, 2), (5, 1), (6, 3), (8, 2), (10, 1), (11, 2), (13, 3), (14, 1)]
CLAVE_32 = (0, 6, 12, 20, 24)              # son 3-2 en dieciseisavos sobre dos compases


def menu():
    rng = np.random.default_rng(401)
    bpm, compases = 90, 6
    paso = 60 / bpm / 4
    total = compases * 16 * paso            # 16,0 s exactos
    n = int(round(total * SR))
    lead, acomp, bajo, perc = (np.zeros(n) for _ in range(4))

    for c, nombre in enumerate(PROG_MENU):
        a = ACORDES[nombre]
        siguiente = ACORDES[PROG_MENU[(c + 1) % compases]]
        base = c * 16 * paso
        # tumbao: quinta en el «y» del 2 y la raíz del acorde que viene en el 4 (anticipa)
        poner(bajo, nota_triangular(hz(a["quinta"]), 5 * paso, 0.8, suelta=0.04), base + 6 * paso)
        poner(bajo, nota_triangular(hz(siguiente["raiz"]), 6 * paso, 1.0, suelta=0.04), base + 12 * paso)
        # montuno una octava arriba de la tríada, pulso 0,125 suavecito
        for p, i in MONTUNO:
            nota = a["triada"][i] if i < 3 else a["triada"][0]
            f = hz(nota) * (4 if i == 3 else 2)
            poner(acomp, nota_pulso(f, paso * 0.9, 0.125, 0.28, suelta=0.03), base + (p + 0.1) * paso)
        # maracas en corcheas (acento en el pulso), clave 3-2 y un bongó en el 4
        for p in range(0, 16, 2):
            poner(perc, maraca(rng) * (0.5 if p % 4 == 0 else 0.3), base + p * paso)
        for p in CLAVE_32:
            if (c % 2) * 16 <= p < (c % 2 + 1) * 16:
                poner(perc, clave_madera() * 0.55, base + (p - (c % 2) * 16) * paso)
        poner(perc, tambora(260) * 0.35, base + 12 * paso)
        poner(perc, tambora(330) * 0.30, base + 14 * paso)
        poner(perc, tambora(150) * 0.45, base)
        # melodía con triangular (flauta de 8 bits), vibrato suave
        tocar(lead, MELODIA_MENU[c], c, paso, 16,
              lambda f, d: nota_triangular(f, d * 0.95, 0.75, suelta=0.1, vibrato=0.008), swing=0.08)

    lead = eco(lead, 3 * paso, fb=0.3)
    y = 0.9 * lead + 0.5 * acomp + 0.8 * bajo + 0.5 * perc
    y = reverb(y, 1.2, 0.18, 411, circular=True)
    return mezclar_bucle(y, 0.8)


# --- muerte: tragedia épica ------------------------------------------------------------------

def timbal(f, vol, largo=2.0):
    """Timbal: parciales inarmónicos (1, 1,5, 1,99, 2,44) con un «pum» de ruido."""
    rng = np.random.default_rng(int(f * 10))
    n = int(largo * SR)
    t = np.arange(n) / SR
    y = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / d)
            for r, a, d in ((1.0, 1.0, 0.9), (1.5, 0.6, 0.6), (1.99, 0.4, 0.45), (2.44, 0.25, 0.3)))
    golpe = banda(rng.standard_normal(n), 100, 1500) * np.exp(-t / 0.05) * 0.8
    return (y + golpe) * np.minimum(t / 0.002, 1) * vol


def redoble(ini, fin, f, vol_ini, vol_fin):
    """Redoble de timbal que crece: golpes cada 45 ms."""
    golpes = []
    t = ini
    while t < fin:
        v = vol_ini + (vol_fin - vol_ini) * (t - ini) / (fin - ini)
        golpes.append((t, v))
        t += 0.045
    return golpes


def acorde_orquesta(notas, dur, vol, ataque, suelta, semilla, brillo_max=18.0):
    """Cuerdas/bronces sintéticos: tres sierras desafinadas por nota, brillo que sigue la
    envolvente (abre cuando sube) y vibrato lento."""
    rng = np.random.default_rng(semilla)
    n = int((dur + suelta * 4) * SR)
    t = np.arange(n) / SR
    env = np.clip(t / ataque, 0, 1) ** 1.5
    env = np.where(t > dur, env * np.exp(-(t - dur) / suelta), env)
    brillo = 2.0 + brillo_max * env
    y = np.zeros(n)
    for nota in notas:
        f = hz(nota)
        for cents in (-7, 0, 6):
            fd = f * 2 ** (cents / 1200)
            ph0 = rng.uniform(0, 1)
            y += serrucho(fd, n, brillo, vibrato=0.004, vib_hz=4.8 + ph0, vib_desde=0.3)
    return y * env * vol / len(notas)


def muerte():
    rng = np.random.default_rng(501)
    total = 7.2
    n = int(total * SR)
    y = np.zeros(n + int(3 * SR))

    # acordes: Re menor (grande) → Si bemol → La mayor (con redoble) → Re menor final
    secciones = [
        (0.00, 2.00, ("D3", "A3", "D4", "F4", "A4"), 1.00, 0.25),
        (2.00, 1.20, ("Bb2", "F3", "D4", "F4", "Bb4"), 1.00, 0.15),
        (3.20, 1.15, ("A2", "E3", "C#4", "E4", "A4"), 1.05, 0.15),
        (4.35, 1.60, ("D3", "A3", "D4", "F4", "A4", "D5"), 1.25, 0.12),
    ]
    for i, (ini, dur, notas, vol, ataque) in enumerate(secciones):
        suelta = 0.35 if i < 3 else 0.45
        poner(y, acorde_orquesta(notas, dur, vol, ataque, suelta, 510 + i), ini)
    # voz de «trompeta» arriba: la línea trágica A4→D5 · D5→F5 · E5→C#5 · D5
    trompeta = [(0.00, 0.9, "A4"), (0.95, 1.05, "D5"), (2.00, 0.55, "D5"), (2.55, 0.6, "F5"),
                (3.20, 0.6, "E5"), (3.80, 0.5, "C#5"), (4.35, 1.6, "D5")]
    for ini, dur, nota in trompeta:
        poner(y, acorde_orquesta((nota,), dur, 0.55, 0.08, 0.2, 520, brillo_max=26.0), ini)
    # coro «aaah» (senos con formante de vocal a) en el acorde final, sube lento
    t = np.arange(int(2.6 * SR)) / SR
    coro = np.zeros(len(t))
    for nota in ("D4", "F4", "A4", "D5"):
        f = hz(nota)
        for k in range(1, 12):
            forma = np.exp(-((k * f - 800) / 350) ** 2) + 0.6 * np.exp(-((k * f - 1150) / 300) ** 2) + 0.15
            coro += forma / k ** 0.5 * np.sin(2 * np.pi * k * f * t * (1 + 0.003 * np.sin(2 * np.pi * 5 * t)))
    coro *= np.clip(t / 0.8, 0, 1) * np.exp(-np.maximum(t - 1.6, 0) / 0.4) * 0.06
    poner(y, coro, 4.35)

    # timbales: golpe al principio (con el eco de la sala), redoble al La y golpe final
    poner(y, timbal(hz("D3"), 3.2), 0.0)
    poner(y, timbal(hz("A2"), 0.9), 0.55)
    for tt, v in redoble(2.9, 4.33, hz("A2"), 0.12, 0.7):
        poner(y, timbal(hz("A2"), v, largo=0.6) * (0.9 + 0.2 * rng.uniform()), tt)
    poner(y, timbal(hz("D3"), 1.8), 4.35)
    # platillo en el golpe final
    nc = int(2.5 * SR)
    tc = np.arange(nc) / SR
    poner(y, banda(rng.standard_normal(nc), 3000, 12000) * np.exp(-tc / 0.7) * np.minimum(tc / 0.003, 1) * 0.35, 4.35)

    y = reverb(y, 2.2, 0.35, 511, circular=False)[:n]
    y = banda(y, lo=90)
    # el último acorde se apaga del todo: caída exponencial desde 5,6 s y fundido de coseno
    tt = np.arange(n) / SR
    y *= np.where(tt > 5.6, np.exp(-(tt - 5.6) / 0.45), 1.0)
    y = fundido_final(y, 0.15)
    return normalizar(y, 0.85)


# --- guardar ---------------------------------------------------------------------------------

def guardar(nombre, x):
    SALIDA.mkdir(parents=True, exist_ok=True)
    datos = np.clip(x, -1, 1)
    with wave.open(str(SALIDA / f"{nombre}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((datos * 32767).astype("<i2").tobytes())
    print(f"{nombre}.wav  {len(x) / SR:.2f} s")


def main():
    guardar("conduccion", conduccion())
    guardar("menu", menu())
    guardar("muerte", muerte())


if __name__ == "__main__":
    main()
