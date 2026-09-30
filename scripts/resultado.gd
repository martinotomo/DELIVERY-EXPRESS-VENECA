extends Control
## Pantalla del remate: caja con el mensaje y «ENTER: otra jornada / ESC: menú».

signal continuar
signal al_menu

const ESPERA_MINIMA := 0.6 # que una tecla sostenida no se salte el chiste

var _t := 0.0
var _texto: Label


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.size = Vector2(640, 360)
	add_child(fondo)

	var caja := ColorRect.new()
	caja.name = "Caja"
	caja.color = Color("dddddd")
	caja.position = Vector2(20, 140)
	caja.size = Vector2(600, 164)
	add_child(caja)
	var interior := ColorRect.new()
	interior.color = Color(0, 0, 0, 0.8) # deja ver un poco la caída dibujada detrás
	interior.position = Vector2(2, 2)
	interior.size = caja.size - Vector2(4, 4)
	caja.add_child(interior)
	_texto = Label.new()
	_texto.name = "Texto"
	_texto.position = Vector2(12, 8)
	_texto.size = caja.size - Vector2(24, 16)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 16)
	caja.add_child(_texto)

	var pista := Label.new()
	pista.name = "Pista"
	pista.text = "ENTER: otra jornada      ESC: menú"
	pista.position = Vector2(0, 322)
	pista.size = Vector2(640, 20)
	pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pista.add_theme_font_size_override("font_size", 8)
	add_child(pista)


## ilustracion: la caída dibujada (F2); el remate se lee encima, con el dibujo oscurecido.
func mostrar(estado: String, mensaje: String, ilustracion: Texture2D = null) -> void:
	_texto.text = mensaje
	if ilustracion != null:
		var fondo := TextureRect.new()
		fondo.name = "Ilustracion"
		fondo.texture = ilustracion
		fondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fondo.stretch_mode = TextureRect.STRETCH_SCALE
		fondo.size = Vector2(640, 360)
		fondo.modulate = Color(0.45, 0.45, 0.5) # oscuro, para que la letra mande
		add_child(fondo)
		move_child(fondo, 1) # encima del negro, debajo de la caja y los textos
	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = {"estrellado": "R.I.P.", "entregado": "ENTREGADO", "sin_tiempo": "CANCELADO"}.get(estado, "")
	titulo.position = Vector2(0, 70)
	titulo.size = Vector2(640, 40)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 32)
	add_child(titulo)


func _process(delta: float) -> void:
	_t += delta
	if _t >= ESPERA_MINIMA and Input.is_action_just_pressed("continuar"):
		set_process(false)
		continuar.emit()
	elif _t >= ESPERA_MINIMA and Input.is_action_just_pressed("menu"):
		set_process(false)
		al_menu.emit()
