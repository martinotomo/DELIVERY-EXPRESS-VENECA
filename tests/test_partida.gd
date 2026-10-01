extends RefCounted
## Contrato de la partida: recoger, entregar, cancelar, estrellarse.

const PARTIDA := preload("res://scripts/partida.gd")


func run(t) -> void:
	var p = PARTIDA.new(1234)
	t.check_eq(p.fase, PARTIDA.RECOGER, "arranca yendo a recoger")
	t.check(p.tiempo_restante > 30.0, "el pedido da tiempo (%.0f s)" % p.tiempo_restante)
	t.check(p.pedido.plato != "", "el pedido tiene plato")
	t.check(p.pedido.direccion.begins_with("Calle "), "el pedido tiene dirección bogotana")
	t.check(p.objetivo() == p.pedido.restaurante, "primero guía al restaurante")
	t.check(p.ruta().size() >= 2, "hay ruta para el minimapa")

	var eventos := []
	p.evento.connect(func(e): eventos.append(e))

	# Llegar rápido no cuenta: hay que parar.
	p.moto.pos = p.pedido.restaurante
	p.moto.vel = 15.0
	p._revisar_llegada()
	t.check_eq(p.fase, PARTIDA.RECOGER, "pasar volando por el restaurante no recoge")
	p.moto.vel = 1.0
	p._revisar_llegada()
	t.check_eq(p.fase, PARTIDA.ENTREGAR, "parado en el restaurante recoge")
	t.check(p.objetivo() == p.pedido.cliente, "después guía al cliente")
	t.check(eventos.has("recogido"), "sale el evento recogido (para la frase)")

	p.moto.pos = p.pedido.cliente
	p.moto.vel = 0.5
	var cliente_viejo: Vector2 = p.pedido.cliente
	p._revisar_llegada()
	t.check_eq(p.entregados, 1, "entregado cuenta 1")
	t.check(eventos.has("entregado"), "sale el evento entregado")
	t.check_eq(p.fase, PARTIDA.RECOGER, "tras entregar sale otro pedido")
	t.check(p.pedido.cliente != cliente_viejo, "el pedido nuevo es otro")

	# Se acaba el tiempo: se cancela y sale otro, la jornada sigue.
	p.advance(p.tiempo_restante + 1.0, false, false, 0.0)
	t.check_eq(p.cancelados, 1, "sin tiempo, se cancela")
	t.check(eventos.has("cancelado"), "sale el evento cancelado")
	t.check(p.tiempo_restante > 30.0, "el pedido nuevo trae tiempo")
	t.check(not p.terminada, "cancelar no acaba la jornada")

	# Estrellarse sí acaba la jornada.
	var fines := []
	p.terminada_por.connect(func(msg): fines.append(msg))
	p.moto.pos = p.ciudad.punto_frente_a(4, 6)
	p.moto.rumbo = PI / 2.0
	p.moto.vel = 18.0
	p.advance(8.0, true, false, 0.0)
	t.check(p.terminada, "estrellarse acaba la jornada")
	t.check(fines.size() == 1 and fines[0].contains("agarre de tu Bwis"), "con el remate de la Bwis")
	var t0: float = p.reloj.t
	p.advance(5.0, true, false, 0.0)
	t.check_eq(p.reloj.t, t0, "terminada, el reloj del día no sigue")
