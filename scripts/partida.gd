extends RefCounted
## Una jornada de domiciliario: recoger, entregar, otro pedido... hasta que la fe supere al agarre.

signal evento(nombre: String)       # recogido, entregado, cancelado, casi, golpe, estrellado, fundido, reparado, charco, lluvia, escampo, atropello, grito, choque, pito
signal terminada_por(mensaje: String)
signal pagado(pesos: int)           # al entregar: tarifa más propina por el tiempo que sobró
signal calificado(estrellas: int, comentario: String) # el cliente califica al recibir (DISENO §5.4)
signal final_logrado(mensaje: String) # el pedido final (la mamá, en la loma) entregado

const CIUDAD := preload("res://scripts/ciudad.gd")
const MOTO := preload("res://scripts/moto_logic.gd")
const MOTOS := preload("res://scripts/motos.gd")
const CICLO := preload("res://scripts/ciclo_dia.gd")
const CLIMA := preload("res://scripts/clima.gd")
const PEATONES := preload("res://scripts/peatones.gd")
const TRANSITO := preload("res://scripts/transito.gd")
const TRANSEUNTES := preload("res://scripts/transeuntes.gd")
const TRAFICO := preload("res://scripts/trafico.gd")
const PELIGROS := preload("res://scripts/peligros.gd")
const PERROS := preload("res://scripts/perros.gd")
const VEL_CHOQUE_CARRO := 1.5 # m/s: más despacio, solo se queda pegado
## Caídas nuevas (F4, D27), como fracción de la velocidad máxima de la moto.
const HUECO_MORTAL := 0.8    # caer en un hueco más rápido que esto mata
const PERRO_MORTAL := 0.6    # pegarle a un perro más rápido que esto mata
const CHOQUE_MORTAL := 0.8   # contra un bus o de frente (contravía) más rápido que esto mata
const FRENO_HUECO := 0.6     # despacio, el hueco quita el 60 % de la velocidad
const AGARRE_ACEITE := 0.35  # sobre el aceite el manubrio gira apenas esto
const CASI_PERRO := 1.2      # m de sobra para que esquivar un perro cuente como casi-choque

const RECOGER := "recoger"
const ENTREGAR := "entregar"
const RADIO_LLEGADA := 7.0
const VEL_PARADA := 3.0      # m/s: hay que parar para recoger o entregar
const VEL_PROMEDIO := 8.0    # m/s con que se calcula el tiempo del pedido
const TIEMPO_EXTRA := 25.0
const TARIFA := 5000         # pesos por pedido entregado
const FRENO_CHARCO := 0.15   # cada charco quita el 15 % de la velocidad
const PROPINA_POR_S := 25    # pesos por cada segundo que sobró (Tomás, 30/09: bajó de 50)

## Tipos de pedido (DISENO §5.4, D27): cambian cómo se maneja. fragil: cuánto se riega por segundo de
## frenazo en seco; freno: cuánto frena la moto con el pedido encima (el licor pesa).
const TIPOS_PEDIDO := {
	"hamburguesa": {"peso": 4.0, "fragil": 0.0, "freno": 1.0, "aviso": "NORMAL: dale sin miedo",
		"platos": ["Hamburguesa doble", "Salchipapa", "Perro caliente", "Empanadas x10", "Pizza familiar", "Arepa de choclo", "Bandeja paisa"]},
	"sopa": {"peso": 2.0, "fragil": 1.0, "freno": 1.0, "aviso": "SOPA: no frenes en seco",
		"platos": ["Ajiaco", "Sancocho", "Changua", "Mondongo"]},
	"torta": {"peso": 1.0, "fragil": 1.6, "freno": 1.0, "aviso": "TORTA: suavecito, que se desbarata",
		"platos": ["Torta de cumpleaños", "Torta tres leches"]},
	"licor": {"peso": 1.0, "fragil": 0.0, "freno": 0.65, "aviso": "LICOR: pesa, frena antes",
		"platos": ["Aguardiente x2", "Canasta de cerveza", "Ron de 750"]},
}
const CLIENTES := ["Doña Gloria", "Andrés", "La del 302", "Don Hernando", "Valentina", "Profe Rubiela",
	"Juancho", "Doña Martha", "El de la portería", "Camila", "Don Aurelio", "Mafe"]
