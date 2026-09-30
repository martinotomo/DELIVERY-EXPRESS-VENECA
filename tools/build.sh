#!/usr/bin/env bash
# Build de entrega en Linux (la nube o el CI). Lo mismo que tools/build.ps1 en Windows:
# licencias -> importar -> pruebas -> exportar el .exe -> comprobar arranque -> .zip.
# Para en el primer fallo.
#
#   GODOT=/ruta/a/godot tools/build.sh
#
# Salen dos zips (D31):
# - DeliveryExpress-<v>-windows.zip: el .exe exportado (plantilla de Godot, con el icono del juego).
#   No va firmado: el Control inteligente de aplicaciones de Windows 11 lo bloquea.
# - DeliveryExpress-<v>-windows-firmado.zip: el binario oficial de Godot 4.7.2 (firmado por
#   Prehensile Tales B.V., bajado de GitHub y comprobado con su SHA-512) renombrado a
#   DeliveryExpress.exe, y el juego al lado en DeliveryExpress.pck, que Godot carga solo por tener
#   el mismo nombre. Renombrar no rompe la firma.
# El arranque se comprueba con los binarios de Linux (mismo PCK): el de entrega y el editor
# renombrado. Los de Windows se prueban en Windows con tools/build.ps1.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
NOMBRE="DeliveryExpress-$VERSION-windows"
SALIDA="build/$NOMBRE"
FIRMADO="build/$NOMBRE-firmado"
GODOT_WIN="Godot_v4.7.2-stable_win64.exe"
RELEASES="https://github.com/godotengine/godot/releases/download/4.7.2-stable"

echo "== 1/6 licencias"
python3 tools/check_entrega.py

echo "== 2/6 importar"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
test -f localization/pantallas.en.translation

echo "== 3/6 pruebas"
"$GODOT" --headless --path . -s res://tests/run_tests.gd | tee build/pruebas.log | tail -1
grep -q " 0 mal" build/pruebas.log

echo "== 4/6 exportar"
rm -rf "$SALIDA" "$FIRMADO" build/linux && mkdir -p "$SALIDA" "$FIRMADO" build/linux
"$GODOT" --headless --path . --export-release "Windows" "$SALIDA/DeliveryExpress.exe" >build/export.log 2>&1
"$GODOT" --headless --path . --export-pack "Windows" "$FIRMADO/DeliveryExpress.pck" >>build/export.log 2>&1
"$GODOT" --headless --path . --export-release "Linux (prueba de arranque)" build/linux/DeliveryExpress.x86_64 >>build/export.log 2>&1
test -s "$SALIDA/DeliveryExpress.exe"
test -s "$FIRMADO/DeliveryExpress.pck"
# El binario oficial firmado, comprobado contra la lista SHA-512 de la versión.
mkdir -p build/cache
if [ ! -f "build/cache/$GODOT_WIN.zip" ]; then
	curl -sSfL -o "build/cache/$GODOT_WIN.zip" "$RELEASES/$GODOT_WIN.zip"
fi
esperado=$(curl -sSfL "$RELEASES/SHA512-SUMS.txt" | awk -v f="$GODOT_WIN.zip" '$2 == f {print $1}')
test "$(sha512sum "build/cache/$GODOT_WIN.zip" | cut -d" " -f1)" = "$esperado"
unzip -o -q -j "build/cache/$GODOT_WIN.zip" "$GODOT_WIN" -d build/cache
cp "build/cache/$GODOT_WIN" "$FIRMADO/DeliveryExpress.exe"
python3 - "$FIRMADO/DeliveryExpress.exe" <<'PY'
import struct, sys
# Tiene firma Authenticode (tabla de certificados del PE); que sea válida lo dice Windows (build.ps1).
d = open(sys.argv[1], "rb").read()
pe = struct.unpack_from("<I", d, 0x3C)[0]
opt = pe + 24
dirs = opt + (112 if struct.unpack_from("<H", d, opt)[0] == 0x20B else 96)
va, tam = struct.unpack_from("<II", d, dirs + 4 * 8) # entrada 4: tabla de certificados (offset en el archivo)
assert tam > 0, "el binario de Godot no trae firma"
assert b"Prehensile Tales" in d[va:va + tam], "la firma no es la de Godot"
print("   firma Authenticode de Prehensile Tales B.V.: %d bytes" % tam)
PY

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
echo "   plantilla de entrega: arrancó y recorrió la calle en $(( $(date +%s) - inicio )) s (render por software)"
# El mismo .pck con el editor de Godot renombrado, como el zip firmado (en Linux, el editor de aquí).
rm -rf build/linux-firmado && mkdir -p build/linux-firmado
cp "$FIRMADO/DeliveryExpress.pck" build/linux-firmado/
cp "$(command -v "$GODOT" || echo "$GODOT")" build/linux-firmado/DeliveryExpress
CORRER=(build/linux-firmado/DeliveryExpress)
command -v xvfb-run >/dev/null && CORRER=(xvfb-run -a -s "-screen 0 1280x720x24" "${CORRER[@]}")
rm -f build/arranque-firmado.log
timeout 120 "${CORRER[@]}" --log-file "$PWD/build/arranque-firmado.log" -- --prueba-arranque >/dev/null 2>&1
grep -q "Delivery Express $VERSION (entrega)" build/arranque-firmado.log
grep -q "trucos=false" build/arranque-firmado.log
grep -q "prueba-arranque: OK" build/arranque-firmado.log
echo "   editor renombrado + .pck: carga el juego solo, en modo entrega y sin F9/F10"

echo "== 6/6 zip"
for d in "$SALIDA" "$FIRMADO"; do
	cp docs/entrega/LEEME.txt assets/LICENSES.md assets/AI_DISCLOSURE.md assets/fuentes/OFL.txt "$d/"
done
cp docs/entrega/GODOT_LICENSE.txt docs/entrega/GODOT_COPYRIGHT.txt "$FIRMADO/"
cp assets/ui/icono.ico "$FIRMADO/DeliveryExpress.ico" # para ponérselo a un acceso directo
(cd build && rm -f "$NOMBRE.zip" "$NOMBRE-firmado.zip" && zip -q -r "$NOMBRE.zip" "$NOMBRE" && zip -q -r "$NOMBRE-firmado.zip" "$NOMBRE-firmado")
ls -la "build/$NOMBRE.zip" "build/$NOMBRE-firmado.zip"
