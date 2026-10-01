extends RefCounted
## Idiomas: todo lo que el jugador lee en la calle, el taller y el resultado sale en inglés con
## TranslationServer en "en", y el español sigue igual (la clave del CSV es el texto en español).

const CSV := "res://localization/textos.csv"
const VOCES := preload("res://scripts/voces.gd")
const PARTIDA := preload("res://scripts/partida.gd")
const MOTOS := preload("res://scripts/motos.gd")
const CIUDAD := preload("res://scripts/ciudad.gd")
const MENSAJES := preload("res://scripts/mensajes.gd")
const PROGRESO := preload("res://scripts/progreso.gd")
const RECORRIDO := preload("res://scenes/recorrido.tscn")
const TALLER := preload("res://scenes/taller.tscn")
const RESULTADO := preload("res://scenes/resultado.tscn")
const RUTA := "user://prueba_idiomas.cfg"

## Iguales a propósito en inglés: platos colombianos y nombres propios.
const IGUALES := ["Salchipapa", "Empanadas x10", "Bandeja paisa", "Ajiaco", "Sancocho", "Changua",
	"Mondongo", "Aguardiente x2", "El Alto"]
## Letras que solo tiene el español; se permiten dentro de estos nombres propios.
const LETRAS_ES := "áéíóúñÁÉÍÓÚÑ¡¿"
const NOMBRES_PROPIOS := ["Doña Gloria", "Doña Martha", "Andrés", "DOÑA GLORIA", "DOÑA MARTHA", "ANDRÉS"]


func run(t) -> void:
	_revisar_csv(t)
	TranslationServer.set_locale("en")
	_revisar_datos(t)
	await _revisar_recorrido(t)
	await _revisar_taller(t)
	await _revisar_resultado(t)
	TranslationServer.set_locale("es")
	_revisar_espanol(t)


## (a) El CSV bien formado: 3 columnas, claves únicas, es == clave, en no vacío.
func _revisar_csv(t) -> void:
	var f := FileAccess.open(CSV, FileAccess.READ)
	t.check(f != null, "existe textos.csv")
	if f == null:
		return
	var cab := f.get_csv_line()
	t.check_eq(Array(cab), ["keys", "es", "en"], "cabecera keys,es,en")
	var vistas := {}
	var n := 0
	var malas := []
	while not f.eof_reached():
		var fila := f.get_csv_line()
		if fila.size() == 1 and fila[0] == "":
			continue
		n += 1
		if fila.size() != 3 or fila[1] != fila[0] or fila[2].strip_edges() == "" or vistas.has(fila[0]):
			malas.append(",".join(fila))
		vistas[fila[0]] = true
	t.check(malas.is_empty(), "cada fila tiene 3 columnas, clave única, es = clave y en lleno: %s" % str(malas))
	t.check(n > 100, "el CSV trae todos los textos del juego (%d filas)" % n)


## Todo lo que la lógica le muestra al jugador.
func _textos_logica() -> Array:
	var todos := []
	for e in VOCES.FRASES:
		todos.append_array(VOCES.FRASES[e])
	for par in PARTIDA.COMENTARIOS:
		todos.append_array(par)
	for tipo in PARTIDA.TIPOS_PEDIDO:
		todos.append(PARTIDA.TIPOS_PEDIDO[tipo].aviso)
		todos.append_array(PARTIDA.TIPOS_PEDIDO[tipo].platos)
	todos.append("Ajiaco para la loma")
	todos.append(PARTIDA.MENSAJE_FINAL)
	for c in MOTOS.REMATES:
		todos.append(MOTOS.REMATES[c])
	for m in MOTOS.NOMBRE_MEJORA:
		todos.append(MOTOS.NOMBRE_MEJORA[m])
	for z in CIUDAD.NOMBRES_ZONA:
		todos.append(CIUDAD.NOMBRES_ZONA[z])
	return todos


