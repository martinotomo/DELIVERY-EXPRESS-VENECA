extends RefCounted
## Versión web (navegador): lo que cambia respecto al .exe.
## - En pantalla completa el navegador se queda con Esc (sale de pantalla completa), así que la
##   pausa también va con P, y el juego se pausa solo si la pestaña pierde el foco.
## - No hay botón Salir (una página no se «cierra» a sí misma).

const UI := preload("res://scripts/ui.gd")
const MENU := preload("res://scenes/menu.tscn")
const RECORRIDO := preload("res://scenes/recorrido.tscn")
const OPCIONES := preload("res://scripts/opciones.gd")


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
