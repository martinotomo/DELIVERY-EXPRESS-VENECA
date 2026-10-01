extends RefCounted
## Tráfico de la ciudad (F3, DISENO §6): carros, taxis, buses y camiones que van derecho por su
## carril, paran en los semáforos en rojo, hacen fila y frenan si la moto se les atraviesa.
## Solo existen cerca de la moto (como la gente de los andenes): los que quedan lejos reaparecen.
## Chocar con uno no mata: frenazo en seco (lo decide partida.gd).
## Sin escenas: advance(delta, donde_esta_la_moto, hacia_donde_va).

const MAX := 14                        # a la vez
const CERCA := Vector2(35.0, 170.0)    # m de la moto donde aparecen (la niebla tapa el «pop»)
const LEJOS := 220.0                   # m: más lejos, reaparece
const ADELANTE := 0.75                 # fracción que aparece por donde va la moto
const CARRIL := 3.0                    # m a la derecha del centro de la vía (la calzada mide 12)
const ACEL := 2.5                      # m/s² arrancando
const FRENO := 6.0                     # m/s² frenando
const HUECO := 2.5                     # m que dejan al de adelante (o a la moto) al parar
const MOTO_LARGO := 2.0
const MOTO_ANCHO := 1.8                # m a cada lado del carril en que la moto «estorba»

## Medidas (m) y velocidad (m/s). fila y hoja: dónde está su dibujo (tools/gen_vehiculos.py).
const TIPOS := {
	"taxi": {"largo": 4.0, "ancho": 1.7, "vel": Vector2(9.0, 12.5), "hoja": "vehiculos", "fila": 0},
	"carro": {"largo": 4.4, "ancho": 1.8, "vel": Vector2(8.0, 11.5), "hoja": "vehiculos", "fila": 1},
	"carro_rojo": {"largo": 4.3, "ancho": 1.8, "vel": Vector2(8.0, 11.5), "hoja": "vehiculos", "fila": 2},
	"bus": {"largo": 11.0, "ancho": 2.5, "vel": Vector2(7.0, 9.0), "hoja": "vehiculos_grandes", "fila": 0},
	"camion": {"largo": 8.0, "ancho": 2.4, "vel": Vector2(6.5, 8.5), "hoja": "vehiculos_grandes", "fila": 1},
}
## Qué sale en cada zona (pesos relativos).
const MEZCLAS := {
	"barrio": {"taxi": 3.0, "carro": 3.0, "carro_rojo": 2.0, "bus": 1.0, "camion": 0.5},
	"centro": {"taxi": 4.0, "carro": 2.0, "carro_rojo": 1.0, "bus": 3.0, "camion": 0.5},
	"industrial": {"taxi": 1.0, "carro": 1.5, "carro_rojo": 1.0, "bus": 0.5, "camion": 4.0},
	"rica": {"taxi": 2.0, "carro": 3.0, "carro_rojo": 3.0, "bus": 0.5, "camion": 0.3},
}

var ciudad
var transito
var MAX_ACTIVOS := MAX # las pruebas lo ponen en 0 para dejar solo los que ponen a mano
## Cada uno: {id, tipo, pos, dir (eje, unitario), via (Vector2i: un cruce de su vía), vel, vmax, largo, ancho}.
var lista: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _siguiente_id := 0


func _init(semilla := 1, p_ciudad = null, p_transito = null) -> void:
	_rng.seed = semilla * 3571 + 11
	ciudad = p_ciudad
	transito = p_transito


func mezcla(zona: String) -> Dictionary:
	return MEZCLAS.get(zona, MEZCLAS.barrio)


func advance(delta: float, moto_pos: Vector2, moto_dir := Vector2.ZERO) -> void:
	if ciudad == null:
		return
	for v in lista.duplicate():
		if v.pos.distance_to(moto_pos) > LEJOS or _fuera(v.pos):
			lista.erase(v)
	var intentos := 0
	while lista.size() < mini(MAX_ACTIVOS, MAX) and intentos < 60:
		intentos += 1
		_aparecer(moto_pos, moto_dir)
	for v in lista:
		var meta: float = minf(v.vmax, _limite(v, moto_pos))
		if v.vel < meta:
			v.vel = minf(v.vel + ACEL * delta, meta)
		else:
			v.vel = maxf(v.vel - FRENO * delta, meta)
		v.pos += v.dir * v.vel * delta


func _fuera(p: Vector2) -> bool:
	var tam: Vector2 = ciudad.tamano()
	return p.x < 2.0 or p.y < 2.0 or p.x > tam.x - 2.0 or p.y > tam.y - 2.0


