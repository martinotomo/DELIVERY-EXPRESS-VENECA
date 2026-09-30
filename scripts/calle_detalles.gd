extends Node3D
## Lo que le da vida a la calle en la F4 (D27): huecos y manchas de aceite pintados en la calzada,
## perros callejeros, avisos de negocios en las fachadas y vallas en las avenidas. Todo con pools que
## se mueven con la moto (solo se dibuja lo de alrededor). La lógica vive en peligros.gd y perros.gd.

const TEX := "res://assets/texturas/"
const ANDEN_ALTO := 0.2
const PELIGROS_MAX := 48           # huecos y aceite dibujados a la vez
const PELIGROS_RADIO := 110.0      # m alrededor de la moto
const MARCA_PIXEL := 0.05          # m por pixel: rama de ~1,5 m, para verla desde lejos
const PERRO_PX := 24.0             # alto del cuadro en perros.png
const PERRO_PIXEL := 0.04          # m por pixel: un perro criollo grande, de ~0,75 m
const AVISOS_FILAS := 12           # avisos.png: 12 negocios de 96×24, uno por fila
const AVISO_TAM := Vector2(4.0, 1.0)
const AVISO_ALTO := 3.3            # m del piso al centro del aviso
const AVISOS_RADIO := 1            # cuadras a cada lado de la moto con avisos (3 × 3; son grandes)
const AVISO_CADA := 16.0           # m de fachada por local
const AVISO_PROB := 45             # % de locales con aviso
## Qué negocios caben en cada tipo de fachada (fila de avisos.png).
const AVISOS_POR_FACHADA := {
	"casa": [0, 2, 5, 6, 10, 1],
	"ladrillo": [0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11],
	"concreto": [1, 3, 4, 7, 8, 9, 11],
	"vidrio": [1, 4, 9, 11],
	"bodega": [3, 7, 8],
}
const VALLAS_FILAS := 3
const VALLA_TAM := Vector2(8.0, 4.0)
const VALLA_ALTO := 4.5            # m de la terraza al centro de la valla
const VALLAS_RADIO := 3            # cruces a cada lado de la moto donde puede haber vallas

var partida
var _decals: Array[MeshInstance3D] = []
var _mat_hueco: StandardMaterial3D
var _mat_aceite: StandardMaterial3D
var _marcas: Array[Sprite3D] = [] # la rama o el cono clavado en el hueco (se ve de lejos; el hueco no)
var _perros: Array[Sprite3D] = []
var _avisos: Array[MeshInstance3D] = []
var _mats_aviso: Array[StandardMaterial3D] = []
var _vallas: Array[Node3D] = []
var _mats_valla: Array[StandardMaterial3D] = []
var _t_peligros := 99.0
var _cuadra_avisos := Vector2i(-99, -99)
var _cruce_vallas := Vector2i(-99, -99)


## mats_luz: los materiales que el ciclo del día prende de noche (los de las fachadas).
func preparar(p_partida, mats_luz: Array[StandardMaterial3D]) -> void:
	partida = p_partida
	name = "CalleDetalles"
	_construir_peligros()
	_construir_perros()
	_construir_avisos(mats_luz)
	_construir_vallas(mats_luz)


