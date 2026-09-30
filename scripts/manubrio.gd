extends Control
## El manubrio de la BWS visto desde el puesto del domiciliario: sprite en pixel art
## (tools/gen_texturas.py) dibujado a 2×, con la aguja del velocímetro encima.
## Se inclina con el giro y tiembla con la velocidad.

const SPRITE := preload("res://assets/ui/manubrio.png")
const ESCALA := 2.0
const ARRIBA := 154.0        # y en pantalla donde empieza el sprite (termina en la barra de estado)
const CENTRO_AGUJA := Vector2(160, 66) # en píxeles del sprite
const PIVOTE := Vector2(320, 334)

var giro := 0.0
var vel_kmh := 0
var _t := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var temblor := roundf(sin(_t * 40.0) * clampf(vel_kmh / 90.0, 0.0, 1.0) * 1.5)
	draw_set_transform(PIVOTE + Vector2(0, temblor), giro * 0.06, Vector2.ONE)
	var origen := Vector2(-PIVOTE.x, ARRIBA - PIVOTE.y)
	draw_texture_rect(SPRITE, Rect2(origen, SPRITE.get_size() * ESCALA), false)
	# Aguja: de 0 a 100 km/h en el arco de la carátula.
	var ang := lerpf(PI * 0.8, PI * 2.2, clampf(vel_kmh / 100.0, 0.0, 1.0))
	var c := origen + CENTRO_AGUJA * ESCALA
	draw_line(c, c + Vector2(cos(ang), sin(ang)) * 20.0, Color("c41e18"), 2.0)
	draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color("1c1c22"))
