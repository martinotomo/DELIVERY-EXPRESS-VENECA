extends RefCounted
## Contrato de los peligros de la vía (F4, D27): huecos y manchas de aceite fijos en la calzada, y
## perros que se atraviesan. Cada uno con su caída y su remate (DISENO §5.5).

const CIUDAD := preload("res://scripts/ciudad.gd")
const PELIGROS := preload("res://scripts/peligros.gd")
const PERROS := preload("res://scripts/perros.gd")
const PARTIDA := preload("res://scripts/partida.gd")
const MOTOS := preload("res://scripts/motos.gd")
const VOCES := preload("res://scripts/voces.gd")


func run(t) -> void:
	var c = CIUDAD.new(1234)
	var pg = PELIGROS.new(1234, c)
	var huecos: Array = pg.lista.filter(func(h): return h.tipo == "hueco")
	var aceites: Array = pg.lista.filter(func(h): return h.tipo == "aceite")
	t.check(huecos.size() > 300, "la ciudad tiene huecos (%d)" % huecos.size())
	t.check(aceites.size() > 60, "y manchas de aceite (%d)" % aceites.size())
	var en_via := true
	for h in pg.lista:
		if c.distancia_anden(h.pos) < h.radio + 0.2:
			en_via = false
	t.check(en_via, "todos quedan en la calzada, no en el andén")
	var otra = PELIGROS.new(1234, c)
	t.check_eq(otra.lista[7].pos, pg.lista[7].pos, "con la misma semilla quedan en el mismo sitio (la ciudad no cambia)")
	# Más huecos en el barrio y la zona industrial que en El Alto.
	var por_zona := {}
	for h in huecos:
		var z: String = c.zona_en(h.pos)
		por_zona[z] = por_zona.get(z, 0) + 1
	var tramos := {}
	for z in c.NOMBRES_ZONA:
		tramos[z] = 0
	for j in c.N_LARGO:
		for i in c.N_ANCHO:
			tramos[c.zona(i, j)] += 1
	var dens: Callable = func(z): return float(por_zona.get(z, 0)) / maxf(tramos[z], 1.0)
	t.check(dens.call("industrial") > dens.call("rica") * 3.0 and dens.call("barrio") > dens.call("rica") * 3.0,
		"El Alto casi no tiene huecos (%.2f por cuadra contra %.2f del barrio)" % [dens.call("rica"), dens.call("barrio")])
	var h0: Dictionary = huecos[0]
	t.check_eq(pg.en(h0.pos).get("id", -1), h0.id, "pisar el hueco lo encuentra")
	t.check(pg.en(h0.pos + Vector2(h0.radio + 0.5, 0)).is_empty() or pg.en(h0.pos + Vector2(h0.radio + 0.5, 0)).id != h0.id, "y fuera del hueco no")
	t.check(pg.cerca(h0.pos, 30.0).size() >= 1, "cerca() da los de alrededor para dibujarlos")

	# Hueco a toda: se mata con su remate. Despacio: brinca, frena y riega el pedido.
	var p = _partida()
	var vmax: float = p.moto.moto.vel_max
	var evs: Array[String] = []
	p.evento.connect(func(e): evs.append(e))
	var remate := [""]
	p.terminada_por.connect(func(m): remate[0] = m)
	_pisar(p, "hueco", vmax * 0.95)
	t.check(p.terminada, "caer en un hueco a más del %d %% de la máxima mata" % roundi(PARTIDA.HUECO_MORTAL * 100))
	t.check_eq(p.causa, "hueco", "la causa queda anotada (para la cinemática)")
	t.check(remate[0].contains("el hueco llevaba ahí más tiempo que tu Bwis"), "con el remate del hueco: %s" % remate[0])

	p = _partida()
	evs.clear()
	p.evento.connect(func(e): evs.append(e))
	p.fase = p.ENTREGAR
	p.pedido.tipo = "sopa"
	_pisar(p, "hueco", vmax * 0.5)
	t.check(not p.terminada, "despacio no mata")
	t.check(p.moto.vel < vmax * 0.5 * 0.6, "pero frena en seco (%.1f m/s)" % p.moto.vel)
	t.check(evs.has("bache"), "y el domiciliario se queja (evento bache)")
	t.check(p.estado_pedido < 1.0, "y la sopa se riega (%.0f %%)" % (p.estado_pedido * 100))

	# Aceite: el manubrio casi no gira mientras se está encima.
	p = _partida()
	_pisar(p, "aceite", 10.0)
	t.check(p.moto.agarre_suelo < 0.5, "sobre el aceite el manubrio casi no agarra (%.2f)" % p.moto.agarre_suelo)
	p.moto.pos += p.moto.direccion() * 30.0
	p.advance(0.02, false, false, 0.0)
	t.check_eq(p.moto.agarre_suelo, 1.0, "al salir del aceite vuelve a agarrar")

	# Perros: pocos, se atraviesan por delante de la moto, de andén a andén.
	var pr = PERROS.new(3, c)
	var centro: Vector2 = c.cruce(20, 40) + Vector2(-40, 0)
	for k in 800:
		pr.advance(0.1, centro, Vector2.LEFT)
	t.check(pr.aparecidos >= 3, "salen perros de vez en cuando (%d en 80 s)" % pr.aparecidos)
	t.check(pr.lista.size() <= pr.MAX, "nunca más de %d a la vez" % pr.MAX)
	var perro: Dictionary = pr.poner(centro + Vector2.LEFT * 30.0, Vector2.LEFT)
	t.check(absf(perro.dir.dot(Vector2.LEFT)) < 0.01, "cruza de lado, atravesado en la vía")
	var antes: Vector2 = perro.pos
	pr.advance(1.0, centro, Vector2.LEFT)
	t.check(perro.pos.distance_to(antes) > 1.0, "y camina")

	# Pegarle a un perro a toda mata («el perro sobrevivió»); despacio, frena y el perro huye.
	p = _partida()
	remate[0] = ""
	p.terminada_por.connect(func(m): remate[0] = m)
	var m = p.moto
	m.vel = m.moto.vel_max * 0.9
	p.perros.poner(m.pos + m.direccion() * 0.3, m.direccion())
	p.advance(0.02, true, false, 0.0)
	t.check(p.terminada and p.causa == "perro", "atropellar un perro a toda mata")
	t.check(remate[0].contains("el perro sobrevivió. El pedido no"), "con su remate: %s" % remate[0])
	p = _partida()
	evs.clear()
	p.evento.connect(func(e): evs.append(e))
	m = p.moto
	m.vel = m.moto.vel_max * 0.3
	var dg: Dictionary = p.perros.poner(m.pos + m.direccion() * 0.3, m.direccion())
	p.advance(0.02, false, false, 0.0)
	t.check(not p.terminada and evs.has("perro"), "despacio no mata: el perro sale corriendo y el domiciliario grita")
	t.check_eq(dg.estado, PERROS.HUYE, "el perro huye")
	# Pasarle rozando sin tocarlo suma a la racha de fe.
	p = _partida()
	m = p.moto
	m.vel = m.moto.vel_max * 0.8
	var lado: Vector2 = m.direccion().orthogonal()
	p.perros.poner(m.pos + m.direccion() * 0.3 + lado * (float(m.moto.radio) + p.perros.RADIO + 0.6), m.direccion())
	p.advance(0.02, true, false, 0.0)
	t.check_eq(p.racha, 1, "esquivar un perro por poco cuenta como casi-choque")

	# Lluvia: estrellarse en el andén mojado tiene su propio remate.
	p = _partida()
	remate[0] = ""
	p.terminada_por.connect(func(msg): remate[0] = msg)
	p.clima.empezar_lluvia(60.0)
	m = p.moto
	m.vel = m.moto.vel_max
	var hasta := 200
	while not p.terminada and hasta > 0:
		p.advance(0.05, true, false, 1.0)
		hasta -= 1
	t.check_eq(p.causa, "lluvia", "estrellarse lloviendo tiene causa lluvia")
	t.check(remate[0].contains("tu fe era impermeable"), "remate de lluvia: %s" % remate[0])

	# Bus y contravía: de frente y a toda, sí mata (despacio sigue como en D26: frena y pita).
	for caso in [["bus", "el bus también tenía fe"], ["contravia", "la contravía era un atajo"]]:
		p = _partida()
		remate[0] = ""
		p.terminada_por.connect(func(msg): remate[0] = msg)
		m = p.moto
		m.vel = m.moto.vel_max * 0.9
		var tipo: String = "bus" if caso[0] == "bus" else "carro"
		var v: Dictionary = p.trafico.poner(tipo, Vector2i(20, 40), -m.direccion(), 10.0)
		v.pos = m.pos + m.direccion() * (float(v.largo) / 2.0 + 0.4)
		v.dir = -m.direccion()
		p.advance(0.02, true, false, 0.0)
		t.check(p.terminada and p.causa == caso[0], "de frente y a toda contra un %s: causa %s (%s)" % [tipo, caso[0], p.causa])
		t.check(remate[0].contains(caso[1]), "remate: %s" % remate[0])
	p = _partida()
	m = p.moto
	m.vel = m.moto.vel_max * 0.4
	var v2: Dictionary = p.trafico.poner("bus", Vector2i(20, 40), -m.direccion(), 10.0)
	v2.pos = m.pos + m.direccion() * (float(v2.largo) / 2.0 + 0.4)
	v2.dir = -m.direccion()
	p.advance(0.02, true, false, 0.0)
	t.check(not p.terminada, "despacio contra un bus no mata (D26)")

	# Cada causa tiene remate por moto y su dibujo de caída.
	for id in MOTOS.ORDEN:
		var datos: Dictionary = MOTOS.get_moto(id)
		for causa in MOTOS.CAUSAS:
			var r: String = MOTOS.remate(causa, datos.nombre)
			t.check(r.contains(datos.nombre) or causa in ["perro", "bus", "contravia"], "remate %s de %s" % [causa, id])
			var png := "res://assets/ui/cinematica_%s_%s.png" % [causa, id] if causa != "curva" else "res://assets/ui/cinematica_%s.png" % id
			t.check(ResourceLoader.exists(png), "hay dibujo de la caída: %s" % png)
	for e in ["bache", "perro"]:
		t.check(VOCES.FRASES.has(e), "el domiciliario dice algo al %s" % e)


func _partida():
	var p = PARTIDA.new(77)
	p.trafico.MAX_ACTIVOS = 0
	p.trafico.lista.clear()
	p.perros.MAX_ACTIVOS = 0
	p.peatones.lista.clear()
	return p


## Pone la moto justo antes de un peligro del tipo dado, alineada con su vía, y avanza sobre él.
func _pisar(p, tipo: String, vel: float) -> void:
	var h: Dictionary = {}
	for x in p.peligros.lista:
		if x.tipo == tipo and p.ciudad.distancia_anden(x.pos) > 3.0:
			h = x
			break
	var m = p.moto
	m.rumbo = 0.0 if h.eje.x != 0.0 else PI / 2.0
	m.pos = h.pos - m.direccion() * 0.3
	m.vel = vel
	p.advance(0.02, false, false, 0.0)
