extends SceneTree
## Corredor de pruebas. Uso:
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --solo=moto
## Sale con 0 solo si todo pasa. Un vigilante aborta a los 150 s si algo se cuelga.

const SUITES := {
	"motos": "res://tests/test_motos.gd",
	"ciudad": "res://tests/test_ciudad.gd",
	"moto": "res://tests/test_moto.gd",
	"motor": "res://tests/test_motor.gd",
	"partida": "res://tests/test_partida.gd",
	"progreso": "res://tests/test_progreso.gd",
	"ciclo": "res://tests/test_ciclo.gd",
	"voces": "res://tests/test_voces.gd",
	"mensajes": "res://tests/test_mensajes.gd",
	"escenas": "res://tests/test_escenas.gd",
}
const LIMITE_S := 150.0

var fallos := 0
var pasadas := 0
var _suite_actual := ""


func _initialize() -> void:
	TranslationServer.set_locale("es")
	create_timer(LIMITE_S).timeout.connect(_vigilante)
	_correr.call_deferred()


func _vigilante() -> void:
	printerr("VIGILANTE: las pruebas pasaron de %d s; algo se colgó en '%s'." % [LIMITE_S, _suite_actual])
	quit(2)


func _correr() -> void:
	# Sin importar, las texturas llegan nulas y el error no dice por qué (CLAUDE.md §4).
	if load("res://assets/ui/manubrio.png") == null:
		printerr("Faltan los assets importados: corre antes  godot --headless --path . --import")
		quit(1)
		return
	var solo := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--solo="):
			solo = arg.substr(7)
	if solo != "" and not SUITES.has(solo):
		printerr("No existe la suite '%s'. Hay: %s" % [solo, ", ".join(SUITES.keys())])
		quit(1)
		return
	for nombre in SUITES:
		if solo != "" and nombre != solo:
			continue
		_suite_actual = nombre
		print("== %s" % nombre)
		var script = load(SUITES[nombre])
		if script == null or not script.can_instantiate():
			check(false, "la suite no compila: %s" % SUITES[nombre])
			continue
		await script.new().run(self)
	print("")
	print("%d comprobaciones: %d bien, %d mal" % [pasadas + fallos, pasadas, fallos])
	quit(0 if fallos == 0 else 1)


## Registra una comprobación. Las suites llaman a esto.
func check(condicion: bool, descripcion: String) -> void:
	if condicion:
		pasadas += 1
	else:
		fallos += 1
		printerr("  FALLA [%s] %s" % [_suite_actual, descripcion])


func check_eq(obtenido, esperado, descripcion: String) -> void:
	check(obtenido == esperado, "%s (obtenido: %s, esperado: %s)" % [descripcion, str(obtenido), str(esperado)])
