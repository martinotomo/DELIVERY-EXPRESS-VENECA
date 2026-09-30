extends RefCounted
## Cómo anda la moto por la ciudad, sin escenas ni fotogramas: advance(delta, mandos).
## Girar muy rápido la hace derrapar (el agarre no da), y el andén a velocidad la mata.

signal estrellado(mensaje: String)
signal casi(tipo: String)
signal golpe # tocó el andén despacio: solo queja
signal fundido  # el motor se quemó por ir a fondo demasiado tiempo
signal reparado # pasó la espera y ya puede seguir

const MENSAJES := preload("res://scripts/mensajes.gd")

const RODANDO := "rodando"
const ESTRELLADA := "estrellada"
const PASO := 1.0 / 60.0
const CASI_DISTANCIA := 1.0 # metros de más sobre el radio que cuentan como «raspando»
const CASI_VEL := 8.0       # m/s mínimos para que raspar asuste
const CASI_ENFRIAR := 4.0   # s entre dos «casi me mato»
const DERRAPE_FRACCION := 0.75 # «se va de lado» solo por encima del 75 % de la velocidad máxima...
const DERRAPE_GIRO := 0.9      # ...con el manubrio casi a tope...
const DERRAPE_SOSTENIDO := 0.35 # ...y sostenido este tiempo (s), no un toque
# Fundir el motor (Tomás, 30/09): a fondo y casi a tope más de 5 s sale el aviso con cuenta
# regresiva de 5 s; si no suelta, se funde, frena en seco y espera 3 s quieto.
const MOTOR_A_TOPE := 0.9      # fracción de la velocidad máxima que cuenta como «a fondo»
const MOTOR_GRACIA := 5.0      # s a fondo antes del aviso
const MOTOR_AVISO := 5.0       # s de cuenta regresiva
const MOTOR_ENFRIA := 5.0      # soltando, se enfría 5 veces más rápido: 1 s basta para quitar el aviso
const MOTOR_ESPERA := 3.0      # s quieto tras fundirse
const FRENO_FUNDIDO := 18.0    # m/s²: frenazo en seco

var moto: Dictionary
var ciudad
var pos := Vector2.ZERO
var rumbo := 0.0 # radianes; 0 = oriente (+x), PI/2 = norte (+y)
var vel := 0.0
var derrapando := false
var estado := RODANDO
var _t_derrape := 0.0
var calor := 0.0            # s acumulados a fondo (0 a MOTOR_GRACIA + MOTOR_AVISO)
var motor_fundido := false
var _t_reparar := 0.0
var _enfriar_casi := 0.0
var _enfriar_golpe := 0.0


func setup(p_moto: Dictionary, p_ciudad, p_pos: Vector2, p_rumbo: float) -> void:
	moto = p_moto
	ciudad = p_ciudad
	pos = p_pos
	rumbo = p_rumbo
	vel = 0.0
	derrapando = false
	_t_derrape = 0.0
	calor = 0.0
	motor_fundido = false
	_t_reparar = 0.0
	estado = RODANDO
	_enfriar_casi = 0.0
	_enfriar_golpe = 0.0


func direccion() -> Vector2:
	return Vector2(cos(rumbo), sin(rumbo))


func vel_kmh() -> int:
	return int(round(vel * 3.6))


## Cuánto gira (rad/s) con el manubrio a tope a una velocidad dada. Parada no gira; de 2 m/s
## hacia arriba va de giro_lento a giro_rapido según (vel/vel_max)^curva_giro.
func giro_max_a(v: float) -> float:
	var k := clampf(v / float(moto.vel_max), 0.0, 1.0)
	var w := lerpf(float(moto.giro_lento), float(moto.giro_rapido), pow(k, float(moto.curva_giro)))
	return w * minf(v / 2.0, 1.0)


## giro: -1 (izquierda) a 1 (derecha).
func advance(delta: float, acelerar: bool, frenar: bool, giro: float) -> void:
	var queda := delta
	while queda > 0.000001 and estado == RODANDO:
		var dt := minf(PASO, queda)
		_paso(dt, acelerar, frenar, clampf(giro, -1.0, 1.0))
		queda -= dt


## Segundos que faltan para fundir el motor mientras sale el aviso; -1 si no hay aviso.
func cuenta_motor() -> float:
	if motor_fundido or calor < MOTOR_GRACIA:
		return -1.0
	return maxf(MOTOR_GRACIA + MOTOR_AVISO - calor, 0.0)


## Segundos que faltan para terminar de reparar (0 si el motor está bien).
func espera_reparacion() -> float:
	return _t_reparar if motor_fundido else 0.0


func _motor(dt: float, acelerar: bool) -> void:
	if motor_fundido:
		if vel <= 0.0:
			_t_reparar -= dt
			if _t_reparar <= 0.0:
				motor_fundido = false
				_t_reparar = 0.0
				calor = 0.0
				reparado.emit()
		return
	if acelerar and vel >= MOTOR_A_TOPE * float(moto.vel_max):
		calor += dt
	else:
		calor = maxf(calor - dt * MOTOR_ENFRIA, 0.0)
	if calor >= MOTOR_GRACIA + MOTOR_AVISO:
		motor_fundido = true
		_t_reparar = MOTOR_ESPERA
		fundido.emit()


func _paso(dt: float, acelerar: bool, frenar: bool, giro: float) -> void:
	_motor(dt, acelerar)
	var vmax: float = moto.vel_max
	var a := -float(moto.roce)
	if motor_fundido:
		a = -FRENO_FUNDIDO # frena en seco y no acelera hasta repararlo
	elif frenar:
		a = -float(moto.freno)
	elif acelerar:
		a = float(moto.acel) * (1.0 - pow(vel / vmax, 2))
	vel = clampf(vel + a * dt, 0.0, vmax)

	# Girar: más maniobrable despacio; a toda, el manubrio a tope la hace irse de lado.
	rumbo += giro * giro_max_a(vel) * dt
	if absf(giro) >= DERRAPE_GIRO and vel > DERRAPE_FRACCION * float(moto.vel_max):
		_t_derrape += dt
	else:
		_t_derrape = 0.0
	derrapando = _t_derrape >= DERRAPE_SOSTENIDO

	_enfriar_golpe = maxf(_enfriar_golpe - dt, 0.0)
	var nueva := pos + direccion() * vel * dt
	var d: float = ciudad.distancia_anden(nueva)
	if d <= float(moto.radio):
		if vel > float(moto.vel_choque):
			pos = nueva
			estado = ESTRELLADA
			estrellado.emit(MENSAJES.muerte_curva(moto.nombre))
		else:
			if vel > 0.5 and _enfriar_golpe <= 0.0:
				_enfriar_golpe = CASI_ENFRIAR
				golpe.emit()
			vel = 0.0 # topó el andén despacio: se queda ahí
		return
	pos = nueva

	_enfriar_casi = maxf(_enfriar_casi - dt, 0.0)
	if d < float(moto.radio) + CASI_DISTANCIA and vel > CASI_VEL and _enfriar_casi <= 0.0:
		_enfriar_casi = CASI_ENFRIAR
		casi.emit("anden")
