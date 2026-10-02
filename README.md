# Delivery Express

Un juego de **Tomás Ardila Marín** (estudiante de ingeniería mecánica, Escuela Colombiana de
Ingeniería Julio Garavito), hecho por ocio y abierto para quien quiera seguirlo.

Eres domiciliario en una ciudad tipo Bogotá, en primera persona y a lo *Doom*: recoges y
entregas pedidos guiado por el minimapa, con huecos, perros, buses, lluvia y un día que pasa
cada 10 minutos. El chiste es uno solo: si entras demasiado rápido en la curva, la moto se va
de lado y «tu fe era más grande que el agarre de tu Bwis». Con lo que ganas compras la NKD 125
y, al final, la Ninja 300.

**Jugar en el navegador:** https://martinotomo.github.io/DELIVERY-EXPRESS-VENECA/ *(cuando se active
GitHub Pages)* · **Windows:** el `.exe` sale de `tools/build.ps1` o `tools/build.sh`.

> Humor negro: caídas, choques y atropellos de caricatura, sin sangre. Nada de esto se hace en
> la calle de verdad.

| Tecla | Qué hace |
|---|---|
| W / ↑ | acelerar |
| S / ↓ / espacio | frenar |
| A D / ← → | girar |
| H | pito (no sirve para nada, como en la vida real) |
| Tab | mapa completo |
| Esc / P | pausa (en el navegador en pantalla completa, P) |

Las letras se cambian en *Opciones*. El juego está en español e inglés.

## Cómo correrlo

Necesitas **Godot 4.7.2** (estable, el normal, no .NET):
https://godotengine.org/download/archive/4.7.2-stable/

```bash
git clone https://github.com/martinotomo/DELIVERY-EXPRESS-VENECA.git
cd DELIVERY-EXPRESS-VENECA
godot --headless --path . --import      # obligatorio en una copia nueva: importa PNG, WAV, CSV…
godot --path .                          # jugar
```

O abre `project.godot` en el editor de Godot y dale a *Play*. En Windows, si `godot` no está en
el PATH, usa la ruta completa del ejecutable.

## Pruebas

```bash
godot --headless --path . -s res://tests/run_tests.gd               # todas (sale 0 solo si pasan)
godot --headless --path . -s res://tests/run_tests.gd -- --solo=motos   # una sola suite
python3 tools/check_entrega.py                                      # cada asset tiene licencia
```

Hay más de mil comprobaciones y corren en menos de un minuto. La lógica (moto, partida, ciudad,
clima, tráfico…) vive en clases `RefCounted` con `advance(delta)`, así que una prueba puede
adelantar el tiempo sin jugar. Las pruebas se escriben primero; ver `CLAUDE.md` §5 y §6.

## Arte y sonido por código

Todo el arte, los sonidos y la música salen de scripts de Python en `tools/` (Python 3.12 con
`numpy`, `scipy` y `Pillow`: `pip install -r requirements.txt`). Por ejemplo:

```bash
python3 tools/gen_motos_taller.py    # las motos del taller
python3 tools/gen_sonidos.py         # motor, choques, ciudad…
python3 tools/gen_musica.py          # música
godot --headless --path . --import   # y volver a importar
```

La paleta vive en `tools/paleta.py`. Para mirar el resultado: `tools/capturas.gd` (capturas del
juego en momentos concretos, necesita ventana o `xvfb-run`) y `tools/gen_hoja_visual.py`.

## Builds

| Qué | Cómo | Sale en |
|---|---|---|
| `.exe` de Windows | `tools/build.sh` (Linux) o `tools/build.ps1` (Windows) | `build/DeliveryExpress-<versión>-windows.zip` |
| Versión web | `tools/build_web.sh` | `build/web-publico/` |

Necesitan las plantillas de exportación de Godot 4.7.2. Los dos scripts corren antes las pruebas
y las licencias, y el arranque se comprueba con `--prueba-arranque`. El `.exe` no va firmado, así
que el *Control inteligente de aplicaciones* de Windows 11 lo bloquea; la versión web no tiene
ese problema. La web se publica sola en GitHub Pages desde `main` con
`.github/workflows/web.yml`.

## Cómo está organizado

| Carpeta | Qué hay |
|---|---|
| `scripts/` | GDScript. `main.gd` es el único que cambia de pantalla; `partida.gd`, `moto_logic.gd`, `ciudad.gd`, `trafico.gd`… es la lógica que se prueba; `recorrido.gd` dibuja la calle |
| `scenes/` | Escenas mínimas (cada una apunta a su script) |
| `tests/` | Corredor propio (`run_tests.gd`) y una suite por tema |
| `tools/` | Generadores de assets, capturas, builds y chequeos de licencias |
| `assets/` | Lo que generan los scripts, más la letra; `LICENSES.md` y `AI_DISCLOSURE.md` |
| `localization/` | Textos en español e inglés (`clave = texto en español`) |
| `docs/` | Dirección visual y lo que va con la entrega |

**Las decisiones del proyecto** (qué se decidió, cuándo y por qué) están numeradas en
[`CLAUDE.md` §0](CLAUDE.md#0-decisiones-de-tomás-mandan-sobre-todo-lo-demás). Ese archivo
también recoge las reglas de trabajo con Godot sin editor que costaron caro. Para colaborar, ver
[CONTRIBUTING.md](CONTRIBUTING.md).

## Licencia

- Código: **MIT** ([LICENSE](LICENSE)).
- Arte, sonido y música propios: **CC BY 4.0** ([LICENSE-ASSETS.md](LICENSE-ASSETS.md)).
- Letra Press Start 2P: SIL OFL 1.1. Godot Engine: MIT.

Hecho con Godot, Python, Audacity y OBS, todo libre. Parte del código se escribió con ayuda de
Claude Code (Anthropic); lo generado con IA está anotado en `assets/AI_DISCLOSURE.md`.

---

## English

**Delivery Express** is a small first-person (*Doom*-style) delivery-rider game set in a
Bogotá-like city, with dark humor: take a corner too fast and "your faith was bigger than your
bike's grip". Made for fun by Tomás Ardila Marín and open for anyone to continue.

- **Run:** install Godot 4.7.2, then `godot --headless --path . --import` once and
  `godot --path .`.
- **Test:** `godot --headless --path . -s res://tests/run_tests.gd` (exits 0 only if everything
  passes).
- **Assets** are generated by the Python scripts in `tools/`. **Builds:** `tools/build.sh`
  (Windows `.exe`) and `tools/build_web.sh` (browser build).
- The code, comments and project decisions (`CLAUDE.md`) are in Spanish; the game itself also
  plays in English. Issues and pull requests in English are welcome.
- **License:** MIT for code, CC BY 4.0 for the game's own art and sound, OFL for the font.
