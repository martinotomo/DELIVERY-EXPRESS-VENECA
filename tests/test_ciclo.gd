extends RefCounted
## Día y noche: un día completo cada 10 minutos, sin saltos.

const CICLO := preload("res://scripts/ciclo_dia.gd")


func run(t) -> void:
	var c = CICLO.new()
	t.check_eq(CICLO.PERIODO, 600.0, "un día dura 10 minutos")
	t.check(absf(c.hora() - 6.0) < 0.01, "arranca al amanecer, 6:00")
	c.advance(150.0)
	t.check(absf(c.hora() - 12.0) < 0.01, "a los 2,5 min es mediodía")
	t.check(c.luz() > 0.95, "mediodía a plena luz (%.2f)" % c.luz())
	c.advance(300.0)
	t.check(absf(c.hora() - 0.0) < 0.01 or absf(c.hora() - 24.0) < 0.01, "a los 7,5 min es medianoche")
	t.check(c.luz() < 0.05, "medianoche oscura (%.2f)" % c.luz())
	t.check(c.farola_encendida(), "de noche se prende la farola")
	c.advance(150.0)
	t.check(absf(c.hora() - 6.0) < 0.01, "a los 10 min vuelve a amanecer")

	# Sin saltos: la luz cambia poco de un fotograma a otro, en todo el día.
	var d = CICLO.new()
	var antes: float = d.luz()
	var salto := 0.0
	for k in 600 * 10:
		d.advance(0.1)
		salto = maxf(salto, absf(d.luz() - antes))
		antes = d.luz()
	t.check(salto < 0.01, "la luz cambia suave (salto máximo %.4f cada 0,1 s)" % salto)
	var mediodia = CICLO.new()
	mediodia.advance(150.0)
	var cielo_dia: Color = mediodia.color_cielo()
	t.check(cielo_dia.v > 0.3, "de día el cielo es claro")
	t.check(c.color_cielo().v < cielo_dia.v, "de noche el cielo es más oscuro que de día")
