extends RefCounted
## Contrato de la gente que camina por los andenes (Tomás, 30/09).

const CIUDAD := preload("res://scripts/ciudad.gd")
const TRANSEUNTES := preload("res://scripts/transeuntes.gd")


func run(t) -> void:
	var c = CIUDAD.new(1234)
	var g = TRANSEUNTES.new(1, c)
	var centro: Vector2 = c.cruce(20, 40)
	g.advance(0.1, centro)
	t.check_eq(g.lista.size(), TRANSEUNTES.MAX, "aparecen %d alrededor de la moto" % TRANSEUNTES.MAX)
	# Caminan siempre por el andén, nunca por la calzada ni dentro de los edificios.
	var siempre_anden := true
	var dentro := false
	var cerca := true
	var andado0: float = g.lista[0].andado
	for k in 600:
		g.advance(1.0 / 10.0, centro)
		for p in g.lista:
			if c.distancia_anden(p.pos) > 0.0:
				siempre_anden = false
			var r: Rect2 = c.cuadra(p.i, p.j)
			if r.grow(-c.ANDEN).has_point(p.pos):
				dentro = true
			if p.pos.distance_to(centro) > TRANSEUNTES.LEJOS + 5.0:
				cerca = false
	t.check(siempre_anden, "van siempre por el andén")
	t.check(not dentro, "no se meten en los edificios")
	t.check(cerca, "solo existen cerca de la moto")
	t.check(g.lista[0].andado > andado0 + 40.0, "caminan (%.0f m en un minuto)" % (g.lista[0].andado - andado0))
	# Dan la vuelta a la esquina sin salirse.
	var r2 := Rect2(0, 0, 10, 20)
	t.check_eq(TRANSEUNTES.punto(r2, 5.0), Vector2(5, 0), "la vuelta empieza por arriba")
	t.check_eq(TRANSEUNTES.punto(r2, 15.0), Vector2(10, 5), "dobla la esquina")
	t.check_eq(TRANSEUNTES.punto(r2, 60.0 + 35.0), Vector2(5, 20), "y sigue dando vueltas")
	# Si la moto se va lejos, la gente reaparece alrededor de ella.
	var otro: Vector2 = c.cruce(5, 70)
	g.advance(0.1, otro)
	var todos_cerca := true
	for p in g.lista:
		if p.pos.distance_to(otro) > TRANSEUNTES.CERCA.y + 30.0:
			todos_cerca = false
	t.check(todos_cerca, "al irse la moto, la gente reaparece cerca de ella")
	t.check_eq(g.lista.size(), TRANSEUNTES.MAX, "sin pasar de %d" % TRANSEUNTES.MAX)
	var ropas := {}
	for p in g.lista:
		ropas[p.ropa] = true
	t.check(ropas.size() >= 3, "con ropa variada (%d)" % ropas.size())
	# Casi todos aparecen por donde va la moto, para que se vean.
	var h = TRANSEUNTES.new(3, c)
	h.advance(0.1, centro, Vector2.RIGHT)
	var delante := 0
	for p in h.lista:
		if (p.pos - centro).x > 0.0:
			delante += 1
	t.check(delante >= TRANSEUNTES.MAX * 0.6, "la mayoría aparece adelante de la moto (%d de %d)" % [delante, TRANSEUNTES.MAX])
