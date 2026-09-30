extends RefCounted
## Peatones (Tomás, 30/09): pocos, de vez en cuando, cruzando por las cebras de las esquinas;
## atropellar a uno tiene su sonido y sus frases, y el pedido se queda sin propina.

const PEATONES := preload("res://scripts/peatones.gd")
const CIUDAD := preload("res://scripts/ciudad.gd")
const PARTIDA := preload("res://scripts/partida.gd")
const VOCES := preload("res://scripts/voces.gd")
const AUDIO := preload("res://scripts/audio.gd")

var ciudad = CIUDAD.new(1)


func run(t) -> void:
	_cebras(t)
	_pocos_y_por_la_cebra(t)
	_atropello(t)
	_frases_y_sonido(t)


func _cebras(t) -> void:
	# Una esquina del centro tiene sus cuatro cebras; una del borde, solo las que tienen andén a los lados.
	t.check_eq(ciudad.cebras(20, 40).size(), 4, "una esquina del centro tiene 4 cebras")
	t.check_eq(ciudad.cebras(0, 0).size(), 0, "la esquina del borde de la ciudad no tiene cebras")
	var bien := true
	for cb in ciudad.cebras(20, 40):
		var r: Rect2 = CIUDAD.rect_cebra(cb)
		# La cebra atraviesa la calzada de andén a andén: sus dos puntas tocan andén, el medio no.
		var cruza: Vector2 = cb.cruza
		var punta_a: Vector2 = cb.centro - cruza * (cb.largo / 2.0 + 0.3)
		var punta_b: Vector2 = cb.centro + cruza * (cb.largo / 2.0 + 0.3)
		if ciudad.en_anden(cb.centro, 0.0) or not ciudad.en_anden(punta_a, 0.0) or not ciudad.en_anden(punta_b, 0.0):
			bien = false
		if not ciudad.en_cebra(cb.centro) or not r.has_point(cb.centro):
			bien = false
	t.check(bien, "cada cebra cruza la calle de andén a andén")
	t.check(not ciudad.en_cebra(ciudad.cruce(20, 40)), "el centro del cruce no es cebra")


func _pocos_y_por_la_cebra(t) -> void:
	var p = PEATONES.new(4, ciudad)
	# La moto va y viene por una calle larga, como jugando.
	var y: float = ciudad.cruce(0, 40).y
	var x0: float = ciudad.cruce(12, 40).x
	var x1: float = ciudad.cruce(28, 40).x
	var x := x0
	var sentido := 1.0
	var mas := 0
	var suma := 0.0
	var fuera := 0
	var cerca := 0
	var delante := 0
	var vistos := {}
	var cruzaron := 0
	var paso := 0.25
	var n := int(1200.0 / paso)  # 20 minutos
	for k in n:
		x += sentido * 12.0 * paso
		if x > x1 or x < x0:
			sentido = -sentido
		var centro := Vector2(x, y)
		var dir := Vector2(sentido, 0.0)
		var antes: int = p.aparecidos
		p.advance(paso, centro, dir)
		if p.aparecidos > antes:
			var nuevo: Dictionary = p.lista[p.lista.size() - 1]
			if nuevo.camino[1].distance_to(centro) < PEATONES.DISTANCIA.x - 8.0:
				cerca += 1
			if (nuevo.camino[1] - centro).dot(dir) > 0.0:
				delante += 1
		mas = maxi(mas, p.lista.size())
		suma += p.lista.size()
		for q in p.lista:
			if not (ciudad.en_anden(q.pos, 0.0) or ciudad.en_cebra(q.pos)):
				fuera += 1
			if ciudad.en_cebra(q.pos):
				vistos[q.camino[1]] = true
			if q.tramo >= 3 and not vistos.get(q.camino[1], false):
				fuera += 1 # llegó al otro lado sin pasar por la cebra
		cruzaron = vistos.size()
	t.check(mas <= PEATONES.MAX, "nunca hay más de %d peatones a la vez (%d)" % [PEATONES.MAX, mas])
	t.check(suma / n < 1.5, "casi siempre hay pocos: %.1f en promedio" % (suma / n))
	t.check(p.aparecidos >= 40 and p.aparecidos <= 180, "de vez en cuando aparece uno: %d en 20 min" % p.aparecidos)
	t.check(cruzaron >= 30, "y cruzan la calle (%d cebras usadas)" % cruzaron)
	t.check_eq(fuera, 0, "solo caminan por el andén y por la cebra")
	t.check_eq(cerca, 0, "nunca aparecen encima de la moto (a menos de %d m)" % int(PEATONES.DISTANCIA.x))
	t.check(delante >= p.aparecidos * 0.6, "casi siempre aparecen por donde va la moto (%d de %d)" % [delante, p.aparecidos])


