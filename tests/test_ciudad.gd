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
		if l < 60.0:
			cortas += 1
		if l > 100.0:
			largas += 1
	t.check(cortas >= 5 and largas >= 5, "hay cuadras cortas (%d) y largas (%d)" % [cortas, largas])
	t.check(c.parques.size() > 0, "hay parques entre los edificios")

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
