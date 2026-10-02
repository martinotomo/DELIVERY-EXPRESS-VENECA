extends RefCounted
## Versión web (navegador): lo que cambia respecto al .exe.
## - En pantalla completa el navegador se queda con Esc (sale de pantalla completa), así que la
##   pausa también va con P, y el juego se pausa solo si la pestaña pierde el foco.
## - No hay botón Salir (una página no se «cierra» a sí misma).
## - Suena: en el navegador el audio va por el mezclador normal («Stream»), no por el de muestras,
##   que no conoce los buses Musica y Efectos que crea opciones.gd y dejaba todo mudo (02/10/2026).
## - Al darle Jugar sale una pantalla de carga mientras se arma la ciudad, y la partida no arranca
##   hasta que el navegador terminó de preparar todo lo que se dibuja (precalentado).
## - La carga dura al menos unos segundos (6 al darle Jugar, 3 al reintentar) y como mucho 10, y
##   enseña qué mata y qué cuesta plata. Mientras se está en el menú, la calle se arma y se
##   precalienta detrás, sin verse ni oír teclas, y al darle Jugar se usa esa (Tomás, 02/10/2026).
## - La letra tiene las mayúsculas con tilde del mismo alto que las demás (tools/gen_fuente.py).

const UI := preload("res://scripts/ui.gd")
const MENU := preload("res://scenes/menu.tscn")
const RECORRIDO := preload("res://scenes/recorrido.tscn")
const OPCIONES := preload("res://scripts/opciones.gd")
const RECORRIDO_GD := preload("res://scripts/recorrido.gd")
const DIRECTOR := preload("res://scripts/main.gd")
const CARGA := preload("res://scripts/carga.gd")


func _tiene(eventos: Array, tecla: int) -> bool:
	for e in eventos:
		if e is InputEventKey and (e.physical_keycode == tecla or e.keycode == tecla):
			return true
	return false


