"""Comprueba que cada archivo de assets/ tiene su fila en LICENSES.md y en AI_DISCLOSURE.md.

    python tools/check_entrega.py            # sale 0 si todo está registrado

Se ignoran los .import y .uid de Godot y los propios registros .md.
"""
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ASSETS = RAIZ / "assets"
IGNORAR = {".import", ".uid", ".md"}


def faltantes(registro: Path) -> list[str]:
    texto = registro.read_text(encoding="utf-8") if registro.exists() else ""
    faltan = []
    for f in sorted(ASSETS.rglob("*")):
        if f.is_file() and f.suffix not in IGNORAR:
            rel = f.relative_to(ASSETS).as_posix()
            if f"| {rel} |" not in texto:
                faltan.append(rel)
    return faltan


def main() -> int:
    mal = 0
    for nombre in ("LICENSES.md", "AI_DISCLOSURE.md"):
        for rel in faltantes(ASSETS / nombre):
            print(f"FALTA en {nombre}: {rel}")
            mal += 1
    if mal == 0:
        print("check_entrega: todos los assets están registrados")
    return 1 if mal else 0


if __name__ == "__main__":
    sys.exit(main())
