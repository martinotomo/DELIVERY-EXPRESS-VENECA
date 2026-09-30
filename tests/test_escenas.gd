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
	var m = ride.partida.moto
	m.pos = ride.partida.ciudad.punto_frente_a(4, 6)
	m.rumbo = PI / 2.0
	m.vel = 18.0
	ride.partida.advance(6.0, true, false, 0.0)
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
