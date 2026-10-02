extends Control
## Menú de pausa (F6, pedido de Tomás): Esc en plena partida congela todo (el tiempo del pedido,
## la hora, el tráfico, los peatones y los sonidos de la calle; la música sigue) y ofrece
## Continuar, Ayuda, Opciones y Volver al menú inicial. Esc otra vez reanuda.

signal al_menu

const UI := preload("res://scripts/ui.gd")
const PANTALLA_OPCIONES := preload("res://scenes/opciones.tscn")
const AYUDA := preload("res://scripts/ayuda.gd")

var opciones # opciones.gd; lo pasa el recorrido (que lo recibe del director)
var _botones: VBoxContainer
var _panel: Control


func _ready() -> void:
	name = "Pausa"
	process_mode = Node.PROCESS_MODE_ALWAYS # es lo único que se mueve mientras el juego está en pausa
	size = Vector2(640, 360)
	visible = false
	var velo := ColorRect.new()
	velo.name = "Velo"
	velo.color = Color(0.05, 0.05, 0.08, 0.72)
	velo.size = size
	add_child(velo)
	_botones = VBoxContainer.new()
	_botones.name = "Botones"
	_botones.position = Vector2(170, 110)
	_botones.size = Vector2(300, 0)
	_botones.add_theme_constant_override("separation", 6)
	add_child(_botones)
	UI.texto(_botones, "PAUSA", Vector2.ZERO, 16, UI.C_AMARILLO, 300.0, "Titulo").custom_minimum_size.y = 34
	UI.boton(_botones, "CONTINUAR", "Continuar").pressed.connect(cerrar)
	UI.boton(_botones, "AYUDA", "Ayuda").pressed.connect(_abrir_ayuda)
	UI.boton(_botones, "OPCIONES", "Opciones").pressed.connect(_abrir_opciones)
	UI.boton(_botones, "VOLVER AL MENÚ INICIAL", "MenuInicial").pressed.connect(_salir)
	var nota := UI.texto(_botones, "El pedido espera: el reloj está quieto.", Vector2.ZERO, 8, UI.C_GRIS, 300.0, "Nota")
	nota.custom_minimum_size.y = 20


func abierta() -> bool:
	return visible


func abrir() -> void:
	visible = true
	_botones.visible = true
	get_tree().paused = true
	(_botones.get_node("Continuar") as Button).grab_focus.call_deferred()


func cerrar() -> void:
	_cerrar_opciones()
	visible = false
	get_tree().paused = false


func _salir() -> void:
	_cerrar_opciones()
	get_tree().paused = false
	al_menu.emit()


func _abrir_opciones() -> void:
	_abrir_panel(PANTALLA_OPCIONES.instantiate(), "PanelOpciones", "Opciones")


func _abrir_ayuda() -> void:
	_abrir_panel(AYUDA.new(), "PanelAyuda", "Ayuda")


## Opciones o ayuda encima de la partida; al volver, el foco regresa a su botón.
func _abrir_panel(panel: Control, nombre: String, boton: String) -> void:
	_panel = panel
	_panel.opciones = opciones
	_panel.volver.connect(func(): _cerrar_opciones_y_enfocar(boton))
	add_child(_panel)
	_panel.name = nombre # después de entrar: la ayuda se pone su propio nombre en _ready
	_botones.visible = false


func _cerrar_opciones() -> void:
	if _panel != null:
		_panel.queue_free()
		remove_child(_panel)
		_panel = null
	_botones.visible = true


func _cerrar_opciones_y_enfocar(boton := "Opciones") -> void:
	_cerrar_opciones()
	(_botones.get_node(boton) as Button).grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if not visible or _panel != null: # con las opciones o la ayuda abiertas, su Esc lo maneja el panel
		return
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		cerrar()