## Velocidad a la que puede ir para alcanzar a parar antes del obstáculo más cercano.
func _limite(v: Dictionary, moto_pos: Vector2) -> float:
	var espacio := INF
	var frente: float = v.largo / 2.0
	var der: Vector2 = Vector2(-v.dir.y, v.dir.x)
	# El de adelante en su mismo carril.
	for o in lista:
		if o == v or o.dir != v.dir:
			continue
		var rel: Vector2 = o.pos - v.pos
		if absf(rel.dot(der)) < 1.2:
			var d: float = rel.dot(v.dir) - frente - o.largo / 2.0
			if rel.dot(v.dir) > 0.0:
				espacio = minf(espacio, d)
	# La moto, si está en su carril por delante.
	var rm: Vector2 = moto_pos - v.pos
	if rm.dot(v.dir) > 0.0 and absf(rm.dot(der)) < MOTO_ANCHO + v.ancho / 2.0 - 0.6:
		espacio = minf(espacio, rm.dot(v.dir) - frente - MOTO_LARGO / 2.0)
	# El semáforo del próximo cruce, si no está en verde (en amarillo sigue si ya no alcanza a parar).
	var linea := _hasta_linea(v)
	if linea > -0.5 and linea < 80.0:
		var eje := "x" if v.dir.x != 0.0 else "y"
		var luz: String = transito.luz(eje)
		if luz == "rojo" or (luz == "amarillo" and linea > v.vel * v.vel / (2.0 * FRENO) + 1.0):
			espacio = minf(espacio, linea + HUECO - 0.5)
	if espacio == INF:
		return INF
	return sqrt(2.0 * FRENO * maxf(espacio - HUECO, 0.0))


## Metros desde el frente del vehículo hasta la línea de pare del próximo cruce con semáforo
## (antes de la cebra). INF si no hay ninguno cerca.
func _hasta_linea(v: Dictionary) -> float:
	var por_x: bool = v.dir.x != 0.0
	var s: float = v.pos.dot(v.dir) + v.largo / 2.0
	var mejor := INF
	var n: int = ciudad.N_ANCHO if por_x else ciudad.N_LARGO
	var cerca: int = ciudad._via_cercana(ciudad.inicio_x if por_x else ciudad.inicio_y, ciudad.anchos if por_x else ciudad.largos, v.pos.x if por_x else v.pos.y)
	for k in range(maxi(cerca - 2, 0), mini(cerca + 3, n + 1)):
		var cr := Vector2i(k, v.via.y) if por_x else Vector2i(v.via.x, k)
		if not transito.tiene_semaforo(cr.x, cr.y):
			continue
		var d: float = ciudad.cruce(cr.x, cr.y).dot(v.dir) - ciudad.CALLE / 2.0 - ciudad.CEBRA - s
		if d > -0.5 and d < mejor:
			mejor = d
	return mejor


## Pone un vehículo en la vía que pasa por el cruce `cruce`, yendo en `dir`, `antes` metros antes
## del centro del cruce (negativo: ya pasado). Devuelve su diccionario.
func poner(tipo: String, cruce: Vector2i, dir: Vector2, antes: float) -> Dictionary:
	var datos: Dictionary = TIPOS[tipo]
	var der := Vector2(-dir.y, dir.x)
	var v := {
		"id": _siguiente_id,
		"tipo": tipo,
		"pos": ciudad.cruce(cruce.x, cruce.y) - dir * antes + der * CARRIL,
		"dir": dir,
		"via": cruce,
		"vel": 0.0,
		"vmax": _rng.randf_range(datos.vel.x, datos.vel.y),
		"largo": datos.largo,
		"ancho": datos.ancho,
	}
	_siguiente_id += 1
	v.vel = v.vmax
	lista.append(v)
	return v


func _aparecer(centro: Vector2, dir: Vector2) -> void:
	var adelante := dir != Vector2.ZERO and _rng.randf() < ADELANTE
	var a := dir.angle() + _rng.randf_range(-0.7, 0.7) if adelante else _rng.randf() * TAU
	var q := centro + Vector2(cos(a), sin(a)) * _rng.randf_range(CERCA.x, CERCA.y)
	if _fuera(q):
		return
	var i: int = ciudad._via_cercana(ciudad.inicio_x, ciudad.anchos, q.x)
	var j: int = ciudad._via_cercana(ciudad.inicio_y, ciudad.largos, q.y)
	var c: Vector2 = ciudad.cruce(i, j)
	var por_x := absf(q.y - c.y) < absf(q.x - c.x) # más cerca de la calle j: va a lo largo de x
	var d := (Vector2.RIGHT if por_x else Vector2.DOWN) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var antes: float = (c - q).dot(d)
	var tipo := _sortear(ciudad.zona_en(q))
	var v := poner(tipo, Vector2i(i, j), d, antes)
	# Que no aparezca encima de otro ni pegado a la moto.
	var mal: bool = v.pos.distance_to(centro) < CERCA.x * 0.8 or _fuera(v.pos)
	for o in lista:
		if o != v and o.pos.distance_to(v.pos) < 14.0:
			mal = true
	if mal:
		lista.erase(v)


func _sortear(zona: String) -> String:
	var m := mezcla(zona)
	var total := 0.0
	for k in m:
		total += m[k]
	var tira := _rng.randf() * total
	for k in m:
		tira -= m[k]
		if tira <= 0.0:
			return k
	return "carro"


## El id del vehículo que toca el punto p (con un margen `radio`), o -1.
func chocado(p: Vector2, radio: float) -> int:
	for v in lista:
		var rel: Vector2 = p - v.pos
		var der: Vector2 = Vector2(-v.dir.y, v.dir.x)
		if absf(rel.dot(v.dir)) <= v.largo / 2.0 + radio and absf(rel.dot(der)) <= v.ancho / 2.0 + radio:
			return v.id
	return -1