func _material_hoja(textura: String, filas: int, fila: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + textura + ".png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(1.0, 1.0 / filas, 1.0)
	m.uv1_offset = Vector3(0.0, float(fila) / filas, 0.0)
	return m


func _construir_peligros() -> void:
	var nodo := Node3D.new()
	nodo.name = "Peligros"
	add_child(nodo)
	_mat_hueco = _material_hoja("hueco", 1, 0)
	_mat_aceite = _material_hoja("aceite", 1, 0)
	for m in [_mat_hueco, _mat_aceite]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	var plano := PlaneMesh.new()
	plano.size = Vector2(1, 1)
	for k in PELIGROS_MAX:
		var mi := MeshInstance3D.new()
		mi.name = "Peligro%d" % k
		mi.mesh = plano
		mi.visible = false
		nodo.add_child(mi)
		_decals.append(mi)
		var sp := Sprite3D.new()
		sp.name = "Marca%d" % k
		sp.texture = load(TEX + "marcas_hueco.png")
		sp.hframes = 2
		sp.pixel_size = MARCA_PIXEL
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = false # la luz se le pone a mano, como a la gente
		sp.visible = false
		nodo.add_child(sp)
		_marcas.append(sp)


func _construir_perros() -> void:
	var nodo := Node3D.new()
	nodo.name = "Perros"
	add_child(nodo)
	var hoja: Texture2D = load(TEX + "perros.png")
	for k in partida.perros.MAX:
		var sp := Sprite3D.new()
		sp.name = "Perro%d" % k
		sp.texture = hoja
		sp.hframes = 4
		sp.vframes = partida.perros.RAZAS
		sp.pixel_size = PERRO_PIXEL
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = false
		sp.double_sided = true
		sp.visible = false
		nodo.add_child(sp)
		_perros.append(sp)


func _construir_avisos(mats_luz: Array[StandardMaterial3D]) -> void:
	var nodo := Node3D.new()
	nodo.name = "Avisos"
	add_child(nodo)
	var luz: Texture2D = load(TEX + "avisos_luz.png")
	for fila in AVISOS_FILAS:
		var m := _material_hoja("avisos", AVISOS_FILAS, fila)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.emission_enabled = true
		m.emission_texture = luz
		m.emission = Color.WHITE
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mats_luz.append(m) # de noche prenden los de caja de luz y los de neón
		_mats_aviso.append(m)
	var quad := QuadMesh.new()
	quad.size = AVISO_TAM
	for k in 64: # crece si hace falta
		var mi := MeshInstance3D.new()
		mi.name = "Aviso%d" % k
		mi.mesh = quad
		mi.visible = false
		nodo.add_child(mi)
		_avisos.append(mi)


func _construir_vallas(mats_luz: Array[StandardMaterial3D]) -> void:
	var nodo := Node3D.new()
	nodo.name = "Vallas"
	add_child(nodo)
	for fila in VALLAS_FILAS:
		var m := _material_hoja("vallas", VALLAS_FILAS, fila)
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission = Color(0.6, 0.6, 0.6)
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mats_luz.append(m) # iluminadas de noche, como las de verdad
		_mats_valla.append(m)
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color("4a4d55")
	var quad := QuadMesh.new()
	quad.size = VALLA_TAM
	var lado := VALLAS_RADIO * 2 + 1
	for k in lado * lado:
		var v := Node3D.new()
		v.name = "Valla%d" % k
		v.visible = false
		var cara := MeshInstance3D.new()
		cara.name = "Cara"
		cara.mesh = quad
		cara.position = Vector3(0, VALLA_ALTO, 0.06)
		v.add_child(cara)
		var espalda := MeshInstance3D.new() # la lámina de atrás y las dos patas
		var caja := BoxMesh.new()
		caja.size = Vector3(VALLA_TAM.x + 0.2, VALLA_TAM.y + 0.2, 0.1)
		caja.material = gris
		espalda.mesh = caja
		espalda.position = Vector3(0, VALLA_ALTO, 0.0)
		v.add_child(espalda)
		for x in [-2.5, 2.5]:
			var pata := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.25, VALLA_ALTO - VALLA_TAM.y / 2.0, 0.25)
			b.material = gris
			pata.mesh = b
			pata.position = Vector3(x, (VALLA_ALTO - VALLA_TAM.y / 2.0) / 2.0, -0.1)
			v.add_child(pata)
		nodo.add_child(v)
		_vallas.append(v)


