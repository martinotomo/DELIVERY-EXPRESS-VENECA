extends RefCounted
## Los remates. El de la curva es el chiste central: no se toca sin decisión de Tomás.

const MENSAJES := preload("res://scripts/mensajes.gd")


func run(t) -> void:
	var m: String = MENSAJES.muerte_curva("BWS")
	t.check(m.begins_with("Has muerto al entrar demasiado rápido en la curva"), "abre con la muerte en la curva")
	t.check(m.contains("tu fe era más grande que el agarre de tu BWS."), "remata con la fe y el agarre de la BWS")
	t.check(MENSAJES.muerte_curva("Ninja 300").ends_with("tu Ninja 300."), "el remate usa el nombre de la moto")
	t.check(MENSAJES.sin_tiempo().length() > 10, "hay mensaje cuando se acaba el tiempo")
	var e: String = MENSAJES.entregado(12.3)
	t.check(e.contains("12"), "el mensaje de entrega dice cuánto tiempo sobró")
	for texto in [m, MENSAJES.sin_tiempo(), e]:
		t.check(not texto.contains("%"), "sin marcadores sin rellenar: %s" % texto)