## (b) En inglés, cada texto cambia (salvo los iguales a propósito) y no deja letras del español.
func _revisar_datos(t) -> void:
	var sin := []
	for s in _textos_logica():
		var en := TranslationServer.translate(s)
		if (en == s and s not in IGUALES) or _tiene_espanol(en):
			sin.append(s)
	t.check(sin.is_empty(), "todo el texto de la lógica tiene inglés: faltan %s" % str(sin))
	for s in ["La del 302", "El de la portería", "Mamá"]:
		t.check(TranslationServer.translate(s) != s, "el cliente «%s» se traduce" % s)
	# Lo que la lógica arma con la plantilla ya traducida.
	t.check_eq(MOTOS.remate("curva", "Bwis"), "You died taking the corner too fast, your faith was bigger than the grip of your Bwis.", "el chiste central en inglés (D9)")
	t.check(str(MOTOS.get_moto("ninja").remate).ends_with("grip of your Ninja 300."), "el remate guardado en la moto sale en inglés")
	t.check(MENSAJES.sin_tiempo().begins_with("Time's up."), "mensaje de tiempo acabado en inglés")
	t.check(MENSAJES.entregado(12.0).contains("12 s to spare"), "mensaje de entregado en inglés")
	t.check_eq(CIUDAD.new(1).nombre_zona("industrial"), "Industrial Zone", "las zonas en inglés")
	var v = VOCES.new(3)
	t.check(not _tiene_espanol(v.frase("casi")) and v.frase("casi") != "", "los subtítulos salen en inglés")
	# La partida: el remate de la curva (viene de moto_logic) y el de cada causa, en inglés.
	var p = PARTIDA.new(5)
	var fines := []
	p.terminada_por.connect(func(m): fines.append(m))
	p._al_estrellarse("x")
	t.check(fines.size() == 1 and fines[0].contains("grip of your Bwis"), "estrellarse en la curva da el remate en inglés: %s" % str(fines))
	var p2 = PARTIDA.new(6)
	var fines2 := []
	p2.terminada_por.connect(func(m): fines2.append(m))
	p2._morir("hueco")
	t.check(fines2.size() == 1 and fines2[0].contains("pothole"), "el remate del hueco en inglés: %s" % str(fines2))
	# El comentario del cliente al calificar.
	var p3 = PARTIDA.new(7)
	var comentarios := []
	p3.calificado.connect(func(_n, c): comentarios.append(c))
	for fase in 2:
		p3.moto.pos = p3.objetivo()
		p3.moto.vel = 0.0
		p3.advance(0.05, false, false, 0.0)
	t.check(comentarios.size() == 1 and not _tiene_espanol(comentarios[0]) and TranslationServer.translate(comentarios[0]) == comentarios[0] and _es_comentario_en(comentarios[0]),
		"el cliente comenta en inglés: %s" % str(comentarios))


func _es_comentario_en(c: String) -> bool:
	for par in PARTIDA.COMENTARIOS:
		for s in par:
			if TranslationServer.translate(s) == c and s != c:
				return true
	return false


## (c) La calle en inglés: nada del HUD con letras del español. (d) Los subtítulos caben en una línea.
func _revisar_recorrido(t) -> void:
	var ride = RECORRIDO.instantiate()
	ride.retraso_resultado = 0.0
	ride.duracion_encuadre = 0.0
	t.root.add_child(ride)
	await t.process_frame
	var p = ride.partida
	# Recoger y ver el pedido de entregar, con sopa (sale el ESTADO) y multado (sin propina).
	p.moto.pos = p.objetivo()
	p.moto.vel = 0.0
	p.advance(0.05, false, false, 0.0)
	p.pedido.tipo = "sopa"
	p.pedido.plato = "Ajiaco para la loma"
	p.pedido.nombre_cliente = "Mamá"
	p.multado = true
	p.racha = 3
	ride._al_evento("casi")
	ride._al_calificar(3, TranslationServer.translate(PARTIDA.COMENTARIOS[2][0]))
	await t.process_frame
	await t.process_frame
	var textos := _textos_de(ride.get_node("HUD"))
	var malos := textos.filter(func(s): return _tiene_espanol(s))
	t.check(malos.is_empty(), "el HUD en inglés no tiene letras del español: %s" % str(malos))
	var pedido: String = ride.get_node("HUD/Pedido").text
	t.check(pedido.begins_with("DELIVER: AJIACO FOR THE HILL TO MOM"), "el pedido en inglés: %s" % pedido)
	t.check(pedido.contains("SOUP: no hard braking") and pedido.contains("CONDITION:") and pedido.contains("NO TIP"), "con su aviso, su estado y la multa: %s" % pedido)
	t.check(ride.get_node("HUD/Racha").text.begins_with("FAITH x3"), "la racha en inglés")
	t.check_eq(ride.get_node("HUD/Derrape").text, "SLIDING OUT!", "el aviso de derrape en inglés")
	t.check(ride.get_node("HUD/Bono").text.begins_with("RAIN: +30%"), "el bono de lluvia en inglés")
	t.check(ride.get_node("HUD/Hora").text.begins_with("DAY ") or ride.get_node("HUD/Hora").text.begins_with("NIGHT "), "la hora en inglés")
	t.check(ride.get_node("HUD/Estrellas").text.contains("Fine. Neither hot nor cold"), "las estrellas con el comentario en inglés")
	t.check(textos.has("TIME") and textos.has("CASH"), "las etiquetas de la barra en inglés")

	# (d) La frase más larga, en inglés, cabe en una línea del subtítulo.
	var sub: Label = ride.get_node("HUD/Subtitulo")
	var fuente: Font = sub.get_theme_font("font")
	var larga := 0.0
	var cual := ""
	for e in VOCES.FRASES:
		for f in VOCES.FRASES[e]:
			var en := TranslationServer.translate(f)
			var ancho := fuente.get_string_size(en, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			if ancho > larga:
				larga = ancho
				cual = en
	t.check(larga + 12.0 <= sub.size.x, "la frase en inglés más larga cabe en una línea (%d px: %s)" % [larga, cual])
	t.check(larga > 0.0, "se midieron las frases")

	# Estrellarse: el resultado que arma la calle, en inglés.
	var fin := []
	ride.terminado.connect(func(estado, msg): fin.append(msg))
	p.entregados = 2
	p.ganado = 15000
	p._morir("perro")
	await t.process_frame
	t.check(fin.size() == 1 and fin[0].contains("the dog survived") and fin[0].contains("You delivered 2 orders") and not _tiene_espanol(fin[0]), "el remate y el cierre en inglés: %s" % str(fin))
	ride.queue_free()
	await t.process_frame


func _revisar_taller(t) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
	var prog = PROGRESO.new(RUTA)
	var taller = TALLER.instantiate()
	taller.progreso = prog
	t.root.add_child(taller)
	await t.process_frame
	var textos := []
	# Todos los estados: en uso, sin plata, bloqueada; con plata: a la venta; comprada: en el garaje.
	for k in 3:
		taller.escogida = k
		taller.actualizar()
		textos.append_array(_textos_de(taller))
	for k in 5:
		prog.plata_de_prueba()
	for k in 3:
		taller.escogida = k
		taller.actualizar()
		textos.append_array(_textos_de(taller))
	taller.escogida = 1
	taller._comprar_moto()
	for k in 3:
		taller.escogida = k
		taller.actualizar()
		textos.append_array(_textos_de(taller))
	taller.escogida = 1
	taller._comprar_mejora("exosto")
	textos.append_array(_textos_de(taller))
	var malos := textos.filter(func(s): return _tiene_espanol(s))
	t.check(malos.is_empty(), "el taller en inglés no tiene letras del español: %s" % str(malos))
	for esperado in ["GARAGE", "CASH", "UPGRADES", "BACK", "IN USE", "IN YOUR GARAGE", "RIDE THIS BIKE", "THIS IS YOUR BIKE", "LOCKED", "EXHAUST  (installed)"]:
		t.check(textos.has(esperado), "el taller dice «%s»" % esperado)
	t.check(textos.any(func(s): return s.begins_with("FOR SALE")), "el taller dice FOR SALE")
	t.check(textos.any(func(s): return s.begins_with("TOP SPEED")), "el taller dice TOP SPEED")
	t.check(textos.any(func(s): return s.begins_with("Buy the NKD 125 first.")), "el taller dice qué comprar primero")
	taller.queue_free()
	await t.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))


