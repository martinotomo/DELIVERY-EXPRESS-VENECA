extends RefCounted
## Versión web (navegador): lo que cambia respecto al .exe.
## - En pantalla completa el navegador se queda con Esc (sale de pantalla completa), así que la
##   pausa también va con P, y el juego se pausa solo si la pestaña pierde el foco.
## - No hay botón Salir (una página no se «cierra» a sí misma).
## - Suena: en el navegador el audio va por el mezclador normal («Stream»), no por el de muestras,
##   que no conoce los buses Musica y Efectos que crea opciones.gd y dejaba todo mudo (02/10/2026).
## - Al darle Jugar sale una pantalla de carga mientras se arma la ciudad, y la partida no arranca
##   hasta que el navegador terminó de preparar todo lo que se dibuja (precalentado).
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
	while rc.cargando and vueltas < 400:
		rc._process(0.02)
		vueltas += 1
	t.check(not rc.cargando, "el precalentado termina (%d fotogramas)" % vueltas)
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
	rc.queue_free()
	rl.queue_free()
	RECORRIDO_GD.precalentar = false
	await t.process_frame
