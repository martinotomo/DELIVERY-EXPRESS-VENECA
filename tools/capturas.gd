extends SceneTree
## Capturas del prototipo en momentos concretos + hoja de contactos, para revisar a ojo.
## Necesita ventana (no --headless). En Linux sin pantalla: xvfb-run.
##   godot --path . -s res://tools/capturas.gd
## Deja los PNG en capturas/ (ignorada por git).

const SALIDA := "res://capturas"

var _fotos: Array[Image] = []
var _main: Node


func _initialize() -> void:
	_correr.call_deferred()


func _ride() -> Node:
	return _main.pantalla_actual()


## Congela el recorrido, lo coloca y espera a que se dibuje (si no, la foto va un paso atrás).
func _colocar(pos: Vector2, rumbo: float, vel: float, reloj_t: float, giro := 0.0) -> void:
	var r := _ride()
	r.set_process(false)
	var m = r.partida.moto
	m.pos = pos
	m.rumbo = rumbo
	m.vel = vel
	m.derrapando = false
	m.calor = 0.0
	r.partida.reloj.t = reloj_t
	r._giro_visual = giro
	r._actualizar_vista(0.0)
	await process_frame
	await process_frame


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [SALIDA, nombre])
	_fotos.append(img)
	print("captura: ", nombre)


