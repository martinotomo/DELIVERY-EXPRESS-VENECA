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
const MAPA := preload("res://scripts/mapa.gd")
const PAUSA := preload("res://scripts/pausa.gd")
const CARGA := preload("res://scripts/carga.gd")

const ALTURA_OJOS := 1.5
const MIRADA_ABAJO := 0.1   # rad que se inclina la vista hacia la calle (se ve más camino por encima del tablero)
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
var opciones # también del director: la pausa las muestra
var pausa: Control # menú de pausa (Esc)
var voces = VOCES.new(1)
var retraso_resultado := 3.0
var ilustracion_final: Texture2D # la caída dibujada, para que el remate se lea encima
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
var _l_ubicacion: Label
var _l_racha: Label
var _l_estrellas: Label
var _t_estrellas := 0.0
const ESTRELLAS_S := 4.5
var _mapa: Control
var _letreros: Array[Node3D] = [] # placas de las esquinas cercanas (se reacomodan al cambiar de cruce)
var _cruce_letreros := Vector2i(-99, -99)
var _mats_placa: Array[StandardMaterial3D] = []
var _audio: Node
var _lluvia: Control
var _charcos: MultiMeshInstance3D
var _peatones: Array[Sprite3D] = [] # uno por cada peatón que puede haber a la vez
var _transeuntes: Array[Sprite3D] = [] # la gente de los andenes
var _vehiculos: Array[Sprite3D] = []  # tráfico: un sprite por vehículo que puede haber a la vez
var _hojas_vehiculos := {}
var _cerros: MeshInstance3D
var _mat_cerros: StandardMaterial3D
var _mat_cerros_luz: StandardMaterial3D
var _mats_semaforo := {}  # "x_rojo", "y_verde"...: una luz por eje y color, todas sincronizadas
var _version_charcos := -1
var _mat_asfalto: StandardMaterial3D
var _acelerando := false
## Teclas de prueba (F9 = lluvia, F10 = +$50.000): solo en versiones de desarrollo, nunca en el .exe exportado.
var trucos := OS.is_debug_build() and not OS.has_feature("entrega") # F9/F10: solo en desarrollo

## Precalentado (02/10/2026, versión web): el navegador prepara cada material la primera vez que lo
## dibuja y, mientras, el juego se congela o la calle sale gris. Antes de soltar la partida se
## dibuja todo una vez (cuatro direcciones con cada combinación de sol y farola, y una muestra de
## cada cosa que aparece después: peatones, carros, perros, charcos, la moto caída) tapado por la
## pantalla de carga, y se espera a que los fotogramas salgan rápidos. Las pruebas lo apagan.
static var precalentar := true
const VISTAS_PRECALENTADO := 4
const LUCES_PRECALENTADO := [[true, false], [true, true], [false, true], [false, false]] # sol, farola
const PASOS_PRECALENTADO := 16 # vistas × luces
const CUADROS_POR_PASO := 2
const CUADRO_RAPIDO_S := 0.1    # un fotograma más corto que esto ya no está preparando nada
const CUADROS_ESTABLES := 6     # seguidos, para soltar
const CARGA_MAX_S := 25         # si el navegador no se calma, se suelta igual
var cargando := false
var _carga: Control
var _t_carga := 0.0
var _paso_carga := 0
var _cuadro_paso := 0
var _estables := 0
var _subtitulo: Label
var _t_subtitulo := 0.0
var _giro_visual := 0.0
var _cinematica := false
var _ilustracion: TextureRect
const ILUSTRACION_TRAS := 0.35  # s de cámara en 3D antes de pasar al dibujo de la caída (el golpe)
const ILUSTRACION_FUNDIDO := 0.25
const ILUSTRACION_ZOOM := 1.08  # acercamiento lento mientras se ve


func _ready() -> void:
	if progreso != null:
		partida = PARTIDA.new(SEMILLA, progreso.datos_moto(), progreso.toca_final())
		if progreso.estrenando() != "":
			get_tree().create_timer(1.2, false).timeout.connect(func(): if is_inside_tree(): _al_evento("moto_nueva"))
	_construir_mundo()
	_construir_hud()
	_audio = AUDIO.new()
	_audio.name = "Audio"
	add_child(_audio)
	_audio.preparar(partida.moto.moto)
	partida.evento.connect(_al_evento)
	partida.calificado.connect(_al_calificar)
	partida.final_logrado.connect(_al_final)
	partida.terminada_por.connect(_al_estrellarse)
	_actualizar_vista(0.0)
	# El menú de pausa va en su propia capa, encima del HUD.
	var capa := CanvasLayer.new()
	capa.name = "CapaPausa"
	capa.layer = 10
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	pausa = PAUSA.new()
	pausa.opciones = opciones
	pausa.al_menu.connect(func(): al_menu.emit())
	capa.add_child(pausa)
	if precalentar:
		cargando = true
		var capa_carga := CanvasLayer.new()
		capa_carga.name = "CapaCarga"
		capa_carga.layer = 9
		add_child(capa_carga)
		_carga = CARGA.new()
		capa_carga.add_child(_carga)


