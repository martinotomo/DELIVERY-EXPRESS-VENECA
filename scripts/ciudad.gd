extends RefCounted
## La ciudad, tipo Bogotá pero más pequeña: 40 cuadras de ancho (carreras) por 80 de largo
## (calles), con cuadras de tamaños distintos para que no se vea cuadriculada.
## Plano en metros: x hacia el oriente, y hacia el norte. Cada cuadra incluye su andén.

const N_ANCHO := 40
const N_LARGO := 80
const CALLE := 12.0 # ancho de la calzada entre andenes
const ANDEN := 3.0  # franja de andén dentro de cada cuadra
const PROB_PARQUE := 0.08

var anchos: Array[float] = []
var largos: Array[float] = []
var inicio_x := PackedFloat64Array()
var inicio_y := PackedFloat64Array()
var parques := {}                  # Vector2i -> true
var alturas := PackedFloat32Array() # por cuadra, índice j * N_ANCHO + i


func _init(semilla := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	anchos = _tamanos(rng, N_ANCHO)
	largos = _tamanos(rng, N_LARGO)
	inicio_x = _inicios(anchos)
	inicio_y = _inicios(largos)
	for j in N_LARGO:
		for i in N_ANCHO:
			if rng.randf() < PROB_PARQUE:
				parques[Vector2i(i, j)] = true
			alturas.append(rng.randf_range(6.0, 12.0) if rng.randf() < 0.6 else rng.randf_range(12.0, 45.0))


## Mezcla de cuadras cortas, medianas y largas: 0,6 a 1,6 veces la cuadra normal de 100 m (DISENO §6).
func _tamanos(rng: RandomNumberGenerator, n: int) -> Array[float]:
	var r: Array[float] = []
	for k in n:
		var d := rng.randf()
		var v := rng.randf_range(60.0, 85.0) if d < 0.35 else (rng.randf_range(85.0, 120.0) if d < 0.8 else rng.randf_range(120.0, 160.0))
		r.append(float(roundi(v)))
	return r


func _inicios(tams: Array[float]) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	var x := CALLE
	for t in tams:
		r.append(x)
		x += t + CALLE
	return r


func tamano() -> Vector2:
	return Vector2(inicio_x[N_ANCHO - 1] + anchos[N_ANCHO - 1] + CALLE,
		inicio_y[N_LARGO - 1] + largos[N_LARGO - 1] + CALLE)


func cuadra(i: int, j: int) -> Rect2:
	return Rect2(inicio_x[i], inicio_y[j], anchos[i], largos[j])


func es_parque(i: int, j: int) -> bool:
	return parques.has(Vector2i(i, j))


func altura(i: int, j: int) -> float:
	return alturas[j * N_ANCHO + i]


## Centro de la carrera i (0..40) cruzando con la calle j (0..80).
func cruce(i: int, j: int) -> Vector2:
	return Vector2(_centro_via(inicio_x, anchos, i), _centro_via(inicio_y, largos, j))


func _centro_via(inicios: PackedFloat64Array, tams: Array[float], k: int) -> float:
	if k < inicios.size():
		return inicios[k] - CALLE / 2.0
	return inicios[k - 1] + tams[k - 1] + CALLE / 2.0


## Punto en la calle, frente al lado sur de la cuadra (i, j): donde se para a recoger o entregar.
func punto_frente_a(i: int, j: int) -> Vector2:
	var r := cuadra(i, j)
	return Vector2(r.get_center().x, r.position.y - 2.5)


## Índice de la última cuadra que empieza antes de v, o -1.
func _indice(inicios: PackedFloat64Array, v: float) -> int:
	return inicios.bsearch(v, true) - 1 if v >= inicios[0] else -1


## Distancia al andén o muro más cercano (0 si está encima o fuera de la ciudad).
func distancia_anden(p: Vector2) -> float:
	var tam := tamano()
	if p.x <= 0.0 or p.y <= 0.0 or p.x >= tam.x or p.y >= tam.y:
		return 0.0
	var d: float = minf(minf(p.x, tam.x - p.x), minf(p.y, tam.y - p.y))
	var ci := _indice(inicio_x, p.x)
	var cj := _indice(inicio_y, p.y)
	for di in range(-1, 2):
		for dj in range(-1, 2):
			var i := ci + di
			var j := cj + dj
			if i < 0 or j < 0 or i >= N_ANCHO or j >= N_LARGO:
				continue
			var r := cuadra(i, j)
			var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
			var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
			d = minf(d, sqrt(dx * dx + dy * dy))
	return d


func en_anden(p: Vector2, radio: float) -> bool:
	return distancia_anden(p) <= radio


## Vía más cercana en un eje: índice k de 0..n tal que el centro de esa vía está más cerca de v.
func _via_cercana(inicios: PackedFloat64Array, tams: Array[float], v: float) -> int:
	var mejor := 0
	for k in inicios.size() + 1:
		if absf(_centro_via(inicios, tams, k) - v) < absf(_centro_via(inicios, tams, mejor) - v):
			mejor = k
	return mejor


## Desde un punto de calle, cómo entrar a la red de cruces: [punto sobre el eje de su vía, cruce (i, j)].
func _enganche(p: Vector2) -> Array:
	var i := _via_cercana(inicio_x, anchos, p.x)
	var j := _via_cercana(inicio_y, largos, p.y)
	var en_calle: bool = absf(_centro_via(inicio_y, largos, j) - p.y) <= CALLE / 2.0
	if en_calle:
		return [Vector2(p.x, _centro_via(inicio_y, largos, j)), Vector2i(i, j)]
	return [Vector2(_centro_via(inicio_x, anchos, i), p.y), Vector2i(i, j)]


## Ruta por calles de a hasta b (los dos en la calle), para el minimapa.
## En una cuadrícula completa basta ir por una calle y luego por una carrera.
func ruta(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ea := _enganche(a)
	var eb := _enganche(b)
	var na: Vector2i = ea[1]
	var nb: Vector2i = eb[1]
	var puntos: Array[Vector2] = [a, ea[0], cruce(na.x, na.y), cruce(nb.x, na.y), cruce(nb.x, nb.y), eb[0], b]
	var r := PackedVector2Array()
	for q in puntos:
		if r.is_empty() or r[r.size() - 1].distance_to(q) > 0.01:
			r.append(q)
	return r


## Dirección al estilo bogotano: «Calle N # M-xx».
func direccion(p: Vector2) -> String:
	var j := _via_cercana(inicio_y, largos, p.y)
	var i: int = maxi(_indice(inicio_x, p.x), 0)
	var r := cuadra(i, 0)
	var placa := clampi(int((p.x - r.position.x) / r.size.x * 100.0), 1, 99)
	return "Calle %d # %d-%02d" % [j + 1, i + 1, placa]
