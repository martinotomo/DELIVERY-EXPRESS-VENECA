extends RefCounted
## Lo que se gana entre partidas: la plata, la moto que se tiene y sus mejoras.
## Morirse no quita nada. Se guarda en disco cada vez que cambia (user://progreso.cfg).

signal cambio

const MOTOS := preload("res://scripts/motos.gd")

var ruta: String
var dinero := 0
var moto := MOTOS.MOTO_INICIAL
var mejoras := {} # de la moto actual: {"exosto": true, ...}


func _init(p_ruta := "user://progreso.cfg") -> void:
	ruta = p_ruta
	cargar()


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ruta) != OK:
		return
	dinero = maxi(int(cfg.get_value("progreso", "dinero", 0)), 0)
	var m := str(cfg.get_value("progreso", "moto", MOTOS.MOTO_INICIAL))
	moto = m if MOTOS.MOTOS.has(m) else MOTOS.MOTO_INICIAL
	var guardadas = cfg.get_value("progreso", "mejoras", {})
	mejoras = {}
	if guardadas is Dictionary:
		for nombre in MOTOS.MEJORAS:
			if guardadas.get(nombre, false):
				mejoras[nombre] = true


func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "dinero", dinero)
	cfg.set_value("progreso", "moto", moto)
	cfg.set_value("progreso", "mejoras", mejoras)
	cfg.save(ruta)


## Cómo anda la moto que se tiene ahora, con sus mejoras.
func datos_moto() -> Dictionary:
	return MOTOS.con_mejoras(moto, mejoras)


func ganar(pesos: int) -> void:
	if pesos <= 0:
		return
	dinero += pesos
	guardar()
	cambio.emit()


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


## La moto que sigue ("" si ya se tiene la última) y su precio.
func siguiente_moto() -> String:
	return MOTOS.siguiente(moto)


func puede_comprar_moto() -> bool:
	var s := siguiente_moto()
	return s != "" and dinero >= int(MOTOS.get_moto(s).precio)


## La moto nueva llega de fábrica; la vieja se entrega (no se guardan sus mejoras).
func comprar_moto() -> bool:
	if not puede_comprar_moto():
		return false
	var s := siguiente_moto()
	dinero -= int(MOTOS.get_moto(s).precio)
	moto = s
	mejoras = {}
	guardar()
	cambio.emit()
	return true


static func pesos(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "$" + s + out
