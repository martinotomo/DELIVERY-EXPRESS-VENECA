extends Control
## Pantalla de juego, en gris y estilo Doom: el mundo se dibuja a 320×180 y se escala entero;
## encima va el manubrio de la moto, el minimapa y el HUD a 640×360.
## Solo dibuja la partida y le pasa los mandos; la lógica vive en partida.gd.

signal terminado(estado: String, mensaje: String)
signal reintentar
signal al_menu

const PARTIDA := preload("res://scripts/partida.gd")
const VOCES := preload("res://scripts/voces.gd")
const MANUBRIO := preload("res://scripts/manubrio.gd")
const MINIMAPA := preload("res://scripts/minimapa.gd")
const PROGRESO := preload("res://scripts/progreso.gd")
const AUDIO := preload("res://scripts/audio.gd")
const LLUVIA := preload("res://scripts/lluvia_pantalla.gd")

const ALTURA_OJOS := 1.35
const ANDEN_ALTO := 0.2
const SUBTITULO_S := 3.5
const SUBTITULO_POS := Vector2(150, 310) # a la derecha del aviso de derrape, sobre la barra (y 334)
const SUBTITULO_TAM := Vector2(470, 20)
const PLATA_ETIQUETA_X := 586.0

const C_TEXTO := Color("e8e8e8")
const C_ROJO := Color("e0301e")

const SEMILLA := 20260929
var partida = PARTIDA.new(SEMILLA)
var progreso # lo pone el director; sin él se juega con la BWS de fábrica
var voces = VOCES.new(1)
var retraso_resultado := 2.2
var duracion_encuadre := 0.5  # las pruebas lo ponen en 0 para medir el cuadro final

var _mundo: SubViewport
var _camara: Camera3D
var _sol: DirectionalLight3D
var _farola: SpotLight3D
var _entorno: Environment
var _faro_rest: MeshInstance3D
var _faro_cli: MeshInstance3D
var _moto_caida: Node3D
var _manubrio: Control
var _l_vel: Label
var _l_reloj: Label
var _l_hora: Label
var _l_pedido: Label
var _l_cuenta: Label
var _l_derrape: Label
var _l_motor: Label
var _l_bono: Label
var _audio: Node
var _lluvia: Control
var _charcos: MultiMeshInstance3D
var _peatones: Array[Sprite3D] = [] # uno por cada peatón que puede haber a la vez
var _version_charcos := -1
var _mat_asfalto: StandardMaterial3D
var _acelerando := false
## Teclas de prueba (F9 = lluvia, F10 = +$50.000): solo en versiones de desarrollo, nunca en el .exe exportado.
var trucos := OS.is_debug_build()
var _subtitulo: Label
var _voz: AudioStreamPlayer
var _t_subtitulo := 0.0
var _giro_visual := 0.0
var _cinematica := false


func _ready() -> void:
	if progreso != null:
		partida = PARTIDA.new(SEMILLA, progreso.datos_moto())
	_construir_mundo()
	_construir_hud()
	_audio = AUDIO.new()
	_audio.name = "Audio"
	add_child(_audio)
	_audio.preparar(partida.moto.moto)
	partida.evento.connect(_al_evento)
	partida.terminada_por.connect(_al_estrellarse)
	_actualizar_vista(0.0)


func _input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if trucos and tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F9:
		partida.clima.alternar_lluvia()
		get_viewport().set_input_as_handled()
	elif trucos and tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F10 and progreso != null:
		progreso.plata_de_prueba()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("continuar"):
		reintentar.emit()
		return
	if Input.is_action_just_pressed("menu"):
		al_menu.emit()
		return
	if not partida.terminada:
		var giro := Input.get_action_strength("derecha") - Input.get_action_strength("izquierda")
		_giro_visual = lerpf(_giro_visual, giro, minf(delta * 8.0, 1.0))
		_acelerando = Input.is_action_pressed("acelerar")
		partida.advance(delta, _acelerando, Input.is_action_pressed("frenar"), giro)
	_actualizar_vista(delta)
	_audio.actualizar(delta, partida, _acelerando)


# --- mundo 3D con texturas pixeladas --------------------------------------------------

const TEX := "res://assets/texturas/"
## Tipos de fachada por altura: [nombre, altura máxima, metros que ocupa la textura (ancho, alto)].
const FACHADAS := [["casa", 10.0], ["ladrillo", 20.0], ["concreto", 32.0], ["vidrio", 999.0]]
const TINTES_CASA := [Color("9fc4a8"), Color("9db4d8"), Color("e6cf8a"), Color("e3a9a0"), Color("f2efe6"), Color("c9a6d6")]

