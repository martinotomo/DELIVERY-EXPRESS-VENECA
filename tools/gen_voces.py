"""Voces provisionales del domiciliario (D11), sintetizadas con espeak-ng.

    python tools/gen_voces.py            # genera assets/voces/*.wav y docs/voces/GUION.md
    python tools/gen_voces.py --guion    # solo reescribe el guion
    python tools/gen_voces.py --todas    # regenera también las que ya grabó Tomás (¡las pisa!)

Las frases se leen directamente de scripts/voces.gd (FRASES), así que si se añade una frase
allí, basta con volver a correr este script. Cada frase n (desde 1) de un evento va en
assets/voces/<evento>_<n>.wav, que es lo que busca el juego (voces.gd, ruta_audio).

Son de relleno: Tomás grabará las suyas con los mismos nombres. Para no pisarlas, este script
marca sus WAV con una etiqueta (bloque LIST/INFO «gen_voces.py») y solo reescribe los que no
existen o llevan esa marca, salvo con --todas.

Las frases que empiezan por «Peatón: » o «Conductor: » las dice otro personaje: se quita el
prefijo y se usa otra voz. Formato de salida (el mismo que deja normalizar_voces.py): WAV mono
44,1 kHz 16 bits, RMS ≈ −20 dBFS, pico ≤ −1 dBFS, 0,10 s de silencio al principio y al final.
"""
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy import signal

RAIZ = Path(__file__).resolve().parent.parent
VOCES_GD = RAIZ / "scripts" / "voces.gd"
SALIDA = RAIZ / "assets" / "voces"
GUION = RAIZ / "docs" / "voces" / "GUION.md"

SR = 44100
RMS_OBJETIVO_DB = -20.0     # nivel medio de todo el archivo
PICO_MAX_DB = -1.0          # pico máximo
SILENCIO_S = 0.10           # silencio al principio y al final
FUNDIDO_S = 0.010           # fundido corto contra clics
MARCA = b"gen_voces.py"     # etiqueta de los WAV sintéticos

# Voces de espeak-ng (español latinoamericano). velocidad en palabras/minuto, tono 0-99.
VOCES = {
    "domiciliario": {"voz": "es-419+m3", "vel": 168, "tono": 52},
    "peaton": {"voz": "es-419+f4", "vel": 160, "tono": 72},
    "conductor": {"voz": "es-419+m7", "vel": 150, "tono": 28},
}
PREFIJOS = {"Peatón: ": "peaton", "Conductor: ": "conductor"}

# Solo en el texto que se le pasa al sintetizador (los subtítulos no cambian).
SUSTITUCIONES = [
    (r"Na' guará", "Naguará"),
    (r"\bpa' ", "pa "),
    (r"\bPiii+", "Piiií"),
    (r"molleja", "moyeja"),
    (r"Firulais", "Firuláis"),
    (r"\.\.\.", ", "),
]

TITULOS = {
    "pedido": "Llega un pedido nuevo",
    "recogido": "Recoger el pedido",
    "entregado": "Entregar el pedido",
    "tarde": "Entregar tarde",
    "cancelado": "El cliente cancela",
    "racha": "Buena racha (esquivando sin chocar)",
    "casi": "Casi se estrella",
    "golpe": "Golpe leve contra el andén",
    "choque": "Choque con un carro",
    "pito": "Un conductor le pita (lo dice el conductor)",
    "atropello": "Atropella a un peatón",
    "grito": "El peatón atropellado grita (lo dice el peatón)",
    "regado": "Se riega la comida",
    "bache": "Cae en un hueco",
    "perro": "Un perro se le atraviesa",
    "fundido": "Se funde el motor",
    "reparado": "Repara el motor",
    "lluvia": "Empieza a llover",
    "escampo": "Deja de llover",
    "moto_nueva": "Compra moto nueva",
    "estrellado": "Se mata (antes del remate)",
    "final": "Final del juego",
}


# ---------------------------------------------------------------- frases desde voces.gd
def leer_frases(ruta=VOCES_GD):
    """Devuelve {evento: [frase, ...]} en el orden de voces.gd."""
    texto = ruta.read_text(encoding="utf-8")
    ini = texto.index("const FRASES")
    bloque = texto[texto.index("{", ini):]
    # hasta la llave que cierra el diccionario (la primera "}" a principio de línea)
    bloque = bloque[: re.search(r"^}", bloque, re.M).end()]
    frases = {}
    actual = None
    for linea in bloque.splitlines():
        m = re.match(r'\s*"([a-z_0-9]+)"\s*:\s*\[', linea)
        if m:
            actual = m.group(1)
            frases[actual] = []
            resto = linea[m.end():]
            frases[actual] += [t.replace('\\"', '"') for t in re.findall(r'"((?:[^"\\]|\\.)*)"', resto)]
            if "]" in resto:
                actual = None
            continue
        if actual is None:
            continue
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', linea):
            frases[actual].append(s.replace('\\"', '"'))
        if re.search(r"^\s*\]", linea):
            actual = None
    return frases


