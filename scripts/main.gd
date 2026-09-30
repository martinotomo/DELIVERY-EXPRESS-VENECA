extends Node
## Director: el único que crea y destruye pantallas. Nunca hay dos vivas a la vez.

const RECORRIDO := preload("res://scenes/recorrido.tscn")
const RESULTADO := preload("res://scenes/resultado.tscn")

@onready var _pantallas: Node = $Pantallas


func _ready() -> void:
	reiniciar()


func pantalla_actual() -> Node:
	var hijos := _pantallas.get_children()
	return hijos[0] if hijos.size() > 0 else null


func reiniciar() -> void:
	var ride := _mostrar(RECORRIDO)
	ride.terminado.connect(_al_terminar)
	ride.reintentar.connect(reiniciar, CONNECT_DEFERRED)


func _al_terminar(estado: String, mensaje: String) -> void:
	_mostrar_resultado.call_deferred(estado, mensaje)


func _mostrar_resultado(estado: String, mensaje: String) -> void:
	var res := _mostrar(RESULTADO)
	res.mostrar(estado, mensaje)
	res.continuar.connect(reiniciar, CONNECT_DEFERRED)


func _mostrar(escena: PackedScene) -> Node:
	for hijo in _pantallas.get_children():
		_pantallas.remove_child(hijo)
		hijo.queue_free()
	var nueva := escena.instantiate()
	_pantallas.add_child(nueva)
	return nueva
