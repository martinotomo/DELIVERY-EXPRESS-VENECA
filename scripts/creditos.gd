extends Control
## Créditos (F6): suben solos a 44 px/s y se saltan con ESPACIO, ENTER o ESC. Al acabar vuelven
## al menú. La pista de salto va sobre su propia franja (CLAUDE.md §5, error 7).

signal volver

const UI := preload("res://scripts/ui.gd")
const VELOCIDAD := 44.0
## [texto, tamaño, color]. Los textos son las claves de localization/pantallas.csv.
const LINEAS := [
	["DELIVERY EXPRESS", 16, "rojo"],
	["", 8, ""],
	["UN JUEGO DE", 8, "amarillo"],
	["Tomás Ardila Marín", 16, ""],
	["Estudiante de ingeniería mecánica", 8, "gris"],
	["Escuela Colombiana de Ingeniería Julio Garavito", 8, "gris"],
	["", 8, ""],
	["PROGRAMACIÓN, ARTE Y SONIDO", 8, "amarillo"],
	["Tomás Ardila Marín con Claude Code (Anthropic)", 8, ""],
	["Todo el arte y el sonido salen de scripts de Python (tools/).", 8, "gris"],
	["", 8, ""],
	["HERRAMIENTAS LIBRES", 8, "amarillo"],
	["Godot Engine 4.7 (licencia MIT)", 8, ""],
	["Python, NumPy, SciPy y Pillow (licencias BSD y HPND)", 8, ""],
	["Audacity y OBS Studio para escuchar y grabar (GPL)", 8, ""],
	["", 8, ""],
	["LETRA", 8, "amarillo"],
	["Press Start 2P, de CodeMan38 (SIL Open Font License 1.1)", 8, ""],
	["", 8, ""],
	["LICENCIAS", 8, "amarillo"],
	["Código: MIT. Arte, sonido y música: CC BY 4.0.", 8, ""],
	["Cada archivo tiene su fila en assets/LICENSES.md", 8, ""],
	["y lo hecho con IA está en assets/AI_DISCLOSURE.md", 8, ""],
	["", 8, ""],
	["CÓDIGO ABIERTO", 8, "amarillo"],
	["github.com/martinotomo/juego-motos-2d", 8, ""],
	["", 8, ""],
	["", 8, ""],
	["Ningún domiciliario salió herido haciendo este juego.", 8, "gris"],
	["", 8, ""],
	["GRACIAS POR JUGAR", 16, "rojo"],
]
const COLORES := {"": UI.C_TEXTO, "rojo": UI.C_ROJO, "amarillo": UI.C_AMARILLO, "gris": UI.C_GRIS}

var _contenido: Control
var _alto := 0.0
var _hecho := false


func _ready() -> void:
	UI.fondo(self)
	_contenido = Control.new()
	_contenido.name = "Contenido"
	_contenido.position = Vector2(0, 340)
	add_child(_contenido)
	var y := 0.0
	for l in LINEAS:
		if l[0] != "":
			UI.texto(_contenido, l[0], Vector2(0, y), l[1], COLORES[l[2]], 640.0)
		y += l[1] + 10.0
	_alto = y
	var franja := ColorRect.new()
	franja.name = "FranjaPista"
	franja.color = UI.C_FONDO
	franja.position = Vector2(0, 338)
	franja.size = Vector2(640, 22)
	add_child(franja)
	UI.texto(franja, "ESPACIO: SALTAR", Vector2(0, 7), 8, UI.C_GRIS, 640.0, "Pista")


func _process(delta: float) -> void:
	avanzar(delta)


func avanzar(delta: float) -> void:
	_contenido.position.y -= VELOCIDAD * delta
	if _contenido.position.y + _alto < 0.0:
		saltar()


func saltar() -> void:
	if _hecho:
		return
	_hecho = true
	volver.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		saltar()
