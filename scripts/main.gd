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
const CARGA := preload("res://scripts/carga.gd")

## Las pruebas la cambian antes de instanciar para no tocar la partida guardada de verdad.
static var ruta_progreso := "user://progreso.cfg"
static var ruta_opciones := "user://opciones.cfg"
## Advertencia de contenido al abrir el juego (CLAUDE.md §8). Las pruebas la apagan.
static var mostrar_advertencia := true
## Al darle Jugar sale primero la pantalla de carga (armar la ciudad tarda, sobre todo en el
## navegador) y la calle se arma un par de fotogramas después, cuando ya se ve. Las pruebas la apagan.
static var pantalla_carga := true
## Mientras se está en el menú (o en el resultado), la calle se arma y se precalienta detrás, sin
## verse, para que al darle Jugar ya casi esté lista (Tomás, 02/10/2026). Las pruebas la apagan.
static var precargar_en_menu := true
const CARGA_DESDE_MENU_S := 6.0  # al darle Jugar: alcanza a leer cómo se pierde
const CARGA_REINTENTO_S := 3.0   # al volver a salir tras caerse

var _reserva: Node     # contenedor de la calle armada detrás del menú (no cuenta como pantalla)
var _clave_reserva := ""

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
	# Primera línea del log: con --log-file, tools/build.ps1 comprueba que el .exe arrancó y que es
	# la versión de entrega (sin las teclas de prueba F9/F10, que solo existen en debug).
	print("%s %s (%s)" % [ProjectSettings.get_setting("application/config/name"),
		ProjectSettings.get_setting("application/config/version"), _modo()])
	progreso = PROGRESO.new(ruta_progreso)
	opciones = OPCIONES.new(ruta_opciones)
	opciones.aplicar()
	print("opciones: idioma=%s volumen=%s guardado_persistente=%s" % [opciones.idioma, opciones.volumen, OS.is_userfs_persistent()])
	_musica = AudioStreamPlayer.new()
	_musica.name = "Musica"
	_musica.bus = &"Musica"
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS # sigue sonando en la pausa
	add_child(_musica)
	_reserva = Node.new()
	_reserva.name = "Reserva"
	add_child(_reserva)
	if "--prueba-arranque" in OS.get_cmdline_user_args():
		_prueba_arranque()
	elif mostrar_advertencia:
		advertencia()
	else:
		menu()


## Para comprobar un .exe sin jugarlo (tools/build.ps1): menú, taller y 6 s de calle con la moto
## guardada; escribe en el log lo que vio y los fps, y cierra. No guarda nada.
## «release»: exportado con plantilla de entrega. «entrega»: el .pck de entrega corriendo en el
## binario oficial firmado de Godot (D31). «desarrollo»: desde el editor o las pruebas.
static func _modo() -> String:
	if not OS.is_debug_build():
		return "release"
	return "entrega" if OS.has_feature("entrega") else "desarrollo"


func _prueba_arranque() -> void:
	progreso.ruta = "user://prueba_arranque.cfg" # lee la partida de verdad, pero no la toca
	menu()
	await get_tree().create_timer(0.5).timeout
	taller()
	await get_tree().create_timer(0.5).timeout
	reiniciar()
	var ride := pantalla_actual()
	await get_tree().create_timer(1.0).timeout
	var cuadros := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(5.0).timeout
	var fps := (Engine.get_frames_drawn() - cuadros) * 1000.0 / maxf(Time.get_ticks_msec() - t0, 1.0)
	print("prueba-arranque: binario=%s moto=%s plata=%d idioma=%s pantallas=%d recorrido=%s reloj=%.1f fps=%.0f trucos=%s" % [
		OS.get_executable_path().get_file(), progreso.moto, progreso.dinero, TranslationServer.get_locale(), _pantallas.get_child_count(),
		ride.name if is_instance_valid(ride) else "-", ride.partida.reloj.t if is_instance_valid(ride) else -1.0,
		fps, ride.trucos if is_instance_valid(ride) else "-"])
	print("prueba-arranque: OK")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progreso.ruta))
	get_tree().quit()


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
	_preparar_reserva.call_deferred()


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
	var actual := pantalla_actual()
	var desde_menu := actual != null and actual.scene_file_path == MENU.resource_path
	var min_s := CARGA_DESDE_MENU_S if desde_menu else CARGA_REINTENTO_S
	var ride := _sacar_reserva()
	if ride != null:
		_quitar_pantallas()
		_pantallas.add_child(ride)
		ride.activar(min_s)
	else:
		if pantalla_carga:
			var carga := _mostrar_nodo(CARGA.new())
			await get_tree().process_frame
			await get_tree().process_frame # dos: el primero arma la pantalla, el segundo ya la dibujó
			if pantalla_actual() != carga:
				return # mientras tanto se fue a otra pantalla
		_quitar_pantallas() # antes de instanciar: la calle puede tardar en armarse
		ride = RECORRIDO.instantiate()
		ride.carga_min_s = min_s
		_mostrar_nodo(ride)
	musica("conduccion")
	ride.partida.pagado.connect(progreso.ganar)
	ride.partida.terminada_por.connect(func(_m): musica("muerte"))
	ride.terminado.connect(_al_terminar)
	ride.reintentar.connect(reiniciar, CONNECT_DEFERRED)
	ride.al_menu.connect(menu, CONNECT_DEFERRED)


## Con qué se armó la calle de reserva: si cambia (otra moto, mejoras, el final, el idioma), se rehace.
func _clave() -> String:
	return "%s|%s|%s" % [progreso.datos_moto(), progreso.toca_final(), TranslationServer.get_locale()]


## Arma la calle detrás de la pantalla actual, un par de fotogramas después (que la pantalla ya se vea).
func _preparar_reserva() -> void:
	if not precargar_en_menu:
		return
	if _reserva.get_child_count() > 0 and _clave_reserva == _clave():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var actual := pantalla_actual()
	if actual == null or actual.name == "Recorrido":
		return # ya se fue a la calle
	if _reserva.get_child_count() > 0 and _clave_reserva == _clave():
		return
	_tirar_reserva()
	var ride: Node = RECORRIDO.instantiate()
	ride.segundo_plano = true
	ride.progreso = progreso
	ride.opciones = opciones
	_clave_reserva = _clave()
	_reserva.add_child(ride)


func _sacar_reserva() -> Node:
	if _reserva == null or _reserva.get_child_count() == 0:
		return null
	if _clave_reserva != _clave():
		_tirar_reserva()
		return null
	var ride := _reserva.get_child(0)
	_reserva.remove_child(ride)
	return ride


func _tirar_reserva() -> void:
	for hijo in _reserva.get_children():
		_reserva.remove_child(hijo)
		hijo.queue_free()


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
	_preparar_reserva.call_deferred()


## Cada pantalla recibe el progreso antes de entrar al árbol (su _ready ya lo tiene).
func _mostrar(escena: PackedScene) -> Node:
	_quitar_pantallas() # antes de instanciar: la nueva (la calle) puede tardar en armarse
	return _mostrar_nodo(escena.instantiate())


func _mostrar_nodo(nueva: Node) -> Node:
	_quitar_pantallas()
	if "progreso" in nueva:
		nueva.progreso = progreso
	if "opciones" in nueva:
		nueva.opciones = opciones
	_pantallas.add_child(nueva)
	return nueva


func _quitar_pantallas() -> void:
	get_tree().paused = false # salir de una partida en pausa no deja el juego congelado
	for hijo in _pantallas.get_children():
		_pantallas.remove_child(hijo)
		hijo.queue_free()
