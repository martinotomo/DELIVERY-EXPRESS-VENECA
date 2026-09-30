extends RefCounted
## La ciudad, tipo Bogotá pero más pequeña: 40 cuadras de ancho (carreras) por 80 de largo
## (calles), con cuadras de tamaños distintos para que no se vea cuadriculada.
## Plano en metros: y hacia el norte y x hacia el occidente (como en Bogotá, las carreras se numeran
## desde los cerros orientales, que quedan en x = 0). Cada cuadra incluye su andén.
## Zonas (DISENO §6, D26): barrio de casas, centro viejo, industrial de bodegas al occidente y la
## zona rica de torres de vidrio al nororiente, contra los cerros.

const N_ANCHO := 40
const N_LARGO := 80
const CALLE := 12.0 # ancho de la calzada entre andenes
const ANDEN := 3.0  # franja de andén dentro de cada cuadra

var anchos: Array[float] = []
var largos: Array[float] = []
var inicio_x := PackedFloat64Array()
var inicio_y := PackedFloat64Array()
var parques := {}                  # Vector2i -> true
var alturas := PackedFloat32Array() # por cuadra, índice j * N_ANCHO + i
var zonas := PackedStringArray()     # por cuadra, mismo índice
var fachadas := PackedStringArray()  # tipo de edificio por cuadra ("parque" si es parque)

## Por zona: probabilidad de parque y [probabilidad, fachada, altura mínima, altura máxima] por tipo.
const ZONAS := {
	"barrio": {"parque": 0.08, "tipos": [[0.7, "casa", 6.0, 10.0], [1.0, "ladrillo", 10.0, 16.0]]},
	"centro": {"parque": 0.05, "tipos": [[0.4, "ladrillo", 12.0, 20.0], [0.9, "concreto", 20.0, 32.0], [1.0, "vidrio", 32.0, 45.0]]},
	"industrial": {"parque": 0.03, "tipos": [[0.75, "bodega", 7.0, 11.0], [1.0, "concreto", 10.0, 16.0]]},
	"rica": {"parque": 0.14, "tipos": [[0.6, "vidrio", 30.0, 60.0], [1.0, "concreto", 18.0, 32.0]]},
}
const NOMBRES_ZONA := {"barrio": "Barrio", "centro": "Centro", "industrial": "Zona Industrial", "rica": "El Alto"}