## Cada fotograma. camara: posición en el plano; derecha: el eje x de la cámara (voltear sprites).
func actualizar(delta: float, camara: Vector2, derecha: Vector3, luz: float, farola: bool) -> void:
	var moto_pos: Vector2 = partida.moto.pos
	_t_peligros += delta
	if _t_peligros > 0.3:
		_t_peligros = 0.0
		_poner_peligros(moto_pos)
	_poner_perros(camara, derecha, luz, farola)
	var c = partida.ciudad
	var cuadra := Vector2i(clampi(c._indice(c.inicio_x, moto_pos.x), 0, c.N_ANCHO - 1), clampi(c._indice(c.inicio_y, moto_pos.y), 0, c.N_LARGO - 1))
	if cuadra != _cuadra_avisos:
		_cuadra_avisos = cuadra
		_poner_avisos(cuadra)
	var cruce := Vector2i(clampi(c._indice(c.inicio_x, moto_pos.x) + 1, 0, c.N_ANCHO), clampi(c._indice(c.inicio_y, moto_pos.y) + 1, 0, c.N_LARGO))
	if cruce != _cruce_vallas:
		_cruce_vallas = cruce
		_poner_vallas(cruce)


func _poner_peligros(centro: Vector2) -> void:
	var lista: Array = partida.peligros.cerca(centro, PELIGROS_RADIO)
	lista.sort_custom(func(a, b): return a.pos.distance_squared_to(centro) < b.pos.distance_squared_to(centro))
	for k in _decals.size():
		var mi := _decals[k]
		mi.visible = k < lista.size()
		if not mi.visible:
			_marcas[k].visible = false
			continue
		var h: Dictionary = lista[k]
		mi.material_override = _mat_hueco if h.tipo == "hueco" else _mat_aceite
		var giro := float(h.id % 4) * PI / 2.0 # cada uno girado distinto para que no se vean repetidos
		var d := 2.0 * float(h.radio) * (1.15 if h.tipo == "hueco" else 1.0) # el dibujo tiene borde de gravilla
		mi.transform = Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(d, 1.0, d)), Vector3(h.pos.x, 0.015, h.pos.y))
		var marca := _marcas[k]
		marca.visible = h.tipo == "hueco" and int(h.get("marca", 2)) < 2
		if marca.visible:
			marca.frame = int(h.marca)
			marca.position = Vector3(h.pos.x, 16.0 * MARCA_PIXEL - 0.1, h.pos.y) # clavada: un poco hundida
			var b := lerpf(0.4, 1.0, partida.reloj.luz())
			marca.modulate = Color(b, b, b)


func _poner_perros(camara: Vector2, derecha: Vector3, luz: float, farola: bool) -> void:
	var lista: Array = partida.perros.lista
	var base_luz := lerpf(0.35, 1.0, luz)
	for k in _perros.size():
		var sp := _perros[k]
		sp.visible = k < lista.size()
		if not sp.visible:
			continue
		var d: Dictionary = lista[k]
		var suelo := ANDEN_ALTO if partida.ciudad.en_anden(d.pos, 0.0) else 0.0
		sp.position = Vector3(d.pos.x, suelo + (PERRO_PX / 2.0 - 2.0) * PERRO_PIXEL, d.pos.y)
		var cuadro := int(d.andado / 0.35) % 2
		if d.estado == partida.perros.HUYE and d.t < 0.5:
			cuadro = 3 # el brinco del susto
		sp.frame = int(d.raza) * 4 + cuadro
		var brillo := base_luz
		if farola:
			brillo = maxf(brillo, 0.95 * clampf(1.0 - d.pos.distance_to(camara) / 35.0, 0.0, 1.0))
		sp.modulate = Color(brillo, brillo, brillo)
		sp.flip_h = Vector3(d.dir.x, 0.0, d.dir.y).dot(derecha) < 0.0


static func _azar(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) % 1000003


