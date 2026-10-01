extends RefCounted
## Día y noche: un día completo cada 10 minutos. Arranca a las 6:00.

const PERIODO := 600.0
const HORA_INICIO := 6.0

const C_NOCHE := Color("0b0f1e")
const C_DIA := Color("8fa6bf")
const C_OCASO := Color("c0703a")

var t := 0.0


func advance(delta: float) -> void:
	t = fmod(t + delta, PERIODO)


func hora() -> float:
	return fmod(HORA_INICIO + 24.0 * t / PERIODO, 24.0)


## 0 de noche, 1 a mediodía. El sol sale a las 5 y se pone a las 19.
func luz() -> float:
	return maxf(sin(PI * (hora() - 5.0) / 14.0), 0.0)


func farola_encendida() -> bool:
	return luz() < 0.25


func color_cielo() -> Color:
	var l := luz()
	var base := C_NOCHE.lerp(C_DIA, l)
	# Tinte naranja al amanecer y al atardecer.
	var ocaso: float = clampf(1.0 - absf(l - 0.2) / 0.2, 0.0, 1.0) * 0.5
	return base.lerp(C_OCASO, ocaso)


func texto_hora() -> String:
	var h := hora()
	return "%d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]