const DECEL_FRENAZO := 5.5   # m/s²: por encima de esto es frenar en seco
const RACHA_MAX := 10
const RACHA_BONO := 0.1      # +10 % de propina por cada casi-choque de la racha
const TARDE_S := 10.0        # entregar con menos de esto es llegar «tarde» (frase de excusa)
const CASI_TRAFICO := 1.0    # m entre la moto y un carro para que cuente como casi-choque
const PROB_ZONA_NUEVA := 0.3 # pedidos que van a una zona de las que abre la moto, aunque quede lejos
## Qué dice el cliente según las estrellas (índice = estrellas - 1).
const COMENTARIOS := [
	["Llegó frío y regado. Una estrella porque no dejan cero.", "¿Esto era mi pedido o un accidente?"],
	["Tarde y medio regado. El domiciliario, eso sí, muy simpático.", "Mejor lo hubiera ido a buscar yo."],
	["Normal. Ni frío ni caliente, como mi ex.", "Llegó. Eso ya es algo."],
	["Rápido y completo. Le faltó el saludo.", "Casi perfecto: el casco daba miedo."],
	["¡Llegó volando y calientico! Ese muchacho tiene fe.", "Cinco estrellas y una oración por su seguridad."],
]

var ciudad
var moto
var reloj
var clima
var peatones
var transito     # semáforos (de ambiente: pasarse el rojo no tiene castigo)
var transeuntes  # gente caminando por los andenes (de ambiente)
var trafico      # carros, taxis, buses y camiones (chocarlos frena en seco; a toda contra un bus o de frente, mata)
var peligros     # huecos y aceite fijos en la calzada
var perros       # perros callejeros que se atraviesan
var causa := ""  # de qué se murió: curva, lluvia, hueco, perro, bus o contravia (elige la cinemática)
var _hueco := -1 # el hueco que se está pisando (brinca una sola vez)
var _pegado := false # la moto está tocando un carro (el choque suena una sola vez)
var _t_pito := -1.0   # s para que el conductor pite e insulte, después del choque
const PITO_TRAS := 1.6
var trafico_casi_enfriar := 0.0
var multado := false     # atropelló a alguien en este pedido: se queda sin propina
var estado_pedido := 1.0 # 1 = como salió del restaurante; los frenazos riegan la sopa y la torta
var racha := 0           # casi-choques seguidos desde el último golpe o entrega (DISENO §5.3)
var ultima_racha := 0    # la racha que se cobró en la última entrega
var es_final := false    # el pedido de ahora es el final (la mamá, en la loma)
var _frenando := false
var _vel_antes := 0.0
var _charco := -1            # el charco que se está pisando (frena una sola vez al entrar)
var pedido := {}
var fase := RECOGER
var tiempo_restante := 0.0
var entregados := 0
var cancelados := 0
var ganado := 0              # pesos de esta jornada (ya quedan guardados al cobrarlos)
var terminada := false
var _rng := RandomNumberGenerator.new()


func _init(semilla := 1, datos_moto: Dictionary = {}, final := false) -> void:
	_rng.seed = semilla
	ciudad = CIUDAD.new(semilla)
	reloj = CICLO.new()
	clima = CLIMA.new(semilla, ciudad)
	clima.empezo_lluvia.connect(func(): evento.emit("lluvia"))
	clima.paro_lluvia.connect(func(): evento.emit("escampo"))
	peatones = PEATONES.new(semilla, ciudad)
	peatones.levantado.connect(func(): evento.emit("grito"))
	transito = TRANSITO.new(ciudad)
	transeuntes = TRANSEUNTES.new(semilla, ciudad)
	trafico = TRAFICO.new(semilla, ciudad, transito)
	peligros = PELIGROS.new(semilla, ciudad)
	perros = PERROS.new(semilla, ciudad)
	moto = MOTO.new()
	var datos := datos_moto if not datos_moto.is_empty() else MOTOS.get_moto(MOTOS.MOTO_INICIAL)
	moto.setup(datos, ciudad, ciudad.cruce(20, 40), 0.0)
	moto.estrellado.connect(_al_estrellarse)
	moto.casi.connect(_al_casi)
	moto.golpe.connect(_al_golpe)
	moto.fundido.connect(func(): evento.emit("fundido"))
	moto.reparado.connect(func(): evento.emit("reparado"))
	es_final = final
	_nuevo_pedido()


