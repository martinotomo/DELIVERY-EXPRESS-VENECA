extends RefCounted
## Una jornada de domiciliario: recoger, entregar, otro pedido... hasta que la fe supere al agarre.

signal evento(nombre: String)       # recogido, entregado, cancelado, casi, golpe, estrellado
signal terminada_por(mensaje: String)

const CIUDAD := preload("res://scripts/ciudad.gd")
const MOTO := preload("res://scripts/moto_logic.gd")
const MOTOS := preload("res://scripts/motos.gd")
const CICLO := preload("res://scripts/ciclo_dia.gd")

const RECOGER := "recoger"
const ENTREGAR := "entregar"
const RADIO_LLEGADA := 7.0
const VEL_PARADA := 3.0      # m/s: hay que parar para recoger o entregar
const VEL_PROMEDIO := 8.0    # m/s con que se calcula el tiempo del pedido
const TIEMPO_EXTRA := 25.0

const PLATOS := ["Bandeja paisa", "Ajiaco", "Hamburguesa doble", "Salchipapa", "Empanadas x10",
	"Arepa de choclo", "Pizza familiar", "Changua", "Tamal con chocolate", "Perro caliente"]

var ciudad
var moto
var reloj
var pedido := {}
var fase := RECOGER
var tiempo_restante := 0.0
var entregados := 0
var cancelados := 0
var terminada := false
var _rng := RandomNumberGenerator.new()


func _init(semilla := 1) -> void:
	_rng.seed = semilla
	ciudad = CIUDAD.new(semilla)
	reloj = CICLO.new()
	moto = MOTO.new()
	moto.setup(MOTOS.get_moto(MOTOS.MOTO_INICIAL), ciudad, ciudad.cruce(20, 40), 0.0)
	moto.estrellado.connect(_al_estrellarse)
	moto.casi.connect(func(_tipo): evento.emit("casi"))
	moto.golpe.connect(func(): evento.emit("golpe"))
	_nuevo_pedido()


func advance(delta: float, acelerar: bool, frenar: bool, giro: float) -> void:
	if terminada:
		return
	moto.advance(delta, acelerar, frenar, giro)
	if terminada:
		return
	reloj.advance(delta)
	tiempo_restante -= delta
	_revisar_llegada()
	if tiempo_restante <= 0.0:
		cancelados += 1
		evento.emit("cancelado")
		_nuevo_pedido()


func objetivo() -> Vector2:
	return pedido.restaurante if fase == RECOGER else pedido.cliente


func ruta() -> PackedVector2Array:
	return ciudad.ruta(moto.pos, objetivo())


func _revisar_llegada() -> void:
	if moto.pos.distance_to(objetivo()) > RADIO_LLEGADA or moto.vel > VEL_PARADA:
		return
	if fase == RECOGER:
		fase = ENTREGAR
		evento.emit("recogido")
	else:
		entregados += 1
		evento.emit("entregado")
		_nuevo_pedido()


func _cuadra_cerca(desde: Vector2, min_d: int, max_d: int) -> Vector2i:
	var i0 := clampi(int(desde.x / ciudad.tamano().x * ciudad.N_ANCHO), 0, ciudad.N_ANCHO - 1)
	var j0 := clampi(int(desde.y / ciudad.tamano().y * ciudad.N_LARGO), 0, ciudad.N_LARGO - 1)
	var di := _rng.randi_range(min_d, max_d) * (1 if _rng.randf() < 0.5 else -1)
	var dj := _rng.randi_range(min_d, max_d) * (1 if _rng.randf() < 0.5 else -1)
	return Vector2i(clampi(i0 + di / 2, 0, ciudad.N_ANCHO - 1), clampi(j0 + dj, 1, ciudad.N_LARGO - 1))


func _nuevo_pedido() -> void:
	var r := _cuadra_cerca(moto.pos, 1, 6)
	var c := _cuadra_cerca(ciudad.punto_frente_a(r.x, r.y), 3, 10)
	if c == r:
		c.y = clampi(c.y + 4, 1, ciudad.N_LARGO - 1)
	var rest: Vector2 = ciudad.punto_frente_a(r.x, r.y)
	var cli: Vector2 = ciudad.punto_frente_a(c.x, c.y)
	pedido = {
		"plato": PLATOS[_rng.randi_range(0, PLATOS.size() - 1)],
		"restaurante": rest,
		"cliente": cli,
		"direccion": ciudad.direccion(cli),
	}
	fase = RECOGER
	var recorrido := _manhattan(moto.pos, rest) + _manhattan(rest, cli)
	tiempo_restante = recorrido / VEL_PROMEDIO + TIEMPO_EXTRA


func _manhattan(a: Vector2, b: Vector2) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y)


func _al_estrellarse(mensaje: String) -> void:
	terminada = true
	evento.emit("estrellado")
	terminada_por.emit(mensaje)
