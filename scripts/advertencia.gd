extends Control
## Advertencia de contenido al abrir el juego (CLAUDE.md §8): humor negro y caídas. No se puede
## saltar hasta los 2 s, para que se alcance a leer; después, cualquier tecla o clic sigue.

signal listo

const UI := preload("res://scripts/ui.gd")
const ESPERA := 2.0

var transcurrido := 0.0
var _pista: Label
var _hecho := false


func _ready() -> void:
	var fondo := UI.fondo(self)
	fondo.color = Color.BLACK
	UI.texto(self, "ADVERTENCIA", Vector2(0, 96), 16, UI.C_ROJO, 640.0, "Titulo")
	UI.parrafo(self, "Este juego tiene humor negro: caídas, choques y atropellos de caricatura, sin sangre. Nada de esto se hace en la vida real: en la calle, maneje con cuidado.", Vector2(60, 140), Vector2(520, 60), 8, UI.C_TEXTO, "Texto")
	var franja := ColorRect.new()
	franja.name = "FranjaPista"
	franja.color = Color("1c1c22")
	franja.position = Vector2(0, 306)
	franja.size = Vector2(640, 24)
	add_child(franja)
	_pista = UI.texto(franja, "PULSA UNA TECLA PARA SEGUIR", Vector2(0, 8), 8, UI.C_AMARILLO, 640.0, "Pista")
	_pista.visible = false


func _process(delta: float) -> void:
	avanzar(delta)


func avanzar(delta: float) -> void:
	transcurrido += delta
	_pista.visible = transcurrido >= ESPERA
	if _pista.visible:
		_pista.modulate.a = 0.6 + 0.4 * absf(sin(transcurrido * 3.0)) # parpadea suave


func saltar() -> void:
	if transcurrido < ESPERA or _hecho:
		return
	_hecho = true
	listo.emit()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed and not event.is_echo():
		get_viewport().set_input_as_handled()
		saltar()
