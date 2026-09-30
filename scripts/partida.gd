extends RefCounted
## Una jornada de domiciliario: recoger, entregar, otro pedido... hasta que la fe supere al agarre.

signal evento(nombre: String)       # recogido, entregado, cancelado, casi, golpe, estrellado, fundido, reparado, charco, lluvia, escampo, atropello, grito
signal terminada_por(mensaje: String)
signal pagado(pesos: int)           # al entregar: tarifa más propina por el tiempo que sobró

const CIUDAD := preload("res://scripts/ciudad.gd")
const MOTO := preload("res://scripts/moto_logic.gd")
const MOTOS := preload("res://scripts/motos.gd")
const CICLO := preload("res://scripts/ciclo_dia.gd")
const CLIMA := preload("res://scripts/clima.gd")
const PEATONES := preload("res://scripts/peatones.gd")

const RECOGER := "recoger"
const ENTREGAR := "entregar"
const RADIO_LLEGADA := 7.0
const VEL_PARADA := 3.0      # m/s: hay que parar para recoger o entregar
const VEL_PROMEDIO := 8.0    # m/s con que se calcula el tiempo del pedido
const TIEMPO_EXTRA := 25.0
const TARIFA := 5000         # pesos por pedido entregado
const FRENO_CHARCO := 0.15   # cada charco quita el 15 % de la velocidad
const PROPINA_POR_S := 50    # pesos por cada segundo que sobró

const PLATOS := ["Bandeja paisa", "Ajiaco", "Hamburguesa doble", "Salchipapa", "Empanadas x10",
	"Arepa de choclo", "Pizza familiar", "Changua", "Tamal con chocolate", "Perro caliente"]

var ciudad
var moto
var reloj
var clima
var peatones
var multado := false     # atropelló a alguien en este pedido: se queda sin propina
var _charco := -1            # el charco que se está pisando (frena una sola vez al entrar)
var pedido := {}
var fase := RECOGER
var tiempo_restante := 0.0
var entregados := 0
var cancelados := 0
var ganado := 0              # pesos de esta jornada (ya quedan guardados al cobrarlos)
var terminada := false
var _rng := RandomNumberGenerator.new()


func _init(semilla := 1, datos_moto: Dictionary = {}) -> void:
	_rng.seed = semilla
	ciudad = CIUDAD.new(semilla)
	reloj = CICLO.new()
	clima = CLIMA.new(semilla, ciudad)
	clima.empezo_lluvia.connect(func(): evento.emit("lluvia"))
	clima.paro_lluvia.connect(func(): evento.emit("escampo"))
	peatones = PEATONES.new(semilla, ciudad)
	peatones.levantado.connect(func(): evento.emit("grito"))
	moto = MOTO.new()
	var datos := datos_moto if not datos_moto.is_empty() else MOTOS.get_moto(MOTOS.MOTO_INICIAL)
	moto.setup(datos, ciudad, ciudad.cruce(20, 40), 0.0)
	moto.estrellado.connect(_al_estrellarse)
	moto.casi.connect(func(_tipo): evento.emit("casi"))
	moto.golpe.connect(func(): evento.emit("golpe"))
	moto.fundido.connect(func(): evento.emit("fundido"))
	moto.reparado.connect(func(): evento.emit("reparado"))
	_nuevo_pedido()


func advance(delta: float, acelerar: bool, frenar: bool, giro: float) -> void:
	if terminada:
		return
	moto.advance(delta, acelerar, frenar, giro)
	if terminada:
		return
	reloj.advance(delta)
	clima.advance(delta, moto.pos)
	_revisar_charco()
	peatones.advance(delta, moto.pos, moto.direccion())
	_revisar_atropello()
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
		var pago := pago_por(0.0 if multado else tiempo_restante, clima.lloviendo())
		ganado += pago
		evento.emit("entregado")
		pagado.emit(pago)
		_nuevo_pedido()


## Lo que paga un pedido según los segundos que sobraron, redondeado a cientos.
## Con lluvia paga el bono del clima (+30 %).
static func pago_por(segundos_sobrantes: float, lluvia := false) -> int:
	var base := TARIFA + int(round(maxf(segundos_sobrantes, 0.0) * PROPINA_POR_S / 100.0)) * 100
	return int(round(base * (1.0 + CLIMA.BONO) / 100.0)) * 100 if lluvia else base


## Atropellar a un peatón: frenazo en seco y el pedido se queda sin propina (solo la tarifa).
func _revisar_atropello() -> void:
	if peatones.atropellar(moto.pos, moto.vel) == -1:
		return
	moto.vel = 0.0
	multado = true
	evento.emit("atropello")


## Pisar un charco frena un poco, una vez por charco.
func _revisar_charco() -> void:
	var k: int = clima.charco_en(moto.pos)
	if k != -1 and k != _charco and moto.vel > 2.0:
		moto.vel *= 1.0 - FRENO_CHARCO
		evento.emit("charco")
	_charco = k


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
	multado = false
	var recorrido := _manhattan(moto.pos, rest) + _manhattan(rest, cli)
	tiempo_restante = recorrido / VEL_PROMEDIO + TIEMPO_EXTRA


func _manhattan(a: Vector2, b: Vector2) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y)


func _al_estrellarse(mensaje: String) -> void:
	terminada = true
	evento.emit("estrellado")
	terminada_por.emit(mensaje)
