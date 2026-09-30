extends RefCounted
## Fundir el motor (Tomás, 30/09): a fondo >5 s sale el aviso con cuenta de 5 s; si no suelta,
## se funde, frena en seco, espera 3 s quieto y sigue. No mata ni cancela el pedido.

const MOTO := preload("res://scripts/moto_logic.gd")
const MOTOS := preload("res://scripts/motos.gd")
const CIUDAD := preload("res://scripts/ciudad.gd")
const PARTIDA := preload("res://scripts/partida.gd")
const PASO := 1.0 / 60.0

var ciudad = CIUDAD.new(1)


## Moto a tope por una calle larga, lejos de los andenes.
func _a_tope():
	var m = MOTO.new()
	m.setup(MOTOS.get_moto("bws"), ciudad, ciudad.cruce(2, 40), PI / 2.0)
	m.vel = m.moto.vel_max
	return m


func run(t) -> void:
	var m = _a_tope()
	var eventos := []
	m.fundido.connect(func(): eventos.append("fundido"))
	m.reparado.connect(func(): eventos.append("reparado"))
	t.check_eq(m.cuenta_motor(), -1.0, "recién arrancada no hay aviso")
	m.advance(4.9, true, false, 0.0)
	t.check_eq(m.cuenta_motor(), -1.0, "4,9 s a fondo todavía sin aviso")
	m.advance(0.2, true, false, 0.0)
	t.check(m.cuenta_motor() > 4.5 and m.cuenta_motor() <= 5.0, "pasados 5 s sale la cuenta de 5 (%.2f)" % m.cuenta_motor())
	m.advance(3.0, true, false, 0.0)
	t.check(absf(m.cuenta_motor() - 1.9) < 0.1, "la cuenta baja con el tiempo (%.2f)" % m.cuenta_motor())
	t.check(not m.motor_fundido, "aún no se funde")

	# Soltar el acelerador enfría y quita el aviso.
	m.advance(1.0, false, false, 0.0)
	t.check_eq(m.cuenta_motor(), -1.0, "soltar 1 s quita el aviso")
	t.check(m.calor < MOTO.MOTOR_GRACIA, "soltando se enfría (%.1f s de calor)" % m.calor)
	t.check(eventos.is_empty(), "no se fundió")

	# A medio acelerador (lejos del tope) no se calienta.
	m = _a_tope()
	m.vel = m.moto.vel_max * 0.6
	m.advance(20.0, false, false, 0.0)
	t.check_eq(m.calor, 0.0, "sin ir a fondo no se calienta")

	# Si no hace caso: se funde, frena en seco, espera 3 s y sigue.
	m = _a_tope()
	eventos.clear()
	m.fundido.connect(func(): eventos.append("fundido"))
	m.reparado.connect(func(): eventos.append("reparado"))
	m.advance(10.05, true, false, 0.0)
	t.check(m.motor_fundido, "10 s a fondo funden el motor")
	t.check_eq(eventos, ["fundido"], "sale el evento fundido una vez")
	t.check_eq(m.estado, MOTO.RODANDO, "fundir el motor no mata")
	var v0: float = m.vel
	m.advance(0.5, true, false, 0.0)
	t.check(m.vel < v0 - 5.0, "frena en seco aunque siga acelerando (%.1f → %.1f m/s)" % [v0, m.vel])
	m.advance(1.5, true, false, 0.0)
	t.check_eq(m.vel, 0.0, "queda quieta")
	t.check(m.motor_fundido and m.espera_reparacion() > 1.0, "y espera la reparación (%.1f s)" % m.espera_reparacion())
	var parada: Vector2 = m.pos
	m.advance(1.0, true, false, 0.0)
	t.check_eq(m.pos, parada, "mientras repara no se mueve aunque acelere")
	m.advance(2.1, true, false, 0.0)
	t.check(not m.motor_fundido, "tras 3 s quieta el motor queda reparado")
	t.check_eq(eventos, ["fundido", "reparado"], "sale el evento reparado")
	m.advance(1.0, true, false, 0.0)
	t.check(m.vel > 1.0, "reparada vuelve a andar")
	t.check_eq(m.cuenta_motor(), -1.0, "el motor reparado arranca frío")

	# En la partida: el pedido sigue y el reloj del pedido no se detiene.
	var p = PARTIDA.new(1234)
	var ev := []
	p.evento.connect(func(e): ev.append(e))
	p.moto.pos = ciudad.cruce(2, 40)
	p.ciudad = ciudad
	p.moto.ciudad = ciudad
	p.moto.rumbo = PI / 2.0
	p.moto.vel = p.moto.moto.vel_max
	var pedido_antes: Dictionary = p.pedido
	var t0: float = p.tiempo_restante
	p.advance(10.1, true, false, 0.0)
	t.check(ev.has("fundido"), "la partida avisa «fundido» (para la frase)")
	p.advance(5.0, false, false, 0.0)
	t.check(ev.has("reparado"), "y «reparado»")
	t.check(not p.terminada, "la jornada sigue")
	t.check(p.pedido == pedido_antes, "el pedido es el mismo")
	t.check(p.tiempo_restante < t0 - 14.0, "el tiempo del pedido siguió corriendo")
