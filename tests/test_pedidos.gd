extends RefCounted
## Contrato de la F5 (DISENO §5.3–5.4): tipos de pedido que cambian la conducción, estado del pedido,
## racha de casi-choques, estrellas, zonas que abre cada moto y el final con la mamá.

const PARTIDA := preload("res://scripts/partida.gd")
const MOTOS := preload("res://scripts/motos.gd")
const PROGRESO := preload("res://scripts/progreso.gd")


func _entregar(p) -> void:
	p.moto.pos = p.pedido.restaurante
	p.moto.vel = 0.0
	p._revisar_llegada()
	p.moto.pos = p.pedido.cliente
	p._revisar_llegada()


func run(t) -> void:
	# Tipos: cada pedido dice cuál es y cómo se maneja.
	var p = PARTIDA.new(77)
	var vistos := {}
	for k in 80:
		p._nuevo_pedido()
		vistos[p.pedido.tipo] = true
		if not PARTIDA.TIPOS_PEDIDO.has(p.pedido.tipo):
			t.check(false, "tipo desconocido: %s" % p.pedido.tipo)
	for tipo in ["hamburguesa", "sopa", "torta", "licor"]:
		t.check(vistos.has(tipo), "salen pedidos de %s" % tipo)
		t.check(PARTIDA.TIPOS_PEDIDO[tipo].aviso != "", "el pedido de %s explica cómo llevarlo" % tipo)

	# Sopa: frenar en seco la riega (baja el estado y suena); ir suave no.
	var eventos: Array[String] = []
	p.evento.connect(func(e): eventos.append(e))
	p.pedido.tipo = "sopa"
	p.fase = PARTIDA.ENTREGAR
	p.estado_pedido = 1.0
	p.moto.pos = p.ciudad.cruce(20, 40)
	p.moto.rumbo = 0.0
	p.moto.vel = 20.0
	for k in 60:
		p.advance(1.0 / 60.0, false, true, 0.0) # frenazo a fondo
	t.check(p.estado_pedido < 0.9, "frenar en seco con sopa la riega (estado %.2f)" % p.estado_pedido)
	t.check(eventos.has("regado"), "y el domiciliario se queja")
	var e_sopa: float = p.estado_pedido
	p.pedido.tipo = "hamburguesa"
	p.estado_pedido = 1.0
	p.moto.vel = 20.0
	for k in 60:
		p.advance(1.0 / 60.0, false, true, 0.0)
	t.check_eq(p.estado_pedido, 1.0, "la hamburguesa aguanta el frenazo")
	p.pedido.tipo = "torta"
	p.estado_pedido = 1.0
	p.moto.vel = 20.0
	for k in 60:
		p.advance(1.0 / 60.0, false, true, 0.0)
	t.check(p.estado_pedido < e_sopa, "la torta es más delicada que la sopa (%.2f vs %.2f)" % [p.estado_pedido, e_sopa])

	# Licor: pesa más, frena peor.
	var q = PARTIDA.new(5)
	q.moto.pos = q.ciudad.cruce(20, 40)
	q.moto.rumbo = 0.0
	q.pedido.tipo = "hamburguesa"
	q.fase = PARTIDA.ENTREGAR
	q._aplicar_tipo()
	q.moto.vel = 20.0
	q.advance(0.5, false, true, 0.0)
	var v_normal: float = q.moto.vel
	q.pedido.tipo = "licor"
	q._aplicar_tipo()
	q.moto.pos = q.ciudad.cruce(20, 40)
	q.moto.vel = 20.0
	q.advance(0.5, false, true, 0.0)
	t.check(q.moto.vel > v_normal + 0.8, "con licor frena peor (%.1f vs %.1f m/s)" % [q.moto.vel, v_normal])
	q.fase = PARTIDA.RECOGER
	q._aplicar_tipo()
	t.check_eq(q.moto.factor_freno, 1.0, "yendo a recoger, el licor todavía no pesa")

	# Pago: la propina baja con el estado del pedido y sube con la racha.
	var base: int = PARTIDA.pago_por(100.0)
	t.check(PARTIDA.pago_por(100.0, false, 0.5) < base, "pedido regado paga menos propina")
	t.check(PARTIDA.pago_por(100.0, false, 1.0, 5) > base, "la racha sube la propina")
	t.check_eq(PARTIDA.pago_por(0.0, false, 1.0, 5), PARTIDA.TARIFA, "sin tiempo sobrante, la racha no inventa propina")
	t.check(PARTIDA.pago_por(100.0, false, 1.0, 999) <= PARTIDA.pago_por(100.0, false, 1.0, PARTIDA.RACHA_MAX), "la racha tiene tope")

	# Racha: cada casi-choque suma, el HUD la muestra; un golpe la corta y entregar la cobra.
	var r = PARTIDA.new(9)
	var ev_r: Array[String] = []
	r.evento.connect(func(e): ev_r.append(e))
	for k in 3:
		r._al_casi("carro")
	t.check_eq(r.racha, 3, "tres casi-choques = racha 3")
	t.check(ev_r.has("racha"), "a la tercera, el domiciliario presume")
	r._al_golpe()
	t.check_eq(r.racha, 0, "un golpe corta la racha")
	r._al_casi("anden")
	r._al_casi("peaton")
	_entregar(r)
	t.check_eq(r.racha, 0, "al entregar se cobra la racha y vuelve a cero")
	t.check_eq(r.ultima_racha, 2, "y se sabe cuánta racha se cobró")

	# Casi-choque con un carro del tráfico: pasar rozando a buena velocidad cuenta.
	var s = PARTIDA.new(11)
	s.trafico.MAX_ACTIVOS = 0
	s.trafico.lista.clear()
	var car: Dictionary = s.trafico.poner("carro", Vector2i(20, 40), Vector2.RIGHT, -40.0)
	car.vel = 0.0
	car.vmax = 0.0
	s.moto.pos = car.pos + Vector2(-6.0, -car.ancho / 2.0 - 0.3 - s.moto.moto.radio - 0.4)
	s.moto.rumbo = 0.0
	s.moto.vel = 12.0
	for k in 60:
		s.advance(1.0 / 60.0, true, false, 0.0)
	t.check(s.racha >= 1, "pasar rozando un carro a buena velocidad suma a la racha (%d)" % s.racha)

	# Estrellas: de 1 a 5, con comentario; entrega impecable = 5, regada y tarde = pocas.
	var e5: Array = PARTIDA.estrellas_por(1.0, 0.6, false)
	var e1: Array = PARTIDA.estrellas_por(0.3, 0.0, true)
	t.check_eq(e5[0], 5, "entrega perfecta, cinco estrellas")
	t.check(e1[0] <= 2, "regada, tarde y atropellando, pocas (%d)" % e1[0])
	t.check(str(e5[1]) != "" and str(e1[1]) != "", "cada calificación trae comentario")
	var calif := []
	r.calificado.connect(func(n, c): calif.append(n))
	_entregar(r)
	t.check(calif.size() == 1 and calif[0] >= 1 and calif[0] <= 5, "al entregar el cliente califica")
	# Entrega tarde (le quedaban menos de 10 s): voz de excusa.
	ev_r.clear()
	r.moto.pos = r.pedido.restaurante
	r._revisar_llegada()
	r.tiempo_restante = 5.0
	r.moto.pos = r.pedido.cliente
	r._revisar_llegada()
	t.check(ev_r.has("tarde"), "entregar con el tiempo justo saca la excusa")
	t.check(ev_r.has("pedido"), "cada pedido nuevo se anuncia")

	# Zonas por moto: la Bwis no va a El Alto ni a la industrial; la Ninja va a todas.
	for id in MOTOS.ORDEN:
		t.check(MOTOS.get_moto(id).zonas.size() >= 2, "la %s dice qué zonas abre" % id)
	t.check(not MOTOS.get_moto("bws").zonas.has("rica") and MOTOS.get_moto("ninja").zonas.has("rica"), "El Alto se abre con la Ninja")
	var b = PARTIDA.new(21)
	var fuera := 0
	for k in 60:
		b._nuevo_pedido()
		for punto in [b.pedido.restaurante, b.pedido.cliente]:
			if not MOTOS.get_moto("bws").zonas.has(b.ciudad.zona_en(punto + Vector2(0, 3))):
				fuera += 1
	t.check_eq(fuera, 0, "con la Bwis los pedidos quedan en sus zonas")
	var n = PARTIDA.new(21, MOTOS.get_moto("ninja"))
	var en_alto := 0
	for k in 120:
		n._nuevo_pedido()
		if n.ciudad.zona_en(n.pedido.cliente + Vector2(0, 3)) == "rica":
			en_alto += 1
	t.check(en_alto > 0, "con la Ninja salen pedidos a El Alto (%d)" % en_alto)

	# Cada moto: estadísticas, precio y remate (criterio 2 de la F5).
	for id in MOTOS.ORDEN:
		var m: Dictionary = MOTOS.get_moto(id)
		t.check(m.vel_max > 0 and m.acel > 0 and m.freno > 0 and m.has("precio"), "la %s tiene estadísticas y precio" % id)
		t.check(str(m.get("remate", "")).contains(m.nombre), "la %s tiene su remate con su nombre" % id)

	# El final (DISENO §15.2): con la Ninja, el último pedido es a la loma, la clienta es la mamá.
	var f = PARTIDA.new(3, MOTOS.get_moto("ninja"), true)
	t.check(f.es_final, "con la Ninja y sin final visto, sale el pedido final")
	t.check_eq(f.ciudad.zona_en(f.pedido.cliente + Vector2(0, 3)), "rica", "el pedido final va a la loma (El Alto)")
	t.check(f.pedido.cliente.x < f.ciudad.cruce(8, 0).x, "pegado a los cerros")
	t.check(f.pedido.nombre_cliente.to_lower().contains("mamá"), "la clienta es la mamá")
	var finales := []
	f.final_logrado.connect(func(msg): finales.append(msg))
	_entregar(f)
	t.check_eq(finales.size(), 1, "entregarlo cierra el juego con el final")
	t.check(finales[0].to_lower().contains("frío"), "y llegó frío: %s" % (finales[0] if finales.size() > 0 else ""))
	t.check(f.terminada, "el final termina la jornada")
	var nf = PARTIDA.new(3, MOTOS.get_moto("ninja"), false)
	t.check(not nf.es_final, "si ya se vio el final, los pedidos son normales")

	# Guardado: el final visto y los pedidos hechos quedan en el progreso.
	var ruta := "user://prueba_pedidos.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	var pr = PROGRESO.new(ruta)
	pr.entregas = 7
	pr.final_hecho = true
	pr.guardar()
	var pr2 = PROGRESO.new(ruta)
	t.check(pr2.entregas == 7 and pr2.final_hecho, "se guardan los pedidos hechos y el final")
	t.check(pr2.toca_final() == false, "con el final visto, no vuelve a tocar")
	pr2.final_hecho = false
	pr2.moto = "ninja"
	t.check(pr2.toca_final(), "con la Ninja y sin final, toca el final")
	pr2.estrenar = "ninja"
	t.check_eq(pr2.estrenando(), "ninja", "la moto recién comprada se estrena en la próxima jornada")
	t.check_eq(pr2.estrenando(), "", "solo una vez")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))

	# Criterio 1 de la F5: una partida entera de la Bwis a la Ninja, sin quedarse sin plata ni bloqueada.
	_partida_entera(t)


