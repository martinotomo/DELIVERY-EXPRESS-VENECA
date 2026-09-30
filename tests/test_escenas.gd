extends RefCounted
## El director y las pantallas: que carguen, que solo haya una viva y que el flujo cierre.


func _pantallas(main: Node) -> Array:
	return main.get_node("Pantallas").get_children()


func run(t) -> void:
	var escena = load("res://scenes/main.tscn")
	t.check(escena != null, "carga main.tscn")
	if escena == null:
		return
	var main: Node = escena.instantiate()
	t.root.add_child(main)
	await t.process_frame
	await t.process_frame

	t.check_eq(_pantallas(main).size(), 1, "al arrancar hay una sola pantalla")
	var ride: Node = main.pantalla_actual()
	t.check_eq(ride.name, "Recorrido", "arranca en el recorrido")
	for ruta in ["Vista/Mundo/Camara", "Vista/Mundo/Sol", "HUD/Manubrio", "HUD/Minimapa",
			"HUD/Velocidad", "HUD/Reloj", "HUD/Hora", "HUD/Pedido", "HUD/Subtitulo"]:
		t.check(ride.has_node(ruta), "existe %s" % ruta)
	var vp: SubViewport = ride.get_node("Vista/Mundo")
	t.check_eq(vp.size, Vector2i(320, 180), "el mundo se dibuja a 320×180 (look Doom)")
	var n_cuadras: int = ride.partida.ciudad.anchos.size() * ride.partida.ciudad.largos.size()
	var edificios: MultiMeshInstance3D = ride.get_node("Vista/Mundo/Ciudad/Andenes")
	t.check_eq(edificios.multimesh.instance_count, n_cuadras, "un andén por cuadra (%d)" % n_cuadras)

	# El manubrio se ve (Tomás: «no se veía la moto»).
	var manubrio: Control = ride.get_node("HUD/Manubrio")
	t.check(manubrio.is_visible_in_tree(), "el manubrio está visible al arrancar")
	t.check(ride.get_node("HUD").visible, "la capa del HUD está visible")
	var pantalla := Rect2(0, 0, 640, 360)
	for g in [-1.0, 0.0, 1.0]:
		var r: Rect2 = manubrio.rect_en_pantalla(g)
		var dentro := r.intersection(pantalla)
		t.check(dentro.get_area() > 0.8 * r.get_area(), "con giro %s el manubrio queda casi todo en pantalla (%s)" % [g, r])
		t.check(r.position.y > 120.0 and r.position.y < 250.0, "el manubrio ocupa la mitad baja, no se sale por abajo (y=%d)" % r.position.y)
	var img: Image = load("res://assets/ui/manubrio.png").get_image()
	var opacos := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				opacos += 1
	t.check(opacos > img.get_width() * img.get_height() / 4, "el sprite del manubrio no está vacío (%d píxeles opacos)" % opacos)
	# A las resoluciones de pantalla comunes la interfaz de 640×360 escala entera y cabe completa.
	t.check_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport", "estirado por viewport")
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2560, 1600), Vector2i(1366, 768)]:
		var k := mini(res.x / 640, res.y / 360)
		t.check(k >= 1, "a %s la escala entera es %d" % [res, k])
		var abajo_manubrio: float = (manubrio.rect_en_pantalla(0.0).end.y) * k
		t.check(abajo_manubrio <= res.y, "a %s el manubrio termina dentro de la ventana (%d ≤ %d)" % [res, abajo_manubrio, res.y])
	# Con la ventana cambiada de tamaño el contenido sigue siendo 640×360 (no se recorta).
	var tam_antes: Vector2i = t.root.size
	for res in [Vector2i(1920, 1080), Vector2i(2560, 1600)]:
		t.root.size = res
		await t.process_frame
		t.check_eq(Vector2i(t.root.get_visible_rect().size), Vector2i(640, 360), "a %s el HUD sigue midiendo 640×360" % res)
		t.check(manubrio.is_visible_in_tree(), "a %s el manubrio sigue visible" % res)
	t.root.size = tam_antes
	await t.process_frame

	# La cámara sigue a la moto.
	ride.partida.advance(2.0, true, false, 0.0)
	await t.process_frame
	var cam: Camera3D = ride.get_node("Vista/Mundo/Camara")
	var p: Vector2 = ride.partida.moto.pos
	t.check(Vector2(cam.position.x, cam.position.z).distance_to(p) < 0.5, "la cámara va donde va la moto")

	# Un evento pone subtítulo.
	ride.partida.evento.emit("casi")
	await t.process_frame
	t.check(ride.get_node("HUD/Subtitulo").visible, "«casi me mato» muestra subtítulo")

	# Estrellarse: cinemática y luego el remate.
	ride.retraso_resultado = 0.0
	ride.duracion_encuadre = 0.0
	var m = ride.partida.moto
	m.pos = ride.partida.ciudad.punto_frente_a(4, 6)
	m.rumbo = PI / 2.0
	m.vel = 18.0
	ride.partida.advance(6.0, true, false, 0.0)
	# Antes de que cambie la pantalla: la moto caída tiene que verse, y grande.
	var caida: Node3D = ride.get_node("Vista/Mundo/MotoCaida")
	t.check(caida.is_visible_in_tree(), "en la caída la moto está visible")
	var caja := AABB()
	var primera := true
	for pieza in caida.get_node("Cuerpo").get_children():
		var gi := pieza as MeshInstance3D
		var b: AABB = gi.global_transform * gi.get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
	var cuadro := Rect2()
	var fuera := 0
	for i in 8:
		var v: Vector3 = caja.get_endpoint(i)
		if not cam.is_position_in_frustum(v):
			fuera += 1
		var q: Vector2 = cam.unproject_position(v)
		cuadro = Rect2(q, Vector2.ZERO) if i == 0 else cuadro.expand(q)
	t.check(fuera <= 2, "la moto caída entra en el cuadro de la cámara (%d esquinas fuera)" % fuera)
	var vista := Rect2(0, 0, 320, 180)
	var visible_px := cuadro.intersection(vista)
	t.check(visible_px.size.x >= 55.0 and visible_px.size.y >= 30.0, "la moto caída se ve grande (%s px en 320×180)" % visible_px.size)
	t.check(vista.has_point(cuadro.get_center()), "la moto caída queda cerca del centro (%s)" % cuadro.get_center())
	await t.process_frame
	await t.process_frame
	t.check_eq(_pantallas(main).size(), 1, "tras estrellarse sigue habiendo una sola pantalla")
	var res: Node = main.pantalla_actual()
	t.check_eq(res.name, "Resultado", "tras estrellarse sale el resultado")
	t.check(res.get_node("Caja/Texto").text.contains("agarre de tu BWS"), "el resultado muestra el remate")

	main.reiniciar()
	await t.process_frame
	await t.process_frame
	t.check_eq(_pantallas(main).size(), 1, "tras reintentar hay una sola pantalla")
	t.check_eq(main.pantalla_actual().name, "Recorrido", "reintentar vuelve al recorrido")

	main.queue_free()
	await t.process_frame
