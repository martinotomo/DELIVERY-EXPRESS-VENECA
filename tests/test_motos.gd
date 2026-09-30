extends RefCounted
## Contrato de los datos de las motos y sus mejoras.

const MOTOS := preload("res://scripts/motos.gd")


func run(t) -> void:
	var bws: Dictionary = MOTOS.get_moto("bws")
	t.check(not bws.is_empty(), "existe la BWS")
	t.check_eq(MOTOS.MOTO_INICIAL, "bws", "la moto inicial es la BWS")
	t.check_eq(bws.get("nombre"), "Bwis", "la BWS se llama «Bwis» en todo lo que ve el jugador (Tomás, 30/09)")
	t.check(MOTOS.get_moto("no-existe").is_empty(), "una moto desconocida devuelve vacío")
	# Dos o tres motos como mucho (Tomás, 30/09): BWS, una intermedia y la Ninja 300 al final.
	t.check_eq(MOTOS.ORDEN.size(), 3, "hay tres motos")
	t.check_eq(MOTOS.ORDEN[0], "bws", "se empieza en la BWS")
	t.check_eq(MOTOS.get_moto(MOTOS.ORDEN[-1]).nombre, "Ninja 300", "se termina en la Ninja 300")
	t.check_eq(MOTOS.siguiente("bws"), "nkd", "después de la BWS viene la NKD")
	t.check_eq(MOTOS.siguiente("ninja"), "", "la Ninja es la última")
	t.check_eq(MOTOS.MEJORAS, ["exosto", "motor"], "dos mejoras: exosto y motor")

	for id in MOTOS.ORDEN:
		var m: Dictionary = MOTOS.get_moto(id)
		for campo in ["vel_max", "acel", "freno", "roce", "giro_lento", "giro_rapido", "curva_giro", "radio", "vel_choque"]:
			t.check(float(m.get(campo, 0.0)) > 0.0, "%s tiene %s positivo" % [id, campo])
		t.check(float(m.freno) > float(m.acel), "%s frena más de lo que acelera" % id)
		for mej in MOTOS.MEJORAS:
			var d: Dictionary = m.mejoras[mej]
			t.check(int(d.precio) > 0 and float(d.vel_max) > 0.0 and float(d.acel) > 0.0, "%s: la mejora %s cuesta y sirve" % [id, mej])
		var toda: Dictionary = MOTOS.con_mejoras(id, {"exosto": true, "motor": true})
		t.check(float(toda.vel_max) > float(m.vel_max) and float(toda.acel) > float(m.acel), "%s mejorada anda más" % id)
		var sig := MOTOS.siguiente(id)
		if sig != "":
			var nueva: Dictionary = MOTOS.get_moto(sig)
			t.check(float(toda.vel_max) < float(nueva.vel_max), "%s al máximo es más lenta que la %s de fábrica (%.1f < %.1f km/h)" % [id, sig, float(toda.vel_max) * 3.6, float(nueva.vel_max) * 3.6])
			t.check(float(toda.acel) < float(nueva.acel), "%s al máximo acelera menos que la %s de fábrica" % [id, sig])
			t.check(int(nueva.precio) > int(m.precio), "la %s cuesta más que la %s" % [sig, id])
	t.check(MOTOS.con_mejoras("bws", {}).vel_max == bws.vel_max, "sin mejoras queda de fábrica")
	t.check(MOTOS.get_moto("bws").vel_max == 25.0, "con_mejoras no cambia los datos de fábrica")
	# Una BWS 125 no pasa de unos 90-95 km/h, y la gracia es que se note.
	var kmh := float(bws.vel_max) * 3.6
	t.check(kmh >= 75.0 and kmh <= 100.0, "velocidad máxima de BWS creíble (%.0f km/h)" % kmh)
