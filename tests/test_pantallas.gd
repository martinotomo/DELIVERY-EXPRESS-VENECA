extends RefCounted
## F6: advertencia al inicio, menú con Opciones y Créditos, pantalla de opciones, créditos,
## pausa con Esc (que de verdad congela la partida), una sola pantalla viva, la música que no se
## corta, las opciones que se recuerdan y los textos en inglés sin cortarse ni quedar en español.

const RUTA := "user://prueba_pantallas.cfg"
const RUTA_OP := "user://prueba_pantallas_opciones.cfg"
const OPCIONES := preload("res://scripts/opciones.gd")
## Palabras que delatan un texto sin traducir cuando el juego está en inglés.
const PALABRAS_ES := ["de", "la", "el", "y", "para", "con", "tu", "los", "las", "que", "en", "del",
	"volver", "menú", "jugar", "salir", "plata", "pausa", "idioma", "teclas", "pito", "música"]
## Nombres propios que se quedan igual en los dos idiomas.
const NOMBRES := ["Tomás Ardila Marín", "Escuela Colombiana de Ingeniería Julio Garavito"]


func _arrancar(t, advertencia := false) -> Node:
	var DIRECTOR = load("res://scripts/main.gd")
	DIRECTOR.ruta_progreso = RUTA
	DIRECTOR.ruta_opciones = RUTA_OP
	DIRECTOR.mostrar_advertencia = advertencia
	var main: Node = load("res://scenes/main.tscn").instantiate()
	t.root.add_child(main)
	await t.process_frame
	await t.process_frame
	return main


func _cerrar(t, main: Node) -> void:
	t.root.get_tree().paused = false
	main.queue_free()
	await t.process_frame
	load("res://scripts/main.gd").mostrar_advertencia = false


func _boton(pantalla: Node, nombre: String) -> Button:
	return pantalla.find_child(nombre, true, false) as Button


