extends Control
## Opciones (F6): volumen general, de música y de efectos; pantalla completa; idioma; teclas.
## Sirve de pantalla (desde el menú) y de panel encima de la partida (desde la pausa). Todo se aplica
## y se guarda al momento. Esc vuelve (o cancela si se está esperando una tecla).

signal volver

const UI := preload("res://scripts/ui.gd")
const OPCIONES := preload("res://scripts/opciones.gd")
const NOMBRES_ACCION := {
	"acelerar": "ACELERAR", "frenar": "FRENAR", "izquierda": "IZQUIERDA", "derecha": "DERECHA",
	"pitar": "PITO", "mapa": "MAPA",
}
const NOMBRES_IDIOMA := {"es": "ESPAÑOL", "en": "ENGLISH"}
const COL_IZQ := 40.0
const COL_DER := 330.0
const ANCHO_COL := 270.0

var opciones # opciones.gd; lo pone el director (o la pausa)
var esperando_tecla := "" # la acción a la que se le está cambiando la tecla
var _aviso: Label


func _ready() -> void:
	if opciones == null:
		opciones = OPCIONES.new()
	construir()


## Arma (o rearma, al cambiar de idioma) todos los controles.
func construir(foco := "") -> void:
	for hijo in get_children():
		remove_child(hijo)
		hijo.queue_free()
	var fondo := UI.fondo(self)
	fondo.color.a = 0.96 # desde la pausa se adivina la calle detrás
	UI.texto(self, "OPCIONES", Vector2(0, 14), 16, UI.C_ROJO, 640.0, "Titulo")

	UI.texto(self, "SONIDO", Vector2(COL_IZQ, 52), 8, UI.C_AMARILLO)
	var y := 70.0
	for cual in ["general", "musica", "efectos"]:
		_barra(cual, y)
		y += 24.0

	UI.texto(self, "PANTALLA", Vector2(COL_IZQ, 150), 8, UI.C_AMARILLO)
	var completa := CheckButton.new()
	completa.name = "PantallaCompleta"
	completa.text = "PANTALLA COMPLETA"
	completa.button_pressed = opciones.pantalla_completa
	completa.position = Vector2(COL_IZQ - 4, 164)
	completa.add_theme_font_size_override("font_size", 8)
	completa.custom_minimum_size = Vector2(ANCHO_COL - 30, 22)
	completa.add_theme_color_override("font_focus_color", UI.C_AMARILLO)
	completa.add_theme_color_override("font_hover_color", UI.C_AMARILLO)
	completa.add_theme_stylebox_override("focus", _marco_foco())
	completa.toggled.connect(func(si):
		opciones.poner_pantalla_completa(si)
		opciones.guardar())
	add_child(completa)
	completa.set_deferred("size", completa.custom_minimum_size) # medido ya con la letra a 8 px

	UI.texto(self, "IDIOMA", Vector2(COL_IZQ, 198), 8, UI.C_AMARILLO)
	var idioma := _boton(tr("IDIOMA") + ": " + NOMBRES_IDIOMA[opciones.idioma], "Idioma", Vector2(COL_IZQ, 212))
	idioma.pressed.connect(_cambiar_idioma)

	UI.texto(self, "TECLAS", Vector2(COL_DER, 52), 8, UI.C_AMARILLO)
	y = 66.0
	for accion in OPCIONES.ACCIONES:
		var b := _boton(_texto_tecla(accion), "Tecla_" + accion, Vector2(COL_DER, y))
		b.pressed.connect(_esperar_tecla.bind(accion))
		y += 25.0
	UI.parrafo(self, "Las flechas y el espacio siempre funcionan.", Vector2(COL_DER, y + 2), Vector2(ANCHO_COL, 24), 8, UI.C_GRIS, "Nota")
	var rest := _boton("RESTABLECER TECLAS", "Restablecer", Vector2(COL_DER, y + 30))
	rest.pressed.connect(func():
		opciones.restablecer_teclas()
		opciones.guardar()
		_aviso.text = ""
		_refrescar_teclas())

	_aviso = UI.texto(self, "", Vector2(0, 298), 8, UI.C_ROJO, 640.0, "Aviso")
	var b_volver := _boton("VOLVER", "Volver", Vector2(170, 318))
	b_volver.custom_minimum_size.x = 300
	b_volver.size.x = 300
	b_volver.pressed.connect(func(): volver.emit())
	var enfocar: Control = find_child(foco, true, false) if foco != "" else null
	(enfocar if enfocar != null else get_node("Volumen_general")).grab_focus.call_deferred()


func _barra(cual: String, y: float) -> void:
	var etiquetas := {"general": "GENERAL", "musica": "MÚSICA", "efectos": "EFECTOS"}
	UI.texto(self, etiquetas[cual], Vector2(COL_IZQ, y + 4), 8)
	var barra := HSlider.new()
	barra.name = "Volumen_" + cual
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.05
	barra.value = opciones.volumen[cual]
	barra.position = Vector2(COL_IZQ + 96, y)
	barra.size = Vector2(120, 16)
	barra.add_theme_stylebox_override("focus", _marco_foco())
	add_child(barra)
	var valor := UI.texto(self, "%d%%" % roundi(barra.value * 100.0), Vector2(COL_IZQ + 226, y + 4), 8, UI.C_GRIS)
	valor.name = "Valor_" + cual
	barra.value_changed.connect(func(v):
		opciones.poner_volumen(cual, v)
		opciones.guardar()
		valor.text = "%d%%" % roundi(v * 100.0))


## Marco amarillo, como el de los botones, para saber dónde está el foco al usar el teclado.
func _marco_foco() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = UI.C_AMARILLO
	s.set_border_width_all(1)
	s.expand_margin_left = 3
	s.expand_margin_right = 3
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	return s


func _boton(t: String, nombre: String, pos: Vector2) -> Button:
	var b := UI.boton(self, t, nombre)
	b.custom_minimum_size = Vector2(ANCHO_COL, 22)
	b.position = pos
	b.size = b.custom_minimum_size
	return b


func _texto_tecla(accion: String) -> String:
	return "%s: %s" % [tr(NOMBRES_ACCION[accion]), OPCIONES.nombre_tecla(opciones.teclas[accion])]


func _refrescar_teclas() -> void:
	for accion in OPCIONES.ACCIONES:
		(get_node("Tecla_" + accion) as Button).text = _texto_tecla(accion)


func _cambiar_idioma() -> void:
	opciones.poner_idioma(opciones.otro_idioma())
	opciones.guardar()
	construir("Idioma")


func _esperar_tecla(accion: String) -> void:
	esperando_tecla = accion
	_aviso.text = ""
	(get_node("Tecla_" + accion) as Button).text = tr("PULSA UNA TECLA...")


## La tecla que se pulsó mientras se esperaba una (las pruebas la llaman directo).
func tecla_pulsada(ev: InputEventKey) -> void:
	var accion := esperando_tecla
	esperando_tecla = ""
	var tecla := ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	if tecla != KEY_ESCAPE:
		if opciones.cambiar_tecla(accion, tecla):
			opciones.guardar()
		else:
			_aviso.text = tr("Esa tecla ya está en uso o no se puede cambiar.")
	_refrescar_teclas()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if esperando_tecla != "":
		tecla_pulsada(tecla)
		get_viewport().set_input_as_handled()
	elif tecla.physical_keycode == KEY_ESCAPE or tecla.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		volver.emit()
