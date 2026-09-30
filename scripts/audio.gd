extends Node
## Todo lo que suena en el recorrido: motor, viento, ciudad (día y noche), lluvia y efectos.
## Los sonidos salen de tools/gen_sonidos.py. La lógica del tono del motor vive en sonido_motor.gd;
## aquí solo se mezclan volúmenes. Las voces (D11) van aparte, en recorrido.gd.

const SONIDO_MOTOR := preload("res://scripts/sonido_motor.gd")
const RUTA := "res://assets/sonidos/%s.wav"
const EFECTOS := {
	"estrellado": "choque", "golpe": "golpe", "casi": "casi", "fundido": "fundido",
	"entregado": "entregado", "recogido": "recogido", "reparado": "reparado", "charco": "charco",
	"atropello": "atropello",
}
const SILENCIO := -60.0

var motor # sonido_motor.gd
var _motores: Array[AudioStreamPlayer] = [] # uno por cada rpm grabada
var _viento: AudioStreamPlayer
var _dia: AudioStreamPlayer
var _noche: AudioStreamPlayer
var _lluvia: AudioStreamPlayer
var _efectos: Array[AudioStreamPlayer] = []
var _siguiente := 0
var ultimo_efecto := ""   # para las pruebas


func preparar(datos_moto: Dictionary) -> void:
	motor = SONIDO_MOTOR.new(datos_moto)
	for rpm in datos_moto.rpm_muestras:
		_motores.append(_bucle("Motor%d" % rpm, "motor_%s_%d" % [datos_moto.id, rpm]))
	_viento = _bucle("Viento", "viento")
	_dia = _bucle("CiudadDia", "ambiente_dia")
	_noche = _bucle("CiudadNoche", "ambiente_noche")
	_lluvia = _bucle("Lluvia", "lluvia")
	for k in 4:
		var p := AudioStreamPlayer.new()
		p.name = "Efecto%d" % k
		add_child(p)
		_efectos.append(p)


func _bucle(nombre: String, sonido: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = nombre
	p.stream = load(RUTA % sonido)
	p.volume_db = SILENCIO
	add_child(p)
	p.play()
	return p


## Cada fotograma: mezcla según la moto, la hora y la lluvia.
func actualizar(delta: float, partida, acelerar: bool) -> void:
	var m = partida.moto
	var viva: bool = not partida.terminada
	motor.advance(delta, m.vel, acelerar and viva and not m.motor_fundido)
	var vol: float = motor.volumen_db(acelerar) if viva and not m.motor_fundido else SILENCIO
	for p in _motores:
		p.volume_db = SILENCIO
	for par in motor.mezcla():
		var p := _motores[par[0]]
		p.pitch_scale = clampf(par[2], 0.5, 2.0)
		p.volume_db = maxf(vol + _db(sqrt(par[1])), SILENCIO) if par[1] > 0.001 else SILENCIO # potencia constante
	var rapidez := clampf(m.vel / 35.0, 0.0, 1.0)
	_viento.volume_db = _db(rapidez * 0.7)
	_viento.pitch_scale = 0.8 + 0.5 * rapidez
	var luz: float = partida.reloj.luz()
	var llueve: float = partida.clima.intensidad
	var dia := smoothstep(0.0, 0.35, luz)
	_dia.volume_db = _db(0.5 * dia * (1.0 - 0.5 * llueve))
	_noche.volume_db = _db(0.45 * (1.0 - dia) * (1.0 - 0.5 * llueve))
	_lluvia.volume_db = _db(1.0 * llueve)


func _db(lineal: float) -> float:
	return maxf(linear_to_db(maxf(lineal, 0.0001)), SILENCIO)


func al_evento(nombre: String) -> void:
	if not EFECTOS.has(nombre):
		return
	var p := _efectos[_siguiente]
	_siguiente = (_siguiente + 1) % _efectos.size()
	p.stream = load(RUTA % EFECTOS[nombre])
	p.volume_db = -4.0
	p.play()
	ultimo_efecto = EFECTOS[nombre]