func run(t) -> void:
	for r in [RUTA, RUTA_OP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(r))

	# --- Advertencia de contenido: sale primero y no se salta antes de 2 s.
	var main: Node = await _arrancar(t, true)
	var adv: Node = main.pantalla_actual()
	t.check_eq(adv.name, "Advertencia", "lo primero es la advertencia de contenido")
	t.check(adv.find_child("Texto", true, false).text.contains("humor negro"), "la advertencia avisa del humor negro")
	t.check(not adv.find_child("Pista", true, false).visible, "antes de 2 s no se ofrece saltarla")
	adv.saltar()
	await t.process_frame
	t.check_eq(main.pantalla_actual().name, "Advertencia", "antes de 2 s no se puede saltar")
	adv.avanzar(2.1)
	t.check(adv.find_child("Pista", true, false).visible, "a los 2 s dice cómo saltarla")
	adv.saltar()
	await t.process_frame
	t.check_eq(main.pantalla_actual().name, "Menu", "después de 2 s se salta al menú")
	await _cerrar(t, main)

	main = await _arrancar(t)
	var reproducciones: int = main.reproducciones
	var menu: Node = main.pantalla_actual()
	t.check_eq(menu.name, "Menu", "sin advertencia (pruebas) arranca en el menú")
	for b in ["Jugar", "Taller", "Opciones", "Creditos", "Salir"]:
		t.check(_boton(menu, b) != null, "el menú tiene el botón %s" % b)
	_revisar_textos(t, menu, "menú (es)")

	# --- Opciones: no corta la música y se aplican al momento.
	_boton(menu, "Opciones").pressed.emit()
	await t.process_frame
	var op: Node = main.pantalla_actual()
	t.check_eq(op.name, "Opciones", "el botón Opciones abre las opciones")
	t.check_eq(main.get_node("Pantallas").get_child_count(), 1, "sigue habiendo una sola pantalla")
	t.check(main.get_node("Musica").playing and main.reproducciones == reproducciones, "la música no se corta al entrar a Opciones")
	for n in ["Volumen_general", "Volumen_musica", "Volumen_efectos"]:
		t.check(op.find_child(n, true, false) is HSlider, "hay barra de %s" % n)
	t.check(op.find_child("PantallaCompleta", true, false) is CheckButton, "hay casilla de pantalla completa")
	for n in ["Idioma", "Restablecer", "Volver"]:
		t.check(_boton(op, n) != null, "hay botón %s" % n)
	for accion in OPCIONES.ACCIONES:
		t.check(_boton(op, "Tecla_" + accion) != null, "se puede cambiar la tecla de %s" % accion)
	(op.find_child("Volumen_musica", true, false) as HSlider).value = 0.3
	t.check(absf(main.opciones.volumen.musica - 0.3) < 0.001, "mover la barra cambia el volumen de la música")
	t.check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica")) - linear_to_db(0.3)) < 0.01, "y se oye al momento")
	t.check_eq(main.get_node("Musica").bus, &"Musica", "la música va por su bus")
	_revisar_textos(t, op, "opciones (es)")

	# Cambiar una tecla: se pulsa el botón y luego la tecla.
	_boton(op, "Tecla_pitar").pressed.emit()
	t.check(op.esperando_tecla == "pitar", "al pulsar el botón espera una tecla")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	ev.keycode = KEY_J
	ev.pressed = true
	op.tecla_pulsada(ev)
	t.check_eq(main.opciones.teclas.pitar, KEY_J, "la tecla nueva queda puesta")
	t.check(_boton(op, "Tecla_pitar").text.contains("J"), "y el botón la muestra")

	# Idioma: cambia al momento, sin cortar la música.
	_boton(op, "Idioma").pressed.emit()
	await t.process_frame
	t.check_eq(TranslationServer.get_locale().substr(0, 2), "en", "el botón de idioma pasa a inglés")
	op = main.pantalla_actual()
	t.check(main.reproducciones == reproducciones, "cambiar el idioma no corta la música")
	_revisar_textos(t, op, "opciones (en)")
	_boton(op, "Volver").pressed.emit()
	await t.process_frame
	menu = main.pantalla_actual()
	t.check_eq(menu.name, "Menu", "Volver regresa al menú")
	t.check(main.reproducciones == reproducciones, "la música del menú siguió sonando todo el rato")
	_revisar_textos(t, menu, "menú (en)")
	t.check_eq(_boton(menu, "Jugar").atr(_boton(menu, "Jugar").text), "PLAY", "en inglés el menú dice PLAY")

	# --- Créditos en inglés: suben solos y se saltan.
	_boton(menu, "Creditos").pressed.emit()
	await t.process_frame
	var cred: Node = main.pantalla_actual()
	t.check_eq(cred.name, "Creditos", "el botón Créditos abre los créditos")
	var todo := _todo_el_texto(cred)
	t.check(todo.contains("Tomás Ardila Marín"), "los créditos nombran al creador")
	t.check(todo.contains("Godot") and todo.contains("Press Start 2P"), "y las herramientas y la fuente con su licencia")
	_revisar_textos(t, cred, "créditos (en)", false) # van subiendo: empiezan debajo de la pantalla
	var contenido: Control = cred.find_child("Contenido", true, false)
	var y0 := contenido.position.y
	cred.avanzar(1.0)
	t.check(absf((y0 - contenido.position.y) - cred.VELOCIDAD) < 0.5, "suben a %d px/s" % cred.VELOCIDAD)
	var pista: Control = cred.find_child("Pista", true, false)
	t.check(pista != null and pista.get_parent().name == "FranjaPista", "la pista de salto va sobre su propia franja")
	cred.saltar()
	await t.process_frame
	t.check_eq(main.pantalla_actual().name, "Menu", "ESPACIO salta los créditos")
	main.pantalla_actual().find_child("Creditos", true, false).pressed.emit()
	await t.process_frame
	main.pantalla_actual().avanzar(999.0)
	await t.process_frame
	t.check_eq(main.pantalla_actual().name, "Menu", "al acabar, los créditos vuelven solos al menú")

	# Advertencia en inglés.
	TranslationServer.set_locale("en")
	main.advertencia()
	await t.process_frame
	_revisar_textos(t, main.pantalla_actual(), "advertencia (en)")
	main.pantalla_actual().avanzar(3.0)
	main.pantalla_actual().saltar()
	await t.process_frame
	main.opciones.poner_idioma("es")
	main.opciones.guardar()

	# --- Pausa: Esc en plena partida.
	_boton(main.pantalla_actual(), "Jugar").pressed.emit()
	await t.process_frame
	await t.process_frame
	var ride: Node = main.pantalla_actual()
	t.check_eq(ride.name, "Recorrido", "Jugar lleva a la calle")
	for i in 5:
		await t.process_frame
	await _pulsar_esc(t)
	t.check(t.root.get_tree().paused, "Esc pausa el juego")
	t.check_eq(main.pantalla_actual().name, "Recorrido", "Esc ya no manda directo al menú")
	var pausa: Node = ride.find_child("Pausa", true, false)
	t.check(pausa != null and pausa.visible, "sale el menú de pausa")
	for b in ["Continuar", "Opciones", "MenuInicial"]:
		t.check(_boton(pausa, b) != null, "la pausa tiene el botón %s" % b)
	_revisar_textos(t, pausa, "pausa (es)")
	var p = ride.partida
	var antes := [p.tiempo_restante, p.reloj.t, p.moto.pos, p.trafico.lista.map(func(v): return v.pos)]
	for i in 10:
		await t.process_frame
	var despues := [p.tiempo_restante, p.reloj.t, p.moto.pos, p.trafico.lista.map(func(v): return v.pos)]
	t.check_eq(despues[0], antes[0], "en pausa el tiempo del pedido no corre")
	t.check_eq(despues[1], antes[1], "en pausa la hora del día no avanza")
	t.check_eq(despues[3], antes[3], "en pausa el tráfico se queda quieto")
	t.check(main.get_node("Musica").playing and not main.get_node("Musica").stream_paused, "la música sigue sonando en la pausa")

	# Opciones desde la pausa.
	_boton(pausa, "Opciones").pressed.emit()
	await t.process_frame
	var panel: Node = pausa.find_child("PanelOpciones", true, false)
	t.check(panel != null and panel.visible, "Opciones abre las opciones encima de la partida")
	t.check(not _boton(pausa, "Continuar").is_visible_in_tree(), "y esconde los botones de la pausa")
	await _pulsar_esc(t)
	t.check(t.root.get_tree().paused, "Esc en las opciones de la pausa vuelve a la pausa, sin reanudar")
	t.check(_boton(pausa, "Continuar").is_visible_in_tree(), "y vuelven los botones de la pausa")

	# Continuar.
	_boton(pausa, "Continuar").pressed.emit()
	await t.process_frame
	await t.process_frame
	t.check(not t.root.get_tree().paused and not pausa.visible, "Continuar reanuda")
	var t_antes: float = p.reloj.t
	for i in 5:
		await t.process_frame
	t.check(p.reloj.t > t_antes, "y el tiempo vuelve a correr")
	t.check_eq(main.pantalla_actual(), ride, "Continuar sigue la misma partida")

	# Esc otra vez cierra la pausa (Esc abre y cierra).
	await _pulsar_esc(t)
	t.check(t.root.get_tree().paused, "Esc vuelve a pausar")
	await _pulsar_esc(t)
	await t.process_frame
	t.check(not t.root.get_tree().paused, "y Esc otra vez reanuda")

	# Volver al menú inicial.
	await _pulsar_esc(t)
	_boton(pausa, "MenuInicial").pressed.emit()
	await t.process_frame
	await t.process_frame
	t.check(not t.root.get_tree().paused, "salir al menú quita la pausa")
	t.check_eq(main.pantalla_actual().name, "Menu", "Volver al menú inicial lleva al menú")
	t.check_eq(main.get_node("Pantallas").get_child_count(), 1, "y queda una sola pantalla")
	await _cerrar(t, main)

	# --- Las opciones se recuerdan al volver a abrir el juego.
	main = await _arrancar(t)
	t.check(absf(main.opciones.volumen.musica - 0.3) < 0.001, "el volumen se recuerda al reabrir")
	t.check_eq(main.opciones.teclas.pitar, KEY_J, "la tecla cambiada se recuerda al reabrir")
	t.check_eq(TranslationServer.get_locale().substr(0, 2), "es", "el idioma guardado se aplica al abrir")
	main.opciones.restablecer_teclas()
	main.opciones.volumen = OPCIONES.VOLUMEN_FABRICA.duplicate()
	main.opciones.aplicar()
	await _cerrar(t, main)
	TranslationServer.set_locale("es")
	for r in [RUTA, RUTA_OP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(r))