## Si la ventana pierde el foco (otra pestaña, otra ventana, o el navegador sale de pantalla
## completa con Esc), la partida se pausa sola.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pausa != null and not partida.terminada and not pausa.visible:
		_mapa.visible = false
		pausa.abrir()


## Esc (o P, que en el navegador no se roba la pantalla completa): en plena partida abre la pausa; ya caído (cinemática), va al menú como antes.
## Enter o R: otra jornada. Van aquí y no en _process para que la tecla que cierra la pausa (o que
## pulsa un botón de ella) no la reciba también la partida.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		if partida.terminada:
			al_menu.emit()
		else:
			_mapa.visible = false
			pausa.abrir()
	elif event.is_action_pressed("continuar"):
		get_viewport().set_input_as_handled()
		reintentar.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mapa") and not partida.terminada:
		_mapa.visible = not _mapa.visible
		get_viewport().set_input_as_handled()
		return
	var tecla := event as InputEventKey
	if trucos and tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F9:
		partida.clima.alternar_lluvia()
		get_viewport().set_input_as_handled()
	elif trucos and tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F10 and progreso != null:
		progreso.plata_de_prueba()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if cargando:
		_precalentar(delta)
		return
	if not partida.terminada and not _mapa.visible: # con el mapa abierto, la partida espera
		var giro := Input.get_action_strength("derecha") - Input.get_action_strength("izquierda")
		_giro_visual = lerpf(_giro_visual, giro, minf(delta * 8.0, 1.0))
		_acelerando = Input.is_action_pressed("acelerar")
		partida.advance(delta, _acelerando, Input.is_action_pressed("frenar"), giro)
		if Input.is_action_just_pressed("pitar"):
			_audio.al_evento("pito_moto") # «mii»: no sirve de nada, como en la vida real
	_actualizar_vista(delta)
	_audio.actualizar(delta, partida, _acelerando)


# --- mundo 3D con texturas pixeladas --------------------------------------------------

const TEX := "res://assets/texturas/"
## Tipos de fachada (cada cuadra dice el suyo según su zona, ciudad.fachada()).
const FACHADAS := ["casa", "ladrillo", "concreto", "vidrio", "bodega"]
const TINTES_CASA := [Color("9fc4a8"), Color("9db4d8"), Color("e6cf8a"), Color("e3a9a0"), Color("f2efe6"), Color("c9a6d6")]

var _mats_luz: Array[StandardMaterial3D] = []
const CALLE_DETALLES := preload("res://scripts/calle_detalles.gd")
var _detalles # huecos, aceite, perros, avisos y vallas (F4)
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
		por_tipo[f] = []
	for j in c.N_LARGO:
		for i in c.N_ANCHO:
			if not c.es_parque(i, j):
				por_tipo[c.fachada(i, j)].append(Vector2i(i, j))
	var edificios := Node3D.new()
	edificios.name = "Edificios"
	ciudad.add_child(edificios)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for tipo in FACHADAS:
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
	_construir_transito(ciudad)
	_construir_peatones()
	_construir_transeuntes()
	_construir_letreros()
	_construir_vehiculos()
	_construir_cerros()
	_detalles = CALLE_DETALLES.new()
	_mundo.add_child(_detalles)
	_detalles.preparar(partida, _mats_luz)

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


## Gente caminando por los andenes (de ambiente): los mismos dibujos de los peatones.
func _construir_transeuntes() -> void:
	var nodo := Node3D.new()
	nodo.name = "Transeuntes"
	_mundo.add_child(nodo)
	var hoja: Texture2D = load(TEX + "peatones.png")
	for k in partida.transeuntes.MAX:
		var sp := Sprite3D.new()
		sp.name = "Transeunte%d" % k
		sp.texture = hoja
		sp.hframes = 4
		sp.vframes = partida.peatones.ROPAS
		sp.pixel_size = PEATON_ALTO / 36.0
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = false
		sp.double_sided = true
		sp.visible = false
		nodo.add_child(sp)
		_transeuntes.append(sp)


func _actualizar_transeuntes() -> void:
	var gente: Array = partida.transeuntes.lista
	var derecha := _camara.global_transform.basis.x
	var luz: float = lerpf(0.35, 1.0, partida.reloj.luz())
	for k in _transeuntes.size():
		var sp := _transeuntes[k]
		sp.visible = k < gente.size()
		if not sp.visible:
			continue
		var p: Dictionary = gente[k]
		sp.position = Vector3(p.pos.x, ANDEN_ALTO + PEATON_PX * sp.pixel_size / 2.0, p.pos.y)
		sp.frame = (p.ropa % partida.peatones.ROPAS) * 4 + int(p.andado / 0.45) % 2
		var brillo := luz
		if _farola.visible:
			brillo = maxf(brillo, 0.95 * clampf(1.0 - p.pos.distance_to(partida.moto.pos) / 35.0, 0.0, 1.0))
		sp.modulate = Color(brillo, brillo, brillo)
		sp.flip_h = Vector3(p.dir.x, 0.0, p.dir.y).dot(derecha) < 0.0


