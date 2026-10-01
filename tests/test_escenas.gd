extends RefCounted
## El director y las pantallas: que carguen, que solo haya una viva y que el flujo cierre.


func _pantallas(main: Node) -> Array:
	return main.get_node("Pantallas").get_children()


const RUTA := "user://prueba_escenas.cfg"
const PROGRESO_T := preload("res://scripts/progreso.gd")
const RECORRIDO := preload("res://scenes/recorrido.tscn")


func run(t) -> void:
	var escena = load("res://scenes/main.tscn")
	t.check(escena != null, "carga main.tscn")
	if escena == null:
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
	var DIRECTOR = load("res://scripts/main.gd")
	DIRECTOR.ruta_progreso = RUTA
	DIRECTOR.ruta_opciones = "user://prueba_escenas_opciones.cfg" # no leer las opciones de verdad (idioma)
	DIRECTOR.mostrar_advertencia = false # la advertencia la prueba test_pantallas
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
	# Logo (F2): dibujado para ese nombre; si el nombre cambia, vuelve el título en letras.
	var logo: TextureRect = menu.get_node_or_null("Logo")
	t.check(logo != null and logo.visible and logo.texture != null, "el menú muestra el logo")
	t.check(not menu.get_node("Titulo").visible, "con logo, el título en letras se esconde")
	if logo != null:
		var r_logo := Rect2(logo.position, logo.size * logo.scale)
		t.check(r_logo.end.y <= menu.find_child("Jugar", true, false).global_position.y and r_logo.position.x >= 0.0 and r_logo.end.x <= 640.0, "el logo no se monta en los botones (%s)" % r_logo)
	t.check(menu.LOGO_PARA == "Delivery Express", "el logo dice para qué nombre está hecho")
	# Música en el director (sobrevive a los cambios de pantalla).
	t.check(main.get_node("Musica").playing and main.musica_actual == "menu", "en el menú suena su música")
	var loop_menu: AudioStreamWAV = main.get_node("Musica").stream
	t.check(loop_menu.loop_mode != AudioStreamWAV.LOOP_DISABLED, "la música del menú da vueltas sin cortarse")
	t.check(menu.get_node("Estado").text.contains("Bwis"), "el menú dice qué moto se tiene")

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
	# Vitrina a lo Most Wanted: las tres motos en fila, se pasa de una a otra con ←/→.
	t.check_eq(taller.escogida, 0, "el taller abre en la moto que se tiene")
	var sprites := []
	for id in ["bws", "nkd", "ninja"]:
		sprites.append(taller.find_child("Moto_" + id, true, false))
	t.check(sprites.all(func(x): return x is TextureRect), "cada moto tiene su dibujo")
	taller._vista = float(taller.escogida)
	taller._acomodar()
	t.check(sprites[0].size.x * sprites[0].scale.x > sprites[1].size.x * sprites[1].scale.x * 1.5, "la escogida se ve grande y las demás pequeñas")
	t.check(sprites[0].position.x < sprites[1].position.x and sprites[1].position.x < sprites[2].position.x, "las motos van una al lado de la otra")
	t.check(sprites[1].modulate.v < sprites[0].modulate.v, "las que no están escogidas se ven apagadas")
	var estado: Label = taller.get_node("Estado")
	t.check(estado.text.contains("EN USO"), "la moto en uso lo dice (%s)" % estado.text)
	t.check(taller.find_child("ComprarMoto", true, false).disabled, "la moto que ya se tiene no se compra")
	taller.mover(1)
	t.check_eq(taller.escogida, 1, "→ pasa a la NKD")
	t.check(taller.get_node("Nombre").text.contains("NKD"), "y muestra su nombre")
	t.check(estado.text.contains("BLOQUEADA") and estado.text.contains("$40.000"), "sin plata sale bloqueada con su precio (%s)" % estado.text)
	t.check(taller.get_node("Candado").visible, "con su candado")
	t.check(b_exosto.disabled, "las mejoras son solo para la moto en uso")
	t.check(taller.get_node("Falta").text.contains("$35.000"), "dice cuánto falta (%s)" % taller.get_node("Falta").text)
	main.progreso.dinero = 60000
	taller.actualizar()
	var b_moto: Button = taller.find_child("ComprarMoto", true, false)
	t.check(not b_moto.disabled and b_moto.text.contains("NKD") and b_moto.text.contains("$40.000"), "con plata se puede comprar (%s)" % b_moto.text)
	t.check(not taller.get_node("Candado").visible, "y ya no tiene candado")
	taller.mover(1)
	t.check(taller.get_node("Estado").text.contains("BLOQUEADA") and taller.get_node("Falta").text.contains("NKD"), "la Ninja pide primero la NKD (%s)" % taller.get_node("Falta").text)
	taller.mover(1)
	t.check_eq(taller.escogida, 2, "no se pasa de la última")
	taller.mover(-1)
	b_moto.pressed.emit()
	t.check_eq(main.progreso.moto, "nkd", "comprar desde la vitrina cambia de moto")
	t.check(taller.get_node("Estado").text.contains("EN USO") and not b_exosto.disabled, "la nueva queda en uso y con sus mejoras a la venta")
	taller.mover(-1)
	t.check(taller.get_node("Estado").text.contains("EN TU GARAJE"), "la Bwis sigue siendo tuya (%s)" % taller.get_node("Estado").text)
	t.check(not b_moto.disabled and b_moto.text.contains("USAR"), "y tiene botón para usarla (%s)" % b_moto.text)
	t.check(b_exosto.disabled, "las mejoras se compran con la moto en uso")
	b_moto.pressed.emit()
	t.check_eq(main.progreso.moto, "bws", "USAR vuelve a la Bwis")
	t.check(taller.get_node("Estado").text.contains("EN USO"), "y la Bwis queda en uso")
	t.check(taller.get_node("Nombre").text.contains("BWIS"), "sin moverse de la Bwis en la vitrina")
	# F10 da plata de prueba en el taller, solo en desarrollo.
	var f10 := InputEventKey.new()
	f10.keycode = KEY_F10
	f10.pressed = true
	t.check(taller.trucos == (OS.is_debug_build() and not OS.has_feature("entrega")), "F10 solo existe en desarrollo (taller)")
	var antes_f10: int = main.progreso.dinero
	taller.trucos = true
	taller._input(f10)
	t.check_eq(main.progreso.dinero, antes_f10 + PROGRESO_T.PLATA_PRUEBA, "F10 en el taller suma plata")
	t.check_eq(taller.get_node("Plata").text, PROGRESO_T.pesos(antes_f10 + PROGRESO_T.PLATA_PRUEBA), "y el saldo se ve al momento")
	taller.trucos = false
	taller._input(f10)
	t.check_eq(main.progreso.dinero, antes_f10 + PROGRESO_T.PLATA_PRUEBA, "en el .exe F10 no hace nada (taller)")
	for hijo in taller.find_children("*", "Control", true, false):
		if hijo is Label or hijo is Button:
			if hijo.is_visible_in_tree():
				var r := Rect2(hijo.global_position, hijo.size)
				t.check(r.position.x >= 0.0 and r.end.x <= 640.0 and r.end.y <= 360.0, "«%s» cabe en el taller" % hijo.text.left(24))
	# La hoja de motos: una por moto, con su propio color.
	var hoja: Image = load("res://assets/ui/motos_taller.png").get_image()
	var colores := []
	for k in 3:
		var suma := Color(0, 0, 0)
		var n := 0
		for y in hoja.get_height():
			for x in range(k * 128, (k + 1) * 128):
				var px := hoja.get_pixel(x, y)
				if px.a > 0.5 and px.s > 0.25:
					suma += px
					n += 1
		colores.append(suma / maxf(n, 1.0))
	t.check(colores[0].b > colores[0].g and colores[2].g > colores[2].r * 1.3, "la Bwis es azulada y la Ninja verde")
	t.check(hoja.get_width() == 384 and hoja.get_height() == 96, "tres motos de 128×96")
	# Deja el progreso como venía (Bwis con exosto) para el resto de la prueba.
	main.progreso.tenidas = {"bws": {"exosto": true}}
	main.progreso.moto = "bws"
	main.progreso.dinero = 5000
	main.progreso.guardar()
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
	t.check_eq(manubrio.sprite_actual(), load("res://assets/ui/manubrio.png"), "la Bwis tiene su manubrio de scooter")
	for id in ["nkd", "ninja"]:
		var otro_r = RECORRIDO.instantiate()
		var prog = PROGRESO_T.new("user://prueba_manubrio.cfg")
		prog.moto = id
		otro_r.progreso = prog
		main.add_child(otro_r)
		t.check_eq(otro_r.get_node("HUD/Manubrio").sprite_actual(), load("res://assets/ui/manubrio_%s.png" % id), "la %s tiene su propio puesto de mando" % id)
		otro_r.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://prueba_manubrio.cfg"))
	var img: Image = load("res://assets/ui/manubrio.png").get_image()
	var opacos := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				opacos += 1
	t.check(opacos > img.get_width() * img.get_height() / 4, "el sprite del manubrio no está vacío (%d píxeles opacos)" % opacos)
	# Puestos de mando dibujados a partir de cómo se ven de verdad (Tomás, 30/09): la aguja cae sobre
	# la carátula clara, los números sobre la pantalla, espejos a los dos lados y la calle al frente libre.
	var MANUBRIO_T := load("res://scripts/manubrio.gd")
	for id in MANUBRIO_T.TABLEROS:
		var tab: Dictionary = MANUBRIO_T.TABLEROS[id]
		var im: Image = MANUBRIO_T.SPRITES[id].get_image()
		t.check(im.get_width() == 320 and im.get_height() == 96, "%s: puesto de 320×96" % id)
		if tab.has("aguja"):
			var cara := im.get_pixelv(Vector2i(tab.aguja) + Vector2i(0, -4))
			t.check(cara.a > 0.5 and cara.v > 0.6, "%s: la aguja gira sobre una carátula clara (%s)" % [id, cara])
		if tab.has("lcd"):
			var r: Rect2 = tab.lcd
			var dentro_lcd := im.get_pixelv(Vector2i(r.get_center()))
			var fuera_lcd := im.get_pixelv(Vector2i(r.position) + Vector2i(-3, int(r.size.y / 2)))
			t.check(dentro_lcd.a > 0.5 and absf(dentro_lcd.v - fuera_lcd.v) > 0.05 or dentro_lcd != fuera_lcd, "%s: los números van sobre la pantalla" % id)
			var tinta: Color = tab.tinta
			t.check(absf(tinta.get_luminance() - dentro_lcd.get_luminance()) > 0.35, "%s: los números se leen sobre la pantalla" % id)
		for lado in [Rect2i(0, 0, 110, 26), Rect2i(210, 0, 110, 26)]:
			var n_esp := 0
			for y in range(lado.position.y, lado.end.y):
				for x in range(lado.position.x, lado.end.x):
					if im.get_pixel(x, y).a > 0.5:
						n_esp += 1
			t.check(n_esp > 150, "%s: tiene espejo a cada lado (%d px)" % [id, n_esp])
		var n_frente := 0
		for y in 18:
			for x in range(130, 190):
				if im.get_pixel(x, y).a > 0.5:
					n_frente += 1
		t.check(n_frente < 60 * 18 * 0.25, "%s: la calle de enfrente se sigue viendo (%d px tapados de %d)" % [id, n_frente, 60 * 18])
	var m_prueba = MANUBRIO_T.new()
	m_prueba.moto_id = "ninja"
	t.check_eq(m_prueba.tablero().marca, "rpm", "la Ninja marca revoluciones con la aguja y la velocidad en la pantalla")
	m_prueba.moto_id = "bws"
	t.check(m_prueba.tablero().has("aguja") and m_prueba.tablero().marca == "vel", "la Bwis tiene velocímetro de aguja (Tomás, 30/09)")
	m_prueba.moto_id = "otra"
	t.check_eq(m_prueba.tablero(), MANUBRIO_T.TABLEROS.bws, "una moto desconocida usa el tablero de la Bwis")
	m_prueba.free()
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
	# Se ve la calle de enfrente por encima del tablero, como en una moto de verdad (Tomás, 30/09):
	# entre el horizonte y lo primero que tapa el centro de la pantalla quedan al menos 55 px.
	var adelante := -cam.global_transform.basis.z
	adelante.y = 0.0
	var lejos := cam.global_position + adelante.normalized() * 2000.0
	lejos.y = 0.0
	var horizonte: float = cam.unproject_position(lejos).y * 2.0
	var MAN := load("res://scripts/manubrio.gd")
	for id in MAN.SPRITES:
		var im: Image = MAN.SPRITES[id].get_image()
		var fila := im.get_height()
		var seguidas := 0   # filas tapadas seguidas (una rayita, como el marco del parabrisas, no cuenta)
		for y in im.get_height():
			var tapados := 0
			for x in range(130, 190):
				if im.get_pixel(x, y).a > 0.5:
					tapados += 1
			seguidas = seguidas + 1 if tapados > 30 else 0
			if seguidas == 4:
				fila = y - 3
				break
		var tope: float = MAN.ARRIBA + fila * MAN.ESCALA
		t.check(tope - horizonte >= 55.0, "%s: se ven %d px de calle entre el horizonte y el tablero" % [id, tope - horizonte])

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

	t.check_eq(main.musica_actual, "conduccion", "en la calle suena la música de conducción")
	ride._al_evento("casi")
	t.check(ride.get_node("HUD/Subtitulo").text in ride.voces.FRASES.casi, "el comentario sale como subtítulo")
	t.check(ride.get_node_or_null("Voz") == null, "y no suena ninguna voz (D28)")
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
	t.check_eq(main.musica_actual, "muerte", "al caer entra la música épica y trágica")
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
	# Luego la ilustración de la caída (F2), de la moto con que se jugaba, a pantalla completa.
	var ilus: TextureRect = ride.get_node("HUD/Cinematica")
	t.check(ilus.visible and ilus.texture != null and ilus.texture.resource_path.ends_with("cinematica_bws.png"), "sale la ilustración de la caída de la Bwis")
	t.check(ilus.size == Vector2(640, 360) or ilus.size * ilus.scale >= Vector2(640, 360), "a pantalla completa")
	await t.process_frame
	await t.process_frame
	t.check_eq(_pantallas(main).size(), 1, "tras estrellarse sigue habiendo una sola pantalla")
	var res: Node = main.pantalla_actual()
	t.check_eq(res.name, "Resultado", "tras estrellarse sale el resultado")
	t.check(res.get_node("Caja/Texto").text.contains("agarre de tu Bwis"), "el resultado muestra el remate")
	var ilus_res: TextureRect = res.get_node_or_null("Ilustracion")
	t.check(ilus_res != null and ilus_res.visible and ilus_res.texture.resource_path.ends_with("cinematica_bws.png"), "el remate va sobre la ilustración de la caída")

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
	t.check(r2.trucos == (OS.is_debug_build() and not OS.has_feature("entrega")), "las teclas de prueba solo existen en desarrollo")
	r2.trucos = true
	r2._input(f9)
	t.check(not cl.lloviendo(), "F9 con lluvia la quita")
	r2._input(f9)
	t.check(cl.lloviendo(), "F9 sin lluvia la pone")
	r2.trucos = false
	r2._input(f9)
	t.check(cl.lloviendo(), "en el .exe exportado F9 no hace nada")
	# F10 da plata de prueba también en la calle (si hay progreso).
	var prog_f10 = PROGRESO_T.new("user://prueba_f10.cfg")
	prog_f10.dinero = 0
	r2.progreso = prog_f10
	var f10c := InputEventKey.new()
	f10c.keycode = KEY_F10
	f10c.pressed = true
	r2.trucos = true
	r2._input(f10c)
	t.check_eq(prog_f10.dinero, PROGRESO_T.PLATA_PRUEBA, "F10 en la calle suma plata")
	r2.trucos = false
	r2._input(f10c)
	t.check_eq(prog_f10.dinero, PROGRESO_T.PLATA_PRUEBA, "en el .exe F10 no hace nada (calle)")
	r2.progreso = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://prueba_f10.cfg"))
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
	# Ciudad con más movimiento (Tomás, 30/09): gente en los andenes, semáforos y señales.
	r2.partida.transeuntes.advance(0.1, r2.partida.moto.pos)
	r2._actualizar_vista(0.0)
	var n_gente := 0
	var en_anden_ok := true
	for tr_sp in r2.get_node("Vista/Mundo/Transeuntes").get_children():
		if tr_sp.visible:
			n_gente += 1
			if c.distancia_anden(Vector2(tr_sp.position.x, tr_sp.position.z)) > 0.0 or tr_sp.position.y < r2.ANDEN_ALTO:
				en_anden_ok = false
	t.check_eq(n_gente, r2.partida.transeuntes.MAX, "se dibuja la gente de los andenes")
	t.check(en_anden_ok, "parada sobre el andén")
	var sem_n: int = r2.get_node("Vista/Mundo/Ciudad/Transito/PostesSemaforo").multimesh.instance_count
	t.check_eq(sem_n, r2.partida.transito.semaforos().size(), "cada semáforo tiene su poste")
	t.check(r2.get_node("Vista/Mundo/Ciudad/Transito/Senal_pare").multimesh.instance_count > 100, "hay señales de PARE")
	r2.partida.transito.t = 0.0
	r2._actualizar_vista(0.0)
	t.check(r2._mats_semaforo.x_verde.emission_energy_multiplier > 0.0 and r2._mats_semaforo.x_rojo.emission_energy_multiplier == 0.0, "con verde para las calles, se prende la luz verde")
	t.check(r2._mats_semaforo.y_rojo.emission_energy_multiplier > 0.0, "y las carreras ven rojo")
	r2.partida.transito.t = 12.0
	r2._actualizar_vista(0.0)
	t.check(r2._mats_semaforo.x_rojo.emission_energy_multiplier > 0.0 and r2._mats_semaforo.y_verde.emission_energy_multiplier > 0.0, "los semáforos cambian")
	# Tráfico (F3): cada vehículo se dibuja donde va, con el cuadro según cómo se ve.
	r2.partida.trafico.advance(0.1, r2.partida.moto.pos, r2.partida.moto.direccion())
	r2._actualizar_vista(0.0)
	var n_veh := 0
	var veh_ok := true
	for k in r2.partida.trafico.lista.size():
		var vs: Sprite3D = r2.get_node("Vista/Mundo/Vehiculos/Vehiculo%d" % k)
		var vd: Dictionary = r2.partida.trafico.lista[k]
		if vs.visible:
			n_veh += 1
			if Vector2(vs.position.x, vs.position.z).distance_to(vd.pos) > 0.01 or vs.texture == null:
				veh_ok = false
	t.check(n_veh == r2.partida.trafico.lista.size() and n_veh > 0 and veh_ok, "cada carro del tráfico tiene su sprite en su sitio (%d)" % n_veh)
	var cam0 := Vector2.ZERO
	t.check_eq(r2.cuadro_vehiculo(cam0, Vector2(10, 0), Vector2(-1, 0)), 0, "un carro que viene de frente se ve de frente")
	t.check_eq(r2.cuadro_vehiculo(cam0, Vector2(10, 0), Vector2(1, 0)), 4, "uno que va adelante se ve de espaldas")
	t.check_eq(r2.cuadro_vehiculo(cam0, Vector2(10, 0), Vector2(0, 1)), 2, "uno que cruza hacia la derecha muestra el frente a la derecha")
	t.check_eq(r2.cuadro_vehiculo(cam0, Vector2(10, 0), Vector2(0, -1)), 6, "y hacia la izquierda, a la izquierda")
	# Los cerros orientales (F3): siempre al oriente (x negativa), lejos y siguiendo a la cámara.
	var cerros: MeshInstance3D = r2.get_node("Vista/Mundo/Cerros")
	var caja_c: AABB = cerros.get_aabb()
	t.check(Vector2(cerros.position.x, cerros.position.z).distance_to(r2.partida.moto.pos) < 0.01, "los cerros siguen a la moto")
	t.check(caja_c.get_center().x < -200.0 and caja_c.position.y + caja_c.size.y > 50.0, "los cerros quedan al oriente y altos (%s)" % str(caja_c))
	t.check((cerros.mesh.surface_get_material(0) as StandardMaterial3D).disable_fog, "la niebla no se los come")
	# F5 en el HUD: tipo de pedido con su aviso, racha de fe y calificación del cliente.
	r2.partida.pedido.tipo = "sopa"
	r2.partida.fase = r2.partida.ENTREGAR
	r2.partida.estado_pedido = 0.5
	r2._actualizar_vista(0.0)
	var l_ped: String = r2.get_node("HUD/Pedido").text
	t.check(l_ped.contains("SOPA") and l_ped.contains("50%"), "el pedido dice que es sopa y cómo va (%s)" % l_ped.replace("\n", " / "))
	t.check(l_ped.contains(r2.partida.pedido.nombre_cliente.to_upper()), "y para quién es")
	r2.partida.racha = 4
	r2._actualizar_vista(0.0)
	var l_racha: Label = r2.get_node("HUD/Racha")
	t.check(l_racha.visible and l_racha.text.contains("4"), "la racha de fe se ve en el HUD (%s)" % l_racha.text)
	r2.partida.racha = 0
	r2._actualizar_vista(0.0)
	t.check(not l_racha.visible, "sin racha no se muestra")
	r2.partida.calificado.emit(4, "Rápido y completo.")
	r2._actualizar_vista(0.0)
	var l_estr: Label = r2.get_node("HUD/Estrellas")
	t.check(l_estr.visible and l_estr.text.count("★") == 4 and l_estr.text.count("☆") == 1, "sale la calificación con estrellas (%s)" % l_estr.text)
	t.check(not Rect2(l_estr.position, l_estr.get_minimum_size()).intersects(Rect2(r2.get_node("HUD/Minimapa").position, r2.get_node("HUD/Minimapa").size)), "la calificación no tapa el minimapa")
	# Nomenclatura (F3): placas en las esquinas cercanas y la ubicación bajo el minimapa.
	r2.partida.moto.pos = c.cruce(20, 41) + Vector2(30, 0)
	r2._actualizar_vista(0.0)
	var placas := 0
	var cerca_ok := true
	for pl in r2.get_node("Vista/Mundo/Letreros").find_children("*", "Label3D", true, false):
		if pl.visible:
			placas += 1
			if Vector2(pl.global_position.x, pl.global_position.z).distance_to(r2.partida.moto.pos) > 2.5 * 172.0:
				cerca_ok = false
			if not (pl.text.begins_with("Cl ") or pl.text.begins_with("Kr ") or pl.text.begins_with("Av ")):
				cerca_ok = false
	t.check(placas >= 16 and cerca_ok, "las esquinas cercanas tienen placa con su calle y carrera (%d)" % placas)
	t.check(r2.get_node("HUD/Ubicacion").text.begins_with("Cl 42"), "bajo el minimapa dice por dónde va: %s" % r2.get_node("HUD/Ubicacion").text)
	t.check(r2.get_node("HUD/Ubicacion").text.contains(c.nombre_zona(c.zona_en(r2.partida.moto.pos)).to_upper()), "y en qué zona")
	# Tab abre el mapa completo (DISENO §6) y lo vuelve a cerrar.
	var mapa: Control = r2.get_node("HUD/Mapa")
	t.check(not mapa.visible, "el mapa completo empieza cerrado")
	var tab := InputEventAction.new()
	tab.action = "mapa"
	tab.pressed = true
	r2._input(tab)
	t.check(mapa.visible, "Tab abre el mapa completo")
	t.check(mapa.a_pantalla(Vector2.ZERO).distance_to(mapa.a_pantalla(c.tamano())) > 300.0, "el mapa cubre toda la ciudad a buen tamaño")
	t.check(Rect2(Vector2.ZERO, mapa.size).has_point(mapa.a_pantalla(r2.partida.moto.pos)), "la moto cae dentro del mapa")
	r2._input(tab)
	t.check(not mapa.visible, "Tab otra vez lo cierra")
	main.menu()
	await t.process_frame
	t.check_eq(main.pantalla_actual().name, "Menu", "se puede volver al menú")
	t.check_eq(_pantallas(main).size(), 1, "con una sola pantalla")
	t.check(main.pantalla_actual().get_node("Estado").text.contains(main.progreso.pesos(main.progreso.dinero)), "el menú muestra la plata ganada")
	DIRECTOR.ruta_progreso = "user://progreso.cfg"
	DIRECTOR.ruta_opciones = "user://opciones.cfg"
	DIRECTOR.mostrar_advertencia = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))

	main.queue_free()
	await t.process_frame
