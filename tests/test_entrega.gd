extends RefCounted
## F7: lo que necesita el .exe de entrega. La exportación en sí la hacen tools/build.sh y
## tools/build.ps1 (con --prueba-arranque); aquí se revisa que los ajustes no se hayan roto.


func run(t) -> void:
	var cfg := ConfigFile.new()
	t.check_eq(cfg.load("res://export_presets.cfg"), OK, "hay export_presets.cfg")
	var win := ""
	for s in cfg.get_sections():
		if cfg.get_value(s, "platform", "") == "Windows Desktop":
			win = s
	t.check(win != "", "hay un ajuste de exportación para Windows")
	if win == "":
		return
	var op := win + ".options"
	t.check(cfg.get_value(op, "binary_format/embed_pck", false), "el PCK va dentro del .exe (un solo archivo)")
	t.check_eq(cfg.get_value(op, "binary_format/architecture", ""), "x86_64", "Windows de 64 bits")
	var icono: String = cfg.get_value(op, "application/icon", "")
	t.check(icono.ends_with(".ico") and FileAccess.file_exists(icono), "el .exe lleva el icono propio (%s)" % icono)
	t.check(FileAccess.file_exists(str(ProjectSettings.get_setting("application/config/icon"))), "la ventana también lleva el icono")
	var version := str(ProjectSettings.get_setting("application/config/version"))
	t.check(version != "" and str(cfg.get_value(op, "application/file_version", "")).begins_with(version), "la versión del .exe es la del proyecto (%s)" % version)
	t.check_eq(cfg.get_value(op, "application/product_name", ""), ProjectSettings.get_setting("application/config/name"), "el .exe se llama como el juego")
	t.check(str(cfg.get_value(op, "application/copyright", "")).contains("Tomás Ardila Marín"), "el copyright es de Tomás")
	var fuera: String = cfg.get_value(win, "exclude_filter", "")
	for carpeta in ["tests/", "tools/", "docs/", "capturas/"]:
		t.check(fuera.contains(carpeta), "el .exe no lleva %s" % carpeta)
	# Las teclas de prueba (F9 lluvia, F10 plata) solo existen en las versiones de desarrollo.
	var recorrido := FileAccess.get_file_as_string("res://scripts/recorrido.gd")
	t.check(recorrido.contains("var trucos := OS.is_debug_build()"), "F9/F10 se apagan solas en la versión de entrega")
	var leeme := FileAccess.get_file_as_string("res://docs/entrega/LEEME.txt")
	t.check(leeme.contains("Tomás Ardila Marín"), "el LEEME del zip nombra al autor")
	t.check(leeme.contains("SOLO PARA USO PRIVADO"), "y avisa que las motos de los memes son solo para uso privado (D21)")
	t.check(leeme.contains(version), "y dice la versión")