const SEMAFORO_ALTO := 4.2   # m del piso al centro de la caja de luces
const COLORES_SEMAFORO := {"rojo": Color("ff3020"), "amarillo": Color("ffb020"), "verde": Color("40ff70")}


## Semáforos (poste, caja y tres luces) y señales (poste, placa gris atrás y la señal adelante).
func _construir_transito(padre: Node3D) -> void:
	var tr = partida.transito
	var sem: Array = tr.semaforos()
	var nodo := Node3D.new()
	nodo.name = "Transito"
	padre.add_child(nodo)
	var postes := _cajas("PostesSemaforo", sem.size(), _material(Color("5a5e66")))
	var cajas := _cajas("CajasSemaforo", sem.size(), _material(Color("1a1a1e")))
	var luces := {}
	for eje in ["x", "y"]:
		for color in COLORES_SEMAFORO:
			var m := _material(COLORES_SEMAFORO[color])
			m.emission_enabled = true
			m.emission = COLORES_SEMAFORO[color]
			_mats_semaforo["%s_%s" % [eje, color]] = m
			var n := 0
			for s_ in sem:
				if s_.eje == eje:
					n += 1
			luces["%s_%s" % [eje, color]] = _cajas("Luz_%s_%s" % [eje, color], n, m)
	var k_eje := {"x": 0, "y": 0}
	var alturas := {"rojo": 0.44, "amarillo": 0.0, "verde": -0.44}
	for k in sem.size():
		var s_: Dictionary = sem[k]
		var base := Vector3(s_.pos.x, ANDEN_ALTO, s_.pos.y)
		var d3 := Vector3(s_.dir.x, 0.0, s_.dir.y)
		postes.multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(0.2, SEMAFORO_ALTO + 0.6, 0.2)), base + Vector3(0, (SEMAFORO_ALTO + 0.6) / 2.0, 0)))
		postes.multimesh.set_instance_color(k, Color.WHITE)
		var caja := base + Vector3(0, SEMAFORO_ALTO, 0)
		cajas.multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(0.55, 1.4, 0.5)), caja))
		cajas.multimesh.set_instance_color(k, Color.WHITE)
		var i: int = k_eje[s_.eje]
		for color in alturas:
			# La luz asoma por la cara que mira al que llega (hacia -dir).
			# Delgada, pegada a la cara: de lado casi no se ve (no confunde al que cruza).
			var pos := caja - d3 * 0.27 + Vector3(0, alturas[color], 0)
			var mm: MultiMesh = luces["%s_%s" % [s_.eje, color]].multimesh
			mm.set_instance_transform(i, Transform3D(Basis.looking_at(d3, Vector3.UP).scaled_local(Vector3(0.36, 0.36, 0.05)), pos))
			mm.set_instance_color(i, Color.WHITE)
		k_eje[s_.eje] = i + 1
	nodo.add_child(postes)
	nodo.add_child(cajas)
	for l in luces.values():
		nodo.add_child(l)

	var senales: Array = tr.senales()
	var por_tipo := {}
	for s_ in senales:
		if not por_tipo.has(s_.tipo):
			por_tipo[s_.tipo] = []
		por_tipo[s_.tipo].append(s_)
	var palos := _cajas("PostesSenal", senales.size(), _material(Color("a0a2a8")))
	var reves := _cajas("RevesSenal", senales.size(), _material(Color("6a6c70")))
	var k_s := 0
	for tipo in por_tipo:
		var lista: Array = por_tipo[tipo]
		var m := _material(Color.WHITE)
		m.albedo_texture = load(TEX + "senal_%s.png" % tipo)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var placa := QuadMesh.new()
		placa.size = Vector2(0.9, 0.9)
		var caras := _cajas("Senal_%s" % tipo, lista.size(), m, placa)
		for k in lista.size():
			var s_: Dictionary = lista[k]
			var base := Vector3(s_.pos.x, ANDEN_ALTO, s_.pos.y)
			var d3 := Vector3(s_.dir.x, 0.0, s_.dir.y)
			var arriba := base + Vector3(0, 2.4, 0)
			# El QuadMesh mira a +Z: se gira para que mire al que llega (hacia -dir).
			caras.multimesh.set_instance_transform(k, Transform3D(Basis.looking_at(d3, Vector3.UP), arriba - d3 * 0.06))
			caras.multimesh.set_instance_color(k, Color.WHITE)
			palos.multimesh.set_instance_transform(k_s, Transform3D(Basis.from_scale(Vector3(0.1, 2.4, 0.1)), base + Vector3(0, 1.2, 0)))
			palos.multimesh.set_instance_color(k_s, Color.WHITE)
			reves.multimesh.set_instance_transform(k_s, Transform3D(Basis.looking_at(d3, Vector3.UP).scaled_local(Vector3(0.86, 0.86, 0.03)), arriba))
			reves.multimesh.set_instance_color(k_s, Color.WHITE)
			k_s += 1
		nodo.add_child(caras)
	nodo.add_child(palos)
	nodo.add_child(reves)