func advance(delta: float, acelerar: bool, frenar: bool, giro: float) -> void:
	if terminada:
		return
	_vel_antes = moto.vel
	moto.advance(delta, acelerar, frenar, giro)
	if terminada:
		return
	_revisar_frenazo(delta)
	reloj.advance(delta)
	clima.advance(delta, moto.pos)
	_revisar_charco()
	peatones.advance(delta, moto.pos, moto.direccion())
	_revisar_atropello()
	transito.advance(delta)
	transeuntes.advance(delta, moto.pos, moto.direccion())
	trafico.advance(delta, moto.pos, moto.direccion())
	_revisar_choque()
	if terminada:
		return
	_revisar_casi_trafico(delta)
	_revisar_peligros()
	if terminada:
		return
	perros.advance(delta, moto.pos, moto.direccion())
	_revisar_perros()
	if terminada:
		return
	if _t_pito >= 0.0:
		_t_pito -= delta
		if _t_pito < 0.0:
			evento.emit("pito")
	tiempo_restante -= delta
	_revisar_llegada()
	if tiempo_restante <= 0.0:
		cancelados += 1
		evento.emit("cancelado")
		_nuevo_pedido()


func objetivo() -> Vector2:
	return pedido.restaurante if fase == RECOGER else pedido.cliente


func ruta() -> PackedVector2Array:
	return ciudad.ruta(moto.pos, objetivo())


func _revisar_llegada() -> void:
	if moto.pos.distance_to(objetivo()) > RADIO_LLEGADA or moto.vel > VEL_PARADA:
		return
	if fase == RECOGER:
		fase = ENTREGAR
		_aplicar_tipo()
		evento.emit("recogido")
	else:
		entregados += 1
		ultima_racha = racha
		racha = 0
		var pago := pago_por(0.0 if multado else tiempo_restante, clima.lloviendo(), estado_pedido, ultima_racha)
		ganado += pago
		evento.emit("entregado")
		pagado.emit(pago)
		var calif := estrellas_por(estado_pedido, tiempo_restante / maxf(float(pedido.get("tiempo_total", 1.0)), 1.0), multado, _rng.randi())
		calificado.emit(calif[0], TranslationServer.translate(calif[1]))
		if tiempo_restante < TARDE_S:
			evento.emit("tarde")
		if es_final:
			es_final = false
			terminada = true
			evento.emit("final")
			final_logrado.emit(TranslationServer.translate(MENSAJE_FINAL))
			return
		_nuevo_pedido()


## Lo que paga un pedido según los segundos que sobraron, redondeado a cientos.
## Con lluvia paga el bono del clima (+30 %).
## La propina baja con el estado del pedido (regado) y sube con la racha de casi-choques.
static func pago_por(segundos_sobrantes: float, lluvia := false, estado := 1.0, p_racha := 0) -> int:
	var propina := maxf(segundos_sobrantes, 0.0) * PROPINA_POR_S * clampf(estado, 0.0, 1.0) * (1.0 + RACHA_BONO * mini(p_racha, RACHA_MAX))
	var base := TARIFA + int(round(propina / 100.0)) * 100
	return int(round(base * (1.0 + CLIMA.BONO) / 100.0)) * 100 if lluvia else base


