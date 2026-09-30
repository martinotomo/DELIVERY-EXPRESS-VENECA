extends RefCounted
## Contrato de la ciudad: tamaño, cuadras distintas, andenes y rutas del minimapa.

const CIUDAD := preload("res://scripts/ciudad.gd")


func run(t) -> void:
	var c = CIUDAD.new(1234)
	t.check_eq(c.anchos.size(), 40, "40 cuadras de ancho (carreras)")
	t.check_eq(c.largos.size(), 80, "80 cuadras de largo (calles)")

	# Que no se vea cuadriculado: cuadras de muchos tamaños distintos.
	var distintos := {}
	for w in c.anchos:
		distintos[int(w)] = true
	t.check(distintos.size() >= 10, "al menos 10 anchos de cuadra distintos (%d)" % distintos.size())
	var cortas := 0
	var largas := 0
	for l in c.largos:
		if l < 80.0:
			cortas += 1
		if l > 125.0:
			largas += 1
	t.check(cortas >= 5 and largas >= 5, "hay cuadras cortas (%d) y largas (%d)" % [cortas, largas])
	t.check(c.parques.size() > 0, "hay parques entre los edificios")
	var todos: Array = c.anchos + c.largos
	t.check(todos.min() >= 60.0 and todos.max() <= 160.0, "cuadras entre 0,6 y 1,6 veces 100 m (DISENO §6)")

	# Misma semilla, misma ciudad; otra semilla, otra ciudad.
	var c2 = CIUDAD.new(1234)
	t.check(c.anchos == c2.anchos and c.largos == c2.largos, "misma semilla = misma ciudad")
	t.check(CIUDAD.new(99).anchos != c.anchos, "otra semilla = otra ciudad")

	var tam: Vector2 = c.tamano()
	t.check(tam.x > 2000.0 and tam.y > 2.0 * tam.x * 0.8, "ciudad grande y más larga que ancha (%.0f × %.0f m)" % [tam.x, tam.y])

	# Andén: dentro de una cuadra sí, en el centro de una calle no.
	var r: Rect2 = c.cuadra(3, 5)
	t.check(c.en_anden(r.get_center(), 0.0), "el centro de una cuadra es andén/edificio")
	var cruce: Vector2 = c.cruce(4, 6)
	t.check(not c.en_anden(cruce, 0.5), "el centro de un cruce es calle")
	t.check(c.en_anden(Vector2(-50, 50), 0.0), "fuera de la ciudad cuenta como muro")
	var borde := Vector2(r.position.x - 1.0, r.get_center().y)
	t.check(absf(c.distancia_anden(borde) - 1.0) < 0.01, "a 1 m del andén mide 1 m (%.2f)" % c.distancia_anden(borde))

	# Ruta: del cruce A a un punto frente a una cuadra, toda por calle y terminando ahí.
	var destino: Vector2 = c.punto_frente_a(20, 60)
	t.check(not c.en_anden(destino, 0.5), "el punto de entrega está en la calle")
	var ruta: PackedVector2Array = c.ruta(c.cruce(2, 2), destino)
	t.check(ruta.size() >= 2, "la ruta tiene puntos")
	t.check(ruta[ruta.size() - 1].distance_to(destino) < 0.01, "la ruta termina en el destino")
	var toda_calle := true
	for k in range(1, ruta.size()):
		var a: Vector2 = ruta[k - 1]
		var b: Vector2 = ruta[k]
		for s in 20:
			if c.en_anden(a.lerp(b, s / 20.0), 0.3):
				toda_calle = false
	t.check(toda_calle, "la ruta del minimapa no atraviesa cuadras")

	# La dirección suena a Bogotá.
	t.check(c.direccion(destino).begins_with("Calle "), "las direcciones son «Calle N # M-xx»: %s" % c.direccion(destino))

	_zonas(t, c)


## Barrios con cara propia (DISENO §6): residencial, centro, industrial y zona rica junto a los cerros.
func _zonas(t, c) -> void:
	var cuenta := {}
	var alto := {}
	var tipos := {}
	var iguales := 0
	var vecinos := 0
	for j in c.N_LARGO:
		for i in c.N_ANCHO:
			var z: String = c.zona(i, j)
			cuenta[z] = cuenta.get(z, 0) + 1
			alto[z] = alto.get(z, 0.0) + c.altura(i, j)
			if not tipos.has(z):
				tipos[z] = {}
			tipos[z][c.fachada(i, j)] = true
			if i + 1 < c.N_ANCHO:
				vecinos += 1
				iguales += int(c.zona(i + 1, j) == z)
	for z in ["barrio", "centro", "industrial", "rica"]:
		t.check(cuenta.get(z, 0) >= 150, "la zona %s tiene al menos 150 cuadras (%d)" % [z, cuenta.get(z, 0)])
	t.check(cuenta.size() == 4, "solo hay 4 zonas: %s" % str(cuenta.keys()))
	t.check(cuenta.get("barrio", 0) > cuenta.get("rica", 0), "casi toda la ciudad es barrio")
	t.check(float(iguales) / vecinos > 0.85, "las zonas son manchas, no un salpicado (%.2f)" % (float(iguales) / vecinos))
	var media := func(z): return alto[z] / cuenta[z]
	t.check(media.call("rica") > 25.0, "la zona rica es de torres (%.1f m)" % media.call("rica"))
	t.check(media.call("barrio") < 14.0, "el barrio es de casas bajas (%.1f m)" % media.call("barrio"))
	t.check(media.call("industrial") < 14.0, "las bodegas son bajas (%.1f m)" % media.call("industrial"))
	t.check(tipos["industrial"].has("bodega"), "la zona industrial tiene bodegas")
	t.check(not tipos["barrio"].has("vidrio") and not tipos["barrio"].has("bodega"), "en el barrio no hay torres de vidrio ni bodegas: %s" % str(tipos["barrio"].keys()))
	t.check(tipos["rica"].has("vidrio"), "la zona rica tiene torres de vidrio")
	# Los cerros quedan al oriente, donde va la carrera 1 (como en Bogotá): la zona rica y el centro, pegados.
	var i_medio := func(z):
		var s := 0.0
		var n := 0
		for j in c.N_LARGO:
			for i in c.N_ANCHO:
				if c.zona(i, j) == z:
					s += i
					n += 1
		return s / n
	t.check(i_medio.call("rica") < 12.0 and i_medio.call("centro") < 14.0, "rica y centro, junto a los cerros (carreras bajas)")
	t.check(i_medio.call("industrial") > 26.0, "la zona industrial, al occidente (carreras altas)")
	var sur := 0
	for j in 20:
		for i in c.N_ANCHO:
			sur += int(c.zona(i, j) == "rica")
	t.check(sur == 0, "la zona rica queda al norte, no al sur")
	t.check(c.zona(-1, 3) == "barrio" and c.zona(99, 99) == "barrio", "fuera de la ciudad cuenta como barrio")
	t.check(c.nombre_zona("rica") != "" and c.nombre_zona("industrial") != "", "cada zona tiene nombre para los letreros")
	_nomenclatura(t, c)
	_criterios_f3(t, c)


