extends Control
## El manubrio de la BWS visto desde el puesto del domiciliario, en bloques grises.
## Se inclina con el giro y tiembla con la velocidad.

const C_OSCURO := Color("2b2b2b")
const C_METAL := Color("8c8c8c")
const C_GUANTE := Color("6a6a6a")
const C_ESPEJO := Color("a9b4bf")
const C_TABLERO := Color("dcdcdc")

var giro := 0.0
var vel_kmh := 0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var temblor := sin(_t * 40.0) * clampf(vel_kmh / 90.0, 0.0, 1.0) * 1.2
	draw_set_transform(Vector2(320, 300 + temblor), giro * 0.12, Vector2.ONE)
	# Tablero central (de la BWS: ancho y chato) con el velocímetro.
	draw_colored_polygon(PackedVector2Array([Vector2(-70, 60), Vector2(70, 60), Vector2(52, -8), Vector2(-52, -8)]), C_OSCURO)
	draw_circle(Vector2(0, 18), 20, C_TABLERO)
	draw_circle(Vector2(0, 18), 17, C_OSCURO)
	var ang := lerpf(PI * 0.8, PI * 2.2, clampf(vel_kmh / 100.0, 0.0, 1.0))
	draw_line(Vector2(0, 18), Vector2(0, 18) + Vector2(cos(ang), sin(ang)) * 14, Color("e05a3a"), 2.0)
	# Barra del manubrio.
	draw_polyline(PackedVector2Array([Vector2(-190, -6), Vector2(-100, 4), Vector2(0, 0), Vector2(100, 4), Vector2(190, -6)]), C_METAL, 9.0)
	# Espejos: palo y espejo redondo.
	for lado in [-1, 1]:
		draw_line(Vector2(lado * 120, 0), Vector2(lado * 150, -62), C_METAL, 4.0)
		draw_circle(Vector2(lado * 156, -74), 17, C_METAL)
		draw_circle(Vector2(lado * 156, -74), 13, C_ESPEJO)
	# Puños y manos con guante, con el antebrazo saliendo de abajo.
	for lado in [-1, 1]:
		var x: float = lado * 200.0
		draw_rect(Rect2(x - 26, -16, 52, 20), C_OSCURO)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 24, -20), Vector2(x + 24, -20), Vector2(x + 30 * lado + 10, 80), Vector2(x - 30 + lado * 30, 80)]), C_GUANTE)
		draw_rect(Rect2(x - 22, -24, 44, 16), C_GUANTE.lightened(0.15))
