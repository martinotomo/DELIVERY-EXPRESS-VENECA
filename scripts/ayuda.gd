extends Control
## Ayuda (Tomás, 02/10/2026): de qué se trata, qué hace cada tecla (las de verdad, también las que
## se cambiaron en Opciones) y las mismas reglas de la pantalla de carga: qué mata y qué cuesta.
## Sirve de pantalla (desde el menú) y de panel encima de la partida (desde la pausa). Esc o
## VOLVER regresan.

signal volver

const UI := preload("res://scripts/ui.gd")
const OPCIONES := preload("res://scripts/opciones.gd")
const CARGA := preload("res://scripts/carga.gd")
## Las teclas fijas de cada acción (project.godot); la de letra sale de las opciones.
const FIJAS := {
	"acelerar": "↑", "frenar": "↓ / ESPACIO", "izquierda": "←", "derecha": "→", "pitar": "", "mapa": "",
}
const NOMBRES := {
	"acelerar": "ACELERAR", "frenar": "FRENAR", "izquierda": "IZQUIERDA", "derecha": "DERECHA",
	"pitar": "PITO", "mapa": "MAPA",
}
const NOTAS := {"pitar": "no sirve de nada", "mapa": "la partida espera"}

var opciones # opciones.gd; lo pone el director (o la pausa)


func _ready() -> void:
	name = "Ayuda"
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.fondo(self)
	UI.texto(self, "AYUDA", Vector2(0, 8), 16, UI.C_AMARILLO, 640.0, "Titulo")
	UI.parrafo(self, "Recoge en la columna naranja y entrega en la verde antes de que se acabe el tiempo. Con la plata compras mejoras y motos en el TALLER.",
		Vector2(20, 32), Vector2(600, 24), 8, UI.C_GRIS, "Objetivo")

	UI.texto(self, "TECLAS", Vector2(CARGA.COL_X[0], 66), 8, UI.C_AMARILLO, 0.0, "TeclasTitulo")
	var izq := _lista("TeclasMovimiento", Vector2(CARGA.COL_X[0], 82))
	var der := _lista("TeclasOtras", Vector2(CARGA.COL_X[1], 82))
	for accion in ["acelerar", "frenar", "izquierda", "derecha"]:
		_linea(izq, accion, "%s: %s" % [tr(NOMBRES[accion]), _teclas(accion)])
	for accion in ["pitar", "mapa"]:
		_linea(der, accion, "%s: %s (%s)" % [tr(NOMBRES[accion]), _teclas(accion), tr(NOTAS[accion])])
	_linea(der, "pausar", "%s: ESC / P" % tr("PAUSAR"))
	_linea(der, "otra", "%s: ENTER / R (%s)" % [tr("OTRA JORNADA"), tr("al caer")])

	CARGA.columna_reglas(self, "TeMata", "TE MATA", UI.C_ROJO, CARGA.TE_MATA, Vector2(CARGA.COL_X[0], 140), 6)
	CARGA.columna_reglas(self, "TeCuesta", "TE CUESTA", UI.C_AMARILLO, CARGA.TE_CUESTA, Vector2(CARGA.COL_X[1], 140), 6)
	UI.parrafo(self, "Morir no te quita la plata.", Vector2(0, 294), Vector2(640, 12), 8, UI.C_GRIS, "Plata")

	var b := UI.boton(self, "VOLVER", "Volver")
	b.custom_minimum_size = Vector2(300, 22)
	b.position = Vector2(170, 318)
	b.size = b.custom_minimum_size
	b.pressed.connect(func(): volver.emit())
	b.grab_focus.call_deferred()


## La tecla de letra (la de las opciones) y la fija, p. ej. «W / ↑».
func _teclas(accion: String) -> String:
	var teclas: Dictionary = opciones.teclas if opciones != null else OPCIONES.TECLAS_FABRICA
	var letra := OPCIONES.nombre_tecla(teclas[accion])
	var fija: String = FIJAS[accion]
	if fija == "":
		return letra
	return "%s / %s" % [letra, fija.replace("ESPACIO", tr("ESPACIO"))]


func _lista(nombre: String, pos: Vector2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = nombre
	v.position = pos
	v.size = Vector2(CARGA.COL_ANCHO, 0)
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	return v


func _linea(padre: Node, nombre: String, t: String) -> void:
	var l := Label.new()
	l.name = "Tecla_" + nombre
	l.text = t
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED # ya va traducido (lleva la tecla adentro)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", UI.C_TEXTO)
	padre.add_child(l)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var tecla := event as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo and (tecla.physical_keycode == KEY_ESCAPE or tecla.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		volver.emit()
