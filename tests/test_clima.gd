extends RefCounted
## Lluvia rara, bono mientras llueve y charcos que frenan (Tomás, 30/09).

const CLIMA := preload("res://scripts/clima.gd")
const CIUDAD := preload("res://scripts/ciudad.gd")
const PARTIDA := preload("res://scripts/partida.gd")

var ciudad = CIUDAD.new(1)


func run(t) -> void:
	var c = CLIMA.new(5, ciudad)
	var centro: Vector2 = ciudad.cruce(20, 40)
	t.check(not c.lloviendo(), "se empieza seco")
	c.advance(CLIMA.PRIMERA.x - 1.0, centro)
	t.check(not c.lloviendo(), "los primeros 6 minutos no llueve")
	t.check_eq(c.charcos.size(), 0, "seco, no hay charcos")

	# Una hora de juego: cuántos aguaceros y cuánto duran.
	c = CLIMA.new(5, ciudad)
	var aguaceros := 0
	var llovido := 0.0
	var antes := false
	var paso := 1.0
	for k in 3600:
		c.advance(paso, centro)
		if c.lloviendo():
			llovido += paso
			if not antes:
				aguaceros += 1
		antes = c.lloviendo()
	t.check(aguaceros >= 2 and aguaceros <= 5, "en una hora llueve pocas veces (%d)" % aguaceros)
	t.check(llovido / 3600.0 < 0.2, "llueve menos del 20 %% del tiempo (%.0f %%)" % (llovido / 36.0))
	t.check(llovido / aguaceros >= CLIMA.DURA.x - 1.0 and llovido / aguaceros <= CLIMA.DURA.y + 1.0, "cada aguacero dura 1 a 2 min (%.0f s)" % (llovido / aguaceros))

	# Charcos: se forman con la lluvia, en la calzada, y se secan después.
	c = CLIMA.new(9, ciudad)
	c.empezar_lluvia(90.0)
	c.advance(5.0, centro)
	var pocos: int = c.charcos.size()
	for k in 60:
		c.advance(1.0, centro)
	t.check(c.intensidad > 0.99, "a los segundos llueve a toda")
	t.check(c.charcos.size() > pocos and c.charcos.size() >= CLIMA.MAX_CHARCOS * 0.8, "con la lluvia se van formando charcos (%d → %d)" % [pocos, c.charcos.size()])
	var en_calle := true
	for ch in c.charcos:
		if ciudad.distancia_anden(ch.pos) < ch.radio:
			en_calle = false
	t.check(en_calle, "todos los charcos están en la calzada, no en el andén")
	var v0: int = c.version
	for k in 60:
		c.advance(1.0, centro)
	t.check(not c.lloviendo(), "el aguacero se acaba")
	for k in int(CLIMA.SECAR) + 5:
		c.advance(1.0, centro)
	t.check_eq(c.charcos.size(), 0, "al escampar los charcos se secan")
	t.check(c.version != v0, "el dibujo de los charcos se entera de los cambios")

	# En la partida: bono con lluvia y charco que frena un 15 %, una vez.
	t.check_eq(PARTIDA.pago_por(20.0, true), int(round(PARTIDA.pago_por(20.0) * 1.3 / 100.0)) * 100, "con lluvia el pedido paga +30 %")
	var p = PARTIDA.new(1234)
	var ev := []
	p.evento.connect(func(e): ev.append(e))
	p.clima.empezar_lluvia(60.0)
	t.check(ev.has("lluvia"), "empezar a llover avisa (subtítulo)")
	p.moto.pos = p.pedido.restaurante
	p._revisar_llegada()
	p.moto.pos = p.pedido.cliente
	var sobra: float = p.tiempo_restante
	var pagos := []
	p.pagado.connect(func(x): pagos.append(x))
	p._revisar_llegada()
	t.check(pagos.size() == 1 and pagos[0] == PARTIDA.pago_por(sobra, true), "entregar lloviendo cobra el bono")
	p.clima.charcos.assign([{"pos": p.moto.pos + Vector2(3, 0), "radio": 1.5}])
	p.moto.vel = 20.0
	p.moto.pos += Vector2(3, 0)
	p._revisar_charco()
	t.check(absf(p.moto.vel - 17.0) < 0.01, "pisar un charco quita el 15 %% (%.1f m/s)" % p.moto.vel)
	t.check(ev.has("charco"), "suena el charco")
	p._revisar_charco()
	t.check(absf(p.moto.vel - 17.0) < 0.01, "seguir encima del mismo charco no frena otra vez")
	p.moto.pos += Vector2(10, 0)
	p._revisar_charco()
	p.moto.pos -= Vector2(10, 0)
	p._revisar_charco()
	t.check(p.moto.vel < 17.0, "volver a entrar sí frena")
