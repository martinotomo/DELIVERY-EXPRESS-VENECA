extends RefCounted
## Cómo anda la moto por la ciudad, sin escenas ni fotogramas: advance(delta, mandos).
## Girar muy rápido la hace derrapar (el agarre no da), y el andén a velocidad la mata.

signal estrellado(mensaje: String)
signal casi(tipo: String)

const MENSAJES := preload("res://scripts/mensajes.gd")

const RODANDO := "rodando"
const ESTRELLADA := "estrellada"
const PASO := 1.0 / 60.0
const CASI_DISTANCIA := 1.0 # metros de más sobre el radio que cuentan como «raspando»
const CASI_VEL := 8.0       # m/s mínimos para que raspar asuste
const CASI_ENFRIAR := 4.0   # s entre dos «casi me mato»

var moto: Dictionary
var ciudad
var pos := Vector2.ZERO
var rumbo := 0.0 # radianes; 0 = oriente (+x), PI/2 = norte (+y)
var vel := 0.0
var derrapando := false
var estado := RODANDO
var _enfriar_casi := 0.0


func setup(p_moto: Dictionary, p_ciudad, p_pos: Vector2, p_rumbo: float) -> void:
	moto = p_moto
	ciudad = p_ciudad
	pos = p_pos
	rumbo = p_rumbo
	vel = 0.0
	derrapando = false
	estado = RODANDO
	_enfriar_casi = 0.0


func direccion() -> Vector2:
	return Vector2(cos(rumbo), sin(rumbo))


func vel_kmh() -> int:
	return int(round(vel * 3.6))


## giro: -1 (izquierda) a 1 (derecha).
func advance(delta: float, acelerar: bool, frenar: bool, giro: float) -> void:
	var queda := delta
	while queda > 0.000001 and estado == RODANDO:
		var dt := minf(PASO, queda)
		_paso(dt, acelerar, frenar, clampf(giro, -1.0, 1.0))
		queda -= dt


func _paso(dt: float, acelerar: bool, frenar: bool, giro: float) -> void:
	var vmax: float = moto.vel_max
	var a := -float(moto.roce)
	if frenar:
		a = -float(moto.freno)
	elif acelerar:
		a = float(moto.acel) * (1.0 - pow(vel / vmax, 2))
	vel = clampf(vel + a * dt, 0.0, vmax)

	# Girar: la curva que pides contra la que el agarre te deja.
	var omega := giro * float(moto.giro_max) * minf(vel / 2.0, 1.0)
	derrapando = false
	if vel > 0.1 and absf(omega) * vel > float(moto.agarre):
		omega = signf(omega) * float(moto.agarre) / vel
		derrapando = true
	rumbo += omega * dt

	var nueva := pos + direccion() * vel * dt
	var d: float = ciudad.distancia_anden(nueva)
	if d <= float(moto.radio):
		if vel > float(moto.vel_choque):
			pos = nueva
			estado = ESTRELLADA
			estrellado.emit(MENSAJES.muerte_curva(moto.nombre))
		else:
			vel = 0.0 # topó el andén despacio: se queda ahí
		return
	pos = nueva

	_enfriar_casi = maxf(_enfriar_casi - dt, 0.0)
	if d < float(moto.radio) + CASI_DISTANCIA and vel > CASI_VEL and _enfriar_casi <= 0.0:
		_enfriar_casi = CASI_ENFRIAR
		casi.emit("anden")