var _mats_luz: Array[StandardMaterial3D] = []
var _mat_bombillos: StandardMaterial3D
var _cielo: ProceduralSkyMaterial
var _t_cielo := 99.0


func _material(color: Color, por_instancia := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = por_instancia
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return m


## Material con textura pegada al mundo (triplanar): se repite igual sin importar el tamaño de la caja.
func _material_tex(nombre: String, metros: Vector3, por_instancia := false) -> StandardMaterial3D:
	var m := _material(Color.WHITE, por_instancia)
	m.albedo_texture = load(TEX + nombre + ".png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / metros.x, 1.0 / metros.y, 1.0 / metros.z)
	return m


func _cajas(nombre: String, n: int, material: Material, malla: PrimitiveMesh = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var forma: PrimitiveMesh = malla if malla != null else BoxMesh.new()
	forma.material = material
	mm.mesh = forma
	mm.instance_count = n
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nombre
	mmi.multimesh = mm
	return mmi


func _caja(padre: Node, tam: Vector3, pos: Vector3, color: Color, nombre := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	b.material = _material(color)
	mi.mesh = b
	mi.position = pos
	if nombre != "":
		mi.name = nombre
	padre.add_child(mi)
	return mi


func _construir_mundo() -> void:
	var vista := SubViewportContainer.new()
	vista.name = "Vista"
	vista.stretch = true
	vista.stretch_shrink = 2
	vista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vista.size = Vector2(640, 360)
	add_child(vista)
	_mundo = SubViewport.new()
	_mundo.name = "Mundo"
	_mundo.size = Vector2i(320, 180)
	_mundo.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vista.add_child(_mundo)

	_entorno = Environment.new()
	_cielo = ProceduralSkyMaterial.new()
	_cielo.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = _cielo
	_entorno.background_mode = Environment.BG_SKY
	_entorno.sky = sky
	_entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_entorno.fog_enabled = true
	_entorno.fog_density = 0.007
	_entorno.fog_sky_affect = 0.35
	var we := WorldEnvironment.new()
	we.environment = _entorno
	_mundo.add_child(we)

	_sol = DirectionalLight3D.new()
	_sol.name = "Sol"
	_mundo.add_child(_sol)

	var c = partida.ciudad
	var tam: Vector2 = c.tamano()
	var ciudad := Node3D.new()
	ciudad.name = "Ciudad"
	_mundo.add_child(ciudad)
	var asfalto := _caja(ciudad, Vector3(tam.x, 0.1, tam.y), Vector3(tam.x / 2.0, -0.05, tam.y / 2.0), Color.WHITE, "Asfalto")
	_mat_asfalto = _material_tex("asfalto", Vector3(5, 5, 5))
	asfalto.mesh.material = _mat_asfalto
	# Charcos: discos planos que brillan; se redibujan cuando el clima los cambia.
	var disco := CylinderMesh.new()
	disco.top_radius = 1.0
	disco.bottom_radius = 1.0
	disco.height = 0.02
	disco.radial_segments = 12
	var agua := _material(Color("5d6f88"))
	agua.emission_enabled = true # brilla un poco, como si reflejara el cielo
	agua.emission = Color("8aa0bf")
	agua.emission_energy_multiplier = 0.7
	agua.roughness = 0.05
	agua.metallic = 0.4
	agua.metallic_specular = 1.0
	_charcos = _cajas("Charcos", 0, agua, disco)
	ciudad.add_child(_charcos)

	var n: int = c.N_ANCHO * c.N_LARGO
	var andenes := _cajas("Andenes", n, _material_tex("anden", Vector3(3, 3, 3), true))
	var parques := _cajas("Parques", c.parques.size(), _material_tex("pasto", Vector3(4, 4, 4), true))
	# Primero contar cuántos edificios hay de cada tipo.
	var por_tipo := {}
	for f in FACHADAS:
		por_tipo[f[0]] = []
	for j in c.N_LARGO:
		for i in c.N_ANCHO:
			if not c.es_parque(i, j):
				por_tipo[_tipo_fachada(c.altura(i, j))].append(Vector2i(i, j))
	var edificios := Node3D.new()
	edificios.name = "Edificios"
	ciudad.add_child(edificios)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for f in FACHADAS:
		var tipo: String = f[0]
		var mat := _material_tex("fachada_" + tipo, Vector3(8, 6.4, 8), true)
		mat.emission_enabled = true
		mat.emission_texture = load(TEX + "fachada_%s_luz.png" % tipo)
		mat.emission = Color.WHITE
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		_mats_luz.append(mat)
		var lista: Array = por_tipo[tipo]
		var mmi := _cajas(tipo.capitalize(), lista.size(), mat)
		for k in lista.size():
			var ij: Vector2i = lista[k]
			var r: Rect2 = c.cuadra(ij.x, ij.y)
			var h: float = c.altura(ij.x, ij.y)
			var dentro := Vector3(r.size.x - 2.0 * c.ANDEN, h, r.size.y - 2.0 * c.ANDEN)
			var centro := Vector3(r.get_center().x, h / 2.0 + ANDEN_ALTO, r.get_center().y)
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(dentro), centro))
			var tinte: Color = TINTES_CASA[rng.randi_range(0, TINTES_CASA.size() - 1)] if tipo == "casa" else Color.WHITE * rng.randf_range(0.8, 1.0)
			tinte.a = 1.0
			mmi.multimesh.set_instance_color(k, tinte)
		edificios.add_child(mmi)

	var k_a := 0
	var k_p := 0
	for j in c.N_LARGO:
		for i in c.N_ANCHO:
			var r: Rect2 = c.cuadra(i, j)
			var centro := Vector3(r.get_center().x, 0.0, r.get_center().y)
			andenes.multimesh.set_instance_transform(k_a, Transform3D(Basis.from_scale(Vector3(r.size.x, ANDEN_ALTO, r.size.y)), centro + Vector3(0, ANDEN_ALTO / 2.0, 0)))
			andenes.multimesh.set_instance_color(k_a, Color.WHITE)
			k_a += 1
			if c.es_parque(i, j):
				var dentro := Vector3(r.size.x - 2.0 * c.ANDEN, 0.1, r.size.y - 2.0 * c.ANDEN)
				parques.multimesh.set_instance_transform(k_p, Transform3D(Basis.from_scale(dentro), centro + Vector3(0, ANDEN_ALTO + 0.05, 0)))
				parques.multimesh.set_instance_color(k_p, Color.WHITE)
				k_p += 1
	ciudad.add_child(andenes)
	ciudad.add_child(parques)
	_construir_lineas(ciudad, c)
	_construir_cebras(ciudad, c)
	_construir_postes(ciudad, c)
	_construir_peatones()

	# Faros de pedido: columnas altas que se ven por encima de los edificios.
	_faro_rest = _caja(_mundo, Vector3(1.2, 60, 1.2), Vector3.ZERO, Color("ff8a2a"), "FaroRestaurante")
	_faro_cli = _caja(_mundo, Vector3(1.2, 60, 1.2), Vector3.ZERO, Color("4ade80"), "FaroCliente")
	for f in [_faro_rest, _faro_cli]:
		var m: StandardMaterial3D = f.mesh.material
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_camara = Camera3D.new()
	_camara.name = "Camara"
	_camara.fov = 75.0
	_camara.near = 0.1
	_camara.far = 450.0
	_mundo.add_child(_camara)
	_camara.current = true
	_farola = SpotLight3D.new()
	_farola.name = "Farola"
	_farola.spot_range = 70.0
	_farola.spot_angle = 30.0
	_farola.light_color = Color("fff1c8")
	_farola.position = Vector3(0, -0.3, 0)
	_camara.add_child(_farola)

	_moto_caida = _construir_moto_caida()
	_moto_caida.visible = false
	_mundo.add_child(_moto_caida)


func _tipo_fachada(h: float) -> String:
	for f in FACHADAS:
		if h <= f[1]:
			return f[0]
	return "vidrio"


## Línea amarilla a trazos por el centro de cada tramo de vía (entre cruce y cruce).
func _construir_lineas(padre: Node3D, c) -> void:
	var horizontales: Array[Transform3D] = []
	var verticales: Array[Transform3D] = []
	for j in c.N_LARGO + 1:
		for i in c.N_ANCHO:
			var y: float = c.cruce(0, j).y
			var x0: float = c.inicio_x[i]
			var largo: float = c.anchos[i] - 2.0 * (c.CEBRA + 1.0) # la línea para antes de la cebra
			horizontales.append(Transform3D(Basis.from_scale(Vector3(largo, 1, 0.25)), Vector3(x0 + c.anchos[i] / 2.0, 0.02, y)))
	for i in c.N_ANCHO + 1:
		for j in c.N_LARGO:
			var x: float = c.cruce(i, 0).x
			var y0: float = c.inicio_y[j]
			var largo: float = c.largos[j] - 2.0 * (c.CEBRA + 1.0)
			verticales.append(Transform3D(Basis.from_scale(Vector3(0.25, 1, largo)), Vector3(x, 0.02, y0 + c.largos[j] / 2.0)))
	for par in [["LineasCalles", "linea_h", horizontales], ["LineasCarreras", "linea_v", verticales]]:
		var mat := _material_tex(par[1], Vector3(4, 4, 4))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var plano := PlaneMesh.new()
		plano.size = Vector2(1, 1)
		var mmi := _cajas(par[0], par[2].size(), mat, plano)
		for k in par[2].size():
			mmi.multimesh.set_instance_transform(k, par[2][k])
			mmi.multimesh.set_instance_color(k, Color.WHITE)
		padre.add_child(mmi)


## Cebras en todas las esquinas: franjas blancas gastadas, un poco por encima de la línea amarilla.
func _construir_cebras(padre: Node3D, c) -> void:
	var calles: Array[Transform3D] = []   # cebras que atraviesan calles (franjas a lo largo de x)
	var carreras: Array[Transform3D] = []
	for j in c.N_LARGO + 1:
		for i in c.N_ANCHO + 1:
			for cb in c.cebras(i, j):
				var r: Rect2 = c.rect_cebra(cb)
				var t := Transform3D(Basis.from_scale(Vector3(r.size.x, 1, r.size.y)), Vector3(r.get_center().x, 0.025, r.get_center().y))
				(calles if cb.cruza.y != 0.0 else carreras).append(t)
	for par in [["CebrasCalles", "cebra_h", calles], ["CebrasCarreras", "cebra_v", carreras]]:
		var mat := _material_tex(par[1], Vector3(4, 4, 4))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var plano := PlaneMesh.new()
		plano.size = Vector2(1, 1)
		var mmi := _cajas(par[0], par[2].size(), mat, plano)
		for k in par[2].size():
			mmi.multimesh.set_instance_transform(k, par[2][k])
			mmi.multimesh.set_instance_color(k, Color.WHITE)
		padre.add_child(mmi)


## Peatones a lo Doom: sprites planos que siempre miran a la cámara (solo giran en el eje vertical).
const PEATON_PX := 40.0      # tamaño del cuadro en la hoja
const PEATON_ALTO := 1.75    # m que mide una persona (36 px de los 40 del cuadro)


func _construir_peatones() -> void:
	var nodo := Node3D.new()
	nodo.name = "Peatones"
	_mundo.add_child(nodo)
	var hoja: Texture2D = load(TEX + "peatones.png")
	for k in partida.peatones.MAX:
		var sp := Sprite3D.new()
		sp.name = "Peaton%d" % k
		sp.texture = hoja
		sp.hframes = 4
		sp.vframes = partida.peatones.ROPAS
		sp.pixel_size = PEATON_ALTO / 36.0
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = false # la luz se le pone a mano (abajo), como en Doom: se ven igual de lejos que de cerca
		sp.double_sided = true
		sp.visible = false
		nodo.add_child(sp)
		_peatones.append(sp)


## Cada fotograma: pone cada sprite donde va su peatón, con el cuadro de su estado.
func _actualizar_peatones() -> void:
	var gente: Array = partida.peatones.lista
	var derecha := _camara.global_transform.basis.x
	var luz: float = lerpf(0.35, 1.0, partida.reloj.luz())
	for k in _peatones.size():
		var sp := _peatones[k]
		sp.visible = k < gente.size()
		if not sp.visible:
			continue
		var p: Dictionary = gente[k]
		var suelo := ANDEN_ALTO if partida.ciudad.en_anden(p.pos, 0.0) else 0.0
		sp.position = Vector3(p.pos.x, suelo + PEATON_PX * sp.pixel_size / 2.0, p.pos.y)
		var cuadro := 0
		if p.estado == partida.peatones.CAIDO:
			cuadro = 2
		elif p.estado == partida.peatones.GRITA:
			cuadro = 3
		else:
			cuadro = int(p.andado / 0.45) % 2 # un paso cada 45 cm
		sp.frame = p.ropa * 4 + cuadro
		var brillo := luz
		if _farola.visible: # de noche, la farola de la moto los alumbra de cerca
			brillo = maxf(brillo, 0.95 * clampf(1.0 - p.pos.distance_to(partida.moto.pos) / 35.0, 0.0, 1.0))
		sp.modulate = Color(brillo, brillo, brillo)
		# El dibujo mira a la derecha: si camina hacia la izquierda de la pantalla, se voltea.
		sp.flip_h = Vector3(p.dir.x, 0.0, p.dir.y).dot(derecha) < 0.0


## Postes de luz en las esquinas de cada cuadra; la bombilla brilla de noche.
func _construir_postes(padre: Node3D, c) -> void:
	var n: int = c.N_ANCHO * c.N_LARGO * 2
	var postes := _cajas("Postes", n, _material(Color("3a3c40")))
	_mat_bombillos = _material(Color("2a2a2a"))
	_mat_bombillos.emission_enabled = true
	_mat_bombillos.emission = Color("f0b046")
	var bombillos := _cajas("Bombillos", n, _mat_bombillos)
	var k := 0
	for j in c.N_LARGO:
		for i in c.N_ANCHO:
			var r: Rect2 = c.cuadra(i, j)
			for esquina in [r.position + Vector2(1.0, 1.0), r.end - Vector2(1.0, 1.0)]:
				var base := Vector3(esquina.x, ANDEN_ALTO, esquina.y)
				postes.multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(0.18, 7.0, 0.18)), base + Vector3(0, 3.5, 0)))
				postes.multimesh.set_instance_color(k, Color.WHITE)
				bombillos.multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(0.7, 0.25, 0.4)), base + Vector3(0, 7.1, 0)))
				bombillos.multimesh.set_instance_color(k, Color.WHITE)
				k += 1
	padre.add_child(postes)
	padre.add_child(bombillos)