## Atropellar a un peatón: frenazo en seco y el pedido se queda sin propina (solo la tarifa).
func _revisar_atropello() -> void:
	if peatones.atropellar(moto.pos, moto.vel) == -1:
		return
	moto.vel = 0.0
	multado = true
	racha = 0
	_regar(0.3)
	evento.emit("atropello")


## Chocar con un carro: frenazo en seco, la moto queda por fuera y el conductor pita e insulta.
## No mata ni quita plata (D26).
func _revisar_choque() -> void:
	if trafico.chocado(moto.pos, 0.5) == -1:
		_pegado = false
		return
	var v: Dictionary = {}
	for x in trafico.lista:
		if x.id == trafico.chocado(moto.pos, 0.5):
			v = x
	if not _pegado and moto.vel > CHOQUE_MORTAL * float(moto.moto.vel_max):
		if v.tipo in ["bus", "camion"]:
			_morir("bus")
			return
		if v.dir.dot(moto.direccion()) < -0.7:
			_morir("contravia")
			return
	if moto.vel > VEL_CHOQUE_CARRO and not _pegado:
		racha = 0
		_regar(0.4)
		evento.emit("choque")
		_t_pito = PITO_TRAS
	_pegado = true
	moto.vel = 0.0
	# Sacarla hacia atrás hasta que no toque.
	var atras: Vector2 = -moto.direccion()
	for k in 24:
		if trafico.chocado(moto.pos, 0.3) == -1:
			break
		moto.pos += atras * 0.25


## Pisar un charco frena un poco, una vez por charco.
func _revisar_charco() -> void:
	var k: int = clima.charco_en(moto.pos)
	if k != -1 and k != _charco and moto.vel > 2.0:
		moto.vel *= 1.0 - FRENO_CHARCO
		evento.emit("charco")
	_charco = k


const MENSAJE_FINAL := "Subiste a la loma con la Ninja, contra los cerros.\nLa clienta era tu mamá: «Mijo, llegó frío».\nY aun así te puso cinco estrellas.\n\nFIN"


## De 1 a 5 estrellas y un comentario: cuenta el estado del pedido, el tiempo que sobró (fracción
## del total) y si atropelló a alguien.
static func estrellas_por(estado: float, fraccion_sobrante: float, p_multado: bool, azar := 0) -> Array:
	var puntos := 1.0 + 2.0 * clampf(estado, 0.0, 1.0) + 2.0 * clampf(fraccion_sobrante / 0.5, 0.0, 1.0)
	if p_multado:
		puntos -= 2.0
	var n := clampi(roundi(puntos), 1, 5)
	var opciones: Array = COMENTARIOS[n - 1]
	return [n, opciones[absi(azar) % opciones.size()]]


## El licor pesa desde que se recoge hasta que se entrega.
func _aplicar_tipo() -> void:
	var tipo: Dictionary = TIPOS_PEDIDO.get(pedido.get("tipo", "hamburguesa"), TIPOS_PEDIDO.hamburguesa)
	moto.factor_freno = float(tipo.freno) if fase == ENTREGAR else 1.0


## Frenar en seco con sopa o torta la riega (baja el estado y con él la propina).
func _revisar_frenazo(delta: float) -> void:
	var decel: float = (_vel_antes - moto.vel) / maxf(delta, 0.0001)
	var en_seco: bool = decel >= DECEL_FRENAZO and _vel_antes > 3.0 and not moto.motor_fundido
	if en_seco and not _frenando and _vel_antes > 8.0:
		evento.emit("frenazo")
	if en_seco and fase == ENTREGAR:
		var fragil: float = TIPOS_PEDIDO[pedido.tipo].fragil
		if fragil > 0.0:
			if not _frenando:
				evento.emit("regado")
			estado_pedido = maxf(estado_pedido - fragil * 0.25 * minf(delta, 1.0) * clampf(decel / 7.0, 0.5, 2.0), 0.0)
	_frenando = en_seco


func _regar(cuanto: float) -> void:
	if fase == ENTREGAR:
		estado_pedido = maxf(estado_pedido - cuanto * TIPOS_PEDIDO[pedido.tipo].fragil, 0.0)