def lista_esperada(frases=None):
    """[(nombre_archivo, evento, n, frase)] de todos los WAV que el juego puede pedir."""
    frases = frases or leer_frases()
    return [(f"{ev}_{i + 1}.wav", ev, i + 1, fr)
            for ev, lista in frases.items() for i, fr in enumerate(lista)]


def hablante(frase):
    for pre, quien in PREFIJOS.items():
        if frase.startswith(pre):
            return quien, frase[len(pre):]
    return "domiciliario", frase


def texto_para_sintesis(frase):
    t = frase
    for a, b in SUSTITUCIONES:
        t = re.sub(a, b, t)
    return t


# ---------------------------------------------------------------- audio común
def db(x):
    return 20 * np.log10(max(x, 1e-12))


def rms(x):
    return float(np.sqrt(np.mean(x ** 2))) if len(x) else 0.0


def leer_wav(ruta):
    """Lee un WAV PCM (8/16/24/32 bits, cualquier nº de canales). Devuelve (mono float, sr, info)."""
    with wave.open(str(ruta)) as w:
        sr, ch, ancho, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        crudo = w.readframes(n)
    if ancho == 1:
        x = (np.frombuffer(crudo, np.uint8).astype(np.float64) - 128) / 128
    elif ancho == 2:
        x = np.frombuffer(crudo, "<i2").astype(np.float64) / 32768
    elif ancho == 3:
        b = np.frombuffer(crudo, np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v >= 1 << 23, v - (1 << 24), v)
        x = v.astype(np.float64) / (1 << 23)
    else:
        x = np.frombuffer(crudo, "<i4").astype(np.float64) / 2 ** 31
    x = x.reshape(-1, ch)
    info = {"sr": sr, "canales": ch, "bits": ancho * 8, "marca": tiene_marca(ruta)}
    return x.mean(axis=1), sr, info


def tiene_marca(ruta):
    try:
        return MARCA in Path(ruta).read_bytes()[-256:]
    except OSError:
        return False


def escribir_wav(ruta, x, marcar=False):
    """WAV mono 44,1 kHz 16 bits; con marcar=True añade LIST/INFO/ISFT = gen_voces.py."""
    datos = (np.clip(x, -1, 1) * 32767).round().astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    trozos = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    trozos += b"data" + struct.pack("<I", len(datos)) + datos
    if len(datos) % 2:
        trozos += b"\0"
    if marcar:
        valor = MARCA + b"\0"
        if len(valor) % 2:
            valor += b"\0"
        info = b"INFO" + b"ISFT" + struct.pack("<I", len(valor)) + valor
        trozos += b"LIST" + struct.pack("<I", len(info)) + info
    Path(ruta).write_bytes(b"RIFF" + struct.pack("<I", 4 + len(trozos)) + b"WAVE" + trozos)


