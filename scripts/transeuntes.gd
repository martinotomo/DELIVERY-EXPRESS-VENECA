extends RefCounted
## Gente caminando por los andenes (Tomás, 30/09: «NPCs caminando a lo largo de la cuadra»), para que
## la ciudad tenga movimiento. Son de ambiente: van siempre por el andén, dándole la vuelta a su cuadra,
## y la moto no se sube al andén sin estrellarse, así que no hay atropello aparte (el de las cebras
## sigue en peatones.gd). Solo existen cerca de la moto: los que quedan lejos reaparecen alrededor.
## Sin escenas: advance(delta, donde_esta_la_moto, hacia_donde_va).

const MAX := 30                         # a la vez (sprites sueltos: el juego sigue fluido)
const CERCA := Vector2(12.0, 90.0)      # m de la moto donde aparecen
const LEJOS := 120.0                    # m: más lejos, reaparece cerca
const ADELANTE := 0.7                   # fracción que aparece por donde va la moto (para verlos)
const VEL := Vector2(0.9, 1.6)          # m/s caminando
const CARRIL := Vector2(0.9, 2.1)       # m desde el filo del andén (el andén mide 3 m)
const ROPAS := 6

var ciudad
## Cada uno: {i, j, carril (Rect2 de su vuelta), s (m recorridos de la vuelta), sentido (1 o -1),
## vel, ropa, andado, pos, dir}.
var lista: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init(semilla := 1, p_ciudad = null) -> void:
	_rng.seed = semilla * 7727 + 3
	ciudad = p_ciudad


func advance(delta: float, centro: Vector2, dir := Vector2.ZERO) -> void:
	if ciudad == null:
		return
	while lista.size() < MAX:
		if not _aparecer(centro, {}, dir):
			break
	for p in lista:
		if p.pos.distance_to(centro) > LEJOS:
			_aparecer(centro, p, dir)
			continue
		var paso: float = p.vel * delta
		p.s = fposmod(p.s + paso * p.sentido, _perimetro(p.carril))
		p.andado += paso
		var antes: Vector2 = p.pos
		p.pos = punto(p.carril, p.s)
		if p.pos.distance_squared_to(antes) > 1e-6:
			p.dir = (p.pos - antes).normalized()


## Pone a alguien (nuevo, o reusa p) a caminar en una cuadra al azar cerca de centro.
func _aparecer(centro: Vector2, p: Dictionary, dir := Vector2.ZERO) -> bool:
	var adelante := dir != Vector2.ZERO and _rng.randf() < ADELANTE
	for intento in 12:
		var a := dir.angle() + _rng.randf_range(-0.9, 0.9) if adelante else _rng.randf() * TAU
		var q := centro + Vector2(cos(a), sin(a)) * _rng.randf_range(CERCA.x, CERCA.y)
		var i: int = ciudad._indice(ciudad.inicio_x, q.x)
		var j: int = ciudad._indice(ciudad.inicio_y, q.y)
		if i < 0 or j < 0 or i >= ciudad.N_ANCHO or j >= ciudad.N_LARGO:
			continue
		var r: Rect2 = ciudad.cuadra(i, j)
		var carril := r.grow(-_rng.randf_range(CARRIL.x, CARRIL.y))
		var nuevo := p.is_empty()
		if nuevo:
			p = {}
			lista.append(p)
		p.i = i
		p.j = j
		p.carril = carril
		p.s = _s_cercano(carril, q) # en el punto de su vuelta más cercano al sorteado (hay cuadras largas)
		p.sentido = 1 if _rng.randf() < 0.5 else -1
		p.vel = _rng.randf_range(VEL.x, VEL.y)
		p.ropa = _rng.randi_range(0, ROPAS - 1)
		p.andado = _rng.randf() * 2.0
		p.pos = punto(carril, p.s)
		p.dir = Vector2.RIGHT
		return true
	return false


static func _s_cercano(r: Rect2, q: Vector2) -> float:
	var per := _perimetro(r)
	var mejor := 0.0
	var d_mejor := INF
	for k in 64:
		var s := per * k / 64.0
		var d := punto(r, s).distance_squared_to(q)
		if d < d_mejor:
			d_mejor = d
			mejor = s
	return mejor


static func _perimetro(r: Rect2) -> float:
	return 2.0 * (r.size.x + r.size.y)


## El punto a s metros de la esquina de arriba a la izquierda, dándole la vuelta al rectángulo.
static func punto(r: Rect2, s: float) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	s = fposmod(s, 2.0 * (w + h))
	if s < w:
		return r.position + Vector2(s, 0)
	s -= w
	if s < h:
		return r.position + Vector2(w, s)
	s -= h
	if s < w:
		return r.position + Vector2(w - s, h)
	s -= w
	return r.position + Vector2(0, h - s)
