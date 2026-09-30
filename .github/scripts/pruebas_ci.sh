#!/usr/bin/env bash
# Corre en el CI lo mismo que Tomás corre en su PC: importar, pruebas y licencias.
# Uso: GODOT=/ruta/a/godot .github/scripts/pruebas_ci.sh
# Sale distinto de 0 si algo falla, o si Godot imprime un error de script aunque salga 0.
set -uo pipefail

GODOT="${GODOT:-godot}"
LOG_DIR="${LOG_DIR:-ci_logs}"
mkdir -p "$LOG_DIR"

if [ ! -f project.godot ]; then
  echo "::notice::Todavía no hay project.godot: no hay nada que importar ni probar."
  exit 0
fi

# Errores que Godot imprime sin cambiar el código de salida.
ERRORES='SCRIPT ERROR|Parse Error|Failed to load script|ERROR: Failed loading resource'

revisar_log() {
  local log="$1"
  if grep -Eq "$ERRORES" "$log"; then
    echo "::error::Godot imprimió errores de script en $log:"
    grep -En "$ERRORES" "$log" | head -20
    return 1
  fi
  return 0
}

echo "== Importar assets"
"$GODOT" --headless --path . --import >"$LOG_DIR/importar.log" 2>&1
codigo=$?
cat "$LOG_DIR/importar.log"
if [ $codigo -ne 0 ]; then
  echo "::error::La importación salió con código $codigo."
  exit 1
fi
revisar_log "$LOG_DIR/importar.log" || exit 1

echo "== Pruebas"
if [ ! -f tests/run_tests.gd ]; then
  echo "::error::Hay project.godot pero falta tests/run_tests.gd (el corredor de pruebas de la F0)."
  exit 1
fi
"$GODOT" --headless --path . -s res://tests/run_tests.gd >"$LOG_DIR/pruebas.log" 2>&1
codigo=$?
cat "$LOG_DIR/pruebas.log"
if [ $codigo -ne 0 ]; then
  echo "::error::Las pruebas salieron con código $codigo."
  exit 1
fi
revisar_log "$LOG_DIR/pruebas.log" || exit 1

echo "== Licencias y registro de IA"
if [ -f tools/check_entrega.py ]; then
  python3 tools/check_entrega.py || { echo "::error::check_entrega.py falló."; exit 1; }
else
  echo "::warning::Todavía no existe tools/check_entrega.py."
fi

echo "Todo en verde."