## Los avisos de las cuadras de alrededor: cada cara de cada cuadra tiene o no un negocio, siempre
## el mismo (sale de la cuadra y la cara, no del azar del momento).
func _poner_avisos(cuadra: Vector2i) -> void:
	var c = partida.ciudad
	var k := 0
	for i in range(cuadra.x - AVISOS_RADIO, cuadra.x + AVISOS_RADIO + 1):
		for j in range(cuadra.y - AVISOS_RADIO, cuadra.y + AVISOS_RADIO + 1):
			if i < 0 or j < 0 or i >= c.N_ANCHO or j >= c.N_LARGO or c.es_parque(i, j):
				continue
			var r: Rect2 = c.cuadra(i, j)
			var dentro := r.grow(-c.ANDEN)
			var opciones: Array = AVISOS_POR_FACHADA.get(c.fachada(i, j), AVISOS_POR_FACHADA.ladrillo)
			for cara in 4:
				# Un negocio posible cada AVISO_CADA metros de fachada, como los locales de una cuadra.
				var sur_norte := cara < 2
				var largo: float = dentro.size.x if sur_norte else dentro.size.y
				var puestos := maxi(int(largo / AVISO_CADA), 1)
				for n in puestos:
					var h := _azar(i * 4 + cara, j, n)
					if h % 100 >= AVISO_PROB:
						continue
					var t := (n + 0.5 + float((h / 100) % 40 - 20) / 100.0) / puestos
					var a := lerpf(0.0, largo, t)
					var pos: Vector2
					var giro: float
					match cara:
						0: # sur (y menor)
							pos = Vector2(dentro.position.x + a, dentro.position.y - 0.08)
							giro = PI
						1: # norte
							pos = Vector2(dentro.position.x + a, dentro.end.y + 0.08)
							giro = 0.0
						2: # x menor
							pos = Vector2(dentro.position.x - 0.08, dentro.position.y + a)
							giro = -PI / 2.0
						_: # x mayor
							pos = Vector2(dentro.end.x + 0.08, dentro.position.y + a)
							giro = PI / 2.0
					if k >= _avisos.size():
						var nuevo := MeshInstance3D.new()
						nuevo.name = "Aviso%d" % k
						nuevo.mesh = _avisos[0].mesh
						_avisos[0].get_parent().add_child(nuevo)
						_avisos.append(nuevo)
					var mi := _avisos[k]
					mi.material_override = _mats_aviso[opciones[(h / 7) % opciones.size()]]
					mi.transform = Transform3D(Basis(Vector3.UP, giro), Vector3(pos.x, AVISO_ALTO, pos.y))
					mi.visible = true
					k += 1
	for q in range(k, _avisos.size()):
		_avisos[q].visible = false


## Vallas en la terraza de algunos edificios de esquina en las avenidas, mirando al cruce.
func _poner_vallas(cruce: Vector2i) -> void:
	var c = partida.ciudad
	var k := 0
	for i in range(cruce.x - VALLAS_RADIO, cruce.x + VALLAS_RADIO + 1):
		for j in range(cruce.y - VALLAS_RADIO, cruce.y + VALLAS_RADIO + 1):
			if i <= 0 or j <= 0 or i >= c.N_ANCHO or j >= c.N_LARGO:
				continue
			if not (c.es_avenida("carrera", i) or c.es_avenida("calle", j)):
				continue
			var h := _azar(i, j, 7)
			if h % 100 >= 45:
				continue
			# En la esquina de una de las cuatro cuadras del cruce, sobre el andén.
			var esquina := h / 100 % 4
			var ci := i if esquina % 2 == 0 else i - 1
			var cj := j if esquina < 2 else j - 1
			if c.es_parque(ci, cj):
				continue
			var r: Rect2 = c.cuadra(ci, cj).grow(-c.ANDEN - 3.5)
			var px: float = r.position.x if ci == i else r.end.x
			var py: float = r.position.y if cj == j else r.end.y
			var hacia: Vector2 = (c.cruce(i, j) - Vector2(px, py)).normalized()
			var v := _vallas[k]
			v.position = Vector3(px, c.altura(ci, cj) + ANDEN_ALTO, py)
			v.rotation = Vector3(0.0, atan2(hacia.x, hacia.y), 0.0)
			(v.get_node("Cara") as MeshInstance3D).material_override = _mats_valla[(h / 400) % VALLAS_FILAS]
			v.visible = true
			k += 1
	for q in range(k, _vallas.size()):
		_vallas[q].visible = false
