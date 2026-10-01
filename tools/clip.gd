extends SceneTree
## Clip corto para TikTok (F7): el menú, y luego cada moto (Bwis, NKD, Ninja) andando y cayéndose,
## con su cinemática y su remate. Se graba con el Movie Maker de Godot (cuadro a cuadro, sin
## perder fotogramas aunque el PC sea lento) y tools/clip.sh lo pasa a MP4.
##   godot --path . --write-movie build/clip/clip.avi --fixed-fps 30 -s res://tools/clip.gd
## El clip de verdad lo graba Tomás con OBS jugando; este es el borrador que muestra qué se ve.

const TOMAS := [
	# moto, causa (""= la curva de verdad, contra el andén), segundos andando antes
	["bws", "", 3.5],
	["nkd", "perro", 3.0],
	["ninja", "bus", 3.0],
]

var _main: Node


func _initialize() -> void:
	_correr.call_deferred()


func _ride() -> Node:
	return _main.pantalla_actual()


func _esperar(s: float) -> void:
	await create_timer(s).timeout


func _correr() -> void:
	var D = load("res://scripts/main.gd")
	D.ruta_progreso = "user://clip_progreso.cfg"
	D.ruta_opciones = "user://clip_opciones.cfg"
	D.mostrar_advertencia = false
	for r in [D.ruta_progreso, D.ruta_opciones]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(r))
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	_main.progreso.dinero = 187500
	_main.menu()
	await _esperar(1.5)

	for toma in TOMAS:
		_main.progreso.tenidas = {"bws": {}, "nkd": {}, "ninja": {}}
		_main.progreso.moto = toma[0]
		_main.reiniciar()
		await process_frame
		var r := _ride()
		r.retraso_resultado = 2.2
		var c = r.partida.ciudad
		var m = r.partida.moto
		# Andando por una carrera larga hacia el norte, a toda.
		m.pos = c.cruce(18, 30) + Vector2(0, 20)
		m.rumbo = PI / 2.0
		m.vel = m.moto.vel_max * 0.8
		r.partida.reloj.t = [60.0, 150.0, 430.0][TOMAS.find(toma)]
		Input.action_press("acelerar")
		await _esperar(toma[2])
		if toma[1] == "":
			# La curva: se tira el giro a fondo a toda velocidad hasta montarse al andén.
			Input.action_press("derecha")
			while not r.partida.terminada:
				await process_frame
			Input.action_release("derecha")
		else:
			r.partida._morir(toma[1])
		Input.action_release("acelerar")
		await _esperar(r.retraso_resultado + 2.8) # la caída dibujada y luego el remate

	_main.menu()
	await _esperar(2.0)
	for r in ["user://clip_progreso.cfg", "user://clip_opciones.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(r))
	quit(0)