## Simula jornadas con pedidos entregados a un ritmo realista (pagos de pago_por con el tiempo que
## sobra al ir a 8 m/s de promedio más algo de racha) y compra en el taller lo que alcance, en orden.
func _partida_entera(t) -> void:
	var ruta := "user://prueba_entera.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	var pr = PROGRESO.new(ruta)
	var pedidos := 0
	var p = PARTIDA.new(4242, pr.datos_moto())
	while pr.moto != "ninja" and pedidos < 200:
		# Un pedido típico: le sobra el tiempo extra más lo que gana la moto sobre el promedio.
		var vel_media: float = minf(float(pr.datos_moto().vel_max) * 0.45, 14.0)
		var recorrido: float = (p.tiempo_restante - PARTIDA.TIEMPO_EXTRA) * PARTIDA.VEL_PROMEDIO
		var sobra: float = maxf(p.tiempo_restante - recorrido / vel_media, 0.0)
		pr.ganar(PARTIDA.pago_por(sobra, false, 0.95, 1))
		pedidos += 1
		p._nuevo_pedido()
		# Taller: mejoras de la moto en uso y la siguiente moto, lo que alcance.
		var compro := true
		while compro:
			compro = false
			if pr.puede_comprar_moto():
				compro = pr.comprar_moto()
				p = PARTIDA.new(4242 + pedidos, pr.datos_moto())
			for mej in MOTOS.MEJORAS:
				if pr.puede_mejorar(mej) and pr.dinero - pr.precio_mejora(mej) >= 0 and pr.moto != "ninja":
					compro = pr.comprar_mejora(mej) or compro
	t.check_eq(pr.moto, "ninja", "la partida simulada llega a la Ninja")
	t.check(pedidos >= 15 and pedidos <= 40, "en unos 20–30 pedidos (%d)" % pedidos)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
