extends RefCounted
## El director y las pantallas: que carguen, que solo haya una viva y que el flujo cierre.


func _pantallas(main: Node) -> Array:
	return main.get_node("Pantallas").get_children()


const RUTA := "user://prueba_escenas.cfg"


func run(t) -> void:
	var escena = load("res://scenes/main.tscn")
	t.check(escena != null, "carga main.tscn")
	if escena == null:
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
	var DIRECTOR = load("res://scripts/main.gd")
	DIRECTOR.ruta_progreso = RUTA
	var main: Node = escena.instantiate()
	t.root.add_child(main)
	await t.process_frame
	await t.process_frame

	# Menú de inicio.
	t.check_eq(_pantallas(main).size(), 1, "al arrancar hay una sola pantalla")
	var menu: Node = main.pantalla_actual()
	t.check_eq(menu.name, "Menu", "arranca en el menú")
	for b in ["Jugar", "Taller", "Salir"]:
		t.check(menu.find_child(b, true, false) is Button, "el menú tiene el botón %s" % b)
	t.check(menu.get_node("Titulo").text == str(ProjectSettings.get_setting("application/config/name")).to_upper(), "el título sale de project.godot")
	t.check_eq(ProjectSettings.get_setting("application/config/name"), "Delivery Express", "el juego se llama Delivery Express (D14)")
	t.check_eq(menu.get_node("Titulo").text, "DELIVERY EXPRESS", "el menú muestra el nombre nuevo")
	t.check(menu.get_node("Estado").text.contains("BWS"), "el menú dice qué moto se tiene")

	# Taller: con plata se compra; sin plata los botones están apagados.
	menu.find_child("Taller", true, false).pressed.emit()
	await t.process_frame
	var taller: Node = main.pantalla_actual()
	t.check_eq(taller.name, "Taller", "el botón Taller abre el taller")
	var b_exosto: Button = taller.find_child("Mejora_exosto", true, false)
	t.check(b_exosto.disabled, "sin plata el exosto está apagado")
	main.progreso.dinero = 13000
	taller.actualizar()
	t.check(not b_exosto.disabled, "con plata se puede comprar el exosto")
	b_exosto.pressed.emit()
	t.check(main.progreso.tiene_mejora("exosto"), "comprar el exosto lo instala")
	t.check(b_exosto.disabled and b_exosto.text.contains("instalado"), "el botón dice que ya está instalado")
	t.check(taller.get_node("Plata").text == "$5.000", "el taller cobra y muestra el saldo (%s)" % taller.get_node("Plata").text)
	t.check(taller.find_child("ComprarMoto", true, false).text.contains("NKD"), "el taller ofrece la siguiente moto")
	for hijo in taller.get_children():
		if hijo is Label:
			t.check(hijo.position.x >= 0.0 and hijo.position.x + hijo.size.x <= 640.0, "el texto «%s» cabe en el taller" % hijo.text.left(24))
	taller.find_child("Volver", true, false).pressed.emit()
	await t.process_frame
	t.check_eq(main.pantalla_actual().name, "Menu", "Volver regresa al menú")
	t.check_eq(_pantallas(main).size(), 1, "sigue habiendo una sola pantalla")
	main.pantalla_actual().find_child("Jugar", true, false).pressed.emit()
	await t.process_frame
	await t.process_frame

	var ride: Node = main.pantalla_actual()
	t.check_eq(ride.name, "Recorrido", "Jugar abre el recorrido")
	t.check(ride.partida.moto.moto.vel_max > 25.0, "se juega con la moto mejorada del taller")
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
	var sub: Label = ride.get_node("HUD/Subtitulo")
	t.check(sub.visible, "«casi me mato» muestra subtítulo")
	# Abajo, sobre la barra de números: no tapa la calle (Tomás, 30/09).
	var r_sub := Rect2(sub.position, sub.size)
	var barra: Control = ride.get_node("HUD/Barra")
	t.check(r_sub.position.y >= 280.0, "el subtítulo va en la parte baja (y=%d)" % r_sub.position.y)
	t.check(r_sub.end.y <= barra.position.y, "el subtítulo no tapa los números de la barra")
	var derr: Label = ride.get_node("HUD/Derrape")
	t.check(not r_sub.intersects(Rect2(derr.position, derr.get_minimum_size())), "el subtítulo no se pisa con el aviso de derrape")
	t.check(r_sub.end.x <= 640.0, "el subtítulo cabe en pantalla")
	var larga := 0.0
	var fuente: Font = sub.get_theme_font("font")
	for e in ride.voces.FRASES:
		for f in ride.voces.FRASES[e]:
			larga = maxf(larga, fuente.get_string_size(f, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	t.check(larga + 12.0 <= r_sub.size.x, "la frase más larga cabe en una línea (%d px)" % larga)

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

	# Entregar paga y la plata sale en la barra.
	var r2: Node = main.pantalla_actual()
	var antes: int = main.progreso.dinero
	r2.partida.moto.pos = r2.partida.pedido.restaurante
	r2.partida._revisar_llegada()
	r2.partida.moto.pos = r2.partida.pedido.cliente
	r2.partida._revisar_llegada()
	t.check(main.progreso.dinero > antes, "entregar en el recorrido suma plata al progreso")
	r2._actualizar_vista(0.0)
	t.check_eq(r2.get_node("HUD/Plata").text, main.progreso.pesos(main.progreso.dinero), "la barra muestra la plata")
	# La cifra va pegada a «PLATA» (Tomás, 30/09), también con cifras largas.
	var l_plata: Label = r2.get_node("HUD/Plata")
	var f_plata: Font = l_plata.get_theme_font("font")
	for cifra in ["$0", "$90.000", "$999.999"]:
		var ancho: float = f_plata.get_string_size(cifra, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var fin_texto: float = l_plata.position.x + l_plata.size.x
		var ini_texto: float = fin_texto - ancho
		t.check(r2.PLATA_ETIQUETA_X - fin_texto <= 12.0, "%s queda junto a PLATA" % cifra)
		t.check(ini_texto > 380.0, "%s no se monta en el TIEMPO" % cifra)
	t.check_eq(l_plata.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "la plata va alineada a la derecha")
	# El aviso de derrape: pequeño, en la esquina, y solo cuando toca.
	var aviso: Label = r2.get_node("HUD/Derrape")
	t.check(not aviso.visible, "sin derrapar no hay aviso")
	r2.partida.moto.derrapando = true
	r2._actualizar_vista(0.0)
	t.check(aviso.visible, "derrapando sale el aviso")
	t.check(aviso.position.x < 100 and aviso.position.y > 280, "el aviso va abajo a la izquierda, no en el centro")
	t.check(aviso.get_theme_font_size("font_size") <= 8, "el aviso es pequeño")
	# El aviso del motor: abajo a la izquierda, con la cuenta, y la espera si se funde.
	var l_motor: Label = r2.get_node("HUD/Motor")
	t.check(not l_motor.visible, "con el motor frío no hay aviso")
	r2.partida.moto.calor = 7.2
	r2._actualizar_vista(0.0)
	t.check(l_motor.visible and l_motor.text.contains("FUNDIR") and l_motor.text.ends_with("3"), "a fondo sale «vas a fundir el motor» con la cuenta (%s)" % l_motor.text)
	t.check(l_motor.position.x < 100 and l_motor.position.y > 280, "el aviso del motor va abajo, no tapa la calle")
	var r_motor := Rect2(l_motor.position, l_motor.get_minimum_size())
	var r_sub2 := Rect2(r2.get_node("HUD/Subtitulo").position, r2.get_node("HUD/Subtitulo").size)
	t.check(not r_motor.intersects(r_sub2) and not r_motor.intersects(Rect2(aviso.position, aviso.get_minimum_size())), "no se pisa con el subtítulo ni con el derrape")
	r2.partida.moto.motor_fundido = true
	r2.partida.moto._t_reparar = 2.5
	r2._actualizar_vista(0.0)
	t.check(l_motor.text.contains("FUNDIDO") and l_motor.text.ends_with("3"), "fundido muestra la espera (%s)" % l_motor.text)
	r2.partida.moto.motor_fundido = false
	r2.partida.moto.calor = 0.0
	# Lluvia en pantalla: gotas, bono abajo a la derecha y charcos dibujados.
	var bono: Label = r2.get_node("HUD/Bono")
	t.check(not bono.visible, "seco no hay aviso de bono")
	r2.partida.clima.empezar_lluvia(90.0)
	r2.partida.clima.advance(30.0, r2.partida.moto.pos)
	r2._actualizar_vista(0.0)
	t.check(bono.visible and bono.text.contains("30%"), "lloviendo sale el bono (%s)" % bono.text)
	t.check(bono.position.y > 280 and bono.position.x > 320 and bono.position.x + bono.get_minimum_size().x <= 640, "el bono va abajo a la derecha, dentro de la pantalla")
	t.check(not Rect2(bono.position, bono.get_minimum_size()).intersects(Rect2(r2.get_node("HUD/Subtitulo").position, r2.get_node("HUD/Subtitulo").size)), "el bono no se pisa con el subtítulo")
	t.check(r2.get_node("HUD/Lluvia").intensidad > 0.9, "se ven las gotas")
	var mm: MultiMesh = r2.get_node("Vista/Mundo/Ciudad/Charcos").multimesh
	t.check(mm.instance_count > 0 and mm.instance_count == r2.partida.clima.charcos.size(), "los charcos se dibujan (%d)" % mm.instance_count)
	var suenan := 0
	for rpm in r2.partida.moto.moto.rpm_muestras:
		if r2.get_node("Audio/Motor%d" % rpm).playing:
			suenan += 1
	t.check_eq(suenan, r2.partida.moto.moto.rpm_muestras.size(), "los bucles del motor están sonando")
	# Pisar un charco suena (Tomás: «que suene que pasa por encima de un charco»).
	r2.partida.clima.charcos.assign([{"pos": r2.partida.moto.pos + Vector2(2, 0), "radio": 1.5}])
	r2.partida.moto.vel = 15.0
	r2.partida.moto.pos += Vector2(2, 0)
	r2._audio.ultimo_efecto = ""
	r2.partida._revisar_charco()
	t.check_eq(r2._audio.ultimo_efecto, "charco", "pisar un charco en el recorrido suena a chapoteo")
	r2._process(0.1)
	var llu: float = r2.get_node("Audio/Lluvia").volume_db
	t.check(llu > -3.0, "la lluvia se oye fuerte mientras llueve (%.1f dB)" % llu)
	var motor_max := -99.0
	for rpm in r2.partida.moto.moto.rpm_muestras:
		motor_max = maxf(motor_max, r2.get_node("Audio/Motor%d" % rpm).volume_db)
	t.check(llu > motor_max, "la lluvia no queda tapada por el motor (%.1f vs %.1f dB)" % [llu, motor_max])
	# F9 prende y apaga la lluvia, solo en versiones de desarrollo.
	var f9 := InputEventKey.new()
	f9.keycode = KEY_F9
	f9.pressed = true
	var cl = r2.partida.clima
	t.check(r2.trucos == OS.is_debug_build(), "las teclas de prueba solo existen en desarrollo")
	r2.trucos = true
	r2._input(f9)
	t.check(not cl.lloviendo(), "F9 con lluvia la quita")
	r2._input(f9)
	t.check(cl.lloviendo(), "F9 sin lluvia la pone")
	r2.trucos = false
	r2._input(f9)
	t.check(cl.lloviendo(), "en el .exe exportado F9 no hace nada")
	cl.parar_lluvia()
	# Cebras pintadas en todas las esquinas, y peatones dibujados donde van.
	var c = r2.partida.ciudad
	var n_cebras := 0
	for j in c.N_LARGO + 1:
		for i in c.N_ANCHO + 1:
			n_cebras += c.cebras(i, j).size()
	var n_dibujadas: int = r2.get_node("Vista/Mundo/Ciudad/CebrasCalles").multimesh.instance_count + r2.get_node("Vista/Mundo/Ciudad/CebrasCarreras").multimesh.instance_count
	t.check(n_cebras > 10000 and n_dibujadas == n_cebras, "todas las esquinas tienen sus cebras pintadas (%d)" % n_dibujadas)
	var pe = r2.partida.peatones
	pe.lista.clear()
	pe._t = 9999.0
	var cb: Dictionary = c.cebras(20, 40)[0]
	var peaton: Dictionary = pe.poner_en(cb)
	peaton.pos = cb.centro
	r2._actualizar_vista(0.0)
	var sp: Sprite3D = r2.get_node("Vista/Mundo/Peatones/Peaton0")
	t.check(sp.visible and Vector2(sp.position.x, sp.position.z).distance_to(cb.centro) < 0.01, "el peatón se dibuja en la cebra")
	t.check(not r2.get_node("Vista/Mundo/Peatones/Peaton1").visible, "los sprites sobrantes no se ven")
	t.check_eq(sp.billboard, BaseMaterial3D.BILLBOARD_FIXED_Y, "el peatón es un sprite plano a lo Doom")
	t.check(sp.frame < 4 * pe.ROPAS and sp.frame % 4 < 2, "caminando usa los cuadros de caminar")
	# Atropello en el recorrido: su sonido, su frase y el pedido sin propina a la vista.
	r2._audio.ultimo_efecto = ""
	r2.partida.moto.pos = peaton.pos
	r2.partida.moto.vel = 10.0
	r2.partida._revisar_atropello()
	r2._actualizar_vista(0.0)
	t.check_eq(r2._audio.ultimo_efecto, "atropello", "atropellar suena a atropello")
	var sub_a: Label = r2.get_node("HUD/Subtitulo")
	t.check(sub_a.visible and r2.voces.FRASES.atropello.has(sub_a.text), "sale una frase de atropello (%s)" % sub_a.text)
	t.check(r2.get_node("HUD/Pedido").text.contains("SIN PROPINA"), "el pedido avisa que se quedó sin propina")
	t.check_eq(sp.frame % 4, 2, "el atropellado se ve en el piso")
	main.menu()
	await t.process_frame
	t.check_eq(main.pantalla_actual().name, "Menu", "se puede volver al menú")
	t.check_eq(_pantallas(main).size(), 1, "con una sola pantalla")
	t.check(main.pantalla_actual().get_node("Estado").text.contains(main.progreso.pesos(main.progreso.dinero)), "el menú muestra la plata ganada")
	DIRECTOR.ruta_progreso = "user://progreso.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))

	main.queue_free()
	await t.process_frame
