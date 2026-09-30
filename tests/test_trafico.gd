extends RefCounted
## Contrato del tráfico (F3): carros, taxis, buses y camiones por su carril, que paran en rojo,
## no se atraviesan entre ellos y se estrellan con la moto sin matarla.

const CIUDAD := preload("res://scripts/ciudad.gd")
const TRANSITO := preload("res://scripts/transito.gd")
const TRAFICO := preload("res://scripts/trafico.gd")
const PARTIDA := preload("res://scripts/partida.gd")
const VOCES := preload("res://scripts/voces.gd")


func run(t) -> void:
	var c = CIUDAD.new(1234)
	var tr = TRANSITO.new(c)
	var tf = TRAFICO.new(5, c, tr)
	var centro: Vector2 = c.cruce(20, 40)

	# Aparecen cerca, casi todos por delante, siempre en la calzada y por su carril derecho.
	tf.advance(0.1, centro, Vector2.RIGHT)
	t.check_eq(tf.lista.size(), tf.MAX, "hay %d vehículos cerca de la moto" % tf.MAX)
	var en_via := true
	var derecha := true
	var adelante := 0
	for v in tf.lista:
		if c.en_anden(v.pos, 0.3):
			en_via = false
		# El carril: a la derecha del centro de su vía, según hacia dónde va.
		var via: Vector2 = c.cruce(v.via.x, v.via.y)
		var lado: float = (v.pos - via).dot(Vector2(-v.dir.y, v.dir.x))
		if absf(lado - tf.CARRIL) > 0.01:
			derecha = false
		if (v.pos - centro).dot(Vector2.RIGHT) > 0.0:
			adelante += 1
	t.check(en_via, "todos aparecen en la calzada")
	t.check(derecha, "todos van por su carril derecho (a %.1f m del centro)" % tf.CARRIL)
	t.check(adelante > tf.MAX / 2, "la mayoría aparece por delante (%d de %d)" % [adelante, tf.MAX])
	var tipos := {}
	for v in tf.lista:
		tipos[v.tipo] = true
	t.check(tipos.size() >= 2, "hay de varios tipos: %s" % str(tipos.keys()))
	for tipo in tf.TIPOS:
		t.check(tf.TIPOS[tipo].largo > tf.TIPOS[tipo].ancho, "%s es más largo que ancho" % tipo)

	# Andan: tras 2 s, cada uno avanzó en su dirección sin salirse del carril.
	var antes := {}
	for v in tf.lista:
		antes[v.id] = v.pos
	tr.t = 0.0
	tf.advance(2.0, centro, Vector2.RIGHT)
	var avanzan := 0
	for v in tf.lista:
		if antes.has(v.id) and (v.pos - antes[v.id]).dot(v.dir) > 5.0:
			avanzan += 1
	t.check(avanzan >= tf.MAX / 2, "los vehículos andan (%d)" % avanzan)

	# Semáforo en rojo: un carro que llega a un cruce con semáforo para antes de la cebra.
	var tf2 = TRAFICO.new(5, c, tr)
	tf2.MAX_ACTIVOS = 0 # solo el de la prueba
	var i := 21
	var j := 42
	t.check(tr.tiene_semaforo(i, j), "el cruce (21, 42) tiene semáforo")
	var v: Dictionary = tf2.poner("carro", Vector2i(i, j), Vector2.RIGHT, 60.0) # por la calle, a 60 m antes
	tr.t = tr.CICLO / 2.0 + 1.0 # rojo para las calles (eje x)
	t.check_eq(tr.luz("x"), "rojo", "las calles tienen rojo")
	for k in 600:
		tf2.advance(1.0 / 30.0, v.pos, Vector2.ZERO)
		tr.t = tr.CICLO / 2.0 + 1.0
	var linea: float = c.cruce(i, j).x - c.CALLE / 2.0 - c.CEBRA
	t.check(v.vel < 0.1, "en rojo se detiene (%.1f m/s)" % v.vel)
	t.check(v.pos.x < linea and v.pos.x > linea - 8.0, "para justo antes de la cebra (%.1f m antes)" % (linea - v.pos.x))
	tr.t = 0.0 # verde para las calles
	for k in 90:
		tf2.advance(1.0 / 30.0, v.pos, Vector2.ZERO)
	t.check(v.vel > 2.0, "con verde arranca otra vez (%.1f m/s)" % v.vel)

	# No se atraviesan: el de atrás frena detrás del de adelante.
	var tf3 = TRAFICO.new(6, c, tr)
	tf3.MAX_ACTIVOS = 0
	tr.t = tr.CICLO / 2.0 + 1.0 # rojo
	var a: Dictionary = tf3.poner("bus", Vector2i(i, j), Vector2.RIGHT, 45.0)
	var b: Dictionary = tf3.poner("taxi", Vector2i(i, j), Vector2.RIGHT, 95.0)
	for k in 900:
		tf3.advance(1.0 / 30.0, a.pos, Vector2.ZERO)
		tr.t = tr.CICLO / 2.0 + 1.0
	var hueco: float = (a.pos - b.pos).dot(Vector2.RIGHT) - (tf3.TIPOS.bus.largo + tf3.TIPOS.taxi.largo) / 2.0
	t.check(hueco > 0.5 and hueco < 6.0, "el taxi hace fila detrás del bus (%.1f m de hueco)" % hueco)

	# No le pasan por encima a la moto: si está en su carril, frenan.
	var tf4 = TRAFICO.new(7, c, tr)
	tf4.MAX_ACTIVOS = 0
	tr.t = 0.0
	var m: Dictionary = tf4.poner("camion", Vector2i(i, j), Vector2.RIGHT, 90.0)
	var moto_pos: Vector2 = m.pos + Vector2.RIGHT * 25.0
	for k in 300:
		tf4.advance(1.0 / 30.0, moto_pos, Vector2.ZERO)
		tr.t = 0.0
	t.check((moto_pos - m.pos).x > tf4.TIPOS.camion.largo / 2.0 + 0.5, "el camión frena detrás de la moto (%.1f m)" % (moto_pos - m.pos).x)

	# Choque: chocado(p, radio) dice qué vehículo toca ese punto.
	t.check_eq(tf4.chocado(m.pos, 0.3), m.id, "tocar un vehículo se detecta")
	t.check_eq(tf4.chocado(m.pos + Vector2(0, 5), 0.3), -1, "a 5 m de lado no")

	# Se reciclan: los que quedan lejos reaparecen cerca de la moto.
	var tf5 = TRAFICO.new(8, c, tr)
	tf5.advance(0.1, centro, Vector2.RIGHT)
	var lejos: Vector2 = c.cruce(5, 10)
	for k in 5:
		tf5.advance(0.1, lejos, Vector2.RIGHT)
	var cerca := true
	for w in tf5.lista:
		if w.pos.distance_to(lejos) > tf5.LEJOS:
			cerca = false
	t.check(cerca, "al irse la moto, el tráfico reaparece alrededor")

	# Mezcla por zona: en la industrial hay camiones; en el centro, buses.
	t.check(tf.mezcla("industrial").get("camion", 0.0) > tf.mezcla("barrio").get("camion", 0.0), "más camiones en la zona industrial")
	t.check(tf.mezcla("centro").get("bus", 0.0) > tf.mezcla("rica").get("bus", 0.0), "más buses en el centro")

	# En la partida: chocar a un carro frena en seco y suena, pero no mata ni quita plata.
	var p = PARTIDA.new(3)
	var eventos: Array[String] = []
	p.evento.connect(func(e): eventos.append(e))
	p.trafico.MAX_ACTIVOS = 0
	p.trafico.lista.clear()
	var car: Dictionary = p.trafico.poner("taxi", Vector2i(20, 40), Vector2.RIGHT, -30.0) # pasado el cruce
	car.vel = 0.0
	p.moto.pos = car.pos - Vector2(3.0, 0)
	p.moto.rumbo = 0.0
	p.moto.vel = 12.0
	p.advance(0.1, true, false, 0.0)
	t.check(eventos.has("choque"), "chocar con un carro es un evento (%s)" % str(eventos))
	t.check(p.moto.vel < 0.5, "frena en seco")
	t.check(not p.terminada, "no mata")
	t.check(p.trafico.chocado(p.moto.pos, 0.2) == -1, "la moto queda por fuera del carro")
	for k in 20:
		p.advance(0.1, false, false, 0.0)
	t.check(eventos.has("pito"), "después del choque el conductor pita e insulta")
	t.check(VOCES.FRASES.has("choque") and VOCES.FRASES.has("pito"), "hay frases de choque y del conductor")
	var eventos2 := eventos.size()
	p.advance(0.1, false, false, 0.0)
	t.check_eq(eventos.count("choque"), 1, "quedarse pegado no repite el choque")