## Casi-choque (andén, carro, peatón, perro): suma a la racha de fe; cada tres, el domiciliario presume.
func _al_casi(_tipo := "") -> void:
	racha = mini(racha + 1, RACHA_MAX)
	evento.emit("casi")
	if racha % 3 == 0:
		evento.emit("racha")


## Tocar el andén despacio: corta la racha y riega un poco lo delicado.
func _al_golpe() -> void:
	racha = 0
	_regar(0.2)
	evento.emit("golpe")


## Pasar rozando un carro a buena velocidad sin tocarlo cuenta como casi-choque.
func _revisar_casi_trafico(delta: float) -> void:
	trafico_casi_enfriar = maxf(trafico_casi_enfriar - delta, 0.0)
	if trafico_casi_enfriar > 0.0 or moto.vel < moto.CASI_VEL or _pegado:
		return
	if trafico.chocado(moto.pos, CASI_TRAFICO + float(moto.moto.radio)) != -1:
		trafico_casi_enfriar = moto.CASI_ENFRIAR
		_al_casi("carro")


func _cuadra_cerca(desde: Vector2, min_d: int, max_d: int) -> Vector2i:
	var i0 := clampi(int(desde.x / ciudad.tamano().x * ciudad.N_ANCHO), 0, ciudad.N_ANCHO - 1)
	var j0 := clampi(int(desde.y / ciudad.tamano().y * ciudad.N_LARGO), 0, ciudad.N_LARGO - 1)
	var di := _rng.randi_range(min_d, max_d) * (1 if _rng.randf() < 0.5 else -1)
	var dj := _rng.randi_range(min_d, max_d) * (1 if _rng.randf() < 0.5 else -1)
	return Vector2i(clampi(i0 + di / 2, 0, ciudad.N_ANCHO - 1), clampi(j0 + dj, 1, ciudad.N_LARGO - 1))


func _nuevo_pedido() -> void:
	var zonas: Array = moto.moto.get("zonas", ["barrio", "centro", "industrial", "rica"])
	var r := _cuadra_cerca(moto.pos, 1, 6)
	for intento in 40:
		if zonas.has(ciudad.zona(r.x, r.y)):
			break
		r = _cuadra_cerca(moto.pos, 1, 6 + intento / 4)
	var c := _cuadra_cerca(ciudad.punto_frente_a(r.x, r.y), 3, 10)
	# Algunos pedidos van a las zonas más finas que abre la moto, aunque queden lejos (pagan más tiempo).
	var lejanas := zonas.filter(func(z): return z != "barrio")
	if es_final:
		c = _cuadra_en_zona("rica", 0, 4)
	elif lejanas.size() > 0 and _rng.randf() < PROB_ZONA_NUEVA:
		c = _cuadra_en_zona(lejanas[_rng.randi_range(0, lejanas.size() - 1)], 0, ciudad.N_ANCHO)
	else:
		for intento in 40:
			if zonas.has(ciudad.zona(c.x, c.y)) and c != r:
				break
			c = _cuadra_cerca(ciudad.punto_frente_a(r.x, r.y), 3, 10 + intento / 4)
	if c == r:
		c.y = clampi(c.y + 4, 1, ciudad.N_LARGO - 1)
	var rest: Vector2 = ciudad.punto_frente_a(r.x, r.y)
	var cli: Vector2 = ciudad.punto_frente_a(c.x, c.y)
	var tipo := _sortear_tipo()
	var platos: Array = TIPOS_PEDIDO[tipo].platos
	pedido = {
		"tipo": tipo,
		"plato": platos[_rng.randi_range(0, platos.size() - 1)],
		"nombre_cliente": CLIENTES[_rng.randi_range(0, CLIENTES.size() - 1)],
		"restaurante": rest,
		"cliente": cli,
		"direccion": ciudad.direccion(cli),
	}
	if es_final:
		pedido.tipo = "sopa"
		pedido.plato = "Ajiaco para la loma"
		pedido.nombre_cliente = "Mamá"
	fase = RECOGER
	multado = false
	estado_pedido = 1.0
	_aplicar_tipo()
	var recorrido := _manhattan(moto.pos, rest) + _manhattan(rest, cli)
	tiempo_restante = recorrido / VEL_PROMEDIO + TIEMPO_EXTRA
	pedido.tiempo_total = tiempo_restante
	evento.emit("pedido")