## Nombres de las vías como en Bogotá: calles (a lo largo de x) y carreras (a lo largo de y), con avenidas.
func _nomenclatura(t, c) -> void:
	t.check_eq(c.nombre_via("calle", 41), "Cl 42", "la vía 41 es la Calle 42")
	t.check_eq(c.nombre_via("carrera", 20), "Kr 21", "la vía 20 es la Carrera 21")
	t.check(c.es_avenida("calle", 6) and c.es_avenida("carrera", 12), "cada sexta vía es avenida")
	t.check(not c.es_avenida("calle", 7) and not c.es_avenida("carrera", 0) and not c.es_avenida("calle", c.N_LARGO), "las demás y los bordes no")
	t.check_eq(c.nombre_via("calle", 6), "Av Cl 7", "las avenidas se marcan con «Av»")
	var p: Vector2 = c.cruce(20, 41) + Vector2(30, 0) # sobre la Calle 42, entre carreras
	var u: String = c.ubicacion(p)
	t.check(u.begins_with("Cl 42") and u.contains("Kr 2"), "la ubicación dice la vía por la que va y la carrera cercana: %s" % u)
	var q: Vector2 = c.cruce(20, 41) + Vector2(0, 30) # sobre la Carrera 21
	t.check(c.ubicacion(q).begins_with("Kr 21"), "yendo por una carrera, primero la carrera: %s" % c.ubicacion(q))
	t.check(c.zona_en(c.cuadra(3, 70).get_center()) == c.zona(3, 70), "zona_en(p) dice la zona de la cuadra donde está p")


## Criterios de salida de la F3 (PLAN_FASES): toda dirección existe y la ruta es la más corta.
func _criterios_f3(t, c) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var existen := true
	var cortas := true
	for k in 200:
		var i := rng.randi_range(0, c.N_ANCHO - 1)
		var j := rng.randi_range(1, c.N_LARGO - 1)
		var p: Vector2 = c.punto_frente_a(i, j)
		# «Calle N # M-xx»: la calle N existe y pasa por ahí; la carrera M también.
		var partes: PackedStringArray = c.direccion(p).replace("Calle ", "").replace("# ", "").replace("-", " ").split(" ")
		var n := int(partes[0])
		var m := int(partes[1])
		if n < 1 or n > c.N_LARGO + 1 or m < 1 or m > c.N_ANCHO + 1 or absf(c.cruce(0, n - 1).y - p.y) > c.CALLE:
			existen = false
		# La ruta del minimapa mide lo mismo que ir en L por la cuadrícula (la más corta posible).
		var a: Vector2 = c.punto_frente_a(rng.randi_range(0, c.N_ANCHO - 1), rng.randi_range(1, c.N_LARGO - 1))
		var ruta: PackedVector2Array = c.ruta(a, p)
		var largo := 0.0
		for q in range(1, ruta.size()):
			largo += ruta[q - 1].distance_to(ruta[q])
		# A la fuerza bruta: salir por cualquier carrera de la calle de a y llegar por cualquiera de la de p.
		var minimo := INF
		var xs: Array[float] = []
		for q in c.N_ANCHO + 1:
			xs.append(c.cruce(q, 0).x)
		for xa in xs:
			for xb in xs:
				minimo = minf(minimo, absf(a.x - xa) + absf(xa - xb) + absf(a.y - p.y) + absf(xb - p.x))
		if absf(a.y - p.y) < 1.0:
			minimo = minf(minimo, absf(a.x - p.x))
		if largo > minimo + 12.0: # lo que cuesta ir del borde de la calle a su centro y volver
			cortas = false
	t.check(existen, "cada dirección «Calle N # M-xx» nombra una calle y una carrera que existen y pasan por ahí")
	t.check(cortas, "la ruta del minimapa es la más corta por la cuadrícula (a lo sumo el desvío de entrar a la vía)")
	# Recalcular al desviarse: la ruta sale siempre de donde está la moto.
	var desde: Vector2 = c.cruce(10, 10)
	var otra: Vector2 = c.cruce(12, 10)
	var meta: Vector2 = c.punto_frente_a(15, 30)
	t.check(c.ruta(desde, meta)[0] == desde and c.ruta(otra, meta)[0] == otra, "si la moto se desvía, la ruta arranca desde donde está")