def a_44k(x, sr):
    if sr == SR:
        return x
    from math import gcd
    g = gcd(sr, SR)
    return signal.resample_poly(x, SR // g, sr // g)


def paso_alto(x, fc=90.0):
    sos = signal.butter(2, fc, "highpass", fs=SR, output="sos")
    return signal.sosfiltfilt(sos, x)


def paso_banda(x, f1=90.0, f2=8000.0):
    sos = signal.butter(2, [f1, f2], "bandpass", fs=SR, output="sos")
    return signal.sosfiltfilt(sos, x)


def recortar_silencio(x, umbral_db=-40.0, margen_s=0.03):
    """Quita el silencio del principio y del final (relativo al pico, en ventanas de 10 ms)."""
    if not len(x) or np.max(np.abs(x)) == 0:
        return x
    v = int(0.010 * SR)
    n = len(x) // v
    env = np.array([np.sqrt(np.mean(x[i * v:(i + 1) * v] ** 2)) for i in range(n)]) if n else np.array([])
    ref = np.max(np.abs(x))
    activo = np.where(env > ref * 10 ** (umbral_db / 20))[0]
    if not len(activo):
        return x
    m = int(margen_s * SR)
    a = max(0, activo[0] * v - m)
    b = min(len(x), (activo[-1] + 1) * v + m)
    return x[a:b]


def compresor(x, umbral_db=-24.0, razon=2.5, ataque_s=0.005, suelta_s=0.08):
    """Compresión suave: baja los picos de volumen para que la voz suene pareja."""
    env = np.abs(x)
    a_at, a_su = np.exp(-1 / (ataque_s * SR)), np.exp(-1 / (suelta_s * SR))
    e = np.empty_like(env)
    prev = 0.0
    for i, v in enumerate(env):
        c = a_at if v > prev else a_su
        prev = c * prev + (1 - c) * v
        e[i] = prev
    nivel = 20 * np.log10(np.maximum(e, 1e-9))
    exceso = np.maximum(nivel - umbral_db, 0)
    ganancia = 10 ** (-exceso * (1 - 1 / razon) / 20)
    return x * ganancia


def limitador(x, techo_db=PICO_MAX_DB - 0.3, ventana_s=0.004):
    """Limitador con anticipación: ninguna muestra pasa del techo, sin recortar la onda."""
    techo = 10 ** (techo_db / 20)
    w = max(1, int(ventana_s * SR))
    env = np.abs(x)
    # máximo en una ventana centrada, luego suavizado
    from scipy.ndimage import maximum_filter1d, uniform_filter1d
    env = maximum_filter1d(env, size=2 * w + 1)
    g = np.minimum(1.0, techo / np.maximum(env, 1e-12))
    g = uniform_filter1d(g, size=w)
    g = np.minimum(g, techo / np.maximum(np.abs(x), 1e-12))
    return x * g


def fundidos(x, t=FUNDIDO_S):
    n = min(int(t * SR), len(x) // 2)
    if n > 0:
        r = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n))
        x = x.copy()
        x[:n] *= r
        x[-n:] *= r[::-1]
    return x


def normalizar(x):
    """Ajusta a RMS ≈ −20 dBFS y pico ≤ −1 dBFS (contando el silencio de relleno)."""
    pad = np.zeros(int(SILENCIO_S * SR))
    obj = 10 ** (RMS_OBJETIVO_DB / 20)
    for _ in range(8):
        total = np.concatenate([pad, x, pad])
        r = rms(total)
        if r <= 0:
            break
        x = limitador(x * obj / r)
        if abs(db(rms(np.concatenate([pad, x, pad]))) - RMS_OBJETIVO_DB) < 0.2:
            break
    return np.concatenate([pad, x, pad])


def terminar(x):
    """Cadena común (síntesis y grabaciones): recorte, fundido, nivel y silencios."""
    x = recortar_silencio(x)
    x = fundidos(x)
    x = normalizar(x)
    return fundidos(x, 0.002)


# ---------------------------------------------------------------- síntesis
def sintetizar(frase, espeak="espeak-ng"):
    quien, texto = hablante(frase)
    v = VOCES[quien]
    vel = v["vel"]
    tono = v["tono"]
    if texto.startswith("¡"):          # frases gritadas: más rápidas y más agudas
        vel += 12
        tono += 6
    if len(texto) > 45:                # frases largas: un poco más rápidas
        vel += 8
    with tempfile.TemporaryDirectory() as d:
        ruta = Path(d) / "v.wav"
        subprocess.run([espeak, "-v", v["voz"], "-s", str(vel), "-p", str(tono), "-a", "160",
                        "-g", "2", "-w", str(ruta), texto_para_sintesis(texto)],
                       check=True, capture_output=True)
        x, sr, _ = leer_wav(ruta)
    x = a_44k(x, sr)
    x = paso_banda(x)
    x = compresor(x)
    return terminar(x)


def generar(todas=False):
    espeak = shutil.which("espeak-ng") or "/usr/bin/espeak-ng"
    SALIDA.mkdir(parents=True, exist_ok=True)
    hechas, saltadas = 0, []
    for nombre, _ev, _n, frase in lista_esperada():
        ruta = SALIDA / nombre
        if ruta.exists() and not todas and not tiene_marca(ruta):
            saltadas.append(nombre)
            continue
        escribir_wav(ruta, sintetizar(frase, espeak), marcar=True)
        hechas += 1
    print(f"gen_voces: {hechas} voces sintéticas en {SALIDA.relative_to(RAIZ)}")
    if saltadas:
        print(f"  no se tocaron {len(saltadas)} grabaciones de Tomás: {', '.join(saltadas)}")