## Cada fotograma: prende la luz que toca en cada eje y apaga las otras (todas van sincronizadas).
func _actualizar_semaforos() -> void:
	for eje in ["x", "y"]:
		var prendida: String = partida.transito.luz(eje)
		for color in COLORES_SEMAFORO:
			var m: StandardMaterial3D = _mats_semaforo["%s_%s" % [eje, color]]
			var on: bool = color == prendida
			m.albedo_color = COLORES_SEMAFORO[color] if on else COLORES_SEMAFORO[color].darkened(0.8)
			m.emission_energy_multiplier = 2.5 if on else 0.0


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


# --- cerros orientales -------------------------------------------------------------

const CERROS_RADIO := 420.0     # m: una franja curva que sigue a la cámara (como un fondo de Doom)
const CERROS_ARCO := PI * 0.9   # rad que ocupa, centrado en el oriente (x negativa)
const CERROS_GRADOS_TEX := 140.0 # grados de horizonte que cubre el ancho de la textura (píxel casi cuadrado)
const CERROS_ABAJO := -2.0      # grados bajo el horizonte donde empieza (lo tapan la ciudad y la niebla)
const CERROS_ARRIBA := 21.0     # grados sobre el horizonte donde acaba la textura


## Los cerros quedan siempre al oriente, lejos: una banda curva sin niebla que se mueve con la
## cámara (no con su giro). La noche prende las casitas y la capilla (cerros_luz.png).
func _construir_cerros() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 48
	var y0 := CERROS_RADIO * tan(deg_to_rad(CERROS_ABAJO))
	var y1 := CERROS_RADIO * tan(deg_to_rad(CERROS_ARRIBA))
	for k in n:
		var a0 := PI - CERROS_ARCO / 2.0 + CERROS_ARCO * k / n
		var a1 := PI - CERROS_ARCO / 2.0 + CERROS_ARCO * (k + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0)) * CERROS_RADIO
		var p1 := Vector3(cos(a1), 0, sin(a1)) * CERROS_RADIO
		var u0 := rad_to_deg(a0) / CERROS_GRADOS_TEX
		var u1 := rad_to_deg(a1) / CERROS_GRADOS_TEX
		var q := [[p0 + Vector3(0, y1, 0), Vector2(u0, 0)], [p1 + Vector3(0, y1, 0), Vector2(u1, 0)], [p1 + Vector3(0, y0, 0), Vector2(u1, 1)],
			[p0 + Vector3(0, y1, 0), Vector2(u0, 0)], [p1 + Vector3(0, y0, 0), Vector2(u1, 1)], [p0 + Vector3(0, y0, 0), Vector2(u0, 1)]]
		for v in q:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var malla := st.commit()
	_mat_cerros = StandardMaterial3D.new()
	_mat_cerros.albedo_texture = load(TEX + "cerros.png")
	_mat_cerros.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat_cerros.texture_repeat = true
	_mat_cerros.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cerros.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat_cerros.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cerros.disable_fog = true
	_mat_cerros.render_priority = -10
	_mat_cerros_luz = _mat_cerros.duplicate()
	_mat_cerros_luz.albedo_texture = load(TEX + "cerros_luz.png")
	_mat_cerros_luz.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cerros_luz.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_cerros_luz.render_priority = -9
	_mat_cerros.next_pass = _mat_cerros_luz
	malla.surface_set_material(0, _mat_cerros)
	_cerros = MeshInstance3D.new()
	_cerros.name = "Cerros"
	_cerros.mesh = malla
	_cerros.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mundo.add_child(_cerros)


## Color de los cerros según la hora: azulados por la distancia de día, casi negros de noche,
## y con la lluvia se pierden en la bruma.
func _actualizar_cerros(luz: float, llueve: float, cielo: Color) -> void:
	_cerros.position = Vector3(_camara.position.x, 0.0, _camara.position.z)
	var tinte := Color(0.92, 0.96, 1.0).lerp(Color(0.16, 0.18, 0.28), 1.0 - luz)
	tinte = tinte.lerp(cielo, 0.55 * llueve)
	_mat_cerros.albedo_color = tinte
	var noche := clampf(1.0 - luz * 2.5, 0.0, 1.0) * (1.0 - 0.6 * llueve)
	_mat_cerros_luz.albedo_color = Color(noche, noche, noche)


# --- tráfico ------------------------------------------------------------------------

const VEHICULO_PX_M := 14.0 # px del dibujo por metro (tools/gen_vehiculos.py)


## Sprites de 8 direcciones a lo Doom: cada columna de la hoja es el vehículo girado 45° más.
func _construir_vehiculos() -> void:
	var nodo := Node3D.new()
	nodo.name = "Vehiculos"
	_mundo.add_child(nodo)
	for hoja in ["vehiculos", "vehiculos_grandes"]:
		_hojas_vehiculos[hoja] = load(TEX + hoja + ".png")
	for k in partida.trafico.MAX:
		var sp := Sprite3D.new()
		sp.name = "Vehiculo%d" % k
		sp.hframes = 8
		sp.pixel_size = 1.0 / VEHICULO_PX_M
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = false
		sp.double_sided = true
		sp.visible = false
		nodo.add_child(sp)
		_vehiculos.append(sp)


