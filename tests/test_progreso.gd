extends RefCounted
## La plata no se pierde al morir, se guarda en disco y paga mejoras y motos.

const PROGRESO := preload("res://scripts/progreso.gd")
const PARTIDA := preload("res://scripts/partida.gd")
const MOTOS := preload("res://scripts/motos.gd")
const RUTA := "user://prueba_progreso.cfg"


func run(t) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
	var p = PROGRESO.new(RUTA)
	t.check_eq(p.dinero, 0, "se empieza sin plata")
	t.check_eq(p.moto, "bws", "se empieza en la BWS")
	t.check(not p.puede_mejorar("exosto"), "sin plata no hay exosto")
	t.check(not p.comprar_mejora("exosto"), "comprar sin plata no hace nada")
	t.check_eq(PROGRESO.pesos(1234567), "$1.234.567", "la plata se escribe a la colombiana")

	# Cobrar por entregar, y morirse no quita la plata.
	var partida = PARTIDA.new(1234, p.datos_moto())
	partida.pagado.connect(p.ganar)
	partida.moto.pos = partida.pedido.restaurante
	partida.moto.vel = 0.0
	partida._revisar_llegada()
	partida.moto.pos = partida.pedido.cliente
	var sobra: float = partida.tiempo_restante
	partida._revisar_llegada()
	t.check_eq(partida.entregados, 1, "entregó un pedido")
	t.check_eq(p.dinero, PARTIDA.pago_por(sobra), "cobró tarifa más propina")
	t.check(p.dinero >= PARTIDA.TARIFA, "un pedido paga al menos la tarifa")
	t.check(PARTIDA.pago_por(60.0) > PARTIDA.pago_por(10.0), "llegar antes da más propina")
	t.check_eq(PARTIDA.pago_por(-5.0), PARTIDA.TARIFA, "sin tiempo sobrante, solo la tarifa")
	t.check_eq(PARTIDA.pago_por(100.0), PARTIDA.TARIFA + 2500, "la propina es de $25 por segundo que sobra (Tomás, 30/09)")
	var antes: int = p.dinero
	partida.moto.pos = partida.ciudad.punto_frente_a(4, 6)
	partida.moto.rumbo = PI / 2.0
	partida.moto.vel = 18.0
	partida.advance(8.0, true, false, 0.0)
	t.check(partida.terminada, "se estrelló")
	t.check_eq(p.dinero, antes, "morirse no quita la plata")
	t.check_eq(PROGRESO.new(RUTA).dinero, antes, "la plata quedó guardada en disco")

	# Mejoras.
	p.dinero = 100000
	var vel0: float = p.datos_moto().vel_max
	t.check(p.comprar_mejora("exosto"), "con plata se compra el exosto")
	t.check_eq(p.dinero, 100000 - p.precio_mejora("exosto"), "el exosto se cobra")
	t.check(p.datos_moto().vel_max > vel0, "con exosto anda más")
	t.check(not p.comprar_mejora("exosto"), "el exosto no se compra dos veces")
	t.check(p.comprar_mejora("motor"), "y el motor")
	var cargado = PROGRESO.new(RUTA)
	t.check(cargado.tiene_mejora("exosto") and cargado.tiene_mejora("motor"), "las mejoras quedan guardadas")
	t.check_eq(cargado.dinero, p.dinero, "el saldo queda guardado")

	# Estado de cada moto en el taller (vitrina a lo Most Wanted, Tomás 30/09).
	p.dinero = int(MOTOS.get_moto("nkd").precio) - 1
	t.check_eq(p.estado_moto("bws"), PROGRESO.EN_USO, "la Bwis está en uso")
	t.check_eq(p.estado_moto("nkd"), PROGRESO.SIN_PLATA, "a la NKD le falta plata")
	t.check_eq(p.falta_para("nkd"), 1, "y se sabe cuánto falta")
	t.check_eq(p.estado_moto("ninja"), PROGRESO.BLOQUEADA, "la Ninja está bloqueada hasta tener la NKD")
	p.dinero += 1
	t.check_eq(p.estado_moto("nkd"), PROGRESO.COMPRABLE, "con la plata justa la NKD se puede comprar")
	p.dinero -= 1

	# Moto siguiente.
	t.check(not p.puede_comprar_moto(), "sin la plata justa no se compra la NKD")
	p.dinero += 1
	t.check(p.comprar_moto(), "con la plata justa sí")
	t.check_eq(p.moto, "nkd", "ahora se anda en la NKD")
	t.check_eq(p.dinero, 0, "la NKD se cobra")
	t.check(not p.tiene_mejora("exosto"), "la moto nueva llega de fábrica")
	t.check_eq(p.datos_moto().nombre, "NKD 125", "y se llama NKD 125")
	t.check_eq(p.estado_moto("bws"), PROGRESO.ENTREGADA, "la Bwis se entregó al comprar la NKD")
	t.check_eq(p.estado_moto("nkd"), PROGRESO.EN_USO, "la NKD queda en uso")
	var partida2 = PARTIDA.new(1, p.datos_moto())
	t.check_eq(partida2.moto.moto.nombre, "NKD 125", "la partida sale con la moto comprada")
	p.moto = "ninja"
	t.check_eq(p.siguiente_moto(), "", "después de la Ninja no hay más")
	p.dinero = 9999999
	t.check(not p.comprar_moto(), "con la Ninja no se compra otra")

	# Plata de prueba (F10, solo en desarrollo): 5 toques alcanzan para las tres motos con todo.
	var q = PROGRESO.new(RUTA)
	q.dinero = 0
	q.moto = "bws"
	q.mejoras = {}
	for k in 5:
		q.plata_de_prueba()
	t.check_eq(q.dinero, 5 * PROGRESO.PLATA_PRUEBA, "cada toque de F10 suma %s" % PROGRESO.pesos(PROGRESO.PLATA_PRUEBA))
	var todo_ok := true
	while true:
		for mej in MOTOS.MEJORAS:
			if not q.tiene_mejora(mej) and not q.comprar_mejora(mej):
				todo_ok = false
		if q.siguiente_moto() == "":
			break
		if not q.comprar_moto():
			todo_ok = false
			break
	t.check(todo_ok and q.moto == "ninja" and q.tiene_mejora("exosto") and q.tiene_mejora("motor"), "con 5 toques se compra todo (sobran %s)" % PROGRESO.pesos(q.dinero))

	# Un archivo roto no tumba el juego.
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	f.store_string("esto no es un cfg [[[")
	f.close()
	var roto = PROGRESO.new(RUTA)
	t.check_eq(roto.moto, "bws", "con archivo roto se empieza de cero")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