## La BWS en bloques para la cinemática: se ve desde fuera solo cuando se cae.
## Eje +X local = hacia delante. Colores genéricos, sin logos (CLAUDE.md §7).
func _construir_moto_caida() -> Node3D:
	var moto := Node3D.new()
	moto.name = "MotoCaida"
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"
	moto.add_child(cuerpo)
	var llanta := Color("1a1a1e")
	var rin := Color("b4b4be")
	var carroceria := Color("2456b0")
	var blanco := Color("e8e8e0")
	for x in [-0.62, 0.66]:  # llantas gordas de BWS con su rin
		_caja(cuerpo, Vector3(0.56, 0.56, 0.3), Vector3(x, 0.28, 0), llanta)
		_caja(cuerpo, Vector3(0.26, 0.26, 0.32), Vector3(x, 0.28, 0), rin)
	_caja(cuerpo, Vector3(1.2, 0.18, 0.46), Vector3(0.0, 0.5, 0), Color("303038"))    # piso
	_caja(cuerpo, Vector3(0.75, 0.38, 0.52), Vector3(-0.48, 0.78, 0), carroceria)     # cola
	_caja(cuerpo, Vector3(0.7, 0.12, 0.4), Vector3(-0.42, 1.02, 0), Color("141418"))  # sillín
	_caja(cuerpo, Vector3(0.12, 0.12, 0.3), Vector3(-0.88, 0.82, 0), Color("d01c1c")) # stop
	_caja(cuerpo, Vector3(0.3, 0.8, 0.6), Vector3(0.52, 0.85, 0), carroceria)         # escudo
	_caja(cuerpo, Vector3(0.1, 0.34, 0.62), Vector3(0.7, 0.95, 0), blanco)            # careta
	_caja(cuerpo, Vector3(0.08, 0.14, 0.14), Vector3(0.76, 1.0, 0.16), Color("ffe680"))  # farola izq.
	_caja(cuerpo, Vector3(0.08, 0.14, 0.14), Vector3(0.76, 1.0, -0.16), Color("ffe680")) # farola der.
	_caja(cuerpo, Vector3(0.44, 0.22, 0.4), Vector3(0.66, 0.56, 0), blanco)           # guardabarros
	_caja(cuerpo, Vector3(0.1, 0.1, 0.9), Vector3(0.45, 1.32, 0), Color("8c8c96"))    # manubrio
	_caja(cuerpo, Vector3(0.6, 0.5, 0.5), Vector3(-0.55, 1.35, 0), Color("e07818"))  # caja del domicilio
	var piloto := Node3D.new()
	piloto.name = "Piloto"
	moto.add_child(piloto)
	_caja(piloto, Vector3(0.9, 0.3, 0.5), Vector3(0, 0.15, 0), Color("aa3c1e"))       # chaqueta
	_caja(piloto, Vector3(0.8, 0.22, 0.4), Vector3(-0.8, 0.11, 0.05), Color("2c3450")) # jean
	_caja(piloto, Vector3(0.36, 0.36, 0.36), Vector3(0.62, 0.2, 0), Color("f0f0f0"))  # casco
	_caja(piloto, Vector3(1.6, 0.02, 1.1), Vector3(0.1, 0.01, 0), Color("8c1010"), "Charco")
	# Luz propia: de noche la escena se ve igual.
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.position = Vector3(-1.5, 2.2, 0)
	luz.omni_range = 7.0
	luz.light_energy = 1.4
	luz.light_color = Color("ffd8a8")
	moto.add_child(luz)
	return moto


