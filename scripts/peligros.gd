extends RefCounted
## Huecos y manchas de aceite en la calzada (F4, D27). Son fijos: con la misma semilla quedan siempre
## en el mismo sitio, como en una ciudad de verdad (el hueco de la 42 lleva ahí años). Más huecos en el
## barrio y la zona industrial; El Alto casi no tiene. La partida decide qué pasa al pisarlos.

const RADIO_HUECO := Vector2(0.7, 1.1)  # m
const RADIO_ACEITE := Vector2(1.3, 2.0) # m
## Probabilidad por cada TRAMO metros de vía según la zona.
const PROB := {
	"hueco": {"barrio": 0.22, "centro": 0.1, "industrial": 0.3, "rica": 0.02},
	"aceite": {"barrio": 0.03, "centro": 0.05, "industrial": 0.12, "rica": 0.01},
}
const TRAMO := 60.0 # m de vía por cada sorteo
const CELDA := 50.0 # m: rejilla para buscar rápido los de alrededor

var ciudad
var lista: Array[Dictionary] = [] # {id, tipo, pos, radio, eje (dirección de la vía), marca}
## marca (huecos): 0 rama, 1 cono, 2 y 3 nada (el que nadie avisó). Ver marcas_hueco.png.
var _rejilla := {}


func _init(semilla := 1, p_ciudad = null) -> void:
	ciudad = p_ciudad
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla * 31 + 5
	for j in ciudad.N_LARGO + 1:
		for i in ciudad.N_ANCHO + 1:
			for eje in [Vector2.RIGHT, Vector2.UP]:
				var a: Vector2 = ciudad.cruce(i, j)
				var ni: int = i + (1 if eje == Vector2.RIGHT else 0)
				var nj: int = j + (1 if eje == Vector2.UP else 0)
				if ni > ciudad.N_ANCHO or nj > ciudad.N_LARGO:
					continue
				var b: Vector2 = ciudad.cruce(ni, nj)
				var z: String = ciudad.zona(clampi(i, 0, ciudad.N_ANCHO - 1), clampi(j, 0, ciudad.N_LARGO - 1))
				var tramos := maxi(int(a.distance_to(b) / TRAMO), 1)
				for n in tramos:
					for tipo in PROB:
						if rng.randf() >= float(PROB[tipo][z]):
							continue
						var r: Vector2 = RADIO_HUECO if tipo == "hueco" else RADIO_ACEITE
						var radio := rng.randf_range(r.x, r.y)
						var t := (n + rng.randf_range(0.15, 0.85)) / tramos
						var pos: Vector2 = a.lerp(b, t) + eje.orthogonal() * rng.randf_range(-3.8, 3.8)
						if ciudad.distancia_anden(pos) < radio + 0.3:
							continue
						_agregar({"tipo": tipo, "pos": pos, "radio": radio, "eje": eje, "marca": rng.randi_range(0, 3)})


func _agregar(h: Dictionary) -> void:
	h.id = lista.size()
	lista.append(h)
	var k := _clave(h.pos)
	if not _rejilla.has(k):
		_rejilla[k] = []
	_rejilla[k].append(h)


func _clave(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELDA), floori(p.y / CELDA))


## Los peligros a menos de r metros de p (para dibujarlos).
func cerca(p: Vector2, r: float) -> Array:
	var res := []
	var c0 := _clave(p - Vector2(r, r))
	var c1 := _clave(p + Vector2(r, r))
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			for h in _rejilla.get(Vector2i(cx, cy), []):
				if h.pos.distance_to(p) <= r:
					res.append(h)
	return res


## El peligro que se pisa en p ({} si ninguno).
func en(p: Vector2) -> Dictionary:
	for h in cerca(p, RADIO_ACEITE.y + 0.1):
		if p.distance_to(h.pos) < h.radio:
			return h
	return {}
