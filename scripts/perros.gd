extends RefCounted
## Perros callejeros que se atraviesan en la vía (F4, D27). Pocos, por delante de la moto, cruzan de
## andén a andén. Pegarles a toda mata a la moto («el perro sobrevivió»); despacio, salen corriendo.

const MAX := 2
const ESPERA := Vector2(8.0, 18.0)       # s entre uno y el siguiente
const DISTANCIA := Vector2(35.0, 90.0)   # m por delante de la moto donde aparece
const VEL := 2.6                         # m/s trotando
const VEL_HUYE := 7.0                    # m/s después del susto
const RADIO := 0.35                      # m de medio cuerpo para el choque
const LEJOS := 200.0
const RAZAS := 3                         # filas de perros.png
const CRUZA := "cruza"
const HUYE := "huye"

var ciudad
var lista: Array[Dictionary] = []
var aparecidos := 0
var MAX_ACTIVOS := MAX # las pruebas lo ponen en 0 para dejar solo los que ponen a mano
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(semilla := 1, p_ciudad = null) -> void:
	_rng.seed = semilla * 13 + 1
	ciudad = p_ciudad
	_t = _rng.randf_range(ESPERA.x * 0.5, ESPERA.y * 0.5)


func advance(delta: float, centro: Vector2, dir: Vector2) -> void:
	for k in range(lista.size() - 1, -1, -1):
		var d: Dictionary = lista[k]
		var v := VEL_HUYE if d.estado == HUYE else VEL
		d.pos += d.dir * v * delta
		d.andado += v * delta
		d.t += delta
		var fin: bool = d.andado > d.cruzar if d.estado == CRUZA else d.t > 3.0
		if fin or d.pos.distance_to(centro) > LEJOS:
			lista.remove_at(k)
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(ESPERA.x, ESPERA.y)
		if lista.size() < mini(MAX_ACTIVOS, MAX):
			_aparecer(centro, dir)


## Pone un perro en pos cruzando la vía que va en la dirección dir_via (de lado, atravesado).
func poner(pos: Vector2, dir_via: Vector2, hacia := 1.0) -> Dictionary:
	var eje := _eje(dir_via)
	var d := {"pos": pos, "dir": eje.orthogonal() * signf(hacia), "estado": CRUZA, "andado": 0.0,
		"t": 0.0, "raza": _rng.randi_range(0, RAZAS - 1), "cruzar": ciudad.CALLE + 4.0, "casi": false}
	lista.append(d)
	aparecidos += 1
	return d


## El perro que toca a quien está en p con ese radio, o {}.
func tocado(p: Vector2, radio: float) -> Dictionary:
	for d in lista:
		if d.estado == CRUZA and p.distance_to(d.pos) < radio + RADIO:
			return d
	return {}


## El perro se asusta y sale corriendo hacia donde iba la moto, de lado.
func espantar(d: Dictionary, dir_moto: Vector2) -> void:
	d.estado = HUYE
	d.t = 0.0
	var lado: Vector2 = _eje(dir_moto).orthogonal()
	d.dir = lado if lado.dot(d.dir) >= 0.0 else -lado


func _eje(v: Vector2) -> Vector2:
	return Vector2(signf(v.x), 0.0) if absf(v.x) >= absf(v.y) else Vector2(0.0, signf(v.y))


## Aparece en el borde de la vía por donde va la moto, más adelante, listo para cruzarla.
func _aparecer(centro: Vector2, dir: Vector2) -> void:
	var eje := _eje(dir)
	var q := centro + eje * _rng.randf_range(DISTANCIA.x, DISTANCIA.y)
	# El centro de esa vía: el cruce más cercano en el eje de lado.
	var lado := eje.orthogonal()
	var i: int = clampi(ciudad._indice(ciudad.inicio_x, q.x) + 1, 0, ciudad.N_ANCHO)
	var j: int = clampi(ciudad._indice(ciudad.inicio_y, q.y) + 1, 0, ciudad.N_LARGO)
	var c: Vector2 = ciudad.cruce(i, j)
	var c2: Vector2 = ciudad.cruce(maxi(i - 1, 0), maxi(j - 1, 0))
	var via := c if absf((c - q).dot(lado)) < absf((c2 - q).dot(lado)) else c2
	var hacia := 1.0 if _rng.randf() < 0.5 else -1.0
	var inicio: Vector2 = q + lado * ((via - q).dot(lado) - hacia * (ciudad.CALLE / 2.0 + 1.5))
	if ciudad.distancia_anden(q + lado * (via - q).dot(lado)) < 2.0:
		return # justo en un cruce raro o fuera de la ciudad: otro día
	var d := poner(inicio, eje, hacia)
	d.cruzar = ciudad.CALLE + 3.0
