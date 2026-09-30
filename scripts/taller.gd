extends Control
## Taller a lo «Most Wanted» (Tomás, 30/09): las tres motos en fila sobre una tarima; con ←/→ se
## pasa de una a otra. La escogida sale grande, con sus datos, sus mejoras y si se puede comprar:
## la que no alcanza sale con candado y su precio. La lógica de qué se puede está en progreso.gd.

signal volver

const UI := preload("res://scripts/ui.gd")
const MOTOS := preload("res://scripts/motos.gd")
const PROGRESO := preload("res://scripts/progreso.gd")
const HOJA := preload("res://assets/ui/motos_taller.png")

const MOTO_TAM := Vector2(128, 96)     # cada moto en la hoja (tools/recortar_motos.py)
const PISO := Vector2(320, 176)        # dónde pisa la moto escogida
const SEPARACION := 200.0              # px entre una moto y la siguiente en la fila
const ESCALA_GRANDE := 1.5
const ESCALA_CHICA := 0.8
const VEL_CARRUSEL := 8.0
# Barras de datos: el tope es la mejor moto con todo (así se ve cuánto le falta a cada una).
const BARRA := Rect2(16, 244, 206, 6)
const C_TARIMA := Color("f0c040")
const C_VERDE := Color("4ade80")

var progreso
var escogida := 0
var _vista := 0.0            # posición animada del carrusel (se acerca a escogida)
var _sprites: Array[TextureRect] = []
var _botones := {}
var _l_nombre: Label
var _l_estado: Label
var _l_falta: Label
var _l_plata: Label
var _l_datos: Array[Label] = []
var _candado: Control
var _tope := {}              # vel_max y acel de la mejor moto con todo
## F10 = +$50.000 para probar: solo en versiones de desarrollo, nunca en el .exe exportado.
var trucos := OS.is_debug_build()


