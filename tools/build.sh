#!/usr/bin/env bash
# Build de entrega en Linux (la nube o el CI). Lo mismo que tools/build.ps1 en Windows:
# licencias -> importar -> pruebas -> exportar el .exe -> comprobar arranque -> .zip.
# Para en el primer fallo.
#
#   GODOT=/ruta/a/godot tools/build.sh
#
# El arranque se comprueba con la exportación de Linux (mismo PCK, misma versión de entrega):
# el .exe de Windows se prueba en Windows con tools/build.ps1 o abriéndolo a mano. No va firmado
# (D31): con el Control inteligente de aplicaciones de Windows 11 prendido, Windows lo bloquea.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
NOMBRE="DeliveryExpress-$VERSION-windows"
SALIDA="build/$NOMBRE"

echo "== 1/6 licencias"
python3 tools/check_entrega.py

echo "== 2/6 importar"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
test -f localization/pantallas.en.translation

echo "== 3/6 pruebas"
"$GODOT" --headless --path . -s res://tests/run_tests.gd | tee build/pruebas.log | tail -1
grep -q " 0 mal" build/pruebas.log

echo "== 4/6 exportar"
rm -rf "$SALIDA" build/linux && mkdir -p "$SALIDA" build/linux
"$GODOT" --headless --path . --export-release "Windows" "$SALIDA/DeliveryExpress.exe" >build/export.log 2>&1
"$GODOT" --headless --path . --export-release "Linux (prueba de arranque)" build/linux/DeliveryExpress.x86_64 >>build/export.log 2>&1
test -s "$SALIDA/DeliveryExpress.exe"

echo "== 5/6 comprobar arranque (versión de entrega)"
rm -f build/arranque.log
inicio=$(date +%s)
CORRER=(build/linux/DeliveryExpress.x86_64)
command -v xvfb-run >/dev/null && CORRER=(xvfb-run -a -s "-screen 0 1280x720x24" "${CORRER[@]}")
timeout 120 "${CORRER[@]}" --log-file "$PWD/build/arranque.log" -- --prueba-arranque >/dev/null 2>&1
grep -q "Delivery Express $VERSION (release)" build/arranque.log
grep -q "trucos=false" build/arranque.log
grep -q "prueba-arranque: OK" build/arranque.log
! grep -q "SCRIPT ERROR" build/arranque.log
echo "   arrancó y recorrió la calle en $(( $(date +%s) - inicio )) s (render por software)"

echo "== 6/6 zip"
cp docs/entrega/LEEME.txt assets/LICENSES.md assets/AI_DISCLOSURE.md assets/fuentes/OFL.txt \
	docs/entrega/GODOT_LICENSE.txt docs/entrega/GODOT_COPYRIGHT.txt "$SALIDA/"
(cd build && rm -f "$NOMBRE.zip" && zip -q -r "$NOMBRE.zip" "$NOMBRE")
ls -la "build/$NOMBRE.zip"
