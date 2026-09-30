extends Control
## El manubrio de la moto visto desde el puesto del domiciliario (cada moto el suyo): sprite en pixel art
## (tools/gen_texturas.py) dibujado a 2×, con la aguja del velocímetro encima.
## Se inclina con el giro y tiembla con la velocidad.

const SPRITES := {
	"bws": preload("res://assets/ui/manubrio.png"),
	"nkd": preload("res://assets/ui/manubrio_nkd.png"),
	"ninja": preload("res://assets/ui/manubrio_ninja.png"),
}
const ESCALA := 2.0
const ARRIBA := 154.0        # y en pantalla donde empieza el sprite (termina en la barra de estado)
const CENTRO_AGUJA := Vector2(160, 66) # en píxeles del sprite
const PIVOTE := Vector2(320, 334)

var moto_id := "bws"     # lo pone el recorrido según la moto que se lleva
var giro := 0.0
var vel_kmh := 0
var tope_kmh := 100.0    # hasta dónde marca el velocímetro (según la moto)
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
	var sprite := sprite_actual()
	draw_texture_rect(sprite, Rect2(origen, sprite.get_size() * ESCALA), false)
	# Aguja: de 0 al tope de la moto en el arco de la carátula.
	var ang := lerpf(PI * 0.8, PI * 2.2, clampf(vel_kmh / tope_kmh, 0.0, 1.0))
	var c := origen + CENTRO_AGUJA * ESCALA
	draw_line(c, c + Vector2(cos(ang), sin(ang)) * 20.0, Color("c41e18"), 2.0)
	draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color("1c1c22"))


## Rectángulo que ocupa el sprite en la pantalla de 640×360 con un giro dado (lo usan las pruebas).
func rect_en_pantalla(con_giro: float) -> Rect2:
	var origen := Vector2(-PIVOTE.x, ARRIBA - PIVOTE.y)
	var tam := sprite_actual().get_size() * ESCALA
	var xf := Transform2D(con_giro * 0.06, PIVOTE)
	var r := Rect2(xf * origen, Vector2.ZERO)
	for esquina in [origen + Vector2(tam.x, 0), origen + Vector2(0, tam.y), origen + tam]:
		r = r.expand(xf * esquina)
	return r


func sprite_actual() -> Texture2D:
	return SPRITES.get(moto_id, SPRITES.bws)
