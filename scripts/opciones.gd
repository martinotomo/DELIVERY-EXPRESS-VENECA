extends RefCounted
## Opciones del jugador (F6): volumen general, de música y de efectos, pantalla completa, idioma y
## teclas. Se guardan en user://opciones.cfg y se aplican al momento. Un archivo dañado no rompe
## nada: cada valor raro vuelve al de fábrica.

const RUTA := "user://opciones.cfg"
const IDIOMAS := ["es", "en"]
## Las acciones que el jugador puede cambiar. Cada una tiene una tecla de letra configurable; las
## flechas (y el espacio de frenar) se quedan siempre para no dejar a nadie sin manejar.
const ACCIONES := ["acelerar", "frenar", "izquierda", "derecha", "pitar", "mapa"]
const TECLAS_FABRICA := {
	"acelerar": KEY_W, "frenar": KEY_S, "izquierda": KEY_A, "derecha": KEY_D,
	"pitar": KEY_H, "mapa": KEY_TAB,
}
## Teclas que no se pueden asignar: las fijas de cada acción y las del juego.
const RESERVADAS := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_ESCAPE, KEY_ENTER,
	KEY_KP_ENTER, KEY_R, KEY_P, KEY_F9, KEY_F10]
const VOLUMEN_FABRICA := {"general": 1.0, "musica": 0.8, "efectos": 1.0}
const BUSES := {"general": "Master", "musica": "Musica", "efectos": "Efectos"}

var ruta := RUTA
var idioma := "es"
var pantalla_completa := false
var volumen := VOLUMEN_FABRICA.duplicate()
var teclas := TECLAS_FABRICA.duplicate()


func _init(p_ruta := RUTA) -> void:
	ruta = p_ruta
	var cfg := ConfigFile.new()
	if cfg.load(ruta) != OK:
		return
	var i = cfg.get_value("idioma", "idioma", "es")
	idioma = i if i in IDIOMAS else "es"
	pantalla_completa = cfg.get_value("pantalla", "completa", false) == true
	for cual in VOLUMEN_FABRICA:
		var v = cfg.get_value("volumen", cual, VOLUMEN_FABRICA[cual])
		volumen[cual] = clampf(float(v), 0.0, 1.0) if (v is float or v is int) else VOLUMEN_FABRICA[cual]
	var usadas := []
	for accion in ACCIONES:
		var k = cfg.get_value("teclas", accion, TECLAS_FABRICA[accion])
		if k is int and _valida(k) and not k in usadas:
			teclas[accion] = k
		usadas.append(teclas[accion])


func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("idioma", "idioma", idioma)
	cfg.set_value("pantalla", "completa", pantalla_completa)
	for cual in volumen:
		cfg.set_value("volumen", cual, volumen[cual])
	for accion in teclas:
		cfg.set_value("teclas", accion, teclas[accion])
	cfg.save(ruta)


## Aplica todo: buses de audio, volumen, pantalla, idioma y teclas.
func aplicar() -> void:
	crear_buses()
	for cual in volumen:
		poner_volumen(cual, volumen[cual])
	poner_pantalla_completa(pantalla_completa)
	poner_idioma(idioma)
	for accion in teclas:
		_asignar(accion, teclas[accion])


## Los buses «Musica» y «Efectos» salen del Master. Se crean una sola vez.
static func crear_buses() -> void:
	for nombre in ["Musica", "Efectos"]:
		if AudioServer.get_bus_index(nombre) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nombre)
			AudioServer.set_bus_send(i, "Master")


func poner_volumen(cual: String, v: float) -> void:
	if not BUSES.has(cual):
		return
	crear_buses()
	volumen[cual] = clampf(v, 0.0, 1.0)
	var i := AudioServer.get_bus_index(BUSES[cual])
	AudioServer.set_bus_mute(i, volumen[cual] <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumen[cual], 0.001)))


func poner_pantalla_completa(si: bool) -> void:
	pantalla_completa = si
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if si else DisplayServer.WINDOW_MODE_WINDOWED)


func poner_idioma(p_idioma: String) -> void:
	idioma = p_idioma if p_idioma in IDIOMAS else "es"
	TranslationServer.set_locale(idioma)


func otro_idioma() -> String:
	return IDIOMAS[(IDIOMAS.find(idioma) + 1) % IDIOMAS.size()]


## Cambia la tecla de letra de una acción. Devuelve false si la tecla ya la usa otra acción o es
## una de las fijas.
func cambiar_tecla(accion: String, tecla: int) -> bool:
	if not accion in ACCIONES or not _valida(tecla):
		return false
	for otra in teclas:
		if otra != accion and teclas[otra] == tecla:
			return false
	teclas[accion] = tecla
	_asignar(accion, tecla)
	return true


func restablecer_teclas() -> void:
	teclas = TECLAS_FABRICA.duplicate()
	for accion in teclas:
		_asignar(accion, teclas[accion])


static func nombre_tecla(tecla: int) -> String:
	return OS.get_keycode_string(tecla).to_upper()


func _valida(tecla: int) -> bool:
	return tecla > 0 and not tecla in RESERVADAS and not OS.get_keycode_string(tecla).is_empty()


## Quita de la acción la tecla configurable anterior (cualquier tecla que no sea fija) y pone la nueva.
func _asignar(accion: String, tecla: int) -> void:
	if not InputMap.has_action(accion):
		return
	for e in InputMap.action_get_events(accion):
		if e is InputEventKey and not e.physical_keycode in RESERVADAS:
			InputMap.action_erase_event(accion, e)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(accion, ev)
