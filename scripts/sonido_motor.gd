extends RefCounted
## Cómo suena el motor según la velocidad (Tomás, 30/09): despacio tranquilo, rápido revolucionado.
## Calcula las rpm de la moto (automática o con cambios) y cómo mezclar sus bucles: hay uno grabado
## a cada rpm de moto.rpm_muestras y se suenan los dos más cercanos, con el tono apenas corrido
## (corrido mucho, el timbre del exosto se deforma y suena «a nave espacial»). Sin nodos.

const SUBIR := 9000.0   # rpm/s que puede subir el tacómetro (sube rápido)
const BAJAR := 6000.0   # rpm/s que puede bajar (al soltar cae más despacio)

var moto: Dictionary
var rpm := 0.0
var cambio := 1


func _init(p_moto: Dictionary) -> void:
	moto = p_moto
	rpm = float(moto.rpm_ralenti)


## Las rpm que "pide" la moto a esa velocidad (sin suavizar) y el cambio en que va.
func rpm_objetivo(vel: float, acelerar: bool) -> float:
	var ral := float(moto.rpm_ralenti)
	var tope := float(moto.rpm_max)
	var frac := clampf(vel / float(moto.vel_max), 0.0, 1.0)
	var n := int(moto.cambios)
	var carga := 0.12 if acelerar else 0.0
	if vel < 0.3:
		cambio = 1
		return ral + (tope - ral) * (0.25 if acelerar else 0.0)
	if n == 0:
		# Automática (CVT): sube con la velocidad y acelerando se queda alta.
		cambio = 1
		return ral + (tope - ral) * clampf(0.2 + 0.68 * sqrt(frac) + carga, 0.0, 1.0)
	# Con cambios: cada cambio va de rpm medias a casi el tope; al pasar, las rpm caen.
	cambio = mini(int(pow(frac, 1.25) * n) + 1, n)
	var ini := pow(float(cambio - 1) / n, 0.8)
	var fin := pow(float(cambio) / n, 0.8)
	var en_cambio := clampf((frac - ini) / maxf(fin - ini, 0.001), 0.0, 1.0)
	var bajo := 0.08 if cambio == 1 else 0.38
	return ral + (tope - ral) * clampf(bajo + (0.9 - bajo) * en_cambio + carga, 0.0, 1.0)


func advance(delta: float, vel: float, acelerar: bool) -> void:
	var meta := rpm_objetivo(vel, acelerar)
	rpm = move_toward(rpm, meta, (SUBIR if meta > rpm else BAJAR) * delta)


## Los bucles que suenan ahora: [[índice en rpm_muestras, peso 0..1, tono], ...] (dos, que suman 1).
func mezcla() -> Array:
	var m: Array = moto.rpm_muestras
	var r := clampf(rpm, float(m[0]), float(m[-1]))
	var k := 0
	while k < m.size() - 2 and r > float(m[k + 1]):
		k += 1
	# Mezcla en escala logarítmica: el oído oye proporciones, no diferencias.
	var p := clampf(log(r / float(m[k])) / log(float(m[k + 1]) / float(m[k])), 0.0, 1.0)
	return [[k, 1.0 - p, rpm / float(m[k])], [k + 1, p, rpm / float(m[k + 1])]]


## 0 en ralentí, 1 al tope de rpm.
func revoluciones() -> float:
	var ral := float(moto.rpm_ralenti)
	return clampf((rpm - ral) / (float(moto.rpm_max) - ral), 0.0, 1.0)


## Volumen en dB: más fuerte revolucionado y acelerando.
func volumen_db(acelerar: bool) -> float:
	return -16.0 + 9.0 * revoluciones() + (3.0 if acelerar else 0.0)