## Columna de la hoja según cómo se ve el vehículo desde la cámara: 0 de frente, 2 con el frente
## a la derecha de la pantalla, 4 de espaldas, 6 con el frente a la izquierda.
static func cuadro_vehiculo(camara: Vector2, pos: Vector2, rumbo_v: Vector2) -> int:
	var hacia := (pos - camara).normalized()
	var derecha := Vector2(-hacia.y, hacia.x)
	var phi := atan2(rumbo_v.dot(derecha), rumbo_v.dot(-hacia))
	return posmod(roundi(phi / (PI / 4.0)), 8)


func _actualizar_vehiculos() -> void:
	var lista: Array = partida.trafico.lista
	var cam := Vector2(_camara.global_position.x, _camara.global_position.z)
	var luz: float = lerpf(0.35, 1.0, partida.reloj.luz())
	for k in _vehiculos.size():
		var sp := _vehiculos[k]
		sp.visible = k < lista.size()
		if not sp.visible:
			continue
		var v: Dictionary = lista[k]
		var datos: Dictionary = partida.trafico.TIPOS[v.tipo]
		var hoja: Texture2D = _hojas_vehiculos[datos.hoja]
		if sp.texture != hoja:
			sp.texture = hoja
			sp.vframes = 3 if datos.hoja == "vehiculos" else 2
		sp.frame = datos.fila * 8 + cuadro_vehiculo(cam, v.pos, v.dir)
		var alto_px: float = hoja.get_height() / float(sp.vframes)
		sp.position = Vector3(v.pos.x, (alto_px / 2.0 - 1.0) * sp.pixel_size, v.pos.y)
		var brillo := luz
		if _farola.visible:
			brillo = maxf(brillo, 0.95 * clampf(1.0 - v.pos.distance_to(partida.moto.pos) / 40.0, 0.0, 1.0))
		sp.modulate = Color(brillo, brillo, brillo)


# --- placas de nomenclatura -----------------------------------------------------------

const LETREROS_RADIO := 2          # cruces a cada lado de la moto con placa (5 × 5)
const PLACA_ALTO := [2.9, 2.5]    # m: la placa de la calle arriba, la de la carrera abajo
const C_PLACA := Color("f2efe6")   # placa blanca con letras negras
const C_PLACA_AV := Color("1f7a3a") # avenidas: placa verde con letras blancas


## Un poste con dos placas (calle y carrera) en una esquina de cada cruce cercano. Se reusan: cuando
## la moto cambia de cruce, se mueven y cambian de texto.
func _construir_letreros() -> void:
	var nodo := Node3D.new()
	nodo.name = "Letreros"
	_mundo.add_child(nodo)
	var fuente: Font = load("res://assets/fuentes/DeliveryPress-Regular.ttf")
	var m_poste := _material(Color("5c5f66"))
	for mat_color in [C_PLACA, C_PLACA_AV]:
		_mats_placa.append(_material(mat_color))
	var lado := (LETREROS_RADIO * 2 + 1)
	for k in lado * lado:
		var poste := Node3D.new()
		poste.name = "Poste%d" % k
		nodo.add_child(poste)
		var palo := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.1, 3.1, 0.1)
		b.material = m_poste
		palo.mesh = b
		palo.position.y = 3.1 / 2.0
		poste.add_child(palo)
		for q in 2: # 0: placa de la calle (se lee yendo por la carrera), 1: la de la carrera
			var placa := MeshInstance3D.new()
			placa.name = "Placa%d" % q
			placa.mesh = BoxMesh.new()
			placa.position.y = PLACA_ALTO[q]
			poste.add_child(placa)
			for cara in 2: # un letrero por cada cara, para que se lea de los dos lados
				var l := Label3D.new()
				l.name = "Texto%d" % cara
				l.font = fuente
				l.font_size = 8
				l.outline_size = 0
				l.pixel_size = 0.035
				l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				l.shaded = false
				l.double_sided = false
				l.position = Vector3(0, 0, 0.051 if cara == 0 else -0.051)
				l.rotation.y = 0.0 if cara == 0 else PI
				placa.add_child(l)
		_letreros.append(poste)