func _init(semilla := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	anchos = _tamanos(rng, N_ANCHO)
	largos = _tamanos(rng, N_LARGO)
	inicio_x = _inicios(anchos)
	inicio_y = _inicios(largos)
	_repartir_zonas(rng)
	for j in N_LARGO:
		for i in N_ANCHO:
			var z: Dictionary = ZONAS[zonas[j * N_ANCHO + i]]
			var parque: bool = rng.randf() < z.parque
			var d := rng.randf()
			for tipo in z.tipos:
				if d < tipo[0]:
					alturas.append(rng.randf_range(tipo[2], tipo[3]))
					fachadas.append("parque" if parque else tipo[1])
					break
			if parque:
				parques[Vector2i(i, j)] = true


## Bordes de zona que culebrean (caminata al azar de ±1 cuadra) para que no sean rectángulos.
func _borde(rng: RandomNumberGenerator, n: int, base: int, juego: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	var v := base
	for k in n:
		v = clampi(v + rng.randi_range(-1, 1), base - juego, base + juego)
		r.append(v)
	return r


func _repartir_zonas(rng: RandomNumberGenerator) -> void:
	var rica_i := _borde(rng, N_LARGO, 9, 2)     # por calle j: hasta qué carrera llega la zona rica
	var rica_j := _borde(rng, N_ANCHO, 52, 3)    # por carrera i: desde qué calle empieza
	var centro_i := _borde(rng, N_LARGO, 11, 2)
	var centro_sur := _borde(rng, N_ANCHO, 24, 2)
	var centro_norte := _borde(rng, N_ANCHO, 44, 2)
	var ind_i := _borde(rng, N_LARGO, 29, 2)
	var ind_j := _borde(rng, N_ANCHO, 45, 3)
	for j in N_LARGO:
		for i in N_ANCHO:
			var z := "barrio"
			if i < rica_i[j] and j >= rica_j[i]:
				z = "rica"
			elif i < centro_i[j] and j >= centro_sur[i] and j <= centro_norte[i]:
				z = "centro"
			elif i > ind_i[j] and j < ind_j[i]:
				z = "industrial"
			zonas.append(z)


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


## "barrio", "centro", "industrial" o "rica" (fuera de la ciudad, "barrio").
func zona(i: int, j: int) -> String:
	if not _existe(Vector2i(i, j)):
		return "barrio"
	return zonas[j * N_ANCHO + i]


## Qué edificio tiene la cuadra: "casa", "ladrillo", "concreto", "vidrio", "bodega" o "parque".
func fachada(i: int, j: int) -> String:
	return fachadas[j * N_ANCHO + i]


func nombre_zona(z: String) -> String:
	return TranslationServer.translate(NOMBRES_ZONA.get(z, "")) if NOMBRES_ZONA.has(z) else ""


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


## Desde un punto de calle, los dos cruces a los extremos de su tramo: {"via": "calle"/"carrera",
## "k": índice de la vía, "cruces": [Vector2i, Vector2i]}.
func _tramo(p: Vector2) -> Dictionary:
	var i := _via_cercana(inicio_x, anchos, p.x)
	var j := _via_cercana(inicio_y, largos, p.y)
	if absf(_centro_via(inicio_y, largos, j) - p.y) <= CALLE / 2.0:
		var bi := clampi(_indice(inicio_x, p.x), 0, N_ANCHO - 1)
		if absf(_centro_via(inicio_x, anchos, i) - p.x) <= CALLE / 2.0:
			return {"via": "calle", "k": j, "cruces": [Vector2i(i, j), Vector2i(i, j)]}
		return {"via": "calle", "k": j, "cruces": [Vector2i(bi, j), Vector2i(bi + 1, j)]}
	var bj := clampi(_indice(inicio_y, p.y), 0, N_LARGO - 1)
	return {"via": "carrera", "k": i, "cruces": [Vector2i(i, bj), Vector2i(i, bj + 1)]}


## Ruta más corta por calles de a hasta b (los dos en la calle), para el minimapa: sale por uno de
## los dos extremos de su tramo, va en L por la cuadrícula y entra por uno de los extremos del de b.
## Se recalcula cada vez desde donde esté la moto.
func ruta(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ta := _tramo(a)
	var tb := _tramo(b)
	var puntos: Array[Vector2] = []
	if ta.via == tb.via and ta.k == tb.k and ta.cruces == tb.cruces:
		puntos = [a, b] # mismo tramo: derecho
	else:
		var mejor := INF
		for ca in ta.cruces:
			for cb in tb.cruces:
				var pa := cruce(ca.x, ca.y)
				var pb := cruce(cb.x, cb.y)
				var codo := cruce(cb.x, ca.y)
				var largo := a.distance_to(pa) + pa.distance_to(codo) + codo.distance_to(pb) + pb.distance_to(b)
				if largo < mejor:
					mejor = largo
					puntos = [a, pa, codo, pb, b]
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


# --- cebras (Tomás, 30/09: los peatones cruzan por las cebras de las esquinas) --------------

const CEBRA := 3.0 # ancho de la cebra: el mismo del andén, que la cebra continúa por la calzada
const _LADOS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Las cebras de la esquina (i, j): una por cada tramo de vía que sale del cruce con andén a los dos
## lados. Cada una: {centro, cruza (hacia dónde la atraviesa el peatón), largo (el ancho de la calle)}.
func cebras(i: int, j: int) -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	var c := cruce(i, j)
	for lado in _LADOS:
		# Las dos cuadras que quedan a lado y lado de la cebra.
		var a: Vector2i
		var b: Vector2i
		if lado.x != 0:
			var ci := i if lado.x > 0 else i - 1
			a = Vector2i(ci, j - 1)
			b = Vector2i(ci, j)
		else:
			var cj := j if lado.y > 0 else j - 1
			a = Vector2i(i - 1, cj)
			b = Vector2i(i, cj)
		if not (_existe(a) and _existe(b)):
			continue
		r.append({
			"centro": c + Vector2(lado) * (CALLE / 2.0 + CEBRA / 2.0),
			"cruza": Vector2(absf(lado.y), absf(lado.x)),
			"largo": CALLE,
		})
	return r


func _existe(q: Vector2i) -> bool:
	return q.x >= 0 and q.y >= 0 and q.x < N_ANCHO and q.y < N_LARGO


## El rectángulo que pinta una cebra en el piso.
static func rect_cebra(cb: Dictionary) -> Rect2:
	var cruza: Vector2 = cb.cruza
	var tam: Vector2 = cruza * float(cb.largo) + Vector2(cruza.y, cruza.x) * CEBRA
	return Rect2(cb.centro - tam / 2.0, tam)


## ¿El punto p está sobre una cebra?
func en_cebra(p: Vector2) -> bool:
	var i := _via_cercana(inicio_x, anchos, p.x)
	var j := _via_cercana(inicio_y, largos, p.y)
	for cb in cebras(i, j):
		if rect_cebra(cb).grow(0.01).has_point(p):
			return true
	return false


# --- nomenclatura (F3): placas de las esquinas, ubicación en el HUD y mapa completo ----------

const CADA_AVENIDA := 6 # cada sexta calle y sexta carrera es avenida (placa verde, más ancha en el mapa)


## tipo: "calle" (vía k a lo largo de x, k de 0..N_LARGO) o "carrera" (vía k a lo largo de y, 0..N_ANCHO).
func es_avenida(tipo: String, k: int) -> bool:
	var n := N_LARGO if tipo == "calle" else N_ANCHO
	return k > 0 and k < n and k % CADA_AVENIDA == 0


## "Cl 42", "Kr 21", "Av Cl 7": como en las placas de Bogotá.
func nombre_via(tipo: String, k: int) -> String:
	var r := "%s %d" % ["Cl" if tipo == "calle" else "Kr", k + 1]
	return "Av " + r if es_avenida(tipo, k) else r


## Por dónde va: la vía en la que está y la vía cruzada más cercana («Cl 42 · Kr 21»).
func ubicacion(p: Vector2) -> String:
	var i := _via_cercana(inicio_x, anchos, p.x)
	var j := _via_cercana(inicio_y, largos, p.y)
	if absf(_centro_via(inicio_y, largos, j) - p.y) <= CALLE / 2.0:
		return "%s · %s" % [nombre_via("calle", j), nombre_via("carrera", i)]
	return "%s · %s" % [nombre_via("carrera", i), nombre_via("calle", j)]


## Zona de la cuadra que hay en p (o la más cercana, si p está en la calle).
func zona_en(p: Vector2) -> String:
	var i := clampi(_indice(inicio_x, p.x), 0, N_ANCHO - 1)
	var j := clampi(_indice(inicio_y, p.y), 0, N_LARGO - 1)
	return zona(i, j)
