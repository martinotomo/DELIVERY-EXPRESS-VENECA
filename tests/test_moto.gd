extends RefCounted
## Contrato de cómo anda la BWS en la ciudad.

const CIUDAD := preload("res://scripts/ciudad.gd")
const MOTOS := preload("res://scripts/motos.gd")
const MOTO := preload("res://scripts/moto_logic.gd")
const PASO := 1.0 / 60.0

var ciudad = CIUDAD.new(1234)


## Moto en el cruce (i, j) mirando hacia +x (por la calle).
func _nueva(i := 4, j := 6):
	var m = MOTO.new()
	m.setup(MOTOS.get_moto("bws"), ciudad, ciudad.cruce(i, j), 0.0)
	return m


func run(t) -> void:
	var m = _nueva()
	t.check_eq(m.vel, 0.0, "arranca parada")
	m.advance(1.0, false, true, 0.0)
	t.check_eq(m.vel, 0.0, "frenar parado no la echa para atrás")

	# Aceleración en recta: nunca pasa del tope.
	m = _nueva()
	var tope := 0.0
	for k in 60 * 8:
		m.advance(PASO, true, false, 0.0)
		tope = maxf(tope, m.vel)
	t.check(tope <= m.moto.vel_max + 0.001, "no pasa de su velocidad máxima")
	t.check(m.vel > 10.0, "en 8 s de recta coge velocidad (%.1f m/s)" % m.vel)

	# Despacio gira cerrado; rápido no puede (la fe contra el agarre).
	m = _nueva()
	m.vel = 5.0
	var h0: float = m.rumbo
	m.advance(1.0, false, false, 1.0)
	var giro_lento := absf(m.rumbo - h0)
	t.check(giro_lento > 0.9, "a 18 km/h gira fuerte (%.2f rad en 1 s)" % giro_lento)
	t.check(not m.derrapando, "a 18 km/h no derrapa")
	m = _nueva()
	m.vel = 20.0
	h0 = m.rumbo
	m.advance(PASO * 6, true, false, 1.0)
	t.check(m.derrapando, "a 72 km/h girando a tope derrapa")
	var omega: float = absf(m.rumbo - h0) / (PASO * 6)
	t.check(omega * m.vel <= m.moto.agarre + 0.05, "la aceleración lateral no pasa del agarre")

	# Contra el andén rápido: muerto, con el remate de la BWS.
	m = _nueva()
	var msgs := []
	m.estrellado.connect(func(x): msgs.append(x))
	m.pos = ciudad.punto_frente_a(4, 6) # en la calle, frente a la cuadra
	m.rumbo = PI / 2.0 # hacia +y: de frente contra el andén
	m.vel = 15.0
	for k in 60 * 5:
		m.advance(PASO, true, false, 0.0)
	t.check_eq(m.estado, MOTO.ESTRELLADA, "al andén a 54 km/h se estrella")
	t.check_eq(msgs.size(), 1, "la señal estrellado sale una vez")
	t.check(msgs.size() == 1 and msgs[0].contains("agarre de tu BWS"), "el remate nombra la BWS")
	var p: Vector2 = m.pos
	m.advance(2.0, true, false, 0.0)
	t.check_eq(m.pos, p, "estrellada ya no se mueve")

	# Contra el andén a paso de peatón: se frena, no se mata.
	m = _nueva()
	m.pos = ciudad.punto_frente_a(4, 6)
	m.rumbo = PI / 2.0
	m.vel = 1.5
	for k in 60 * 20:
		m.advance(PASO, false, false, 0.0)
		m.vel = maxf(m.vel, 1.5)
	t.check_eq(m.estado, MOTO.RODANDO, "al andén a 5 km/h no se mata")
	t.check(not ciudad.en_anden(m.pos, 0.0), "y no se mete en la cuadra")

	# Casi me mato: pasar raspando el andén rápido avisa una sola vez seguida.
	m = _nueva()
	var casis := []
	m.casi.connect(func(tipo): casis.append(tipo))
	var r: Rect2 = ciudad.cuadra(4, 6)
	m.pos = Vector2(r.position.x + 5.0, r.position.y - m.moto.radio - 0.4)
	m.rumbo = 0.0
	m.vel = 12.0
	for k in 30:
		m.advance(PASO, true, false, 0.0)
	t.check_eq(m.estado, MOTO.RODANDO, "raspando el andén no se estrella")
	t.check_eq(casis.size(), 1, "«casi me mato» sale una vez, no en cada fotograma (%d)" % casis.size())

	# Determinismo.
	var a = _nueva()
	var b = _nueva()
	a.advance(3.0, true, false, 0.3)
	for k in 180:
		b.advance(PASO, true, false, 0.3)
	t.check(a.pos.distance_to(b.pos) < 0.01, "advance(3 s) = 180 × advance(1/60)")