func _actualizar_letreros() -> void:
	var c = partida.ciudad
	var p: Vector2 = partida.moto.pos
	var centro := Vector2i(c._via_cercana(c.inicio_x, c.anchos, p.x), c._via_cercana(c.inicio_y, c.largos, p.y))
	var luz: float = lerpf(0.4, 1.0, partida.reloj.luz())
	for m in _mats_placa:
		m.albedo_color = (C_PLACA if m == _mats_placa[0] else C_PLACA_AV) * Color(luz, luz, luz)
	if centro == _cruce_letreros:
		return
	_cruce_letreros = centro
	var lado := LETREROS_RADIO * 2 + 1
	for k in _letreros.size():
		var i := centro.x + k % lado - LETREROS_RADIO
		var j := centro.y + k / lado - LETREROS_RADIO
		var poste := _letreros[k]
		poste.visible = i >= 0 and j >= 0 and i <= c.N_ANCHO and j <= c.N_LARGO
		if not poste.visible:
			continue
		# En la esquina de la cuadra (i, j), o de la (i-1, j-1) en el borde; lejos del poste del semáforo.
		var s := Vector2(1, 1) if i < c.N_ANCHO and j < c.N_LARGO else Vector2(-1, -1)
		var esq: Vector2 = c.cruce(i, j) + s * (c.CALLE / 2.0 + 0.6)
		poste.position = Vector3(esq.x, ANDEN_ALTO, esq.y)
		for q in 2:
			var tipo := "calle" if q == 0 else "carrera"
			var texto: String = c.nombre_via(tipo, j if q == 0 else i)
			var av: bool = c.es_avenida(tipo, j if q == 0 else i)
			var placa: MeshInstance3D = poste.get_node("Placa%d" % q)
			var ancho := texto.length() * 8 * 0.035 + 0.24
			(placa.mesh as BoxMesh).size = Vector3(ancho, 0.38, 0.1)
			(placa.mesh as BoxMesh).material = _mats_placa[1 if av else 0]
			# La placa de la calle va a lo largo de la calle (x): se lee de frente yendo por la carrera.
			placa.rotation.y = 0.0 if q == 0 else PI / 2.0
			placa.position.x = (ancho / 2.0 - 0.05) * (1.0 if q == 0 else 0.0) * s.x
			placa.position.z = (ancho / 2.0 - 0.05) * (1.0 if q == 1 else 0.0) * s.y
			for cara in 2:
				var l: Label3D = placa.get_node("Texto%d" % cara)
				l.text = texto
				l.modulate = Color.WHITE if av else Color("15151a")


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
	_etiqueta(Vector2(338, 344), tr("TIEMPO"))
	# Alineada a la derecha, pegada a «PLATA»: crece hacia la izquierda con cifras largas.
	_l_cuenta = _texto(Vector2(PLATA_ETIQUETA_X - 8 - 200, 339), 16, "Plata")
	_l_cuenta.size = Vector2(200, 22)
	_l_cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_l_cuenta.add_theme_color_override("font_color", C_ROJO)
	_etiqueta(Vector2(PLATA_ETIQUETA_X, 344), tr("PLATA"))

	var mini: Control = MINIMAPA.new()
	mini.name = "Minimapa"
	mini.partida = partida
	mini.position = Vector2(502, 8)
	mini.size = Vector2(130, 130)
	hud.add_child(mini)
	_l_hora = _texto(Vector2(502, 142), 8, "Hora")
	# Por dónde va (la vía y la cruzada más cercana) y en qué zona, bajo la hora.
	_l_ubicacion = _texto(Vector2(502, 154), 8, "Ubicacion")
	_l_ubicacion.add_theme_color_override("font_color", Color("c8d8ff"))

	_l_pedido = _texto(Vector2(8, 8), 8, "Pedido")
	_l_pedido.add_theme_stylebox_override("normal", _fondo())
	# Racha de fe (casi-choques seguidos), debajo del pedido.
	_l_racha = _texto(Vector2(8, 60), 8, "Racha")
	_l_racha.add_theme_color_override("font_color", Color("f0c040"))
	_l_racha.add_theme_stylebox_override("normal", _fondo())
	_l_racha.visible = false
	# Calificación del cliente al entregar, al centro sobre los subtítulos.
	_l_estrellas = _texto(Vector2(0, 286), 8, "Estrellas")
	_l_estrellas.add_theme_color_override("font_color", Color("ffd84a"))
	_l_estrellas.add_theme_stylebox_override("normal", _fondo())
	_l_estrellas.visible = false
	# Aviso de derrape pequeño y en la esquina, encima de la velocidad (no tapa la calle).
	_l_derrape = _texto(Vector2(8, 314), 8, "Derrape")
	_l_derrape.text = tr("¡SE VA DE LADO!")
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
	_l_bono.text = tr("LLUVIA: +%d%% POR PEDIDO") % roundi(partida.clima.BONO * 100.0)
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

	# La ilustración de la caída (tools/gen_cinematica.py): encima de todo, se prende al estrellarse.
	_ilustracion = TextureRect.new()
	_ilustracion.name = "Cinematica"
	_ilustracion.texture = load("res://assets/ui/cinematica_%s.png" % partida.moto.moto.id)
	_ilustracion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ilustracion.stretch_mode = TextureRect.STRETCH_SCALE
	_ilustracion.size = Vector2(640, 360)
	_ilustracion.pivot_offset = Vector2(320, 190)
	_ilustracion.visible = false
	hud.add_child(_ilustracion)

	_mapa = MAPA.new()
	_mapa.name = "Mapa"
	_mapa.partida = partida
	_mapa.size = Vector2(640, 360)
	_mapa.visible = false
	hud.add_child(_mapa)


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
		_camara.rotation = Vector3(-MIRADA_ABAJO, -m.rumbo - PI / 2.0, -_giro_visual * 0.07)

	_actualizar_cielo(delta)

	var p: Dictionary = partida.pedido
	var recoger: bool = partida.fase == partida.RECOGER
	_faro_rest.visible = recoger
	_faro_cli.visible = not recoger
	_faro_rest.position = Vector3(p.restaurante.x, 30, p.restaurante.y)
	_faro_cli.position = Vector3(p.cliente.x, 30, p.cliente.y)

	_manubrio.giro = _giro_visual
	_manubrio.vel_kmh = m.vel_kmh()
	_manubrio.rpm = _audio.motor.revoluciones()
	_manubrio.cambio = int(_audio.motor.cambio) if int(m.moto.get("cambios", 0)) > 0 else 0
	_l_vel.text = "%3d" % m.vel_kmh()
	var s := int(ceil(maxf(partida.tiempo_restante, 0.0)))
	_l_reloj.text = "%d:%02d" % [s / 60, s % 60]
	_l_reloj.modulate.a = 0.35 if s <= 15 and int(Time.get_ticks_msec() / 250) % 2 == 0 else 1.0
	_l_cuenta.text = PROGRESO.pesos(progreso.dinero if progreso != null else partida.ganado)
	_l_ubicacion.text = "%s\n%s" % [partida.ciudad.ubicacion(m.pos), partida.ciudad.nombre_zona(partida.ciudad.zona_en(m.pos)).to_upper()]
	_l_hora.text = (tr("DIA") if partida.reloj.luz() > 0.25 else tr("NOCHE")) + " " + partida.reloj.texto_hora()
	var tipo: Dictionary = partida.TIPOS_PEDIDO[p.tipo]
	# Idioma (localization/textos.csv): el plato, el aviso y algunos clientes se traducen al mostrarlos.
	if recoger:
		_l_pedido.text = tr("RECOGE: %s\n%s\nSigue la columna naranja") % [tr(p.plato).to_upper(), tr(tipo.aviso)]
	else:
		_l_pedido.text = tr("ENTREGA: %s A %s\n%s\n%s") % [tr(p.plato).to_upper(), tr(str(p.nombre_cliente)).to_upper(), p.direccion, tr(tipo.aviso)]
		if float(tipo.fragil) > 0.0:
			_l_pedido.text += "\n" + tr("ESTADO: %d%%") % roundi(partida.estado_pedido * 100.0)
	_l_racha.visible = partida.racha > 0 and not partida.terminada
	_l_racha.text = tr("FE x%d  +%d%% PROPINA") % [partida.racha, roundi(partida.RACHA_BONO * 100.0 * partida.racha)]
	_l_racha.position.y = _l_pedido.position.y + _l_pedido.get_minimum_size().y + 4.0
	_t_estrellas = maxf(_t_estrellas - delta, 0.0)
	_l_estrellas.visible = _t_estrellas > 0.0 and not partida.terminada
	_l_derrape.visible = m.derrapando and not partida.terminada
	var cuenta: float = m.cuenta_motor()
	if m.motor_fundido:
		_l_motor.text = tr("MOTOR FUNDIDO: espera %d") % ceili(maxf(m.espera_reparacion(), 0.0))
	elif cuenta >= 0.0:
		_l_motor.text = tr("¡VAS A FUNDIR EL MOTOR! %d") % ceili(cuenta)
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
	_actualizar_transeuntes()
	_actualizar_semaforos()
	_actualizar_letreros()
	_actualizar_vehiculos()
	_detalles.actualizar(delta, Vector2(_camara.global_position.x, _camara.global_position.z), _camara.global_transform.basis.x,
		partida.reloj.luz(), _farola.visible)
	if partida.multado:
		_l_pedido.text += "\n" + tr("SIN PROPINA: atropellaste a alguien")

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
	_actualizar_cerros(luz, llueve, cielo)