## Dónde va la cámara de la cinemática: detrás y a un lado de la moto (tres cuartos), baja,
## para que la moto se vea de perfil y llene el cuadro. Se elige el lado que queda sobre la calle.
func encuadre_caida() -> Array:
	var m = partida.moto
	var dir: Vector2 = m.direccion()
	var mejor := Vector2.ZERO
	var mejor_d := -1.0
	for lado in [1.0, -1.0]:
		var p: Vector2 = m.pos - dir.rotated(lado * deg_to_rad(80.0)) * 3.4
		var d: float = partida.ciudad.distancia_anden(p)
		if d > mejor_d:
			mejor_d = d
			mejor = p
	var ojo := Vector3(mejor.x, 3.0, mejor.y)
	var mira := Vector3(m.pos.x, 0.2, m.pos.y) + Vector3(dir.x, 0.0, dir.y) * 0.9
	return [ojo, mira]


# --- HUD --------------------------------------------------------------------------

func _texto(pos: Vector2, tam: int, nombre: String, ancho := 0.0) -> Label:
	var l := Label.new()
	if nombre != "":
		l.name = nombre
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", C_TEXTO)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	if ancho > 0.0:
		l.size = Vector2(ancho, tam + 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$HUD.add_child(l)
	return l


func _construir_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	_lluvia = LLUVIA.new()
	_lluvia.name = "Lluvia"
	_lluvia.size = Vector2(640, 360)
	hud.add_child(_lluvia)

	_manubrio = MANUBRIO.new()
	_manubrio.name = "Manubrio"
	_manubrio.moto_id = partida.moto.moto.id
	_manubrio.tope_kmh = ceilf(float(partida.moto.moto.vel_max) * 3.6 / 20.0) * 20.0 + 20.0
	_manubrio.size = Vector2(640, 360)
	_manubrio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_manubrio)

	# Barra de estado abajo, a lo Doom: números grandes en rojo sobre fondo oscuro.
	var barra := ColorRect.new()
	barra.name = "Barra"
	barra.color = Color("1c1c22")
	barra.position = Vector2(0, 334)
	barra.size = Vector2(640, 26)
	hud.add_child(barra)
	var filo := ColorRect.new()
	filo.color = Color("5c5c64")
	filo.size = Vector2(640, 2)
	barra.add_child(filo)
	_l_vel = _texto(Vector2(10, 339), 16, "Velocidad")
	_l_vel.add_theme_color_override("font_color", C_ROJO)
	_etiqueta(Vector2(84, 344), "KM/H")
	_l_reloj = _texto(Vector2(248, 339), 16, "Reloj")
	_l_reloj.add_theme_color_override("font_color", C_ROJO)
	_etiqueta(Vector2(338, 344), "TIEMPO")
	# Alineada a la derecha, pegada a «PLATA»: crece hacia la izquierda con cifras largas.
	_l_cuenta = _texto(Vector2(PLATA_ETIQUETA_X - 8 - 200, 339), 16, "Plata")
	_l_cuenta.size = Vector2(200, 22)
	_l_cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_l_cuenta.add_theme_color_override("font_color", C_ROJO)
	_etiqueta(Vector2(PLATA_ETIQUETA_X, 344), "PLATA")

	var mini: Control = MINIMAPA.new()
	mini.name = "Minimapa"
	mini.partida = partida
	mini.position = Vector2(502, 8)
	mini.size = Vector2(130, 130)
	hud.add_child(mini)
	_l_hora = _texto(Vector2(502, 142), 8, "Hora")

	_l_pedido = _texto(Vector2(8, 8), 8, "Pedido")
	_l_pedido.add_theme_stylebox_override("normal", _fondo())
	# Aviso de derrape pequeño y en la esquina, encima de la velocidad (no tapa la calle).
	_l_derrape = _texto(Vector2(8, 314), 8, "Derrape")
	_l_derrape.text = "¡SE VA DE LADO!"
	_l_derrape.add_theme_color_override("font_color", C_ROJO)
	_l_derrape.add_theme_stylebox_override("normal", _fondo())
	_l_derrape.visible = false
	# Aviso del motor, encima del de derrape: cuenta regresiva y luego la espera de la reparación.
	_l_motor = _texto(Vector2(8, 290), 8, "Motor")
	_l_motor.add_theme_color_override("font_color", Color("f0c040"))
	_l_motor.add_theme_stylebox_override("normal", _fondo())
	_l_motor.visible = false
	# Bono de lluvia, abajo a la derecha (no tapa la calle).
	_l_bono = _texto(Vector2(0, 290), 8, "Bono")
	_l_bono.text = "LLUVIA: +%d%% POR PEDIDO" % roundi(partida.clima.BONO * 100.0)
	_l_bono.add_theme_color_override("font_color", Color("8ec8ff"))
	_l_bono.add_theme_stylebox_override("normal", _fondo())
	_l_bono.position.x = 632.0 - _l_bono.get_minimum_size().x
	_l_bono.visible = false

	# Subtítulos con su propia franja de fondo, para que se lean sobre la calle en movimiento.
	# Abajo, justo encima de la barra: puede tapar el velocímetro, nunca la calle (Tomás, 30/09).
	_subtitulo = _texto(SUBTITULO_POS, 8, "Subtitulo", SUBTITULO_TAM.x)
	_subtitulo.size = SUBTITULO_TAM
	_subtitulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitulo.add_theme_stylebox_override("normal", _fondo())
	_subtitulo.visible = false

	_voz = AudioStreamPlayer.new()
	_voz.name = "Voz"
	add_child(_voz)


