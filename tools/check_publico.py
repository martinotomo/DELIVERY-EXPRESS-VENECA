"""¿Se puede publicar esta versión web? (GitHub Pages desde este repo, D32)

    python tools/check_publico.py build/web

Falla (código 1) si:
- alguna fila de assets/LICENSES.md tiene una licencia que no deja publicar («privado», «sin
  licencia»), como lo estuvieron las motos recortadas de memes (D21, ya cambiadas);
- el .pck de la web lleva algo de docs/ (ahí están las imágenes de referencia de Tomás) o un
  recorte de los memes;
- falta en la carpeta la licencia de Godot (MIT) o la de la letra (OFL), que hay que repartir con
  el juego.
Probado en negativo: con las filas viejas de D21 en LICENSES.md se ponía en rojo.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PROHIBIDO = re.compile(r"privad|sin licencia", re.IGNORECASE)
RUTAS_PROHIBIDAS = (b"res://docs/", b"docs/referencias", b"moto_bws.png", b"moto_nkd.png", b"moto_ninja.png")
LICENCIAS_JUNTO = ("GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt", "OFL.txt")


def main():
    web = Path(sys.argv[1]) if len(sys.argv) > 1 else RAIZ / "build" / "web"
    problemas = []
    for linea in (RAIZ / "assets" / "LICENSES.md").read_text(encoding="utf-8").splitlines():
        celdas = [c.strip() for c in linea.strip().strip("|").split("|")]
        if len(celdas) >= 4 and celdas[0] not in ("Archivo", "---") and PROHIBIDO.search(celdas[3]):
            problemas.append(f"assets/{celdas[0]}: licencia «{celdas[3][:60]}» no deja publicar")
    pck = web / "index.pck"
    if not pck.exists():
        problemas.append(f"no está {pck}")
    else:
        datos = pck.read_bytes()
        for ruta in RUTAS_PROHIBIDAS:
            if ruta in datos:
                problemas.append(f"el .pck lleva {ruta.decode()}")
    for f in LICENCIAS_JUNTO:
        if not (web / f).exists():
            problemas.append(f"falta {f} junto al juego")
    for p in problemas:
        print("NO SE PUEDE PUBLICAR:", p)
    if problemas:
        sys.exit(1)
    print("check_publico: la versión web se puede publicar")


if __name__ == "__main__":
    main()