func _ready() -> void:
	var ultima := MOTOS.con_mejoras(MOTOS.ORDEN[-1], {"exosto": true, "motor": true})
	_tope = {"vel_max": float(ultima.vel_max), "acel": float(ultima.acel)}
	# El fondo y la tarima se dibujan en _draw (debajo de todo); luego las motos y encima el texto.
	for k in MOTOS.ORDEN.size():
		var tr := TextureRect.new()
		tr.name = "Moto_" + MOTOS.ORDEN[k]
		var at := AtlasTexture.new()
		at.atlas = HOJA
		at.region = Rect2(Vector2(k * MOTO_TAM.x, 0), MOTO_TAM)
		tr.texture = at
		tr.size = MOTO_TAM
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		_sprites.append(tr)

	UI.texto(self, "TALLER", Vector2(16, 10), 24, UI.C_ROJO, 0.0, "Titulo")
	_l_plata = UI.texto(self, "", Vector2(424, 10), 16, UI.C_AMARILLO, 0.0, "Plata")
	_l_plata.size = Vector2(200, 22)
	_l_plata.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var l_p := UI.texto(self, "PLATA", Vector2(424, 32), 8, UI.C_GRIS)
	l_p.size = Vector2(200, 14)
	l_p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for lado in [-1, 1]:
		var f := UI.boton(self, "<" if lado < 0 else ">", "Anterior" if lado < 0 else "Siguiente")
		f.custom_minimum_size = Vector2(28, 40)
		f.size = Vector2(28, 40)
		f.position = Vector2(10 if lado < 0 else 602, 96)
		f.focus_mode = Control.FOCUS_NONE
		f.pressed.connect(mover.bind(lado))

	# Ficha de la moto escogida, abajo a la izquierda.
	_l_nombre = UI.texto(self, "", Vector2(16, 190), 16, UI.C_TEXTO, 0.0, "Nombre")
	_l_estado = UI.texto(self, "", Vector2(16, 214), 8, UI.C_TEXTO, 0.0, "Estado")
	_candado = Control.new()
	_candado.name = "Candado"
	_candado.size = Vector2(12, 14)
	_candado.draw.connect(_dibujar_candado)
	add_child(_candado)
	for nombre in ["VELOCIDAD", "ACELERACIÓN"]:
		_l_datos.append(UI.texto(self, "", Vector2.ZERO, 8, UI.C_GRIS, 0.0, "Dato_" + nombre))
	_l_falta = UI.texto(self, "", Vector2(16, 296), 8, UI.C_GRIS, 0.0, "Falta")
	_l_falta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_l_falta.size = Vector2(310, 30)

	# Mejoras y compra, abajo a la derecha.
	UI.texto(self, "MEJORAS", Vector2(342, 190), 8, UI.C_GRIS)
	var col := UI.columna(self, Vector2(342, 204), 282.0)
	for mej in MOTOS.MEJORAS:
		var b := UI.boton(col, "", "Mejora_" + mej)
		b.custom_minimum_size = Vector2(282, 26)
		b.pressed.connect(_comprar_mejora.bind(mej))
		_botones[mej] = b
	var b_moto := UI.boton(col, "", "ComprarMoto")
	b_moto.custom_minimum_size = Vector2(282, 26)
	b_moto.pressed.connect(_comprar_moto)
	_botones["moto"] = b_moto
	var b_volver := UI.boton(col, "VOLVER", "Volver")
	b_volver.custom_minimum_size = Vector2(282, 26)
	b_volver.pressed.connect(func(): volver.emit())
	UI.texto(self, "< >  ELEGIR MOTO      ESC  VOLVER      Morir no quita la plata.", Vector2(0, 342), 8, UI.C_GRIS, 640.0, "Ayuda")

	if progreso != null:
		escogida = maxi(MOTOS.ORDEN.find(progreso.moto), 0)
	_vista = float(escogida)
	actualizar()
	b_volver.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if trucos and tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F10 and progreso != null:
		progreso.plata_de_prueba()
		actualizar()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("izquierda"):
		mover(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("derecha"):
		mover(1)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		volver.emit()
		return
	_vista = lerpf(_vista, float(escogida), minf(delta * VEL_CARRUSEL, 1.0))
	if absf(_vista - escogida) < 0.001:
		_vista = float(escogida)
	_acomodar()
	queue_redraw()


## Pasa a la moto de al lado (-1 izquierda, 1 derecha), sin salirse de la fila.
func mover(lado: int) -> void:
	escogida = clampi(escogida + lado, 0, MOTOS.ORDEN.size() - 1)
	actualizar()


## Pone cada moto en su sitio del carrusel: la escogida grande en la tarima, las demás a los lados.
func _acomodar() -> void:
	for k in _sprites.size():
		var sp := _sprites[k]
		var d := float(k) - _vista
		var cerca := clampf(1.0 - absf(d), 0.0, 1.0)
		var esc := lerpf(ESCALA_CHICA, ESCALA_GRANDE, cerca)
		sp.scale = Vector2(esc, esc)
		var tam := MOTO_TAM * esc
		var piso_y := lerpf(PISO.y - 34.0, PISO.y, cerca) # las de atrás, un poco más arriba (lejos)
		sp.position = Vector2(PISO.x + d * SEPARACION - tam.x / 2.0, piso_y - tam.y)
		var luz := lerpf(0.4, 1.0, cerca)
		if progreso != null and progreso.estado_moto(MOTOS.ORDEN[k]) in [PROGRESO.BLOQUEADA, PROGRESO.SIN_PLATA]:
			luz *= lerpf(0.55, 0.85, cerca) # la que no se tiene se ve en sombra, como en una vitrina
		sp.modulate = Color(luz, luz, luz)
		sp.z_index = 1 if k == escogida else 0


func actualizar() -> void:
	if progreso == null:
		return
	var id: String = MOTOS.ORDEN[escogida]
	var estado: String = progreso.estado_moto(id)
	var de_fabrica := MOTOS.get_moto(id)
	var datos: Dictionary = progreso.datos_de(id)
	var precio := int(de_fabrica.precio)
	_l_plata.text = PROGRESO.pesos(progreso.dinero)
	_l_nombre.text = str(de_fabrica.nombre).to_upper()

	_candado.visible = estado in [PROGRESO.BLOQUEADA, PROGRESO.SIN_PLATA]
	var textos := {
		PROGRESO.EN_USO: ["EN USO", C_VERDE],
		PROGRESO.TENIDA: ["EN TU GARAJE", UI.C_TEXTO],
		PROGRESO.COMPRABLE: ["A LA VENTA  " + PROGRESO.pesos(precio), UI.C_AMARILLO],
		PROGRESO.SIN_PLATA: ["BLOQUEADA  " + PROGRESO.pesos(precio), UI.C_ROJO],
		PROGRESO.BLOQUEADA: ["BLOQUEADA  " + PROGRESO.pesos(precio), UI.C_ROJO],
	}
	_l_estado.text = textos[estado][0]
	_l_estado.add_theme_color_override("font_color", textos[estado][1])
	_l_estado.position.x = 32.0 if _candado.visible else 16.0
	_candado.position = Vector2(16, 211)

	var faltan := ""
	match estado:
		PROGRESO.SIN_PLATA:
			faltan = "Te faltan %s para comprarla." % PROGRESO.pesos(progreso.falta_para(id))
		PROGRESO.BLOQUEADA:
			faltan = "Primero compra la %s." % MOTOS.get_moto(MOTOS.ORDEN[escogida - 1]).nombre
		PROGRESO.TENIDA:
			faltan = "Es tuya, con sus mejoras. Sácala con USAR; las mejoras se compran con la moto en uso."
		PROGRESO.COMPRABLE:
			faltan = "Tu %s se queda en el garaje." % MOTOS.get_moto(progreso.moto).nombre
		PROGRESO.EN_USO:
			faltan = "Con todas las mejoras sigue siendo peor que la siguiente de fábrica." if id != MOTOS.ORDEN[-1] else "La mejor moto de la ciudad."
	_l_falta.text = faltan

	_l_datos[0].text = "VELOCIDAD  %d km/h" % roundi(float(datos.vel_max) * 3.6)
	_l_datos[1].text = "ACELERACIÓN  %.1f" % float(datos.acel)
	for k in 2:
		_l_datos[k].position = Vector2(BARRA.position.x, BARRA.position.y - 13 + k * 26)

	for mej in MOTOS.MEJORAS:
		var b: Button = _botones[mej]
		var nombre: String = MOTOS.NOMBRE_MEJORA[mej].to_upper()
		var precio_mej := int(de_fabrica.mejoras[mej].precio)
		if progreso.tenidas.get(id, {}).get(mej, false):
			b.text = "%s  (ya instalado)" % nombre
		else:
			b.text = "%s  %s" % [nombre, PROGRESO.pesos(precio_mej)]
		b.disabled = estado != PROGRESO.EN_USO or not progreso.puede_mejorar(mej)
	var bm: Button = _botones["moto"]
	match estado:
		PROGRESO.EN_USO:
			bm.text = "ESTA ES TU MOTO"
		PROGRESO.TENIDA:
			bm.text = "USAR ESTA MOTO"
		PROGRESO.BLOQUEADA:
			bm.text = "BLOQUEADA"
		_:
			bm.text = "COMPRAR %s  %s" % [str(de_fabrica.nombre).to_upper(), PROGRESO.pesos(precio)]
	bm.disabled = estado not in [PROGRESO.COMPRABLE, PROGRESO.TENIDA]
	_candado.queue_redraw()
	_acomodar()
	queue_redraw()


## Fondo de vitrina: piso con líneas que se van, luz desde arriba y la tarima de la escogida.
func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.C_FONDO)
	var horizonte := PISO.y - 40.0
	for k in 12:
		var y := horizonte + pow(k / 11.0, 1.6) * 60.0
		draw_line(Vector2(0, y), Vector2(640, y), Color(1, 1, 1, 0.03 + 0.02 * k / 11.0), 1.0)
	for k in range(-8, 9):
		draw_line(Vector2(PISO.x + k * 12, horizonte), Vector2(PISO.x + k * 90, horizonte + 60), Color(1, 1, 1, 0.035), 1.0)
	var foco := PackedVector2Array([Vector2(290, 0), Vector2(350, 0), Vector2(460, PISO.y + 6), Vector2(180, PISO.y + 6)])
	draw_colored_polygon(foco, Color(1, 0.95, 0.8, 0.05))
	# Tarima: aros de luz bajo la moto escogida.
	for k in 4:
		var r := Vector2(130 - k * 22, 13 - k * 2.5)
		_elipse(PISO + Vector2(0, 2), r, Color(C_TARIMA, 0.05 + 0.05 * k))
	_elipse(PISO + Vector2(0, 2), Vector2(128, 13), Color(C_TARIMA, 0.35), false)
	draw_rect(Rect2(0, 184, 640, 176), Color(0, 0, 0, 0.35))
	draw_line(Vector2(0, 184), Vector2(640, 184), Color("5c5c64"), 1.0)
	# Barras de datos: blanco lo que tiene; amarillo tenue lo que le darían las mejoras que faltan.
	if progreso == null:
		return
	var id: String = MOTOS.ORDEN[escogida]
	var ahora: Dictionary = progreso.datos_de(id)
	var todo := MOTOS.con_mejoras(id, {"exosto": true, "motor": true})
	for k in 2:
		var campo: String = ["vel_max", "acel"][k]
		var r := Rect2(BARRA.position + Vector2(0, k * 26), BARRA.size)
		draw_rect(r, Color("2a2a32"))
		var f_todo := float(todo[campo]) / float(_tope[campo])
		var f_ahora := float(ahora[campo]) / float(_tope[campo])
		draw_rect(Rect2(r.position, Vector2(r.size.x * f_todo, r.size.y)), Color(C_TARIMA, 0.3))
		draw_rect(Rect2(r.position, Vector2(r.size.x * f_ahora, r.size.y)), UI.C_TEXTO)
		draw_rect(r, Color("5c5c64"), false, 1.0)