func _fondo() -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = Color(0, 0, 0, 0.72)
	f.content_margin_left = 6
	f.content_margin_right = 6
	f.content_margin_top = 4
	f.content_margin_bottom = 4
	return f


func _etiqueta(pos: Vector2, texto: String) -> void:
	var l := _texto(pos, 8, "")
	l.text = texto
	l.add_theme_color_override("font_color", Color("9a9aa2"))


# --- dibujar la partida -------------------------------------------------------------

func _actualizar_vista(delta: float) -> void:
	var m = partida.moto
	if not _cinematica:
		var cabeceo := sin(Time.get_ticks_msec() / 90.0) * 0.015 * clampf(m.vel / 25.0, 0.0, 1.0)
		_camara.position = Vector3(m.pos.x, ALTURA_OJOS + cabeceo, m.pos.y)
		_camara.rotation = Vector3(0.0, -m.rumbo - PI / 2.0, -_giro_visual * 0.07)

	_actualizar_cielo(delta)

	var p: Dictionary = partida.pedido
	var recoger: bool = partida.fase == partida.RECOGER
	_faro_rest.visible = recoger
	_faro_cli.visible = not recoger
	_faro_rest.position = Vector3(p.restaurante.x, 30, p.restaurante.y)
	_faro_cli.position = Vector3(p.cliente.x, 30, p.cliente.y)

	_manubrio.giro = _giro_visual
	_manubrio.vel_kmh = m.vel_kmh()
	_l_vel.text = "%3d" % m.vel_kmh()
	var s := int(ceil(maxf(partida.tiempo_restante, 0.0)))
	_l_reloj.text = "%d:%02d" % [s / 60, s % 60]
	_l_reloj.modulate.a = 0.35 if s <= 15 and int(Time.get_ticks_msec() / 250) % 2 == 0 else 1.0
	_l_cuenta.text = PROGRESO.pesos(progreso.dinero if progreso != null else partida.ganado)
	_l_hora.text = ("DIA " if partida.reloj.luz() > 0.25 else "NOCHE ") + partida.reloj.texto_hora()
	if recoger:
		_l_pedido.text = "RECOGE: %s\nSigue la columna naranja" % p.plato.to_upper()
	else:
		_l_pedido.text = "ENTREGA: %s\n%s" % [p.plato.to_upper(), p.direccion]
	_l_derrape.visible = m.derrapando and not partida.terminada
	var cuenta: float = m.cuenta_motor()
	if m.motor_fundido:
		_l_motor.text = "MOTOR FUNDIDO: espera %d" % ceili(maxf(m.espera_reparacion(), 0.0))
	elif cuenta >= 0.0:
		_l_motor.text = "¡VAS A FUNDIR EL MOTOR! %d" % ceili(cuenta)
	_l_motor.visible = (m.motor_fundido or cuenta >= 0.0) and not partida.terminada
	var clima = partida.clima
	_l_bono.visible = clima.lloviendo() and not partida.terminada
	_lluvia.intensidad = clima.intensidad
	_lluvia.giro = _giro_visual
	if clima.version != _version_charcos:
		_version_charcos = clima.version
		var mm := _charcos.multimesh
		mm.instance_count = clima.charcos.size()
		for k in clima.charcos.size():
			var ch: Dictionary = clima.charcos[k]
			mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(ch.radio, 1.0, ch.radio * 0.8)), Vector3(ch.pos.x, 0.012, ch.pos.y)))
			mm.set_instance_color(k, Color.WHITE)

	_actualizar_peatones()
	if partida.multado:
		_l_pedido.text += "\nSIN PROPINA: atropellaste a alguien"

	_t_subtitulo = maxf(_t_subtitulo - delta, 0.0)
	_subtitulo.visible = _t_subtitulo > 0.0


