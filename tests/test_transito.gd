extends RefCounted
## Contrato de los semáforos y las señales (Tomás, 30/09: la ciudad con más cositas).

const CIUDAD := preload("res://scripts/ciudad.gd")
const TRANSITO := preload("res://scripts/transito.gd")


func run(t) -> void:
	var c = CIUDAD.new(1234)
	var tr = TRANSITO.new(c)
	# El ciclo: nunca verde (ni amarillo) para los dos ejes a la vez, y cada eje pasa por los tres.
	var vistas := {"x": {}, "y": {}}
	var chocan := false
	for k in 400:
		tr.advance(0.1)
		var lx: String = tr.luz("x")
		var ly: String = tr.luz("y")
		vistas.x[lx] = true
		vistas.y[ly] = true
		if lx != "rojo" and ly != "rojo":
			chocan = true
	t.check(not chocan, "nunca tienen paso las calles y las carreras a la vez")
	t.check(vistas.x.size() == 3 and vistas.y.size() == 3, "cada eje pasa por verde, amarillo y rojo")
	tr.t = 0.0
	t.check_eq(tr.luz("x"), "verde", "al empezar el ciclo las calles tienen verde")
	tr.advance(TRANSITO.VERDE + 0.5)
	t.check_eq(tr.luz("x"), "amarillo", "después del verde viene el amarillo")
	tr.advance(TRANSITO.CICLO * 3.0)
	t.check_eq(tr.luz("x"), "amarillo", "el ciclo se repite igual")

	# Dónde van.
	var sem: Array = tr.semaforos()
	t.check(sem.size() > 200 and sem.size() < 2000, "hay semáforos, pero no en todos los cruces (%d)" % sem.size())
	t.check(sem.size() % 4 == 0, "cuatro por cruce, uno por cada lado")
	var en_anden := true
	var lejos_de_la_luz := true
	for s in sem:
		if c.distancia_anden(s.pos) > 0.0 or c.en_cebra(s.pos):
			en_anden = false
		var r: Rect2 = c.cuadra(c._indice(c.inicio_x, s.pos.x), c._indice(c.inicio_y, s.pos.y))
		for esquina in [r.position + Vector2(1, 1), r.end - Vector2(1, 1)]:
			if s.pos.distance_to(esquina) < 0.6:
				lejos_de_la_luz = false
	t.check(en_anden, "los semáforos están en el andén, no en la calzada")
	t.check(lejos_de_la_luz, "y no se montan en los postes de luz")
	var s0: Dictionary = sem[0]
	t.check(s0.eje == ("x" if s0.dir.x != 0.0 else "y"), "cada semáforo sabe de qué eje es")
	var sen: Array = tr.senales()
	var tipos := {}
	var sen_ok := true
	for s in sen:
		tipos[s.tipo] = tipos.get(s.tipo, 0) + 1
		if c.distancia_anden(s.pos) > 0.0:
			sen_ok = false
	t.check(tipos.has("pare") and tipos.has("peatones") and tipos.has("velocidad"), "hay PARE, señal de peatones y de velocidad (%s)" % tipos)
	t.check(sen_ok, "las señales están en el andén")
	t.check(sen.size() < 5000, "no llenan la ciudad de postes (%d)" % sen.size())
	t.check_eq(TRANSITO.new(c).senales().size(), sen.size(), "siempre salen en el mismo sitio")
