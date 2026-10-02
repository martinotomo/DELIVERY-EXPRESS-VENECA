#!/usr/bin/env bash
# Versión web para jugar en el navegador (D32). Para en el primer fallo:
# licencias -> importar -> pruebas -> exportar Web -> licencias junto al juego -> ¿se puede publicar?
# -> (si hay Playwright) prueba en Chromium.
#
#   GODOT=/ruta/a/godot tools/build_web.sh
#
# Deja build/web-publico/: exactamente lo que sube a GitHub Pages .github/workflows/web.yml.
# Este script no publica nada.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
WEB="build/web-publico"

echo "== 1/6 licencias"
python3 tools/check_entrega.py

echo "== 2/6 importar"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
test -f localization/pantallas.en.translation

echo "== 3/6 pruebas"
mkdir -p build && touch build/.gdignore # que Godot no importe lo exportado
"$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee build/pruebas.log | grep "comprobaciones"
grep -q " 0 mal" build/pruebas.log

echo "== 4/6 exportar Web (sin hilos: GitHub Pages no manda las cabeceras que piden los hilos)"
rm -rf "$WEB" && mkdir -p "$WEB"
"$GODOT" --headless --path . --export-release "Web" "$WEB/index.html" >build/export-web.log 2>&1
test -s "$WEB/index.wasm" && test -s "$WEB/index.pck"

echo "== 5/6 licencias junto al juego"
cp docs/entrega/GODOT_LICENSE.txt docs/entrega/GODOT_COPYRIGHT.txt assets/fuentes/OFL.txt "$WEB/"
cp LICENSE LICENSE-ASSETS.md assets/LICENSES.md "$WEB/"
touch "$WEB/.nojekyll" # que GitHub Pages sirva los archivos tal cual
python3 tools/check_publico.py "$WEB"

echo "== 6/6 prueba en el navegador"
if command -v node >/dev/null && NODE_PATH="$(npm root -g 2>/dev/null)" node -e 'require("playwright")' 2>/dev/null; then
	NODE_PATH="$(npm root -g)" node tools/probar_web.mjs "$WEB" build/capturas-web > build/probar_web.json
	python3 - <<'PY'
import json
d = json.load(open("build/probar_web.json"))
assert not d["errores"] and not d["errores_script"], d
assert "(release)" in d["linea_version"], d["linea_version"]
assert '"general": 0.95' in (d["linea_opciones_2"] or ""), "las opciones no se guardaron en el navegador"
assert d["audio_rms_menu"] > 0.005, f"no suena nada en el navegador (RMS {d['audio_rms_menu']})"
mb = sum(v["mb"] for v in d["archivos"].values()); gz = sum(v["mb_gzip"] for v in d["archivos"].values())
print(f"   arrancó en {d['segundos_hasta_arrancar']:.1f} s; {mb:.1f} MB ({gz:.1f} MB con gzip); opciones guardadas al recargar")
PY
else
	echo "   (sin Playwright: se salta)"
fi
du -sh "$WEB"
