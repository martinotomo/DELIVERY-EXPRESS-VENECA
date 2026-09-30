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
	await _foto("0b_taller")
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
	await _colocar(c.cruce(22, 44) + Vector2(-50, 0), 0.0, 20.0, 290.0)
	await _foto("3_atardecer")
	# Noche con la farola.
	await _colocar(c.cruce(20, 42) + Vector2(-40, 0), 0.0, 10.0, 450.0)
	_ride()._al_evento("casi")
	_ride()._actualizar_vista(0.0)
	await process_frame
	await _foto("4_noche_casi")

	# Contra el andén a toda: la cinemática y el remate.
	var r := _ride()
	r.retraso_resultado = 2.0
	await _colocar(c.punto_frente_a(20, 41), PI / 2.0, 16.0, 120.0)
	r.set_process(true)
	r.partida.advance(1.0, true, false, 0.0)
	await create_timer(0.8).timeout
	await _foto("5_caida")
	await create_timer(1.8).timeout
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
	await create_timer(0.8).timeout
	await _foto("7_caida_noche")

	_hoja()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	quit(0)


func _hoja() -> void:
	var w := 640
	var h := 360
	var hoja := Image.create(w * 2, h * 5, false, Image.FORMAT_RGBA8)
	for i in _fotos.size():
		var f := _fotos[i]
		f.convert(Image.FORMAT_RGBA8)
		hoja.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	hoja.save_png("%s/hoja.png" % SALIDA)
	print("hoja: capturas/hoja.png")
