extends Control
## El puesto de mando de la moto visto desde el asiento (cada moto el suyo): sprite en pixel art
## (tools/gen_manubrios.py) dibujado a 2×, con la aguja y los números del tablero encima.
## Se inclina con el giro y tiembla con la velocidad.

const SPRITES := {
	"bws": preload("res://assets/ui/manubrio.png"),
	"nkd": preload("res://assets/ui/manubrio_nkd.png"),
	"ninja": preload("res://assets/ui/manubrio_ninja.png"),
}
const ESCALA := 2.0
const ARRIBA := 142.0        # y en pantalla donde empieza el sprite (termina en la barra de estado)
## Tablero de cada moto, en píxeles del sprite (tienen que coincidir con tools/gen_manubrios.py):
## aguja = centro y largo de la aguja; marca "vel" (velocímetro) o "rpm" (tacómetro);
## lcd = pantalla donde se escribe la velocidad (y el cambio, si la moto tiene).
const TABLEROS := {
	"bws": {"aguja": Vector2(160, 48), "largo": 10.0, "marca": "vel", "achate": 0.8},
	"nkd": {"aguja": Vector2(160, 42), "largo": 11.0, "marca": "vel"},
	"ninja": {"aguja": Vector2(145, 38), "largo": 7.5, "marca": "rpm", "lcd": Rect2(159, 30, 32, 16),
		"tinta": Color("b8e0ff"), "cambio": true},
}
const C_AGUJA := Color("e8401c")
## Segmentos de los números del LCD (a, b, c, d, e, f, g) para cada cifra.
const SEGMENTOS := ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]
const PIVOTE := Vector2(320, 334)

var moto_id := "bws"     # lo pone el recorrido según la moto que se lleva
var giro := 0.0
var vel_kmh := 0
var tope_kmh := 100.0    # hasta dónde marca el velocímetro (según la moto)
var rpm := 0.0           # 0 en ralentí, 1 al tope (lo pone el recorrido desde el sonido del motor)
var cambio := 0          # el cambio en que va (0 = automática, no se muestra)
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
	var tab: Dictionary = tablero()
	if tab.has("aguja"):
		# Aguja: de 0 al tope en el arco de la carátula (velocidad o revoluciones, según la moto).
		var f := clampf(vel_kmh / tope_kmh, 0.0, 1.0) if tab.marca == "vel" else clampf(rpm, 0.0, 1.0)
		var ang := lerpf(PI * 0.8, PI * 2.2, f)
		var c: Vector2 = origen + tab.aguja * ESCALA
		draw_line(c, c + Vector2(cos(ang), sin(ang) * tab.get("achate", 0.9)) * tab.largo * ESCALA, C_AGUJA, 2.0)
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color("1c1c22"))
	if tab.has("lcd"):
		_pantalla(origen, tab)
	draw_set_transform(Vector2.ZERO)


## Números de siete segmentos en la pantalla LCD: la velocidad a la derecha y el cambio a la izquierda.
func _pantalla(origen: Vector2, tab: Dictionary) -> void:
	var r: Rect2 = tab.lcd
	var tinta: Color = tab.tinta
	var p := origen + r.position * ESCALA
	var tam := r.size * ESCALA
	var alto := 14.0 if r.size.y >= 14.0 else 12.0
	var ancho := 8.0
	var texto := str(clampi(vel_kmh, 0, 999))
	var x := p.x + tam.x - 4.0 - texto.length() * (ancho + 2.0)
	var y := p.y + tam.y - alto - 3.0
	for ch in texto:
		_cifra(Vector2(x, y), ancho, alto, int(ch), tinta)
		x += ancho + 2.0
	if tab.get("cambio", false) and cambio > 0:
		_cifra(Vector2(p.x + 4.0, y), ancho, alto, cambio, Color("f0c040"))


func _cifra(pos: Vector2, ancho: float, alto: float, n: int, color: Color) -> void:
	var g := 2.0  # grosor del segmento
	var medio := floorf(alto / 2.0) - 1.0
	var segs := {
		"a": Rect2(0, 0, ancho, g), "g": Rect2(0, medio, ancho, g), "d": Rect2(0, alto - g, ancho, g),
		"f": Rect2(0, 0, g, medio + g), "b": Rect2(ancho - g, 0, g, medio + g),
		"e": Rect2(0, medio, g, alto - medio), "c": Rect2(ancho - g, medio, g, alto - medio),
	}
	for s in SEGMENTOS[n]:
		var q: Rect2 = segs[s]
		draw_rect(Rect2(pos + q.position, q.size), color)


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


func tablero() -> Dictionary:
	return TABLEROS.get(moto_id, TABLEROS.bws)
