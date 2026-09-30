extends Control
## Minimapa que gira con la moto (siempre mirando hacia arriba) y marca la ruta al pedido.

const ESCALA := 0.55 # px por metro
const C_FONDO := Color(0.08, 0.08, 0.1, 0.85)
const C_CUADRA := Color("4a4a4a")
const C_PARQUE := Color("3d5a3a")
const C_RUTA := Color("ffcc33")
const C_RESTAURANTE := Color("ff8a2a")
const C_CLIENTE := Color("4ade80")

var partida


func _ready() -> void:
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


func _a_pantalla(w: Vector2) -> Vector2:
	var rr: Vector2 = (w - partida.moto.pos).rotated(-partida.moto.rumbo)
	return size / 2.0 + Vector2(rr.y, -rr.x) * ESCALA


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_FONDO)
	if partida == null:
		return
	var c = partida.ciudad
	var p: Vector2 = partida.moto.pos
	var ci := clampi(c.inicio_x.bsearch(p.x) - 1, 0, c.N_ANCHO - 1)
	var cj := clampi(c.inicio_y.bsearch(p.y) - 1, 0, c.N_LARGO - 1)
	for i in range(maxi(ci - 4, 0), mini(ci + 5, c.N_ANCHO)):
		for j in range(maxi(cj - 4, 0), mini(cj + 5, c.N_LARGO)):
			var r: Rect2 = c.cuadra(i, j)
			var pts := PackedVector2Array([_a_pantalla(r.position), _a_pantalla(Vector2(r.end.x, r.position.y)),
				_a_pantalla(r.end), _a_pantalla(Vector2(r.position.x, r.end.y))])
			draw_colored_polygon(pts, C_PARQUE if c.es_parque(i, j) else C_CUADRA)
	var ruta: PackedVector2Array = partida.ruta()
	var en_pantalla := PackedVector2Array()
	for q in ruta:
		en_pantalla.append(_a_pantalla(q))
	if en_pantalla.size() >= 2:
		draw_polyline(en_pantalla, C_RUTA, 2.0)
	# Objetivo: punto, o flecha en el borde si queda lejos.
	var color := C_RESTAURANTE if partida.fase == partida.RECOGER else C_CLIENTE
	var o := _a_pantalla(partida.objetivo())
	var centro := size / 2.0
	var margen := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	if not margen.has_point(o):
		var dir := (o - centro).normalized()
		o = centro + dir * (minf(size.x, size.y) / 2.0 - 7.0)
	draw_circle(o, 4.0, color)
	# La moto, en el centro mirando hacia arriba.
	draw_colored_polygon(PackedVector2Array([centro + Vector2(0, -6), centro + Vector2(4, 4), centro + Vector2(-4, 4)]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color("888888"), false, 1.0)
