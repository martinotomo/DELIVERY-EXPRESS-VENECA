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

	# Maniobrabilidad progresiva (Tomás, 30/09/2026): a tope igual que antes, despacio mucho más.
	m = _nueva()
	var vmax: float = m.moto.vel_max
	t.check(absf(m.giro_max_a(vmax) - 6.0 / 25.0) < 0.001, "a velocidad máxima gira igual que la primera versión (%.3f rad/s)" % m.giro_max_a(vmax))
	t.check_eq(m.giro_max_a(0.0), 0.0, "parada no gira")
	var anterior := INF
	var baja := true
	for i in range(2, 26):
		var w: float = m.giro_max_a(float(i))
		if w >= anterior:
			baja = false
		anterior = w
	t.check(baja, "de 2 m/s en adelante, cuanto más rápido menos gira (progresivo)")
	t.check(absf(m.giro_max_a(2.0) / m.giro_max_a(vmax) - 9.0) < 0.05, "a 7 km/h gira 9 veces lo de tope (Tomás) (%.2f rad/s)" % m.giro_max_a(2.0))
	t.check(m.giro_max_a(10.0) > 1.5 * 0.6, "a 36 km/h gira más que antes (antes 0,60 rad/s; ahora %.2f)" % m.giro_max_a(10.0))
	m.vel = 5.0
	var h0: float = m.rumbo
	m.advance(1.0, false, false, 1.0)
	var giro_lento := absf(m.rumbo - h0)
	t.check(giro_lento > 1.4, "a 18 km/h gira fuerte (%.2f rad en 1 s)" % giro_lento)
	t.check(not m.derrapando, "a 18 km/h no derrapa")
	# «Se va de lado»: solo muy rápido, casi a tope de manubrio y sostenido (Tomás, 30/09).
	m = _nueva()
	m.vel = 15.0 # 54 km/h: antes ya avisaba
	m.advance(1.0, true, false, 1.0)
	t.check(not m.derrapando, "a 54 km/h girando a tope ya no avisa")
	m = _nueva()
	m.vel = 23.0
	m.advance(PASO * 6, true, false, 1.0)
	t.check(not m.derrapando, "un toque de manubrio a 83 km/h no avisa")
	m.advance(0.5, true, false, 1.0)
	t.check(m.derrapando, "sostener el giro a tope a 83 km/h sí avisa")
	m.advance(PASO, true, false, 0.5)
	t.check(not m.derrapando, "al soltar el manubrio se quita")
	m = _nueva()
	m.vel = 23.0
	m.advance(1.0, true, false, 0.6)
	t.check(not m.derrapando, "a 83 km/h con medio manubrio no avisa")

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
	t.check(msgs.size() == 1 and msgs[0].contains("agarre de tu Bwis"), "el remate nombra la Bwis")
	var p: Vector2 = m.pos
	m.advance(2.0, true, false, 0.0)
	t.check_eq(m.pos, p, "estrellada ya no se mueve")

	# Contra el andén a paso de peatón: se frena, no se mata.
	m = _nueva()
	var golpes := [0]
	m.golpe.connect(func(): golpes[0] += 1)
	m.pos = ciudad.punto_frente_a(4, 6)
	m.rumbo = PI / 2.0
	m.vel = 1.5
	for k in 60 * 20:
		m.advance(PASO, false, false, 0.0)
		m.vel = maxf(m.vel, 1.5)
	t.check_eq(m.estado, MOTO.RODANDO, "al andén a 5 km/h no se mata")
	t.check(not ciudad.en_anden(m.pos, 0.0), "y no se mete en la cuadra")
	t.check(golpes[0] >= 1, "el golpe leve con el andén avisa (para la queja)")
	t.check(golpes[0] <= 6, "y no repite la queja en cada fotograma (%d en 20 s)" % golpes[0])

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