func _revisar_resultado(t) -> void:
	var casos := [["estrellado", MOTOS.remate("bus", "Bwis") + "\n\n" + TranslationServer.translate("Ni un pedido entregado. La app ya te está buscando reemplazo."), "R.I.P."],
		["final", TranslationServer.translate(PARTIDA.MENSAJE_FINAL), "THE END"],
		["sin_tiempo", MENSAJES.sin_tiempo(), "CANCELLED"],
		["entregado", MENSAJES.entregado(20.0), "DELIVERED"]]
	for caso in casos:
		var res = RESULTADO.instantiate()
		t.root.add_child(res)
		await t.process_frame
		res.mostrar(caso[0], caso[1])
		var textos := _textos_de(res)
		var malos := textos.filter(func(s): return _tiene_espanol(s))
		t.check(malos.is_empty(), "el resultado «%s» en inglés no tiene letras del español: %s" % [caso[0], str(malos)])
		t.check_eq(res.get_node("Titulo").text, caso[2], "el título del resultado «%s» en inglés" % caso[0])
		t.check(res.get_node("Pista").text.begins_with("ENTER: another shift"), "la pista del resultado en inglés")
		res.queue_free()
		await t.process_frame


## En español todo queda igual: la traducción de cada texto es él mismo.
func _revisar_espanol(t) -> void:
	var distintos := []
	for s in _textos_logica():
		if TranslationServer.translate(s) != s:
			distintos.append(s)
	t.check(distintos.is_empty(), "en español los textos no cambian: %s" % str(distintos))
	t.check_eq(MOTOS.remate("curva", "Bwis"), "Has muerto al entrar demasiado rápido en la curva, tu fe era más grande que el agarre de tu Bwis.", "el chiste central sigue igual en español")


## Lo que muestran todos los Label y Button de un árbol (con la traducción automática de Godot).
func _textos_de(nodo: Node) -> Array:
	var out := []
	for n in nodo.find_children("*", "", true, false):
		if n is Label or n is Button:
			var s: String = n.text
			if s != "":
				out.append(n.atr(s) if n.can_auto_translate() else s)
	return out


func _tiene_espanol(s: String) -> bool:
	for nombre in NOMBRES_PROPIOS:
		s = s.replace(nombre, "")
	for c in LETRAS_ES:
		if s.contains(c):
			return true
	return false
