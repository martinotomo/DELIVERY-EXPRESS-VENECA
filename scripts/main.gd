extends Node
## Director: el único que crea y destruye pantallas. Nunca hay dos vivas a la vez.
## Guarda el progreso (plata, moto, mejoras), que sobrevive a todas las pantallas.

const PROGRESO := preload("res://scripts/progreso.gd")
const MENU := preload("res://scenes/menu.tscn")
const TALLER := preload("res://scenes/taller.tscn")
const RECORRIDO := preload("res://scenes/recorrido.tscn")
const RESULTADO := preload("res://scenes/resultado.tscn")

## Las pruebas la cambian antes de instanciar para no tocar la partida guardada de verdad.
static var ruta_progreso := "user://progreso.cfg"

var progreso

@onready var _pantallas: Node = $Pantallas


func _ready() -> void:
	progreso = PROGRESO.new(ruta_progreso)
	menu()


func pantalla_actual() -> Node:
	var hijos := _pantallas.get_children()
	return hijos[0] if hijos.size() > 0 else null


func menu() -> void:
	var m := _mostrar(MENU)
	m.jugar.connect(reiniciar, CONNECT_DEFERRED)
	m.taller.connect(taller, CONNECT_DEFERRED)
	m.salir.connect(func(): get_tree().quit())


func taller() -> void:
	var t := _mostrar(TALLER)
	t.volver.connect(menu, CONNECT_DEFERRED)


func reiniciar() -> void:
	var ride := _mostrar(RECORRIDO)
	ride.partida.pagado.connect(progreso.ganar)
	ride.terminado.connect(_al_terminar)
	ride.reintentar.connect(reiniciar, CONNECT_DEFERRED)
	ride.al_menu.connect(menu, CONNECT_DEFERRED)


func _al_terminar(estado: String, mensaje: String) -> void:
	_mostrar_resultado.call_deferred(estado, mensaje)


func _mostrar_resultado(estado: String, mensaje: String) -> void:
	var res := _mostrar(RESULTADO)
	res.mostrar(estado, mensaje)
	res.continuar.connect(reiniciar, CONNECT_DEFERRED)
	res.al_menu.connect(menu, CONNECT_DEFERRED)


## Cada pantalla recibe el progreso antes de entrar al árbol (su _ready ya lo tiene).
func _mostrar(escena: PackedScene) -> Node:
	for hijo in _pantallas.get_children():
		_pantallas.remove_child(hijo)
		hijo.queue_free()
	var nueva := escena.instantiate()
	if "progreso" in nueva:
		nueva.progreso = progreso
	_pantallas.add_child(nueva)
	return nueva
