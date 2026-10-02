extends Control
## Pantalla de carga: la pone el director al darle Jugar (mientras se arma la ciudad) y la calle la
## deja encima mientras el navegador prepara todo lo que se dibuja (precalentado, recorrido.gd).
## Dura al menos unos segundos (recorrido.carga_min_s) para que alcance a leer qué mata y qué cuesta
## plata en la calle (Tomás, 02/10/2026). Las reglas salen de partida.gd, moto_logic.gd y motos.gd:
## si cambian allá, se cambian aquí.

const UI := preload("res://scripts/ui.gd")
const TE_MATA := [
	"ANDÉN: subirte a más de 11 km/h.",
	"CURVA: girar a tope yendo a fondo; la moto se va de lado.",
	"HUECO: caer en uno a más del 80 % de la máxima.",
	"PERRO: pegarle a más del 60 % de la máxima.",
	"BUS O CAMIÓN, o un carro de frente: a más del 80 %.",
]
const TE_CUESTA := [
	"PEATÓN: atropellarlo te quita la propina del pedido.",
	"CARRO: chocarlo despacio es frenazo, pito e insultos.",
	"FRENAZO O HUECO DESPACIO: se riega la sopa o la torta.",
	"MOTOR: a fondo mucho rato se funde; 3 s quieto.",
	"ACEITE: casi no gira. CHARCO: te frena.",
]
const CONSEJOS := [
	"La sopa y la torta se riegan si frenas en seco.",
	"Los huecos con rama o cono se ven de lejos. Los otros, no.",
	"Si llueve, el pedido paga más. Y el andén resbala.",
	"Sigue la columna naranja para recoger y la verde para entregar.",
]
const COL_ANCHO := 284.0
const COL_X := [24.0, 332.0]

var avance := 0.0 # de 0 a 1
var _barra: ColorRect


func _ready() -> void:
	name = "Carga"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(640, 360)
	var fondo := UI.fondo(self)
	fondo.color = UI.C_FONDO
	UI.texto(self, "CÓMO NO MORIR REPARTIENDO", Vector2(0, 18), 16, UI.C_AMARILLO, 640.0, "Titulo")
	_columna("TeMata", "TE MATA", UI.C_ROJO, TE_MATA, COL_X[0])
	_columna("TeCuesta", "TE CUESTA", UI.C_AMARILLO, TE_CUESTA, COL_X[1])
	UI.parrafo(self, "Morir no te quita la plata.", Vector2(0, 256), Vector2(640, 12), 8, UI.C_GRIS, "Plata")

	UI.texto(self, "CARGANDO LA CIUDAD", Vector2(0, 284), 8, UI.C_GRIS, 640.0, "Cargando")
	var marco := ColorRect.new()
	marco.name = "Marco"
	marco.color = UI.C_GRIS
	marco.position = Vector2(170, 298)
	marco.size = Vector2(300, 12)
	add_child(marco)
	var hueco := ColorRect.new()
	hueco.color = Color.BLACK
	hueco.position = Vector2(2, 2)
	hueco.size = Vector2(296, 8)
	marco.add_child(hueco)
	_barra = ColorRect.new()
	_barra.name = "Barra"
	_barra.color = UI.C_ROJO
	_barra.position = Vector2(2, 2)
	_barra.size = Vector2(0, 8)
	marco.add_child(_barra)
	var consejo: String = CONSEJOS[randi() % CONSEJOS.size()]
	UI.parrafo(self, consejo, Vector2(80, 324), Vector2(480, 24), 8, UI.C_GRIS, "Consejo")
	poner_avance(avance)


## Una columna: el encabezado de color y debajo cada regla, partida en líneas si no cabe.
func _columna(nombre: String, titulo: String, color: Color, reglas: Array, x: float) -> void:
	UI.texto(self, titulo, Vector2(x, 54), 8, color, 0.0, nombre + "Titulo")
	var v := VBoxContainer.new()
	v.name = nombre
	v.position = Vector2(x, 72)
	v.size = Vector2(COL_ANCHO, 0)
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	for regla in reglas:
		var l := Label.new()
		l.text = regla
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(COL_ANCHO, 0)
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", UI.C_TEXTO)
		l.add_theme_constant_override("line_spacing", 3)
		v.add_child(l)


func poner_avance(f: float) -> void:
	avance = clampf(f, 0.0, 1.0)
	if _barra != null:
		_barra.size.x = 296.0 * avance
