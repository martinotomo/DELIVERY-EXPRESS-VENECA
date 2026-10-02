extends Control
## Menú de inicio: Jugar, Taller, Ayuda, Opciones, Créditos y Salir. Muestra la moto y la plata que se tienen.

signal jugar
signal taller
signal abrir_ayuda
signal abrir_opciones
signal abrir_creditos
signal salir

const UI := preload("res://scripts/ui.gd")
const PROGRESO := preload("res://scripts/progreso.gd")

const LOGO_PARA := "Delivery Express" # tools/gen_logo.py lo dibuja para este nombre (D14, D26)
const LOGO_RECORTE := Rect2(54, 100, 526, 152) # dónde está el dibujo dentro de logo.png (640×360)
const LOGO_ESCALA := 0.75

var progreso


func _ready() -> void:
	UI.fondo(self)
	# Franja de calle con líneas amarillas, para que no sea solo negro.
	var calle := ColorRect.new()
	calle.color = Color("2e2e36")
	calle.position = Vector2(0, 300)
	calle.size = Vector2(640, 60)
	add_child(calle)
	for i in 8:
		var linea := ColorRect.new()
		linea.color = UI.C_AMARILLO
		linea.position = Vector2(20 + i * 84, 328)
		linea.size = Vector2(44, 4)
		add_child(linea)

	var nombre := str(ProjectSettings.get_setting("application/config/name", ""))
	var titulo := UI.texto(self, nombre.to_upper(), Vector2(0, 50), 32, UI.C_ROJO, 640.0, "Titulo")
	var lema_y := 96.0
	if nombre == LOGO_PARA:
		var recorte := AtlasTexture.new()
		recorte.atlas = load("res://assets/ui/logo.png")
		recorte.region = LOGO_RECORTE
		var logo := TextureRect.new()
		logo.name = "Logo"
		logo.texture = recorte
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		logo.size = LOGO_RECORTE.size
		logo.scale = Vector2.ONE * LOGO_ESCALA
		logo.position = Vector2((640.0 - LOGO_RECORTE.size.x * LOGO_ESCALA) / 2.0, 4)
		add_child(logo)
		titulo.visible = false
		lema_y = 4 + LOGO_RECORTE.size.y * LOGO_ESCALA
	UI.texto(self, "Domicilios a toda. La fe no frena.", Vector2(0, lema_y), 8, UI.C_GRIS, 640.0)

	var col := UI.columna(self, Vector2(170, 132), 300.0)
	col.add_theme_constant_override("separation", 3)
	var botones := [
		["JUGAR", "Jugar", jugar], ["TALLER", "Taller", taller], ["AYUDA", "Ayuda", abrir_ayuda], ["OPCIONES", "Opciones", abrir_opciones],
		["CRÉDITOS", "Creditos", abrir_creditos], ["SALIR", "Salir", salir],
	]
	if UI.en_web:
		botones.pop_back() # una página no se cierra a sí misma
	for b in botones:
		var boton := UI.boton(col, b[0], b[1])
		boton.custom_minimum_size.y = 20
		var senal: Signal = b[2]
		boton.pressed.connect(func(): senal.emit())
	var b_jugar: Button = col.get_node("Jugar")

	var estado := UI.texto(self, "", Vector2(0, 280), 8, UI.C_TEXTO, 640.0, "Estado")
	if progreso != null:
		estado.text = tr("Moto: %s    Plata: %s") % [progreso.datos_moto().nombre, PROGRESO.pesos(progreso.dinero)]
	b_jugar.grab_focus.call_deferred()
