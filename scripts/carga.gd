extends Control
## Pantalla de carga: la pone el director al darle Jugar (mientras se arma la ciudad) y la calle la
## deja encima mientras el navegador prepara todo lo que se dibuja (precalentado, recorrido.gd).
## Una barra que se llena y un consejo del domiciliario, para que no se vea un fondo gris.

const UI := preload("res://scripts/ui.gd")
const CONSEJOS := [
	"Despacio en las curvas: la fe no reemplaza el agarre.",
	"La sopa y la torta se riegan si frenas en seco.",
	"Los huecos con rama o cono se ven de lejos. Los otros, no.",
	"Si llueve, el pedido paga más. Y el andén resbala.",
	"Sigue la columna naranja para recoger y la verde para entregar.",
]

var avance := 0.0 # de 0 a 1
var _barra: ColorRect


func _ready() -> void:
	name = "Carga"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(640, 360)
	var fondo := UI.fondo(self)
	fondo.color = UI.C_FONDO
	UI.texto(self, "CARGANDO LA CIUDAD", Vector2(0, 140), 16, UI.C_AMARILLO, 640.0, "Titulo")
	var marco := ColorRect.new()
	marco.name = "Marco"
	marco.color = UI.C_GRIS
	marco.position = Vector2(170, 176)
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
	UI.parrafo(self, consejo, Vector2(80, 210), Vector2(480, 30), 8, UI.C_GRIS, "Consejo")
	poner_avance(avance)


func poner_avance(f: float) -> void:
	avance = clampf(f, 0.0, 1.0)
	if _barra != null:
		_barra.size.x = 296.0 * avance