func run(t) -> void:
	# Salir no existe en la web.
	var antes: bool = UI.en_web
	UI.en_web = true
	var m: Node = MENU.instantiate()
	t.root.add_child(m)
	await t.process_frame
	var salir: Button = m.find_child("Salir", true, false)
	t.check(salir == null or not salir.visible, "en la web el menú no tiene Salir")
	m.queue_free()
	UI.en_web = false
	m = MENU.instantiate()
	t.root.add_child(m)
	await t.process_frame
	t.check(m.find_child("Salir", true, false) != null, "en el .exe sí")
	m.queue_free()
	UI.en_web = antes

	# P también pausa (y no se puede asignar a otra acción).
	t.check(_tiene(InputMap.action_get_events("menu"), KEY_P), "P también abre la pausa")
	var o = OPCIONES.new("user://prueba_web_opciones.cfg")
	t.check(not o.cambiar_tecla("pitar", KEY_P), "P no se puede poner a otra acción")

	# Perder el foco (cambiar de pestaña, salir de pantalla completa) pausa la partida.
	var r: Node = RECORRIDO.instantiate()
	t.root.add_child(r)
	await t.process_frame
	r.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.check(t.root.get_tree().paused and r.pausa.visible, "si la ventana pierde el foco, se pausa")
	r.pausa.cerrar()
	r.partida.terminada = true
	r.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.check(not t.root.get_tree().paused, "ya caído, perder el foco no abre la pausa")
	t.root.get_tree().paused = false
	r.queue_free()
	await t.process_frame

	# Sonido en el navegador: mezclador normal.
	t.check(ProjectSettings.get_setting("audio/general/default_playback_type.web") == 0, "en la web el audio va por el mezclador normal (Stream)")

	# Letra: la nuestra, con las mayúsculas con tilde de alto completo.
	var fuente: String = ProjectSettings.get_setting("gui/theme/custom_font")
	t.check(fuente.ends_with("DeliveryPress-Regular.ttf"), "la letra del juego es Delivery Press (Press Start 2P con tildes arregladas)")

	# Pantalla de carga del director: al darle Jugar sale primero la carga y luego la calle.
	DIRECTOR.pantalla_carga = true
	var d: Node = load("res://scenes/main.tscn").instantiate()
	t.root.add_child(d)
	await t.process_frame
	d.reiniciar()
	t.check(d.pantalla_actual() is CARGA, "al darle Jugar sale primero la pantalla de carga")
	for i in 6:
		await t.process_frame
	t.check(d.pantalla_actual() != null and d.pantalla_actual().name == "Recorrido", "y después de unos fotogramas, la calle")
	t.check(d._pantallas.get_child_count() == 1, "nunca hay dos pantallas vivas")
	d.queue_free()
	await t.process_frame
	DIRECTOR.pantalla_carga = false

	# Precalentado: la partida espera tapada por la carga hasta que todo se dibujó una vez.
	RECORRIDO_GD.precalentar = true
	var rc: Node = RECORRIDO.instantiate()
	t.root.add_child(rc)
	await t.process_frame
	t.check(rc.cargando, "la calle arranca cargando")
	var tapa: Control = rc.find_child("Carga", true, false)
	t.check(tapa != null and tapa.is_visible_in_tree(), "con la pantalla de carga encima")
	var reloj0: float = rc.partida.reloj.t
	for i in 4:
		rc._process(0.05)
	t.check(is_equal_approx(rc.partida.reloj.t, reloj0), "mientras carga, la partida no corre (ni el tiempo del pedido)")
	var vueltas := 0
	while rc.cargando and vueltas < 1000:
		rc._process(0.02)
		vueltas += 1
	t.check(not rc.cargando, "el precalentado termina (%d fotogramas)" % vueltas)
	t.check(0.2 + vueltas * 0.02 >= rc.CARGA_MIN_S - 0.05, "aunque esté listo antes, la carga dura al menos %d s para leerla (%.1f s)" % [rc.CARGA_MIN_S, 0.2 + vueltas * 0.02])
	t.check(rc.CARGA_MIN_S >= 5.0 and rc.CARGA_MAX_S <= 10.0, "entre 5 y 10 s (Tomás)")
	t.check(vueltas >= rc.PASOS_PRECALENTADO, "y pasa por todas las vistas y luces antes de soltar")
	t.check(tapa == null or not is_instance_valid(tapa) or not tapa.is_visible_in_tree(), "al terminar se quita la carga")
	t.check(not rc._moto_caida.visible, "la moto caída vuelve a esconderse")
	rc._process(0.1)
	t.check(rc.partida.reloj.t > reloj0, "y la partida arranca")
	# Si el navegador va lento (fotogramas largos), espera, pero nunca más del tope.
	var rl: Node = RECORRIDO.instantiate()
	t.root.add_child(rl)
	await t.process_frame
	vueltas = 0
	while rl.cargando and vueltas < 1000:
		rl._process(0.5)
		vueltas += 1
	t.check(not rl.cargando and vueltas * 0.5 <= rl.CARGA_MAX_S + 1.0, "con fotogramas lentos suelta al tope de %d s" % rl.CARGA_MAX_S)
	# Godot recorta el delta de los fotogramas muy lentos: la carga se mide con el reloj de verdad.
	var rq: Node = RECORRIDO.instantiate()
	t.root.add_child(rq)
	await t.process_frame
	rq._process(0.01)
	var tq: float = rq._t_carga
	OS.delay_msec(300)
	rq._process(0.01)
	t.check(rq._t_carga - tq >= 0.29, "un fotograma de 0,3 s cuenta 0,3 s aunque Godot diga 0,01 (%.2f)" % (rq._t_carga - tq))
	rq.queue_free()
	rc.queue_free()
	rl.queue_free()
	await t.process_frame

	# Lo que se lee en la carga: qué mata y qué cuesta plata, en los dos idiomas.
	var cg: Control = CARGA.new()
	t.root.add_child(cg)
	await t.process_frame
	var mata: Node = cg.find_child("TeMata", true, false)
	var cuesta: Node = cg.find_child("TeCuesta", true, false)
	t.check(mata != null and mata.get_child_count() >= 5, "la carga dice qué te mata (andén, curva, hueco, perro, bus)")
	t.check(cuesta != null and cuesta.get_child_count() >= 5, "y qué te cuesta (peatón, carro, frenazo, motor, aceite)")
	var textos: Array = CARGA.TE_MATA + CARGA.TE_CUESTA
	var juntos := " ".join(textos)
	for cosa in ["ANDÉN", "PERRO", "HUECO", "PEATÓN", "propina", "CARRO", "BUS"]:
		t.check(cosa in juntos, "la carga nombra: %s" % cosa)
	TranslationServer.set_locale("en")
	var sin_traducir := []
	for x in textos + ["CÓMO NO MORIR REPARTIENDO", "TE MATA", "TE CUESTA", "Morir no te quita la plata."]:
		if TranslationServer.translate(x) == x:
			sin_traducir.append(x)
	TranslationServer.set_locale("es")
	t.check(sin_traducir.is_empty(), "todo lo de la carga tiene inglés %s" % [sin_traducir])
	var fuera := []
	for l in cg.find_children("*", "Label", true, false):
		var caja: Rect2 = l.get_global_rect()
		if caja.end.x > 640.5 or caja.end.y > 360.5:
			fuera.append(l.name)
	t.check(fuera.is_empty(), "nada de la carga se sale de la pantalla %s" % [fuera])
	cg.queue_free()

	# Precarga en el menú: la calle se arma detrás del menú y al darle Jugar se usa esa.
	DIRECTOR.pantalla_carga = true
	DIRECTOR.precargar_en_menu = true
	DIRECTOR.ruta_progreso = "user://prueba_web_progreso.cfg"
	var dm: Node = load("res://scenes/main.tscn").instantiate()
	t.root.add_child(dm)
	await t.process_frame
	dm.menu()
	for i in 6:
		await t.process_frame
	var reserva: Node = dm._reserva.get_child(0) if dm._reserva.get_child_count() > 0 else null
	t.check(reserva != null and reserva.name == "Recorrido", "en el menú, la calle se arma detrás")
	t.check(dm._pantallas.get_child_count() == 1 and dm.pantalla_actual().scene_file_path == MENU.resource_path, "y la pantalla sigue siendo el menú (una sola)")
	if reserva != null:
		t.check(not reserva.visible and not reserva.get_node("HUD").visible, "sin verse: ni la calle ni el HUD")
		t.check(reserva.cargando and reserva.segundo_plano, "precalentando en segundo plano")
		var r0: float = reserva.partida.reloj.t
		for i in 400:
			reserva._process(0.02)
		t.check(reserva.calentada(), "termina de precalentar detrás del menú")
		t.check(is_equal_approx(reserva.partida.reloj.t, r0) and reserva.cargando, "pero la partida no arranca sola")
		var esc := InputEventAction.new()
		esc.action = "menu"
		esc.pressed = true
		reserva._unhandled_input(esc)
		t.check(not reserva.pausa.visible, "y no oye las teclas del menú (Esc no le abre la pausa)")
		dm.reiniciar()
		t.check(dm.pantalla_actual() == reserva, "al darle Jugar se usa la calle ya armada")
		t.check(reserva.visible and reserva.cargando and reserva.find_child("Carga", true, false) != null, "con la pantalla de carga encima")
		t.check(is_equal_approx(reserva.carga_min_s, DIRECTOR.CARGA_DESDE_MENU_S), "que dura %d s desde el menú" % DIRECTOR.CARGA_DESDE_MENU_S)
		var n := 0
		while reserva.cargando and n < 1000:
			reserva._process(0.02)
			n += 1
		t.check(not reserva.cargando and absf(n * 0.02 - DIRECTOR.CARGA_DESDE_MENU_S) < 0.1, "ya precalentada, sale justo a los %d s (%.2f s)" % [DIRECTOR.CARGA_DESDE_MENU_S, n * 0.02])
		reserva._process(0.1)
		t.check(reserva.partida.reloj.t > r0, "y arranca")
	# Si cambia la moto (taller), la reserva vieja no sirve: se rehace.
	dm.menu()
	for i in 6:
		await t.process_frame
	var vieja_id: int = dm._reserva.get_child(0).get_instance_id() if dm._reserva.get_child_count() > 0 else 0
	dm.progreso.moto = "nkd" if dm.progreso.moto != "nkd" else "bws"
	dm.reiniciar()
	for i in 6:
		await t.process_frame
	var usada: Node = dm.pantalla_actual()
	t.check(vieja_id != 0 and usada.get_instance_id() != vieja_id and usada.name == "Recorrido" and usada.partida.moto.moto.id == dm.progreso.moto, "con otra moto no usa la calle vieja")
	t.check(is_equal_approx(usada.carga_min_s, DIRECTOR.CARGA_DESDE_MENU_S), "y la carga también dura lo del menú")
	dm.queue_free()
	await t.process_frame
	DIRECTOR.pantalla_carga = false
	DIRECTOR.precargar_en_menu = false
	RECORRIDO_GD.precalentar = false
	await t.process_frame
