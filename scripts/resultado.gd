extends Control
## Pantalla del remate: caja con el mensaje y «Pulsa ENTER para continuar».

signal continuar

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
	caja.position = Vector2(30, 170)
	caja.size = Vector2(580, 136)
	add_child(caja)
	var interior := ColorRect.new()
	interior.color = Color.BLACK
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
	pista.text = "Pulsa ENTER para continuar"
	pista.position = Vector2(0, 318)
	pista.size = Vector2(640, 20)
	pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pista.add_theme_font_size_override("font_size", 12)
	add_child(pista)


func mostrar(estado: String, mensaje: String) -> void:
	_texto.text = mensaje
	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = {"estrellado": "R.I.P.", "entregado": "ENTREGADO", "sin_tiempo": "CANCELADO"}.get(estado, "")
	titulo.position = Vector2(0, 80)
	titulo.size = Vector2(640, 40)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 32)
	add_child(titulo)


func _process(delta: float) -> void:
	_t += delta
	if _t >= ESPERA_MINIMA and Input.is_action_just_pressed("continuar"):
		set_process(false)
		continuar.emit()
