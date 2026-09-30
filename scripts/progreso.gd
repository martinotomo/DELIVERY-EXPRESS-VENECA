extends RefCounted
## Lo que se gana entre partidas: la plata, las motos que se tienen (cada una con sus mejoras) y
## cuál se está usando. Comprar una moto no entrega la anterior: se queda en el garaje (Tomás, 30/09).
## Morirse no quita nada. Se guarda en disco cada vez que cambia (user://progreso.cfg).

signal cambio

const MOTOS := preload("res://scripts/motos.gd")

var ruta: String
var dinero := 0
## Motos compradas: {id: {"exosto": true, ...}} con las mejoras de cada una.
var tenidas := {MOTOS.MOTO_INICIAL: {}}
## La que se usa ahora. Ponerla a mano (pruebas, capturas) la agrega al garaje.
var moto := MOTOS.MOTO_INICIAL:
	set(v):
		moto = v
		if not tenidas.has(v):
			tenidas[v] = {}
## Mejoras de la moto en uso (el mismo diccionario que guarda tenidas).
var mejoras: Dictionary:
	get:
		if not tenidas.has(moto):
			tenidas[moto] = {}
		return tenidas[moto]
	set(v):
		tenidas[moto] = v


func _init(p_ruta := "user://progreso.cfg") -> void:
	ruta = p_ruta
	cargar()


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ruta) != OK:
		return
	dinero = maxi(int(cfg.get_value("progreso", "dinero", 0)), 0)
	var m := str(cfg.get_value("progreso", "moto", MOTOS.MOTO_INICIAL))
	if not MOTOS.MOTOS.has(m):
		m = MOTOS.MOTO_INICIAL
	tenidas = {}
	var guardadas = cfg.get_value("progreso", "tenidas") if cfg.has_section_key("progreso", "tenidas") else null
	if guardadas is Dictionary:
		for id in guardadas:
			if MOTOS.MOTOS.has(str(id)):
				tenidas[str(id)] = _limpiar(guardadas[id])
	else:
		# Partida de antes del garaje: solo guardaba la moto actual y sus mejoras, y las anteriores se
		# entregaban. Ahora son tuyas otra vez (de fábrica: sus mejoras no quedaron guardadas).
		for id in MOTOS.ORDEN.slice(0, MOTOS.ORDEN.find(m)):
			tenidas[id] = {}
		tenidas[m] = _limpiar(cfg.get_value("progreso", "mejoras", {}))
	tenidas[MOTOS.MOTO_INICIAL] = tenidas.get(MOTOS.MOTO_INICIAL, {})
	moto = m


static func _limpiar(d) -> Dictionary:
	var out := {}
	if d is Dictionary:
		for nombre in MOTOS.MEJORAS:
			if d.get(nombre, false):
				out[nombre] = true
	return out


func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "dinero", dinero)
	cfg.set_value("progreso", "moto", moto)
	cfg.set_value("progreso", "tenidas", tenidas)
	cfg.save(ruta)


## Cómo anda la moto que se tiene ahora, con sus mejoras.
func datos_moto() -> Dictionary:
	return MOTOS.con_mejoras(moto, mejoras)


## Cómo anda cualquier moto: con sus mejoras si es tuya, de fábrica si no.
func datos_de(id: String) -> Dictionary:
	return MOTOS.con_mejoras(id, tenidas.get(id, {}))


## Sacar del garaje otra moto que ya se tiene.
func usar(id: String) -> bool:
	if not tenidas.has(id):
		return false
	moto = id
	guardar()
	cambio.emit()
	return true


func ganar(pesos: int) -> void:
	if pesos <= 0:
		return
	dinero += pesos
	guardar()
	cambio.emit()


## Plata de prueba (F10 en el taller o en la calle, solo en versiones de desarrollo).
const PLATA_PRUEBA := 50000


func plata_de_prueba() -> void:
	ganar(PLATA_PRUEBA)


func tiene_mejora(nombre: String) -> bool:
	return mejoras.get(nombre, false)


func precio_mejora(nombre: String) -> int:
	return int(MOTOS.get_moto(moto).mejoras[nombre].precio)


func puede_mejorar(nombre: String) -> bool:
	return nombre in MOTOS.MEJORAS and not tiene_mejora(nombre) and dinero >= precio_mejora(nombre)


func comprar_mejora(nombre: String) -> bool:
	if not puede_mejorar(nombre):
		return false
	dinero -= precio_mejora(nombre)
	mejoras[nombre] = true
	guardar()
	cambio.emit()
	return true


## La próxima moto por comprar ("" si ya se tienen todas): la primera de la fila que no es tuya.
func siguiente_moto() -> String:
	for id in MOTOS.ORDEN:
		if not tenidas.has(id):
			return id
	return ""


func puede_comprar_moto() -> bool:
	var s := siguiente_moto()
	return s != "" and dinero >= int(MOTOS.get_moto(s).precio)


## La moto nueva llega de fábrica y sale a la calle; la anterior se queda en el garaje con sus mejoras.
func comprar_moto() -> bool:
	if not puede_comprar_moto():
		return false
	var s := siguiente_moto()
	dinero -= int(MOTOS.get_moto(s).precio)
	tenidas[s] = {}
	moto = s
	guardar()
	cambio.emit()
	return true


## Cómo está cada moto para el taller.
const EN_USO := "en_uso"
const TENIDA := "tenida"           # tuya, en el garaje: se puede volver a usar
const COMPRABLE := "comprable"     # la siguiente, y alcanza la plata
const SIN_PLATA := "sin_plata"     # la siguiente, pero no alcanza
const BLOQUEADA := "bloqueada"     # más adelante: primero hay que comprar la del medio


func estado_moto(id: String) -> String:
	if id == moto:
		return EN_USO
	if tenidas.has(id):
		return TENIDA
	if id != siguiente_moto():
		return BLOQUEADA
	return COMPRABLE if puede_comprar_moto() else SIN_PLATA


## Cuánta plata falta para comprar esa moto (0 si alcanza).
func falta_para(id: String) -> int:
	return maxi(int(MOTOS.get_moto(id).precio) - dinero, 0)


static func pesos(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "$" + s + out