## El cliente califica: estrellas y su comentario, un rato en pantalla.
func _al_calificar(estrellas: int, comentario: String) -> void:
	_l_estrellas.text = "%s%s  «%s»" % ["★".repeat(estrellas), "☆".repeat(5 - estrellas), comentario]
	_l_estrellas.size = Vector2.ZERO
	_l_estrellas.position.x = roundf((640.0 - _l_estrellas.get_minimum_size().x) / 2.0)
	_t_estrellas = ESTRELLAS_S


## El pedido final entregado: se acaba el juego (se puede seguir jugando después).
func _al_final(mensaje: String) -> void:
	if progreso != null:
		progreso.marcar_final()
	for hijo in $HUD.get_children():
		hijo.visible = hijo == _subtitulo and _subtitulo.visible
	if retraso_resultado > 0.0:
		await get_tree().create_timer(retraso_resultado, false).timeout
	if is_inside_tree():
		terminado.emit("final", mensaje)


func _al_evento(nombre: String) -> void:
	_audio.al_evento(nombre)
	var texto: String = voces.frase(nombre)
	if texto == "":
		return
	_subtitulo.text = texto
	_subtitulo.visible = true
	_t_subtitulo = SUBTITULO_S


# --- la caída ----------------------------------------------------------------------

func _al_estrellarse(mensaje: String) -> void:
	_cinematica = true
	var m = partida.moto
	# Solo queda el subtítulo, abajo, para que no tape la escena.
	for hijo in $HUD.get_children():
		hijo.visible = hijo == _subtitulo and _subtitulo.visible
	# Primero la cámara sale a ver la moto en 3D; luego, el dibujo de la caída con un zoom lento.
	# Cada causa tiene su dibujo (hueco, perro, lluvia, bus, contravía); la curva usa el de siempre.
	var dibujo := "res://assets/ui/cinematica_%s_%s.png" % [partida.causa, m.moto.id]
	if partida.causa != "curva" and ResourceLoader.exists(dibujo):
		_ilustracion.texture = load(dibujo)
	_ilustracion.visible = true
	_ilustracion.move_to_front()
	_ilustracion.modulate.a = 0.0
	_ilustracion.scale = Vector2.ONE
	var tw_i := create_tween()
	tw_i.tween_interval(ILUSTRACION_TRAS if retraso_resultado > 0.0 else 0.0)
	tw_i.tween_property(_ilustracion, "modulate:a", 1.0, ILUSTRACION_FUNDIDO)
	tw_i.tween_property(_ilustracion, "scale", Vector2.ONE * ILUSTRACION_ZOOM, maxf(retraso_resultado - ILUSTRACION_TRAS, 0.1))
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
	var cierre := tr("Ni un pedido entregado. La app ya te está buscando reemplazo.")
	if partida.entregados > 0:
		cierre = tr("Entregaste %d pedidos: +%s, y esa plata no se pierde.") % [partida.entregados, PROGRESO.pesos(partida.ganado)]
	var final_msg := "%s\n\n%s" % [mensaje, cierre]
	ilustracion_final = _ilustracion.texture
	if retraso_resultado <= 0.0:
		terminado.emit("estrellado", final_msg)
		return
	await get_tree().create_timer(retraso_resultado, false).timeout
	if is_inside_tree():
		terminado.emit("estrellado", final_msg)


