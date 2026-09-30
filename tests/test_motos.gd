extends RefCounted
## Contrato de los datos de las motos.

const MOTOS := preload("res://scripts/motos.gd")


func run(t) -> void:
	var bws: Dictionary = MOTOS.get_moto("bws")
	t.check(not bws.is_empty(), "existe la BWS")
	t.check_eq(MOTOS.MOTO_INICIAL, "bws", "la moto inicial es la BWS")
	t.check_eq(bws.get("nombre"), "BWS", "la BWS se llama BWS en los mensajes")
	for campo in ["vel_max", "acel", "freno", "roce", "agarre", "giro_max", "radio", "vel_choque"]:
		t.check(float(bws.get(campo, 0.0)) > 0.0, "la BWS tiene %s positivo" % campo)
	# Una BWS 125 no pasa de unos 90-95 km/h, y la gracia es que se note.
	var kmh := float(bws.vel_max) * 3.6
	t.check(kmh >= 75.0 and kmh <= 100.0, "velocidad máxima de BWS creíble (%.0f km/h)" % kmh)
	t.check(float(bws.freno) > float(bws.acel), "frena más de lo que acelera")
	t.check(MOTOS.get_moto("no-existe").is_empty(), "una moto desconocida devuelve vacío")
