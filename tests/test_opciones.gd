extends RefCounted
## Contrato de las opciones (F6): volumen general, de música y de efectos, pantalla completa,
## idioma y teclas. Se guardan en user:// y se aplican al momento.

const OPCIONES := preload("res://scripts/opciones.gd")
const RUTA := "user://prueba_opciones.cfg"


func run(t) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
	var o = OPCIONES.new(RUTA)
	t.check_eq(o.idioma, "es", "de fábrica en español")
	t.check(not o.pantalla_completa, "de fábrica en ventana")
	t.check(o.volumen.general == 1.0 and o.volumen.musica > 0.0 and o.volumen.efectos == 1.0, "volúmenes de fábrica")
	for accion in OPCIONES.ACCIONES:
		t.check(InputMap.has_action(accion), "la acción «%s» existe" % accion)
		t.check(o.teclas.has(accion), "la tecla de «%s» es configurable" % accion)

	# Aplicar: buses de audio y volumen.
	o.aplicar()
	for bus in ["Musica", "Efectos"]:
		t.check(AudioServer.get_bus_index(bus) != -1, "existe el bus de audio %s" % bus)
	o.poner_volumen("musica", 0.5)
	t.check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica")) - linear_to_db(0.5)) < 0.01, "el volumen de música se aplica al bus")
	o.poner_volumen("efectos", 0.0)
	t.check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Efectos")), "en cero, los efectos quedan en silencio")
	o.poner_volumen("general", 0.25)
	t.check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.25)) < 0.01, "el volumen general va al bus Master")

	# Idioma.
	o.poner_idioma("en")
	t.check_eq(TranslationServer.get_locale().substr(0, 2), "en", "cambiar a inglés cambia el idioma del juego")
	t.check_eq(tr_(o, "JUGAR"), "PLAY", "y se traduce el menú")
	o.poner_idioma("es")
	t.check_eq(TranslationServer.get_locale().substr(0, 2), "es", "y se puede volver al español")

	# Teclas: cambiar una, no dejar dos acciones con la misma, restablecer.
	t.check(o.cambiar_tecla("pitar", KEY_J), "se puede cambiar el pito a la J")
	t.check(_tiene(InputMap.action_get_events("pitar"), KEY_J), "la J ya pita")
	t.check(not _tiene(InputMap.action_get_events("pitar"), KEY_H), "y la H ya no")
	t.check(not o.cambiar_tecla("pitar", KEY_W), "no deja poner una tecla que ya usa otra acción (W = acelerar)")
	t.check(_tiene(InputMap.action_get_events("acelerar"), KEY_UP), "las flechas siguen funcionando aunque se cambie la letra")
	t.check_eq(OPCIONES.nombre_tecla(KEY_J), "J", "el nombre de la tecla se puede mostrar")

	# Guardar y volver a abrir.
	o.pantalla_completa = true
	o.guardar()
	var o2 = OPCIONES.new(RUTA)
	t.check_eq(o2.idioma, "es", "el idioma se recuerda")
	t.check(o2.pantalla_completa, "la pantalla completa se recuerda")
	t.check(absf(o2.volumen.musica - 0.5) < 0.001 and o2.volumen.efectos == 0.0 and absf(o2.volumen.general - 0.25) < 0.001, "los volúmenes se recuerdan")
	t.check_eq(o2.teclas.pitar, KEY_J, "las teclas se recuerdan")
	o2.restablecer_teclas()
	t.check_eq(o2.teclas.pitar, KEY_H, "restablecer devuelve las teclas de fábrica")
	t.check(_tiene(InputMap.action_get_events("pitar"), KEY_H), "y el pito vuelve a la H")

	# Un archivo dañado no rompe nada: vuelve a lo de fábrica.
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	f.store_string("[volumen]\nmusica=\"mucho\"\n[teclas]\npitar=-3\n")
	f.close()
	var o3 = OPCIONES.new(RUTA)
	t.check(o3.volumen.musica >= 0.0 and o3.volumen.musica <= 1.0, "un volumen raro en el archivo se corrige")
	t.check_eq(o3.teclas.pitar, KEY_H, "una tecla rara en el archivo vuelve a la de fábrica")

	# Dejarlo todo como estaba para las demás pruebas.
	var limpio = OPCIONES.new(RUTA)
	limpio.restablecer_teclas()
	limpio.volumen = OPCIONES.VOLUMEN_FABRICA.duplicate()
	limpio.aplicar()
	TranslationServer.set_locale("es")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))


func tr_(_o, clave: String) -> String:
	return TranslationServer.translate(clave)


func _tiene(eventos: Array, tecla: int) -> bool:
	for e in eventos:
		if e is InputEventKey and (e.physical_keycode == tecla or e.keycode == tecla):
			return true
	return false