# --- precalentado (pantalla de carga) -------------------------------------------------

func _precalentar(delta: float) -> void:
	_t_carga += delta
	if _paso_carga < PASOS_PRECALENTADO:
		_poner_paso_precalentado(_paso_carga)
		_cuadro_paso += 1
		if _cuadro_paso >= CUADROS_POR_PASO:
			_cuadro_paso = 0
			_paso_carga += 1
			if _paso_carga == PASOS_PRECALENTADO:
				_quitar_muestras()
	else:
		_estables = _estables + 1 if delta < CUADRO_RAPIDO_S else 0
	_carga.poner_avance(0.85 * _paso_carga / float(PASOS_PRECALENTADO) + 0.15 * _estables / float(CUADROS_ESTABLES))
	var listo := _paso_carga >= PASOS_PRECALENTADO and _estables >= CUADROS_ESTABLES
	if listo or _t_carga >= CARGA_MAX_S:
		_terminar_carga()


## Un paso: la vista de la partida girada a una de las cuatro direcciones, con una combinación de
## luces, y una muestra de todo lo que aparece después, delante de la cámara.
func _poner_paso_precalentado(i: int) -> void:
	_actualizar_vista(0.0)
	var luces: Array = LUCES_PRECALENTADO[i / VISTAS_PRECALENTADO]
	_sol.visible = luces[0]
	_sol.light_energy = maxf(_sol.light_energy, 0.5)
	_farola.visible = luces[1]
	_camara.rotation.y += TAU * (i % VISTAS_PRECALENTADO) / VISTAS_PRECALENTADO
	var base := _camara.global_transform
	var frente := -base.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var lado := Vector3(-frente.z, 0.0, frente.x)
	var suelo := Vector3(base.origin.x, 0.0, base.origin.z)
	_moto_caida.visible = true
	_moto_caida.position = suelo + frente * 6.0
	var muestras: Array[Sprite3D] = []
	for pool in [_peatones, _transeuntes, _vehiculos, _detalles.muestras_precalentado()]:
		if pool.size() > 0:
			muestras.append(pool[0])
	for k in muestras.size():
		var sp: Sprite3D = muestras[k]
		if sp.texture == null and not _hojas_vehiculos.is_empty():
			sp.texture = _hojas_vehiculos.values()[0]
		sp.visible = true
		sp.position = suelo + frente * 9.0 + lado * (k - 1.5) * 2.0 + Vector3(0, 1.0, 0)
	var mm := _charcos.multimesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(1.5, 1.0, 1.2)), suelo + frente * 5.0 + Vector3(0, 0.012, 0)))
	mm.set_instance_color(0, Color.WHITE)


func _quitar_muestras() -> void:
	_moto_caida.visible = false
	_charcos.multimesh.instance_count = 0
	_version_charcos = -1 # que los charcos de verdad se vuelvan a poner
	_actualizar_vista(0.0) # y todo lo demás, como va en la partida


func _terminar_carga() -> void:
	cargando = false
	if _paso_carga < PASOS_PRECALENTADO:
		_quitar_muestras()
	if _carga != null:
		_carga.visible = false
		_carga.get_parent().queue_free()
		_carga = null
