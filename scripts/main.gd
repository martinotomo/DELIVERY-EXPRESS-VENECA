extends Node
## Director: el único que crea y destruye pantallas. Nunca hay dos vivas a la vez.
## Guarda el progreso (plata, moto, mejoras), que sobrevive a todas las pantallas.

const PROGRESO := preload("res://scripts/progreso.gd")
const MENU := preload("res://scenes/menu.tscn")
const TALLER := preload("res://scenes/taller.tscn")
const RECORRIDO := preload("res://scenes/recorrido.tscn")
const RESULTADO := preload("res://scenes/resultado.tscn")

## Las pruebas la cambian antes de instanciar para no tocar la partida guardada de verdad.
static var ruta_progreso := "user://progreso.cfg"

var progreso
## Música (DISENO §11): vive aquí, en el director, para que no se corte al cambiar de pantalla
## (CLAUDE.md §5). Menú y taller: «menu»; en la calle: «conduccion»; al caer: «muerte».
var musica_actual := ""
var _musica: AudioStreamPlayer
const MUSICA_DB := {"menu": -12.0, "conduccion": -18.0, "muerte": -6.0} # la de la calle va −18 dB bajo los efectos

@onready var _pantallas: Node = $Pantallas


func _ready() -> void:
	progreso = PROGRESO.new(ruta_progreso)
	_musica = AudioStreamPlayer.new()
	_musica.name = "Musica"
	add_child(_musica)
	menu()


func musica(nombre: String) -> void:
	if nombre == musica_actual and _musica.playing:
		return
	musica_actual = nombre
	_musica.stream = load("res://assets/musica/%s.wav" % nombre)
	_musica.volume_db = MUSICA_DB[nombre]
	_musica.play()



func pantalla_actual() -> Node:
	var hijos := _pantallas.get_children()
	return hijos[0] if hijos.size() > 0 else null


func menu() -> void:
	var m := _mostrar(MENU)
	musica("menu")
	m.jugar.connect(reiniciar, CONNECT_DEFERRED)
	m.taller.connect(taller, CONNECT_DEFERRED)
	m.salir.connect(func(): get_tree().quit())


func taller() -> void:
	var t := _mostrar(TALLER)
	musica("menu")
	t.volver.connect(menu, CONNECT_DEFERRED)


func reiniciar() -> void:
	var ride := _mostrar(RECORRIDO)
	musica("conduccion")
	ride.partida.pagado.connect(progreso.ganar)
	ride.partida.terminada_por.connect(func(_m): musica("muerte"))
	ride.terminado.connect(_al_terminar)
	ride.reintentar.connect(reiniciar, CONNECT_DEFERRED)
	ride.al_menu.connect(menu, CONNECT_DEFERRED)


func _al_terminar(estado: String, mensaje: String) -> void:
	if estado == "final":
		musica("menu")
	var ilustracion: Texture2D = pantalla_actual().get("ilustracion_final")
	_mostrar_resultado.call_deferred(estado, mensaje, ilustracion)


func _mostrar_resultado(estado: String, mensaje: String, ilustracion: Texture2D = null) -> void:
	var res := _mostrar(RESULTADO)
	res.mostrar(estado, mensaje, ilustracion)
	res.continuar.connect(reiniciar, CONNECT_DEFERRED)
	res.al_menu.connect(menu, CONNECT_DEFERRED)


## Cada pantalla recibe el progreso antes de entrar al árbol (su _ready ya lo tiene).
func _mostrar(escena: PackedScene) -> Node:
	for hijo in _pantallas.get_children():
		_pantallas.remove_child(hijo)
		hijo.queue_free()
	var nueva := escena.instantiate()
	if "progreso" in nueva:
		nueva.progreso = progreso
	_pantallas.add_child(nueva)
	return nueva
