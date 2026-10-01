extends SceneTree
## Mide los fps recorriendo la ciudad de punta a punta (criterio 4 de la F3, PLAN_FASES.md).
## La moto va sola por la Carrera 21, del sur al norte, a 25 m/s (90 km/h), con tráfico, gente,
## semáforos y el ciclo de día corriendo. Al final imprime fps promedio, el 1 % más lento y el
## peor fotograma, y lo guarda en user://medir_fps.txt.
##
## En el PC de Tomás (con ventana, NO headless; en un portátil, probar también con la gráfica integrada):
##   godot --path . -s res://tools/medir_fps.gd
## Opcional: -- --segundos=60 --vel=25

const RECORRIDO := preload("res://scenes/recorrido.tscn")

var _segundos := 90.0
var _vel := 25.0
var _tiempos: PackedFloat32Array = []
var _r
var _t := 0.0
var _desde: Vector2
var _hasta: Vector2


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--segundos="):
			_segundos = float(arg.split("=")[1])
		elif arg.begins_with("--vel="):
			_vel = float(arg.split("=")[1])
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_r = RECORRIDO.instantiate()
	root.add_child(_r)
	_r.set_process(false) # la moto la manejamos aquí; lo demás sigue igual que en el juego
	var c = _r.partida.ciudad
	_desde = c.cruce(20, 0) + Vector2(-3, 20)
	_hasta = c.cruce(20, c.N_LARGO) + Vector2(-3, -20)
	_r.partida.moto.pos = _desde
	_r.partida.moto.rumbo = PI / 2.0
	print("medir_fps: %.0f s a %.0f m/s por la Carrera 21 (%.0f m)" % [_segundos, _vel, _desde.distance_to(_hasta)])


func _process(delta: float) -> bool:
	if _r == null:
		return false
	_t += delta
	if _t > 2.0: # los primeros fotogramas compilan shaders: no cuentan
		_tiempos.append(delta)
	var m = _r.partida.moto
	var k := fmod(_t * _vel, 2.0 * _desde.distance_to(_hasta)) / _desde.distance_to(_hasta)
	var ida := k <= 1.0
	m.pos = _desde.lerp(_hasta, k if ida else 2.0 - k)
	m.rumbo = PI / 2.0 if ida else -PI / 2.0
	m.vel = _vel
	# Lo que hace el juego cada fotograma, sin mandos ni choques (la moto va por el centro de la vía).
	var p = _r.partida
	p.reloj.advance(delta * 20.0) # el día pasa rápido: se mide también de noche
	p.clima.advance(delta, m.pos)
	p.peatones.advance(delta, m.pos, m.direccion())
	p.transito.advance(delta)
	p.transeuntes.advance(delta, m.pos, m.direccion())
	p.trafico.advance(delta, m.pos, m.direccion())
	_r._actualizar_vista(delta)
	if _t >= _segundos + 2.0:
		_informe()
		return true
	return false


func _informe() -> void:
	var ordenados := _tiempos.duplicate()
	ordenados.sort()
	var n := ordenados.size()
	var suma := 0.0
	for x in ordenados:
		suma += x
	var promedio := n / suma
	var uno_pct: float = 1.0 / ordenados[int(n * 0.99)]
	var peor: float = ordenados[n - 1] * 1000.0
	var lentos := 0
	for x in ordenados:
		if x > 1.0 / 55.0:
			lentos += 1
	var texto := "fotogramas: %d\nfps promedio: %.1f\nfps del 1 %% más lento: %.1f\npeor fotograma: %.1f ms\nfotogramas por debajo de 55 fps: %d (%.1f %%)\ngráfica: %s\n" % [
		n, promedio, uno_pct, peor, lentos, 100.0 * lentos / n, RenderingServer.get_video_adapter_name()]
	print(texto)
	var f := FileAccess.open("user://medir_fps.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(texto)
		print("guardado en ", ProjectSettings.globalize_path("user://medir_fps.txt"))
