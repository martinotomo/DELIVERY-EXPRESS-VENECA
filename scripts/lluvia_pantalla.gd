extends Control
## Gotas de lluvia dibujadas encima de la calle, en 2D a 640×360 (se ven pixeladas, a lo Doom).
## intensidad 0..1 dice cuántas gotas; giro las inclina un poco con el manubrio.

const MAX_GOTAS := 160

var intensidad := 0.0
var giro := 0.0
var _gotas := PackedVector3Array() # x, y, largo
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 99
	for k in MAX_GOTAS:
		_gotas.append(Vector3(_rng.randf_range(-40, 680), _rng.randf_range(0, 360), _rng.randf_range(8, 18)))


func _process(delta: float) -> void:
	visible = intensidad > 0.01
	if not visible:
		return
	for k in _gotas.size():
		var g := _gotas[k]
		g.y += 520.0 * delta
		g.x += (40.0 + giro * 120.0) * delta
		if g.y > 360.0:
			g = Vector3(_rng.randf_range(-40, 680), _rng.randf_range(-30, 0), g.z)
		_gotas[k] = g
	queue_redraw()


func _draw() -> void:
	var n := int(MAX_GOTAS * intensidad)
	var color := Color(0.78, 0.84, 0.95, 0.45)
	for k in n:
		var g := _gotas[k]
		draw_line(Vector2(g.x, g.y), Vector2(g.x - 3.0 - giro * 6.0, g.y - g.z), color, 1.0)