func _pulsar_esc(t) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	t.root.push_input(ev)
	var suelta := ev.duplicate()
	suelta.pressed = false
	t.root.push_input(suelta)
	await t.process_frame


func _todo_el_texto(n: Node) -> String:
	var s := ""
	for c in n.find_children("*", "Control", true, false):
		if (c is Label or c is Button) and c.is_visible_in_tree():
			s += c.atr(c.text) + "\n"
	return s


## Ningún texto visible se sale de su caja, y en inglés ninguno se queda en español.
func _revisar_textos(t, pantalla: Node, donde: String, vertical := true) -> void:
	var ingles := TranslationServer.get_locale().begins_with("en")
	var malos := []
	var largos := []
	for c in pantalla.find_children("*", "Control", true, false):
		if not ((c is Label or c is Button) and c.is_visible_in_tree()):
			continue
		var texto: String = c.atr(c.text)
		if texto.strip_edges() == "":
			continue
		if ingles and _parece_espanol(texto):
			malos.append(texto)
		var envuelve: bool = c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF
		if not envuelve and not texto.contains("\n"):
			var fuente: Font = c.get_theme_font("font")
			var tam: int = c.get_theme_font_size("font_size")
			var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			var margen := 20.0 if c is Button else 0.0
			if ancho + margen > c.size.x + 1.0:
				largos.append("%s (%d > %d)" % [texto, ancho + margen, c.size.x])
		var r: Rect2 = c.get_global_rect()
		if r.position.x < -1 or r.end.x > 641 or (vertical and (r.position.y < -1 or r.end.y > 361)):
			largos.append("%s fuera de la pantalla" % texto)
	t.check(malos.is_empty(), "%s: nada queda en español %s" % [donde, malos])
	t.check(largos.is_empty(), "%s: ningún texto se sale de su caja %s" % [donde, largos])


func _parece_espanol(texto: String) -> bool:
	var s := texto
	for n in NOMBRES:
		s = s.replace(n, "")
	for letra in ["á", "é", "í", "ó", "ú", "ñ", "¿", "¡"]:
		if s.to_lower().contains(letra):
			return true
	var limpio := s.to_lower()
	for signo in [".", ",", ":", ";", "(", ")", "!", "?", "«", "»", "\n", "/", "-"]:
		limpio = limpio.replace(signo, " ")
	for palabra in limpio.split(" ", false):
		if palabra in PALABRAS_ES:
			return true
	return false
