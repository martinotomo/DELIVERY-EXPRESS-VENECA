extends Control
## Mapa completo de la ciudad (DISENO §6), con Tab: las zonas en colores, las avenidas, la ruta,
## el pedido y la moto. El norte queda arriba y los cerros a la derecha (al oriente), como en Bogotá.
## Mientras está abierto la partida se detiene (recorrido.gd no la avanza).

const C_FONDO := Color(0.05, 0.05, 0.07, 0.92)
const C_ZONA := {
	"barrio": Color("6b5b52"),
	"centro": Color("8a7a5a"),
	"industrial": Color("54606b"),
	"rica": Color("5d7d8f"),
}
const C_PARQUE := Color("3d6a3a")
const C_AVENIDA := Color("c8c8b4")
const C_CERROS := Color("35523a")
const C_RUTA := Color("ffcc33")
const C_RESTAURANTE := Color("ff8a2a")
const C_CLIENTE := Color("4ade80")
const C_TEXTO := Color("e8e8e8")
const ALTO_MAPA := 330.0 # px que ocupa el largo de la ciudad

var partida
var _escala := 0.0
var _origen := Vector2.ZERO # esquina de arriba a la derecha del plano (x = 0, y = máximo)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_acomodar()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _acomodar() -> void:
	if partida == null:
		return
	var tam: Vector2 = partida.ciudad.tamano()
	_escala = ALTO_MAPA / tam.y
	_origen = Vector2(size.x / 2.0 + tam.x * _escala / 2.0 + 40.0, (size.y - ALTO_MAPA) / 2.0)


## Del plano (m) a la pantalla: el occidente (x grande) a la izquierda y el norte (y grande) arriba.
func a_pantalla(w: Vector2) -> Vector2:
	if _escala == 0.0:
		_acomodar()
	var tam: Vector2 = partida.ciudad.tamano()
	return _origen + Vector2(-w.x, tam.y - w.y) * _escala


func _rect(r: Rect2) -> Rect2:
	var a := a_pantalla(r.position)
	var b := a_pantalla(r.end)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_FONDO)
	if partida == null:
		return
	var c = partida.ciudad
	var tam: Vector2 = c.tamano()
	var todo := _rect(Rect2(Vector2.ZERO, tam))
	# Los cerros orientales, a la derecha.
	draw_rect(Rect2(todo.end.x, todo.position.y, 10, todo.size.y), C_CERROS)
	draw_rect(todo, Color("2a2a30"))
	for j in c.N_LARGO:
		for i in c.N_ANCHO:
			var col: Color = C_PARQUE if c.es_parque(i, j) else C_ZONA[c.zona(i, j)]
			draw_rect(_rect(c.cuadra(i, j)), col)
	# Avenidas: una raya clara por el centro.
	for j in range(c.CADA_AVENIDA, c.N_LARGO, c.CADA_AVENIDA):
		var y: float = a_pantalla(c.cruce(0, j)).y
		draw_line(Vector2(todo.position.x, y), Vector2(todo.end.x, y), C_AVENIDA, 1.0)
	for i in range(c.CADA_AVENIDA, c.N_ANCHO, c.CADA_AVENIDA):
		var x: float = a_pantalla(c.cruce(i, 0)).x
		draw_line(Vector2(x, todo.position.y), Vector2(x, todo.end.y), C_AVENIDA, 1.0)
	draw_rect(todo, Color("888888"), false, 1.0)

	var ruta := PackedVector2Array()
	for q in partida.ruta():
		ruta.append(a_pantalla(q))
	if ruta.size() >= 2:
		draw_polyline(ruta, C_RUTA, 2.0)
	var recoger: bool = partida.fase == partida.RECOGER
	var parpadeo := int(Time.get_ticks_msec() / 300) % 2 == 0
	draw_circle(a_pantalla(partida.pedido.restaurante), 4.0 if recoger and parpadeo else 3.0, C_RESTAURANTE)
	draw_circle(a_pantalla(partida.pedido.cliente), 4.0 if not recoger and parpadeo else 3.0, C_CLIENTE)
	# La moto: flecha blanca con borde negro, hacia donde va (rumbo 0 = +x = izquierda en el mapa).
	var m = partida.moto
	var p := a_pantalla(m.pos)
	var d := Vector2(-cos(m.rumbo), -sin(m.rumbo))
	var n := Vector2(-d.y, d.x)
	var flecha := PackedVector2Array([p + d * 7.0, p - d * 4.0 + n * 4.0, p - d * 2.0, p - d * 4.0 - n * 4.0])
	draw_colored_polygon(flecha, Color.WHITE)
	flecha.append(flecha[0])
	draw_polyline(flecha, Color.BLACK, 1.0)

	# Leyenda a la izquierda.
	var f := get_theme_default_font()
	var x := 16.0
	var y := 30.0
	draw_string(f, Vector2(x, y), tr("MAPA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_TEXTO)
	y += 26.0
	for z in ["barrio", "centro", "industrial", "rica"]:
		draw_rect(Rect2(x, y - 8, 10, 10), C_ZONA[z])
		draw_string(f, Vector2(x + 16, y), c.nombre_zona(z).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TEXTO)
		y += 16.0
	draw_rect(Rect2(x, y - 8, 10, 10), C_PARQUE)
	draw_string(f, Vector2(x + 16, y), tr("PARQUE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TEXTO)
	y += 16.0
	draw_line(Vector2(x, y - 3), Vector2(x + 10, y - 3), C_AVENIDA, 1.0)
	draw_string(f, Vector2(x + 16, y), tr("AVENIDA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TEXTO)
	y += 16.0
	draw_rect(Rect2(x, y - 8, 10, 10), C_CERROS)
	draw_string(f, Vector2(x + 16, y), tr("CERROS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TEXTO)
	y += 24.0
	draw_circle(Vector2(x + 5, y - 4), 3.0, C_RESTAURANTE)
	draw_string(f, Vector2(x + 16, y), tr("RECOGER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TEXTO)
	y += 16.0
	draw_circle(Vector2(x + 5, y - 4), 3.0, C_CLIENTE)
	draw_string(f, Vector2(x + 16, y), tr("ENTREGAR"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TEXTO)
	y += 16.0
	draw_line(Vector2(x, y - 3), Vector2(x + 10, y - 3), C_RUTA, 2.0)
	draw_string(f, Vector2(x + 16, y), tr("RUTA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TEXTO)
	# Dónde está, y cómo cerrar.
	var abajo := size.y - 34.0
	draw_string(f, Vector2(x, abajo), c.ubicacion(m.pos), HORIZONTAL_ALIGNMENT_LEFT, 200, 8, C_TEXTO)
	draw_string(f, Vector2(x, abajo + 14), c.nombre_zona(c.zona_en(m.pos)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 200, 8, Color("9a9aa2"))
	draw_string(f, Vector2(size.x - 16 - 160, abajo + 14), tr("TAB: VOLVER"), HORIZONTAL_ALIGNMENT_RIGHT, 160, 8, Color("9a9aa2"))
	# La rosa de los vientos, arriba a la derecha.
	var rosa := Vector2(size.x - 30, 34)
	draw_string(f, rosa + Vector2(-4, -8), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TEXTO)
	draw_line(rosa, rosa + Vector2(0, 14), C_TEXTO, 1.0)
	draw_colored_polygon(PackedVector2Array([rosa + Vector2(0, -4), rosa + Vector2(3, 2), rosa + Vector2(-3, 2)]), C_TEXTO)
