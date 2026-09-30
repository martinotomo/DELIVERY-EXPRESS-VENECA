extends Node
## Director: el único que crea y destruye pantallas. Nunca hay dos vivas a la vez.
## Guarda el progreso (plata, moto, mejoras), que sobrevive a todas las pantallas.

const PROGRESO := preload("res://scripts/progreso.gd")
const MENU := preload("res://scenes/menu.tscn")
const TALLER := preload("res://scenes/taller.tscn")
const RECORRIDO := preload("res://scenes/recorrido.tscn")
const RESULTADO := preload("res://scenes/resultado.tscn")
const OPCIONES := preload("res://scripts/opciones.gd")
const PANTALLA_OPCIONES := preload("res://scenes/opciones.tscn")
const CREDITOS := preload("res://scenes/creditos.tscn")
const ADVERTENCIA := preload("res://scenes/advertencia.tscn")

## Las pruebas la cambian antes de instanciar para no tocar la partida guardada de verdad.
static var ruta_progreso := "user://progreso.cfg"
static var ruta_opciones := "user://opciones.cfg"
## Advertencia de contenido al abrir el juego (CLAUDE.md §8). Las pruebas la apagan.
static var mostrar_advertencia := true

var opciones # volumen, pantalla, idioma y teclas (opciones.gd); se aplican al abrir

var progreso
## Música (DISENO §11): vive aquí, en el director, para que no se corte al cambiar de pantalla
## (CLAUDE.md §5). Menú y taller: «menu»; en la calle: «conduccion»; al caer: «muerte».
var musica_actual := ""
var reproducciones := 0 # cuántas veces arrancó una pista (las pruebas miran que no se corte)
var _musica: AudioStreamPlayer
const MUSICA_DB := {"menu": -12.0, "conduccion": -18.0, "muerte": -6.0} # la de la calle va −18 dB bajo los efectos

@onready var _pantallas: Node = $Pantallas


func _ready() -> void:
	progreso = PROGRESO.new(ruta_progreso)
	opciones = OPCIONES.new(ruta_opciones)
	opciones.aplicar()
	_musica = AudioStreamPlayer.new()
	_musica.name = "Musica"
	_musica.bus = &"Musica"
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS # sigue sonando en la pausa
	add_child(_musica)
	if mostrar_advertencia:
		advertencia()
	else:
		menu()


func musica(nombre: String) -> void:
	if nombre == musica_actual and _musica.playing:
		return
	musica_actual = nombre
	_musica.stream = load("res://assets/musica/%s.wav" % nombre)
	_musica.volume_db = MUSICA_DB[nombre]
	_musica.play()
	reproducciones += 1



func pantalla_actual() -> Node:
	var hijos := _pantallas.get_children()
	return hijos[0] if hijos.size() > 0 else null


func menu() -> void:
	var m := _mostrar(MENU)
	musica("menu")
	m.jugar.connect(reiniciar, CONNECT_DEFERRED)
	m.taller.connect(taller, CONNECT_DEFERRED)
	m.abrir_opciones.connect(pantalla_opciones, CONNECT_DEFERRED)
	m.abrir_creditos.connect(creditos, CONNECT_DEFERRED)
	m.salir.connect(func(): get_tree().quit())


func taller() -> void:
	var t := _mostrar(TALLER)
	musica("menu")
	t.volver.connect(menu, CONNECT_DEFERRED)


func advertencia() -> void:
	var a := _mostrar(ADVERTENCIA)
	musica("menu")
	a.listo.connect(menu, CONNECT_DEFERRED)


func pantalla_opciones() -> void:
	var o := _mostrar(PANTALLA_OPCIONES)
	musica("menu")
	o.volver.connect(menu, CONNECT_DEFERRED)


func creditos() -> void:
	var c := _mostrar(CREDITOS)
	musica("menu")
	c.volver.connect(menu, CONNECT_DEFERRED)


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
	get_tree().paused = false # salir de una partida en pausa no deja el juego congelado
	for hijo in _pantallas.get_children():
		_pantallas.remove_child(hijo)
		hijo.queue_free()
	var nueva := escena.instantiate()
	if "progreso" in nueva:
		nueva.progreso = progreso
	if "opciones" in nueva:
		nueva.opciones = opciones
	_pantallas.add_child(nueva)
	return nueva