func _elipse(centro: Vector2, radio: Vector2, color: Color, relleno := true) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		pts.append(centro + Vector2(cos(a) * radio.x, sin(a) * radio.y))
	if relleno:
		draw_colored_polygon(pts, color)
	else:
		draw_polyline(pts, color, 1.0)


## Candado pequeño al lado de «BLOQUEADA».
func _dibujar_candado() -> void:
	var rojo := UI.C_ROJO
	_candado.draw_arc(Vector2(6, 6), 3.5, PI, TAU, 8, rojo, 2.0)
	_candado.draw_line(Vector2(2.5, 6), Vector2(2.5, 8), rojo, 2.0)
	_candado.draw_line(Vector2(9.5, 6), Vector2(9.5, 8), rojo, 2.0)
	_candado.draw_rect(Rect2(1, 8, 10, 6), rojo)
	_candado.draw_rect(Rect2(5, 10, 2, 2), UI.C_FONDO)


func _comprar_mejora(nombre: String) -> void:
	progreso.comprar_mejora(nombre)
	actualizar()


func _comprar_moto() -> void:
	var id: String = MOTOS.ORDEN[escogida]
	if progreso.estado_moto(id) == PROGRESO.TENIDA:
		progreso.usar(id)
	else:
		progreso.comprar_moto()
	actualizar()