# ---------------------------------------------------------------- guion
def escribir_guion():
    frases = leer_frases()
    total = sum(len(v) for v in frases.values())
    orden = [e for e in TITULOS if e in frases] + [e for e in frases if e not in TITULOS]
    L = []
    L.append("# Guion de voces — Delivery Express")
    L.append("")
    L.append("**Tomás Ardila Marín** · voces del domiciliario venezolano (decisión D11)")
    L.append("")
    L.append("> Este archivo lo escribe `python tools/gen_voces.py` a partir de `scripts/voces.gd`. "
             "Si se cambia una frase, se cambia en `voces.gd` y se vuelve a correr el script; "
             "no edites este archivo a mano.")
    L.append("")
    L.append(f"Son **{total} frases** en {len(frases)} situaciones. Ahora mismo el juego trae voces "
             "de relleno hechas por computador (suenan a robot). Cada archivo que grabes con el "
             "**mismo nombre** reemplaza al de relleno, y el juego lo usa sin tocar nada más.")
    L.append("")
    L.append("## 1. Qué hay que entregar")
    L.append("")
    L.append("- Un archivo **WAV** por frase, en la carpeta `assets/voces/`, con el nombre exacto de "
             "la tabla (por ejemplo `recogido_1.wav`).")
    L.append("- **Mono** (un solo canal), **44 100 Hz**, **16 bits**. Si Audacity lo guarda distinto, "
             "no pasa nada: `normalizar_voces.py` lo convierte.")
    L.append("- Una sola toma por archivo, sin ruidos antes ni después. El script recorta el silencio "
             "sobrante, iguala el volumen de todas y deja 0,1 s de silencio a cada lado.")
    L.append("- Las frases que empiezan por **Peatón:** o **Conductor:** las dice otro personaje: "
             "no leas la palabra «Peatón» o «Conductor». Puedes pedírselas a otra persona o "
             "cambiar la voz (más aguda o más grave).")
    L.append("- La columna «Cómo decirla» es solo una pista de actuación: dilo como te salga más natural.")
    L.append("")
    L.append("## 2. El guion")
    L.append("")
    for ev in orden:
        L.append(f"### {TITULOS.get(ev, ev)} (`{ev}`)")
        L.append("")
        L.append("| Archivo | Frase | Cómo decirla |")
        L.append("|---|---|---|")
        for i, fr in enumerate(frases[ev]):
            quien, texto = hablante(fr)
            if quien == "peaton":
                pista = "voz de peatón indignado (otra persona o voz cambiada)"
            elif quien == "conductor":
                pista = "voz de conductor bravo, pitando"
            elif texto.startswith("¡"):
                pista = "gritado, con energía"
            elif texto.startswith("¿") or "?" in texto:
                pista = "preguntando, medio en chiste"
            else:
                pista = "tranquilo, conversado"
            quien_txt = {"peaton": "Peatón: ", "conductor": "Conductor: "}.get(quien, "")
            texto_md = texto.replace("|", "\\|")
            L.append(f"| `{ev}_{i + 1}.wav` | {quien_txt}{texto_md} | {pista} |")
        L.append("")
    L.append("## 3. Cómo grabar (Audacity, paso a paso)")
    L.append("")
    L.append("**Antes de empezar**")
    L.append("")
    L.append("1. Busca el cuarto más «muerto» que tengas: con cama, cortinas, ropa o cojines. Las "
             "paredes desnudas hacen eco. Un clóset lleno de ropa es un estudio excelente.")
    L.append("2. Apaga ventilador, aire y todo lo que zumbe. Cierra la ventana.")
    L.append("3. Pon el micrófono a **un palmo (15–20 cm)** de la boca, un poco de lado para que "
             "las «p» y las «b» no soplen dentro. Si es el micrófono del portátil o de los "
             "audífonos, igual sirve: mantén siempre la misma distancia.")
    L.append("4. En Audacity: arriba, junto al micrófono, elige tu micrófono y **1 canal (mono)**. "
             "Abajo a la izquierda, **Frecuencia del proyecto: 44100 Hz**.")
    L.append("5. Graba una frase gritada de prueba y mira la barra de nivel (arriba): lo más alto "
             "debe quedar alrededor de **−6 dB** y nunca tocar el rojo (0 dB). Si toca el rojo, "
             "baja el volumen del micrófono o aléjate un poco; si casi no se mueve, acércate.")
    L.append("")
    L.append("**Grabando**")
    L.append("")
    L.append("6. Graba **5 segundos de silencio** al principio (quieto, sin hablar): sirve para "
             "quitar el ruido de fondo después.")
    L.append("7. Di cada frase **tres veces seguidas**, con un par de segundos de pausa entre "
             "cada una, y di el nombre del archivo antes («recogido uno»). Así luego eliges la mejor.")
    L.append("8. Exagera: el personaje es un venezolano que habla todo el tiempo y con cariño. "
             "Sonríe mientras hablas (se nota en la voz). Si te equivocas, sigue y repite; se corta después.")
    L.append("9. Graba por bloques (por ejemplo, una situación de la tabla cada vez) y guarda el "
             "proyecto (*Archivo → Guardar proyecto*) de vez en cuando.")
    L.append("")
    L.append("**Limpiando**")
    L.append("")
    L.append("10. **Quitar el ruido de fondo**: selecciona el trozo de silencio del principio → "
             "*Efecto → Reducción de ruido y reparación → Reducción de ruido → Obtener perfil de "
             "ruido*. Luego selecciona toda la pista (Ctrl+A) → otra vez *Reducción de ruido* → "
             "deja los valores (12 dB, 6, 3) → *Aceptar*. Si la voz queda «metálica», deshaz "
             "(Ctrl+Z) y repite con 6 dB.")
    L.append("11. Escucha las tres tomas de una frase, **selecciona la mejor** con el ratón "
             "(un poquito antes de que empiece a hablar y un poquito después de que termine).")
    L.append("12. *Archivo → Exportar → Exportar audio seleccionado…* (o *Exportar selección*). "
             "Tipo: **WAV (Microsoft)**, Codificación: **PCM de 16 bits con signo**, Canales: "
             "**Mono**, Frecuencia: **44100 Hz**. Nombre: el de la tabla, por ejemplo "
             "`recogido_1.wav`, dentro de `assets/voces/`. Si pregunta por metadatos, "
             "*Aceptar* sin llenar nada.")
    L.append("13. Repite 11–12 con cada frase. No hace falta subir el volumen ni igualarlo a mano: "
             "eso lo hace el script del paso siguiente.")
    L.append("")
    L.append("## 4. Después de grabar: dejar los archivos listos")
    L.append("")
    L.append("Abre una terminal en la carpeta del juego y corre, en este orden:")
    L.append("")
    L.append("```bash")
    L.append("python tools/normalizar_voces.py     # ajusta tus grabaciones al formato del juego")
    L.append("python tools/medir_voces.py          # comprueba que todas están bien (0 = todo bien)")
    L.append("```")
    L.append("")
    L.append("- `normalizar_voces.py` convierte a mono 44,1 kHz 16 bits, recorta el silencio, quita "
             "los graves que los portátiles no suenan (debajo de 90 Hz), iguala el volumen de todas "
             "las frases y deja 0,1 s de silencio a cada lado. Avisa si una grabación **satura** "
             "(se grabó demasiado fuerte: hay que repetirla), si es **muy bajita** o **muy larga**, "
             "y dice qué archivos faltan. Se puede correr las veces que quieras: lo que ya está "
             "bien no lo vuelve a tocar.")
    L.append("- Si guardaste las grabaciones en otra carpeta, pásala: "
             "`python tools/normalizar_voces.py C:/ruta/de/mis/grabaciones` (las deja en `assets/voces/`).")
    L.append("- `medir_voces.py` revisa cada archivo esperado: que exista, que sea mono 44,1 kHz, que "
             "su volumen medio esté a ±2 dB del objetivo (−20 dBFS), que el pico no pase de −1 dBFS y "
             "que empiece y termine en silencio. Solo dice «todo bien» (y sale con 0) si pasan todos.")
    L.append("- Después, abre Godot (o corre `godot --headless --path . --import`) para que importe "
             "los WAV nuevos, y juega.")
    L.append("- **Cuidado**: `python tools/gen_voces.py` rehace las voces de robot, pero **no pisa** "
             "tus grabaciones (solo reescribe los archivos que él mismo hizo).")
    L.append("- Cada archivo tuyo necesita su fila en `assets/LICENSES.md` (autor: Tomás Ardila "
             "Marín, grabación propia) antes de repartir el juego.")
    L.append("")
    GUION.parent.mkdir(parents=True, exist_ok=True)
    GUION.write_text("\n".join(L), encoding="utf-8")
    print(f"gen_voces: guion con {total} frases en {GUION.relative_to(RAIZ)}")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--guion" not in args:
        generar(todas="--todas" in args)
    escribir_guion()