func _atropello(t) -> void:
	var pa = PARTIDA.new(3)
	var eventos: Array[String] = []
	pa.evento.connect(func(e): eventos.append(e))
	pa.peatones._t = 9999.0 # que no salgan otros
	# La moto sale del cruce (20, 40) hacia el oriente: la cebra de ese lado le queda de frente.
	var cb: Dictionary = {}
	for c in pa.ciudad.cebras(20, 40):
		if c.cruza == Vector2(0, 1) and c.centro.x > pa.moto.pos.x:
			cb = c
	var peaton: Dictionary = pa.peatones.poner_en(cb)
	peaton.pos = cb.centro - cb.cruza * 0.6 # entrando al carril de la moto
	peaton.tramo = 2
	pa.moto.pos = cb.centro - Vector2(6.0, 0.0)
	pa.moto.vel = 8.0
	for k in 240:
		pa.advance(1.0 / 60.0, true, false, 0.0)
		if eventos.has("atropello"):
			break
	t.check(eventos.has("atropello"), "pasar por encima de un peatón es un atropello")
	t.check_eq(pa.moto.vel, 0.0, "la moto frena en seco")
	t.check(not pa.terminada, "atropellar no mata al domiciliario: sigue el turno")
	t.check(pa.multado, "el pedido queda sin propina")
	t.check_eq(peaton.estado, PEATONES.CAIDO, "el peatón queda en el piso")
	var n_atropellos := eventos.count("atropello")
	# Se levanta, grita y se va; no se le puede volver a atropellar.
	for k in int((PEATONES.T_CAIDO + 0.2) * 60.0):
		pa.advance(1.0 / 60.0, false, false, 0.0)
	t.check(eventos.has("grito"), "a los segundos se levanta y le grita")
	t.check_eq(peaton.estado, PEATONES.GRITA, "está parado gritando")
	t.check_eq(pa.peatones.atropellar(peaton.pos, 10.0), -1, "al mismo peatón no se le atropella dos veces")
	for k in int((PEATONES.T_GRITO + 0.2) * 60.0):
		pa.advance(1.0 / 60.0, false, false, 0.0)
	t.check_eq(peaton.estado, PEATONES.CAMINA, "después sigue caminando")
	t.check_eq(eventos.count("atropello"), n_atropellos, "un solo atropello por peatón")
	# Un toquecito casi parado no cuenta.
	var otro: Dictionary = pa.peatones.poner_en(cb)
	t.check_eq(pa.peatones.atropellar(otro.pos, 0.5), -1, "rozar a alguien casi parado no es atropello")
	# Pagar: sin propina (solo la tarifa, con el bono de la lluvia si llueve).
	pa.fase = pa.ENTREGAR
	pa.tiempo_restante = 100.0
	pa.moto.pos = pa.pedido.cliente
	pa.moto.vel = 0.0
	var pagos: Array[int] = []
	pa.pagado.connect(func(v): pagos.append(v))
	pa._revisar_llegada()
	t.check_eq(pagos, [PARTIDA.pago_por(0.0)], "entregar después de atropellar paga solo la tarifa")
	t.check(PARTIDA.pago_por(100.0) > PARTIDA.pago_por(0.0), "sin atropello habría pagado propina")
	t.check(not pa.multado, "el pedido siguiente vuelve a tener propina")


func _frases_y_sonido(t) -> void:
	for ev in ["atropello", "grito"]:
		t.check(VOCES.FRASES.get(ev, []).size() >= 3, "hay varias frases para «%s»" % ev)
	var gritos_ok := true
	for f in VOCES.FRASES.grito:
		if not f.begins_with("Peatón: "):
			gritos_ok = false
	t.check(gritos_ok, "el grito se marca como del peatón en el subtítulo")
	t.check_eq(AUDIO.EFECTOS.get("atropello", ""), "atropello", "el atropello tiene su propio sonido")
	t.check(load("res://assets/sonidos/atropello.wav") != null, "el sonido del atropello existe e importa")
