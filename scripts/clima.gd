extends RefCounted
## La lluvia (Tomás, 30/09): llueve rara vez; mientras llueve cada pedido paga un bono y en la
## calle se van formando charcos que frenan un poco al pisarlos. Al escampar se secan despacio.
## Sin escenas: advance(delta, donde_esta_la_moto) y una prueba lo lleva a cualquier momento.

signal empezo_lluvia
signal paro_lluvia

const PRIMERA := Vector2(360.0, 720.0)    # s de juego antes del primer aguacero (6 a 12 min)
const ENTRE := Vector2(720.0, 1200.0)     # s secos entre aguaceros (12 a 20 min)
const DURA := Vector2(60.0, 120.0)        # s que llueve (1 a 2 min)
const SUBIDA := 8.0                       # s en que la lluvia llega a toda (y en que se va)
const MOJAR := 40.0                       # s de lluvia para que el piso quede empapado
const SECAR := 120.0                      # s para secarse del todo al escampar
const BONO := 0.3                         # +30 % por pedido mientras llueve
const MAX_CHARCOS := 60
const RADIO_CHARCOS := 180.0              # m alrededor de la moto donde hay charcos
const RADIO_CHARCO := Vector2(1.5, 3.2)   # m

var ciudad
var intensidad := 0.0    # 0 a 1: cuánto llueve ahora (para el sonido y la imagen)
var humedad := 0.0       # 0 a 1: qué tan mojado está el piso (cuántos charcos hay)
var charcos: Array[Dictionary] = []  # {pos: Vector2, radio: float}
var version := 0         # cambia cada vez que cambian los charcos (para redibujarlos)
var _lloviendo := false
var _t := 0.0            # s que faltan para el próximo cambio (empezar o parar)
var _rng := RandomNumberGenerator.new()


func _init(semilla := 1, p_ciudad = null) -> void:
	_rng.seed = semilla * 7919 + 3
	ciudad = p_ciudad
	_t = _rng.randf_range(PRIMERA.x, PRIMERA.y)


func lloviendo() -> bool:
	return _lloviendo


## Segundos hasta que empiece (si está seco) o pare (si llueve).
func falta() -> float:
	return _t


func empezar_lluvia(duracion := -1.0) -> void:
	_lloviendo = true
	_t = duracion if duracion > 0.0 else _rng.randf_range(DURA.x, DURA.y)
	empezo_lluvia.emit()


func parar_lluvia() -> void:
	_lloviendo = false
	_t = _rng.randf_range(ENTRE.x, ENTRE.y)
	paro_lluvia.emit()


## Para probar sin esperar (tecla F9 en versiones de desarrollo): prende o apaga la lluvia.
func alternar_lluvia() -> void:
	if _lloviendo:
		parar_lluvia()
	else:
		empezar_lluvia()


func advance(delta: float, centro: Vector2) -> void:
	_t -= delta
	if _t <= 0.0:
		if _lloviendo:
			parar_lluvia()
		else:
			empezar_lluvia()
	var meta := 1.0 if _lloviendo else 0.0
	intensidad = move_toward(intensidad, meta, delta / SUBIDA)
	if _lloviendo:
		humedad = minf(humedad + delta * intensidad / MOJAR, 1.0)
	else:
		humedad = maxf(humedad - delta / SECAR, 0.0)
	if ciudad != null:
		_charcos(centro)


## El charco que pisa quien está en p, o -1.
func charco_en(p: Vector2) -> int:
	for k in charcos.size():
		if p.distance_to(charcos[k].pos) < charcos[k].radio:
			return k
	return -1


func _charcos(centro: Vector2) -> void:
	var cambio := false
	# Los que quedaron lejos se reciclan cerca de la moto.
	for k in range(charcos.size() - 1, -1, -1):
		if charcos[k].pos.distance_to(centro) > RADIO_CHARCOS * 1.6:
			charcos.remove_at(k)
			cambio = true
	var meta := int(humedad * MAX_CHARCOS)
	var intentos := 0
	while charcos.size() < meta and intentos < 20:
		intentos += 1
		var c := _nuevo_charco(centro)
		if not c.is_empty():
			charcos.append(c)
			cambio = true
	while charcos.size() > meta:
		charcos.remove_at(_rng.randi_range(0, charcos.size() - 1))
		cambio = true
	if cambio:
		version += 1


## Un charco en la calzada (nunca en el andén), en una vía cerca de la moto.
func _nuevo_charco(centro: Vector2) -> Dictionary:
	# La mitad, en línea recta desde la moto: si va por una vía, caen en esa vía (se ven y se pisan).
	if _rng.randf() < 0.5:
		var ejes := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
		var eje: Vector2 = ejes[_rng.randi_range(0, 3)]
		var q := centro + eje * _rng.randf_range(20.0, RADIO_CHARCOS) + eje.orthogonal() * _rng.randf_range(-3.0, 3.0)
		var rq := _rng.randf_range(RADIO_CHARCO.x, RADIO_CHARCO.y)
		if ciudad.distancia_anden(q) < rq + 0.3:
			return {}
		return {"pos": q, "radio": rq}
	var i0: int = clampi(ciudad._indice(ciudad.inicio_x, centro.x), 0, ciudad.N_ANCHO - 1)
	var j0: int = clampi(ciudad._indice(ciudad.inicio_y, centro.y), 0, ciudad.N_LARGO - 1)
	var i := clampi(i0 + _rng.randi_range(-1, 1), 0, ciudad.N_ANCHO - 1)
	var j := clampi(j0 + _rng.randi_range(-1, 1), 0, ciudad.N_LARGO - 1)
	var a: Vector2 = ciudad.cruce(i, j)
	var horizontal := _rng.randf() < 0.5
	var b: Vector2 = ciudad.cruce(i + 1, j) if horizontal else ciudad.cruce(i, j + 1)
	var p := a.lerp(b, _rng.randf_range(0.15, 0.85))
	var lateral := Vector2(0, 1) if horizontal else Vector2(1, 0)
	p += lateral * _rng.randf_range(-3.5, 3.5)
	var r := _rng.randf_range(RADIO_CHARCO.x, RADIO_CHARCO.y)
	var d := p.distance_to(centro)
	if ciudad.distancia_anden(p) < r + 0.3 or d > RADIO_CHARCOS or d < 15.0: # no aparece debajo
		return {}
	return {"pos": p, "radio": r}
