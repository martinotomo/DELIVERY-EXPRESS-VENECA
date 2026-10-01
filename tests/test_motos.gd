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

	# Manejo por moto (Tomás, 30/09): la más cara gira mejor que la más barata a la misma velocidad,
	# y también a su propia velocidad máxima (curva más cerrada), sin perder la curva de D12.
	var MOTO := load("res://scripts/moto_logic.gd")
	var logicas := {}
	for id in MOTOS.ORDEN + ["bws_toda", "nkd_toda"]:
		var l = MOTO.new()
		var base_id: String = id.trim_suffix("_toda")
		l.moto = MOTOS.con_mejoras(base_id, {"exosto": true, "motor": true}) if id.ends_with("_toda") else MOTOS.get_moto(base_id)
		logicas[id] = l
	var orden_ok := true
	var mejorada_ok := true
	for v10 in range(30, 400, 5):
		var v := v10 / 10.0
		var w_b: float = logicas.bws.giro_max_a(v)
		var w_n: float = logicas.nkd.giro_max_a(v)
		var w_j: float = logicas.ninja.giro_max_a(v)
		if v <= 25.0 and not (w_n > w_b):
			orden_ok = false
		if v <= 30.5 and not (w_j > w_n):
			orden_ok = false
		if v <= 28.0 and not (logicas.bws_toda.giro_max_a(v) < w_n):
			mejorada_ok = false
		if v <= 34.0 and not (logicas.nkd_toda.giro_max_a(v) < w_j):
			mejorada_ok = false
	t.check(orden_ok, "a la misma velocidad la NKD gira más que la Bwis y la Ninja más que la NKD")
	t.check(mejorada_ok, "las mejoras no dan el giro de la moto siguiente")
	var radios := []
	for id in MOTOS.ORDEN:
		var m: Dictionary = MOTOS.get_moto(id)
		radios.append(float(m.vel_max) / logicas[id].giro_max_a(float(m.vel_max)))
	t.check(radios[0] > radios[1] and radios[1] > radios[2], "a fondo, la curva más cerrada es la de la Ninja (radios %d, %d, %d m)" % radios)
	t.check_eq(float(bws.giro_rapido), 0.24, "la Bwis sigue girando como la dejó Tomás a tope")
	t.check_eq(float(bws.giro_lento), 2.7, "y despacio")
	for k in 2:
		var a: Dictionary = MOTOS.get_moto(MOTOS.ORDEN[k])
		var b: Dictionary = MOTOS.get_moto(MOTOS.ORDEN[k + 1])
		t.check(float(b.agarre) > float(a.agarre), "la %s tiene más agarre que la %s" % [b.id, a.id])
		t.check(float(b.vel_choque) > float(a.vel_choque), "la %s aguanta un toque más fuerte al andén que la %s" % [b.id, a.id])
