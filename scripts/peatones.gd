extends RefCounted
## Peatones (Tomás, 30/09): pocos, y de vez en cuando uno cruza la calle por la cebra de una esquina.
## Llegan por el andén, cruzan, y siguen por el andén del otro lado hasta perderse.
## Si la moto atropella a uno: cae (sin sangre, a lo cómico), se levanta, grita y sigue su camino.
## Sin escenas: advance(delta, donde_esta_la_moto, hacia_donde_va).

signal levantado # el atropellado se paró y va a gritarle al domiciliario

const MAX := 3                            # nunca hay más a la vez
const ESPERA := Vector2(7.0, 15.0)        # s entre uno y el siguiente
const DISTANCIA := Vector2(30.0, 140.0)   # m de la moto a la cebra donde aparece
const ADELANTE := 0.75                    # fracción que aparece por donde va la moto (para verlos)
const VEL := 1.3                          # m/s caminando
const VEL_SUSTO := 2.4                    # m/s después del atropello (se va rápido, cojeando)
const ACERA := 5.0                        # m que camina por el andén antes y después de cruzar
const LEJOS := 260.0                      # m: más lejos de la moto, desaparece
const RADIO_GOLPE := 0.9                  # m entre moto y peatón que cuentan como atropello
const VEL_ATROPELLO := 1.5                # m/s: más despacio es un empujoncito, no cuenta
const T_CAIDO := 3.0                      # s en el piso
const T_GRITO := 2.0                      # s parado gritando antes de irse
const ROPAS := 6                          # variantes de ropa del sprite

const CAMINA := "camina"
const CAIDO := "caido"
const GRITA := "grita"

var ciudad
## Cada peatón: {pos, camino: [4 puntos], tramo (a qué punto va), estado, t, ropa, golpeado, andado}.
var lista: Array[Dictionary] = []
var aparecidos := 0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(semilla := 1, p_ciudad = null) -> void:
	_rng.seed = semilla * 104729 + 17
	ciudad = p_ciudad
	_t = _rng.randf_range(3.0, ESPERA.y) # el primero no sale apenas arranca


func advance(delta: float, centro: Vector2, dir: Vector2) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(ESPERA.x, ESPERA.y)
		if lista.size() < MAX and ciudad != null:
			_aparecer(centro, dir)
	for k in range(lista.size() - 1, -1, -1):
		var p := lista[k]
		if _mover(p, delta) or p.pos.distance_to(centro) > LEJOS:
			lista.remove_at(k)


## Pone un peatón a cruzar la cebra cb (de un lado u otro). Lo devuelve para poder moverlo.
func poner_en(cb: Dictionary, al_reves := false) -> Dictionary:
	var cruza: Vector2 = cb.cruza * (-1.0 if al_reves else 1.0)
	var medio: float = float(cb.largo) / 2.0 + 0.6
	var a: Vector2 = cb.centro - cruza * medio
	var b: Vector2 = cb.centro + cruza * medio
	var p := {
		"pos": a - cruza * ACERA,
		"camino": [a - cruza * ACERA, a, b, b + cruza * ACERA],
		"tramo": 1,
		"estado": CAMINA,
		"t": 0.0,
		"ropa": _rng.randi_range(0, ROPAS - 1),
		"golpeado": false,
		"andado": 0.0,
		"dir": cruza,
	}
	lista.append(p)
	aparecidos += 1
	return p


## ¿La moto en pos, a vel, atropella a alguien? Devuelve el índice o -1. Cada peatón, una sola vez.
func atropellar(pos: Vector2, vel: float) -> int:
	if vel < VEL_ATROPELLO:
		return -1
	for k in lista.size():
		var p := lista[k]
		if p.estado == CAMINA and not p.golpeado and pos.distance_to(p.pos) < RADIO_GOLPE:
			p.estado = CAIDO
			p.t = T_CAIDO
			p.golpeado = true
			return k
	return -1


## Mueve un peatón; devuelve true si ya terminó su camino (se va).
func _mover(p: Dictionary, delta: float) -> bool:
	if p.estado == CAIDO:
		p.t -= delta
		if p.t <= 0.0:
			p.estado = GRITA
			p.t = T_GRITO
			levantado.emit()
		return false
	if p.estado == GRITA:
		p.t -= delta
		if p.t <= 0.0:
			p.estado = CAMINA
		return false
	var queda := delta * (VEL_SUSTO if p.golpeado else VEL)
	while queda > 0.0:
		if p.tramo >= p.camino.size():
			return true
		var meta: Vector2 = p.camino[p.tramo]
		var d: float = p.pos.distance_to(meta)
		if d <= queda:
			p.pos = meta
			queda -= d
			p.andado += d
			p.tramo += 1
		else:
			p.dir = (meta - p.pos) / d
			p.pos += p.dir * queda
			p.andado += queda
			queda = 0.0
	return p.tramo >= p.camino.size()


## Escoge una cebra cerca de la moto (casi siempre por delante) donde no haya nadie cruzando.
func _aparecer(centro: Vector2, dir: Vector2) -> void:
	var i0: int = ciudad._via_cercana(ciudad.inicio_x, ciudad.anchos, centro.x)
	var j0: int = ciudad._via_cercana(ciudad.inicio_y, ciudad.largos, centro.y)
	var adelante := _rng.randf() < ADELANTE
	for intento in 16:
		var i := clampi(i0 + _rng.randi_range(-2, 2), 0, ciudad.N_ANCHO)
		var j := clampi(j0 + _rng.randi_range(-2, 2), 0, ciudad.N_LARGO)
		var opciones: Array[Dictionary] = ciudad.cebras(i, j)
		if opciones.is_empty():
			continue
		var cb: Dictionary = opciones[_rng.randi_range(0, opciones.size() - 1)]
		var rel: Vector2 = cb.centro - centro
		var d := rel.length()
		if d < DISTANCIA.x or d > DISTANCIA.y:
			continue
		if adelante and rel.dot(dir) < 0.5 * d:
			continue
		if _ocupada(cb):
			continue
		poner_en(cb, _rng.randf() < 0.5)
		return


func _ocupada(cb: Dictionary) -> bool:
	for p in lista:
		if p.camino[1].distance_to(cb.centro) < float(cb.largo):
			return true
	return false
