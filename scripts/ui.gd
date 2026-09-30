extends RefCounted
## Piezas de interfaz comunes (botones, textos, fondo) para menú, taller y resultado.
## En la F4 esto pasa a un tema .tres (CLAUDE.md §5).

const C_FONDO := Color("1c1c22")
const C_TEXTO := Color("e8e8e8")
const C_GRIS := Color("9a9aa2")
const C_ROJO := Color("e0301e")
const C_AMARILLO := Color("f0c040")


static func fondo(padre: Control) -> ColorRect:
	var f := ColorRect.new()
	f.name = "Fondo"
	f.color = C_FONDO
	f.size = Vector2(640, 360)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(f)
	return f


static func texto(padre: Node, t: String, pos: Vector2, tam: int, color := C_TEXTO, ancho := 0.0, nombre := "") -> Label:
	var l := Label.new()
	if nombre != "":
		l.name = nombre
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	padre.add_child(l)
	if ancho > 0.0:
		# Después de entrar al árbol: antes mide con la letra por defecto y se estira de más.
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(ancho, tam + 6)
	return l


static func _caja(color: Color, borde: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = borde
	s.set_border_width_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func boton(padre: Node, t: String, nombre: String) -> Button:
	var b := Button.new()
	b.name = nombre
	b.text = t
	b.custom_minimum_size = Vector2(300, 28)
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_color_override("font_color", C_TEXTO)
	b.add_theme_color_override("font_focus_color", C_AMARILLO)
	b.add_theme_color_override("font_hover_color", C_AMARILLO)
	b.add_theme_color_override("font_disabled_color", Color("5c5c64"))
	b.add_theme_stylebox_override("normal", _caja(Color("2a2a32"), Color("5c5c64")))
	b.add_theme_stylebox_override("hover", _caja(Color("3a3a44"), C_AMARILLO))
	b.add_theme_stylebox_override("focus", _caja(Color("3a3a44"), C_AMARILLO))
	b.add_theme_stylebox_override("pressed", _caja(Color("15151a"), C_AMARILLO))
	b.add_theme_stylebox_override("disabled", _caja(Color("202026"), Color("34343c")))
	padre.add_child(b)
	return b


static func columna(padre: Node, pos: Vector2, ancho: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = pos
	v.size = Vector2(ancho, 0)
	v.add_theme_constant_override("separation", 6)
	padre.add_child(v)
	return v


## Texto que se parte en varias líneas dentro de una caja de ancho fijo (centrado).
static func parrafo(padre: Node, t: String, pos: Vector2, tam_caja: Vector2, tam := 8, color := C_TEXTO, nombre := "") -> Label:
	var l := Label.new()
	if nombre != "":
		l.name = nombre
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(tam_caja.x, 0)
	l.position = pos
	l.size = tam_caja
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	padre.add_child(l)
	return l