func _sortear_tipo() -> String:
	var total := 0.0
	for k in TIPOS_PEDIDO:
		total += TIPOS_PEDIDO[k].peso
	var tira := _rng.randf() * total
	for k in TIPOS_PEDIDO:
		tira -= TIPOS_PEDIDO[k].peso
		if tira <= 0.0:
			return k
	return "hamburguesa"


## Una cuadra (no parque) de la zona z con la carrera entre i_min e i_max, con calle al sur (j ≥ 1).
func _cuadra_en_zona(z: String, i_min: int, i_max: int) -> Vector2i:
	var opciones: Array[Vector2i] = []
	for j in range(1, ciudad.N_LARGO):
		for i in range(i_min, mini(i_max, ciudad.N_ANCHO)):
			if ciudad.zona(i, j) == z and not ciudad.es_parque(i, j):
				opciones.append(Vector2i(i, j))
	if opciones.is_empty():
		return _cuadra_cerca(moto.pos, 3, 10)
	return opciones[_rng.randi_range(0, opciones.size() - 1)]


func _manhattan(a: Vector2, b: Vector2) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y)


## Huecos (brincan o matan) y aceite (el manubrio no agarra mientras se está encima).
func _revisar_peligros() -> void:
	var h: Dictionary = peligros.en(moto.pos)
	var tipo: String = h.get("tipo", "")
	moto.agarre_suelo = AGARRE_ACEITE if tipo == "aceite" else 1.0
	var id: int = h.get("id", -1) if tipo == "hueco" else -1
	if id != -1 and id != _hueco:
		if moto.vel > HUECO_MORTAL * float(moto.moto.vel_max):
			_morir("hueco")
			return
		if moto.vel > 2.0:
			moto.vel *= 1.0 - FRENO_HUECO
			_regar(0.3)
			evento.emit("bache")
	_hueco = id


## Pegarle a un perro: a toda mata; despacio, frena y el perro sale corriendo. Esquivarlo por poco
## suma a la racha.
func _revisar_perros() -> void:
	var r := float(moto.moto.radio)
	var d: Dictionary = perros.tocado(moto.pos, r)
	if not d.is_empty():
		if moto.vel > PERRO_MORTAL * float(moto.moto.vel_max):
			_morir("perro")
			return
		perros.espantar(d, moto.direccion())
		if moto.vel > 1.0:
			moto.vel *= 0.4
			racha = 0
			_regar(0.3)
			evento.emit("perro")
		return
	if moto.vel < moto.CASI_VEL:
		return
	for x in perros.lista:
		if x.estado == perros.CRUZA and not x.casi and moto.pos.distance_to(x.pos) < r + perros.RADIO + CASI_PERRO:
			x.casi = true
			_al_casi("perro")


## Caídas que no son contra el andén: la moto queda en el piso y sale su cinemática.
func _morir(p_causa: String) -> void:
	moto.vel = 0.0
	moto.estado = moto.ESTRELLADA
	causa = p_causa
	_al_estrellarse(MOTOS.remate(p_causa, str(moto.moto.nombre)))


func _al_estrellarse(mensaje: String) -> void:
	if causa == "":
		# Contra el andén: la curva de siempre, o la mojada si está lloviendo.
		causa = "lluvia" if clima.lloviendo() else "curva"
		# Se arma aquí para que salga en el idioma de ahora (el de moto_logic se armó al salir).
		mensaje = MOTOS.remate(causa, str(moto.moto.nombre))
	terminada = true
	evento.emit("estrellado")
	terminada_por.emit(mensaje)
