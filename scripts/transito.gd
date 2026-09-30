extends RefCounted
## Semáforos y señales de tránsito de la ciudad (Tomás, 30/09: «señalizaciones, semáforos»).
## Por ahora son de ambiente: pasarse un rojo no tiene castigo.
##
## Semáforos en los cruces de las avenidas (cada tercera carrera con cada tercera calle): un poste en
## cada esquina, mirando al que llega por ese lado. Todos los de la ciudad van sincronizados: mientras
## las calles (vías a lo largo de x) tienen verde, las carreras (a lo largo de y) tienen rojo, y al revés.
## En los demás cruces, algunos PARE; y cerca de algunas cebras, la señal de peatones o la de velocidad.
## Sin escenas: advance(delta) y luz(eje).

const CICLO := 20.0      # s de una vuelta completa
const VERDE := 8.0       # s en verde
const AMARILLO := 2.0    # s en amarillo (el resto del medio ciclo, en rojo)
const CADA := 3          # semáforo en cada tercera carrera y tercera calle
const PROB_PARE := 0.35  # cruces sin semáforo que tienen PARE
const PROB_OTRA := 0.25  # cruces sin semáforo con señal de peatones o de velocidad
const ESQUINA := 2.0     # m desde el borde de la cuadra hasta el poste (en el andén, sin chocar con el de la luz)
const DIRS := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]

var ciudad
var t := 0.0


func _init(p_ciudad = null) -> void:
	ciudad = p_ciudad


func advance(delta: float) -> void:
	t = fmod(t + delta, CICLO)


## "verde", "amarillo" o "rojo" para el que va a lo largo del eje "x" (calles) o "y" (carreras).
func luz(eje: String) -> String:
	var f := fmod(t + (0.0 if eje == "x" else CICLO / 2.0), CICLO)
	if f < VERDE:
		return "verde"
	if f < VERDE + AMARILLO:
		return "amarillo"
	return "rojo"


func tiene_semaforo(i: int, j: int) -> bool:
	return _interior(i, j) and i % CADA == 0 and j % CADA == 0


## Los cuatro bloques alrededor del cruce existen (no es borde de la ciudad).
func _interior(i: int, j: int) -> bool:
	return i >= 1 and j >= 1 and i < ciudad.N_ANCHO and j < ciudad.N_LARGO


## Poste en la esquina de delante a la derecha de quien llega en la dirección d, en el andén.
func esquina(i: int, j: int, d: Vector2) -> Vector2:
	var derecha := Vector2(-d.y, d.x)
	var off: float = ciudad.CALLE / 2.0 + ESQUINA
	return ciudad.cruce(i, j) + (d + derecha) * off


## Todos los semáforos: {pos (poste), dir (hacia donde va el que lo mira), eje ("x" o "y")}.
func semaforos() -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	for j in range(0, ciudad.N_LARGO + 1, CADA):
		for i in range(0, ciudad.N_ANCHO + 1, CADA):
			if not tiene_semaforo(i, j):
				continue
			for d in DIRS:
				r.append({"pos": esquina(i, j, d), "dir": d, "eje": "x" if d.x != 0.0 else "y"})
	return r


## Señales en postes: {pos, dir (hacia donde va el que la lee), tipo: "pare", "peatones" o "velocidad"}.
func senales() -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	for j in range(1, ciudad.N_LARGO):
		for i in range(1, ciudad.N_ANCHO):
			if tiene_semaforo(i, j):
				continue
			rng.seed = (i * 7919 + j * 104729) * 31 + 5
			var tira := rng.randf()
			if tira < PROB_PARE:
				# PARE para las carreras o para las calles (las otras tienen la vía): dos, uno por lado.
				var eje_y := rng.randf() < 0.5
				for d in ([DIRS[1], DIRS[3]] if eje_y else [DIRS[0], DIRS[2]]):
					r.append({"pos": _antes(i, j, d), "dir": d, "tipo": "pare"})
			elif tira < PROB_PARE + PROB_OTRA:
				var d: Vector2 = DIRS[rng.randi_range(0, 3)]
				r.append({"pos": _antes(i, j, d), "dir": d, "tipo": "peatones" if rng.randf() < 0.6 else "velocidad"})
	return r


## Poste a la derecha antes de llegar al cruce (donde se para el que viene en la dirección d).
func _antes(i: int, j: int, d: Vector2) -> Vector2:
	var derecha := Vector2(-d.y, d.x)
	var off: float = ciudad.CALLE / 2.0 + ESQUINA
	return ciudad.cruce(i, j) - d * (off + ciudad.CEBRA) + derecha * off