## Cielo, sol, ventanas y postes según la hora. El cielo se recalcula cada medio segundo.
func _actualizar_cielo(delta: float) -> void:
	var ciclo = partida.reloj
	var luz: float = ciclo.luz()
	var llueve: float = partida.clima.intensidad
	var cielo: Color = ciclo.color_cielo().lerp(Color("6b7280").darkened(0.6 * (1.0 - luz)), llueve * 0.7)
	_entorno.fog_density = lerpf(0.007, 0.02, llueve)
	# Piso mojado: brilla más cuanto más agua tiene.
	_mat_asfalto.roughness = lerpf(1.0, 0.35, partida.clima.humedad)
	_mat_asfalto.metallic_specular = lerpf(0.5, 0.9, partida.clima.humedad)
	_t_cielo += delta
	if _t_cielo >= 0.5 or delta == 0.0:
		_t_cielo = 0.0
		_cielo.sky_top_color = cielo.darkened(0.35)
		_cielo.sky_horizon_color = cielo.lightened(0.12)
		_cielo.ground_horizon_color = cielo.darkened(0.2)
		_cielo.ground_bottom_color = cielo.darkened(0.6)
		_entorno.fog_light_color = cielo.darkened(0.1)
	var h: float = ciclo.hora()
	_sol.rotation = Vector3(-deg_to_rad(sin(PI * (h - 5.0) / 14.0) * 70.0), deg_to_rad(90.0 - (h - 5.0) * 12.0), 0.0)
	_sol.visible = luz > 0.0
	_sol.light_energy = luz * 1.1 * (1.0 - 0.5 * llueve)
	_sol.light_color = Color("ffd9a0").lerp(Color("fff6e6"), luz)
	_entorno.ambient_light_color = Color("46507a").lerp(Color("c8c4bc"), luz)
	_entorno.ambient_light_energy = lerpf(0.45, 0.75, luz)
	var noche := clampf(1.0 - luz * 2.5, 0.0, 1.0)
	for mat in _mats_luz:
		mat.emission_energy_multiplier = noche * 1.3
	_mat_bombillos.emission_energy_multiplier = noche * 4.0
	_farola.visible = ciclo.farola_encendida()
	_farola.light_energy = 2.5