func _correr() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	root.size = Vector2i(640, 360)
	var ruta := "user://capturas_progreso.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	load("res://scripts/main.gd").ruta_progreso = ruta # no tocar la partida guardada de verdad
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_main.progreso.dinero = 23500
	_main.menu()
	await process_frame
	await process_frame
	await _foto("0a_menu")
	_main.taller()
	await process_frame
	_main.progreso.comprar_mejora("exosto")
	_ride().actualizar()
	await process_frame
	await create_timer(0.2).timeout
	await _foto("0b_taller")
	# La vitrina: la NKD bloqueada, luego a la venta, y la Ninja que pide primero la NKD.
	var tl := _ride()
	tl.mover(1)
	await create_timer(0.8).timeout
	await _foto("0c_taller_bloqueada")
	_main.progreso.dinero = 61500
	tl.actualizar()
	await create_timer(0.2).timeout
	await _foto("0d_taller_a_la_venta")
	tl.mover(1)
	await create_timer(0.8).timeout
	await _foto("0e_taller_ninja")
	# Comprar la NKD no entrega la Bwis: sigue en el garaje con su exosto, lista para USAR.
	tl.mover(-1)
	tl._comprar_moto()
	tl.mover(-1)
	await create_timer(0.8).timeout
	await _foto("0f_taller_garaje")
	_main.progreso.tenidas = {"bws": {"exosto": true}}
	_main.progreso.moto = "bws"
	_main.progreso.dinero = 23500
	_main.reiniciar()
	await process_frame
	await process_frame
	var c = _ride().partida.ciudad

	# Mañana, por una calle larga.
	await _colocar(c.cruce(20, 40) + Vector2(-30, 0), 0.0, 12.0, 60.0)
	await _foto("1_manana")
	# Mediodía, mirando hacia el norte por una carrera, girando.
	await _colocar(c.cruce(18, 38) + Vector2(0, -40), PI / 2.0, 23.0, 150.0, 1.0)
	_ride().partida.moto.derrapando = true
	_ride()._actualizar_vista(0.0)
	await process_frame
	await _foto("2_mediodia_derrape")
	# Atardecer.
	await _colocar(c.cruce(22, 44) + Vector2(-50, 0), 0.0, 24.0, 290.0)
	_ride().partida.moto.calor = 7.2 # a fondo: sale la cuenta para fundir el motor
	_ride()._actualizar_vista(0.0)
	await process_frame
	await _foto("3_atardecer_motor")
	_ride().partida.moto.calor = 0.0
	# Noche con la farola.
	await _colocar(c.cruce(20, 42) + Vector2(-40, 0), 0.0, 10.0, 450.0)
	_ride()._al_evento("casi")
	_ride()._actualizar_vista(0.0)
	await process_frame
	await _foto("4_noche_casi")

	# Contra el andén a toda: la cinemática y el remate.
	var r := _ride()
	r.retraso_resultado = 3.0
	await _colocar(c.punto_frente_a(20, 41), PI / 2.0, 16.0, 120.0)
	r.set_process(true)
	r.partida.advance(1.0, true, false, 0.0)
	await create_timer(0.55).timeout
	await _foto("5_caida")
	await create_timer(1.5).timeout
	await _foto("5b_caida_dibujo")
	await create_timer(1.6).timeout
	await process_frame
	await _foto("6_remate")

	# Otra caída, de noche y entrando en diagonal: la moto tiene que verse igual.
	_main.reiniciar()
	await process_frame
	await process_frame
	r = _ride()
	r.retraso_resultado = 5.0
	await _colocar(c.punto_frente_a(21, 43) + Vector2(-6, 0), PI / 2.0 - 0.6, 16.0, 460.0)
	r.set_process(true)
	r.partida.advance(1.0, true, false, 0.0)
	await create_timer(0.55).timeout
	await _foto("7_caida_noche")

	# Lluvia de tarde: gotas, piso mojado, charcos y el bono.
	_main.reiniciar()
	await process_frame
	await process_frame
	r = _ride()
	r.partida.clima.empezar_lluvia(120.0)
	for k in 90:
		r.partida.clima.advance(1.0, c.cruce(20, 40) + Vector2(-40, 0))
	await _colocar(c.cruce(20, 40) + Vector2(-40, 0), 0.0, 14.0, 250.0)
	r._lluvia.set_process(true)
	await create_timer(0.3).timeout
	await _foto("8_lluvia")
	r.partida.clima.parar_lluvia()
	r.partida.clima.intensidad = 0.0
	r.partida.clima.humedad = 0.0
	r.partida.clima.charcos.clear()
	r.partida.clima.version += 1
	r._t_subtitulo = 0.0

	# Peatones cruzando por la cebra de la esquina, de día y de noche, y uno atropellado.
	var pe = r.partida.peatones
	pe._t = 9999.0
	for foto in [["9_peatones_dia", 120.0], ["10_peatones_noche", 470.0]]:
		pe.lista.clear()
		var esquina: Vector2 = c.cruce(21, 40)
		for cb in c.cebras(21, 40):
			if cb.cruza == Vector2(0, 1):
				var q: Dictionary = pe.poner_en(cb, cb.centro.x < esquina.x)
				q.pos = cb.centro + cb.cruza * (-2.5 if cb.centro.x < esquina.x else 1.5)
				q.tramo = 2
				q.andado = 0.5 if cb.centro.x < esquina.x else 0.0
		await _colocar(esquina + Vector2(-19, -2), 0.0, 6.0, foto[1])
		await _foto(foto[0])
	pe.lista.clear()
	var cb2: Dictionary = c.cebras(21, 40)[0] # la del oriente del cruce, atravesando la calle
	var caido: Dictionary = pe.poner_en(cb2)
	caido.pos = cb2.centro + Vector2(0, 1.0)
	r.partida.moto.pos = caido.pos
	r.partida.moto.vel = 10.0
	r.partida._revisar_atropello()
	await _colocar(cb2.centro - Vector2(6.5, 0), 0.0, 0.0, 200.0)
	await _foto("11_atropello")

	# Ciudad con movimiento: gente en los andenes, semáforo de avenida y señales, de día y de noche.
	var cruce_sem: Vector2 = c.cruce(21, 42)
	r.partida.multado = false
	r.partida.peatones.lista.clear()
	r._t_subtitulo = 0.0
	for foto in [["13_ciudad_dia", 150.0, 1.0], ["14_ciudad_noche", 480.0, 13.0]]:
		r.partida.transito.t = foto[2]
		r.partida.transeuntes.lista.clear()
		r.partida.transeuntes.advance(0.1, cruce_sem + Vector2(-24, 3), Vector2.RIGHT)
		await _colocar(cruce_sem + Vector2(-24, 3), 0.0, 6.0, foto[1])
		await _foto(foto[0])

	# Zonas de la ciudad (F3): una foto en cada una, con las placas de la esquina de enfrente.
	r.partida.transeuntes.lista.clear()
	for z in ["barrio", "centro", "industrial", "rica"]:
		var ij := _cruce_en_zona(c, z)
		await _colocar(c.cruce(ij.x, ij.y) + Vector2(-22, 3), 0.0, 6.0, 140.0)
		await _foto("15_zona_" + z)
	# Tráfico: carros haciendo fila en el rojo de una avenida, de día y de noche.
	for foto in [["17_trafico_dia", 140.0], ["18_trafico_noche", 470.0]]:
		var sem_ij := Vector2i(21, 42)
		var moto_p: Vector2 = c.cruce(sem_ij.x, sem_ij.y) + Vector2(-100, 3)
		var tf = r.partida.trafico
		tf.lista.clear()
		r.partida.transito.t = r.partida.transito.CICLO / 2.0 + 1.0
		for k in 5:
			var tipo: String = ["taxi", "bus", "carro", "carro_rojo", "camion"][k]
			tf.poner(tipo, sem_ij, Vector2.RIGHT, 20.0 + k * 13.0)
		tf.poner("taxi", sem_ij, Vector2.LEFT, 40.0)
		tf.poner("camion", sem_ij, Vector2.DOWN, 25.0)
		tf.poner("carro", sem_ij, Vector2.UP, -15.0)
		for k in 150:
			tf.advance(0.1, moto_p, Vector2.ZERO)
			r.partida.transito.t = r.partida.transito.CICLO / 2.0 + 1.0
		tf.MAX_ACTIVOS = 0
		await _colocar(moto_p + Vector2(45, -1.5), 0.0, 3.0, foto[1]) # a unos 15 m del último de la fila
		await _foto(foto[0])
		tf.MAX_ACTIVOS = tf.MAX
	# Los cerros orientales: mirando al oriente (rumbo PI), de día, al atardecer y de noche.
	for foto in [["19_cerros_dia", 140.0], ["19b_cerros_tarde", 290.0], ["19c_cerros_noche", 470.0]]:
		await _colocar(c.cruce(8, 60) + Vector2(40, 3), PI, 0.0, foto[1])
		await _foto(foto[0])
	# Mapa completo (Tab).
	r._mapa.visible = true
	await process_frame
	await _foto("16_mapa")
	r._mapa.visible = false

	# Cada moto con su puesto de mando.
	for id in ["nkd", "ninja"]:
		_main.progreso.moto = id
		_main.progreso.mejoras = {}
		_main.reiniciar()
		await process_frame
		await process_frame
		await _colocar(c.cruce(20, 40) + Vector2(-30, 0), 0.0, 20.0, 100.0)
		await _foto("12_manubrio_" + id)
	_main.progreso.moto = "bws"

	# F4: huecos, aceite, perro y avisos de negocios, de día y de noche.
	_main.reiniciar()
	await process_frame
	await process_frame
	r = _ride()
	var hueco: Dictionary = {}
	for h in r.partida.peligros.lista:
		if h.tipo == "hueco" and h.eje == Vector2.RIGHT and c.distancia_anden(h.pos) > 3.0 and h.marca == 0 and h.pos.distance_to(c.cruce(20, 40)) < 900.0:
			hueco = h
			break
	var ante: Vector2 = hueco.pos - Vector2(22, 0)
	ante.y = hueco.pos.y
	r.partida.perros.lista.clear()
	r.partida.perros.poner(hueco.pos - Vector2(10, -2.0), Vector2.RIGHT, -1.0)
	for foto in [["20_hueco_aceite_perro", 140.0], ["20b_hueco_noche", 470.0]]:
		r._detalles._t_peligros = 99.0
		await _colocar(ante, 0.0, 6.0, foto[1])
		await _foto(foto[0])
	# Avisos en las fachadas (mirando de lado hacia las cuadras) y una valla en una avenida.
	await _colocar(c.cruce(20, 40) + Vector2(-20, 3), -0.35, 0.0, 150.0)
	await _foto("21_avisos")
	await _colocar(c.cruce(20, 40) + Vector2(-20, 3), -0.35, 0.0, 470.0)
	await _foto("21b_avisos_noche")
	var valla: Node3D = null
	for cru in [Vector2i(18, 36), Vector2i(24, 42), Vector2i(12, 48), Vector2i(30, 30), Vector2i(18, 54)]:
		await _colocar(c.cruce(cru.x, cru.y) + Vector2(1, 1), 0.0, 0.0, 150.0)
		for v in r._detalles._vallas:
			if v.visible and v.position.distance_to(Vector3(c.cruce(cru.x, cru.y).x, v.position.y, c.cruce(cru.x, cru.y).y)) < 30.0:
				valla = v
				break
		if valla != null:
			var cr: Vector2 = c.cruce(cru.x, cru.y)
			var hacia := (Vector2(valla.position.x, valla.position.z) - cr).normalized()
			await _colocar(cr - hacia * 30.0, hacia.angle(), 0.0, 150.0)
			r._camara.rotation.x = 0.18 # mirar hacia arriba, a la terraza
			await process_frame
			await _foto("22_valla")
			break

	# F5: el pedido con su tipo, el estado de la sopa, la racha de fe y la calificación.
	r.partida.fase = r.partida.ENTREGAR
	r.partida.pedido.tipo = "sopa"
	r.partida.pedido.plato = "Ajiaco"
	r.partida.pedido.nombre_cliente = "Doña Gloria"
	r.partida.estado_pedido = 0.72
	r.partida.racha = 4
	r._al_calificar(4, "Rápido y completo. Le faltó el saludo.")
	await _colocar(c.cruce(20, 40) + Vector2(-30, 0), 0.0, 14.0, 140.0)
	await _foto("23_pedido_racha_estrellas")

	# Las otras caídas (DISENO §5.5): cada una con su dibujo y su remate.
	for causa in ["hueco", "perro", "lluvia", "bus", "contravia"]:
		_main.reiniciar()
		await process_frame
		await process_frame
		r = _ride()
		r.retraso_resultado = 3.0
		await _colocar(c.cruce(20, 40) + Vector2(-30, 0), 0.0, 20.0, 140.0)
		r.set_process(true)
		r.partida._morir(causa)
		await create_timer(2.2).timeout
		await _foto("24_caida_" + causa)
		await create_timer(1.2).timeout
		await process_frame
		await _foto("24b_remate_" + causa)

	# El final: la mamá en la loma.
	_main.reiniciar()
	await process_frame
	await process_frame
	r = _ride()
	r.retraso_resultado = 0.0
	r.partida.final_logrado.emit(r.partida.MENSAJE_FINAL)
	await process_frame
	await process_frame
	await _foto("25_final")

	_hoja()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	quit(0)


## Un cruce con las cuatro cuadras de alrededor en la zona z (el más cercano al centro de la zona).
func _cruce_en_zona(c, z: String) -> Vector2i:
	var suma := Vector2.ZERO
	var n := 0
	var todos: Array[Vector2i] = []
	for j in range(1, c.N_LARGO):
		for i in range(1, c.N_ANCHO):
			if c.zona(i, j) == z and c.zona(i - 1, j) == z and c.zona(i, j - 1) == z and c.zona(i - 1, j - 1) == z:
				todos.append(Vector2i(i, j))
				suma += Vector2(i, j)
				n += 1
	var medio := suma / maxf(n, 1)
	todos.sort_custom(func(a, b): return Vector2(a).distance_to(medio) < Vector2(b).distance_to(medio))
	return todos[0]


func _hoja() -> void:
	var w := 640
	var h := 360
	var hoja := Image.create(w * 2, h * ((_fotos.size() + 1) / 2), false, Image.FORMAT_RGBA8)
	for i in _fotos.size():
		var f := _fotos[i]
		f.convert(Image.FORMAT_RGBA8)
		hoja.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	hoja.save_png("%s/hoja.png" % SALIDA)
	print("hoja: capturas/hoja.png")