func _al_evento(nombre: String) -> void:
	_audio.al_evento(nombre)
	var texto: String = voces.frase(nombre)
	if texto == "":
		return
	_subtitulo.text = texto
	_subtitulo.visible = true
	_t_subtitulo = SUBTITULO_S
	var ruta: String = VOCES.ruta_audio(nombre, voces._ultima.get(nombre, 0))
	if ResourceLoader.exists(ruta):
		_voz.stream = load(ruta)
		_voz.play()


# --- la caída ----------------------------------------------------------------------

func _al_estrellarse(mensaje: String) -> void:
	_cinematica = true
	var m = partida.moto
	# Solo queda el subtítulo, abajo, para que no tape la escena.
	for hijo in $HUD.get_children():
		hijo.visible = hijo == _subtitulo and _subtitulo.visible
	# Moto de lado en el andén y el piloto unos metros adelante.
	_moto_caida.visible = true
	_moto_caida.position = Vector3(m.pos.x, ANDEN_ALTO, m.pos.y)
	_moto_caida.rotation = Vector3(0.0, -m.rumbo, 0.0)
	_moto_caida.scale = Vector3.ONE * 1.3  # un poco más grande que la real, para que se lea en 320×180
	var cuerpo: Node3D = _moto_caida.get_node("Cuerpo")
	cuerpo.rotation = Vector3(deg_to_rad(88), 0, 0)
	var piloto: Node3D = _moto_caida.get_node("Piloto")
	piloto.position = Vector3(2.3, 0.0, -0.9)
	# Cámara a tercera persona, mirando la escena.
	var encuadre := encuadre_caida()
	var ojo: Vector3 = encuadre[0]
	var mira: Vector3 = encuadre[1]
	_camara.rotation.z = 0.0
	if duracion_encuadre <= 0.0:
		_camara.position = ojo
		_camara.look_at(mira)
	else:
		var desde_pos := _camara.position
		var mover := func(k: float) -> void:
			_camara.position = desde_pos.lerp(ojo, k)
			_camara.look_at(mira)
		var tw := create_tween()
		tw.tween_method(mover, 0.0, 1.0, duracion_encuadre).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var cierre := "Ni un pedido entregado. La app ya te está buscando reemplazo."
	if partida.entregados > 0:
		cierre = "Entregaste %d pedidos: +%s, y esa plata no se pierde." % [partida.entregados, PROGRESO.pesos(partida.ganado)]
	var final_msg := "%s\n\n%s" % [mensaje, cierre]
	if retraso_resultado <= 0.0:
		terminado.emit("estrellado", final_msg)
		return
	await get_tree().create_timer(retraso_resultado).timeout
	if is_inside_tree():
		terminado.emit("estrellado", final_msg)
