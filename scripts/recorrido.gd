extends Control
## Pantalla de juego, en gris y estilo Doom: el mundo se dibuja a 320×180 y se escala entero;
## encima va el manubrio de la BWS, el minimapa y el HUD a 640×360.
## Solo dibuja la partida y le pasa los mandos; la lógica vive en partida.gd.

signal terminado(estado: String, mensaje: String)
signal reintentar

const PARTIDA := preload("res://scripts/partida.gd")
const VOCES := preload("res://scripts/voces.gd")
const MANUBRIO := preload("res://scripts/manubrio.gd")
const MINIMAPA := preload("res://scripts/minimapa.gd")

const ALTURA_OJOS := 1.35
const ANDEN_ALTO := 0.2
const SUBTITULO_S := 3.5

const C_ASFALTO := Color("3a3a3c")
const C_ANDEN := Color("8a8a86")
const C_PARQUE := Color("46603f")
const C_TEXTO := Color("e8e8e8")

var partida = PARTIDA.new(20260929)
var voces = VOCES.new(1)
var retraso_resultado := 2.2

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
var _subtitulo: Label
var _voz: AudioStreamPlayer
var _t_subtitulo := 0.0
var _giro_visual := 0.0
var _cinematica := false


func _ready() -> void:
	_construir_mundo()
	_construir_hud()
	partida.evento.connect(_al_evento)
	partida.terminada_por.connect(_al_estrellarse)
	_actualizar_vista(0.0)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("continuar"):
		reintentar.emit()
		return
	if not partida.terminada:
		var giro := Input.get_action_strength("derecha") - Input.get_action_strength("izquierda")
		_giro_visual = lerpf(_giro_visual, giro, minf(delta * 8.0, 1.0))
		partida.advance(delta, Input.is_action_pressed("acelerar"), Input.is_action_pressed("frenar"), giro)
	_actualizar_vista(delta)


# --- mundo 3D gris -----------------------------------------------------------------

func _material(color: Color, por_instancia := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = por_instancia
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _cajas(nombre: String, n: int, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var caja := BoxMesh.new()
	caja.material = material
	mm.mesh = caja
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
	_entorno.background_mode = Environment.BG_COLOR
	_entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_entorno.fog_enabled = true
	_entorno.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = _entorno
	_mundo.add_child(we)

	_sol = DirectionalLight3D.new()
	_sol.name = "Sol"
	_sol.rotation = Vector3(deg_to_rad(-55), deg_to_rad(30), 0)
	_mundo.add_child(_sol)

	var c = partida.ciudad
	var tam: Vector2 = c.tamano()
	var ciudad := Node3D.new()
	ciudad.name = "Ciudad"
	_mundo.add_child(ciudad)
	_caja(ciudad, Vector3(tam.x, 0.1, tam.y), Vector3(tam.x / 2.0, -0.05, tam.y / 2.0), C_ASFALTO, "Asfalto")

	var n: int = c.N_ANCHO * c.N_LARGO
	var andenes := _cajas("Andenes", n, _material(Color.WHITE, true))
	var edificios := _cajas("Edificios", n - c.parques.size(), _material(Color.WHITE, true))
	var parques := _cajas("Parques", c.parques.size(), _material(Color.WHITE, true))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var k_a := 0
	var k_e := 0
	var k_p := 0
	for j in c.N_LARGO:
		for i in c.N_ANCHO:
			var r: Rect2 = c.cuadra(i, j)
			var centro := Vector3(r.get_center().x, 0.0, r.get_center().y)
			andenes.multimesh.set_instance_transform(k_a, Transform3D(Basis.from_scale(Vector3(r.size.x, ANDEN_ALTO, r.size.y)), centro + Vector3(0, ANDEN_ALTO / 2.0, 0)))
			andenes.multimesh.set_instance_color(k_a, C_ANDEN)
			k_a += 1
			var dentro := Vector3(r.size.x - 2.0 * c.ANDEN, 0.0, r.size.y - 2.0 * c.ANDEN)
			if c.es_parque(i, j):
				parques.multimesh.set_instance_transform(k_p, Transform3D(Basis.from_scale(Vector3(dentro.x, 0.1, dentro.z)), centro + Vector3(0, ANDEN_ALTO + 0.05, 0)))
				parques.multimesh.set_instance_color(k_p, C_PARQUE)
				k_p += 1
			else:
				var h: float = c.altura(i, j)
				edificios.multimesh.set_instance_transform(k_e, Transform3D(Basis.from_scale(Vector3(dentro.x, h, dentro.z)), centro + Vector3(0, h / 2.0, 0)))
				var gris := rng.randf_range(0.35, 0.7)
				edificios.multimesh.set_instance_color(k_e, Color(gris, gris, gris * rng.randf_range(0.95, 1.05)))
				k_e += 1
	ciudad.add_child(andenes)
	ciudad.add_child(edificios)
	ciudad.add_child(parques)

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
	_camara.far = 350.0
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


## La BWS en bloques para la cinemática: se ve desde fuera solo cuando se cae.
func _construir_moto_caida() -> Node3D:
	var moto := Node3D.new()
	moto.name = "MotoCaida"
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"
	moto.add_child(cuerpo)
	_caja(cuerpo, Vector3(0.5, 0.5, 0.25), Vector3(-0.6, 0.25, 0), Color("2b2b2b"))  # llanta trasera gorda
	_caja(cuerpo, Vector3(0.5, 0.5, 0.25), Vector3(0.65, 0.25, 0), Color("2b2b2b"))  # llanta delantera
	_caja(cuerpo, Vector3(1.4, 0.25, 0.5), Vector3(0, 0.45, 0), Color("c8c8c8"))     # piso
	_caja(cuerpo, Vector3(0.6, 0.4, 0.5), Vector3(-0.45, 0.75, 0), Color("c8c8c8"))  # cola y sillín
	_caja(cuerpo, Vector3(0.25, 0.7, 0.55), Vector3(0.6, 0.8, 0), Color("c8c8c8"))  # escudo
	_caja(cuerpo, Vector3(0.1, 0.1, 0.9), Vector3(0.55, 1.2, 0), Color("8c8c8c"))    # manubrio
	var piloto := Node3D.new()
	piloto.name = "Piloto"
	moto.add_child(piloto)
	_caja(piloto, Vector3(1.0, 0.3, 0.45), Vector3(0, 0.15, 0), Color("6a6a6a"))     # cuerpo tendido
	_caja(piloto, Vector3(0.35, 0.35, 0.35), Vector3(0.7, 0.18, 0), Color("eeeeee")) # casco
	_caja(piloto, Vector3(0.5, 0.5, 0.5), Vector3(-0.3, 0.5, 0.35), Color("c8742c")) # caja del domicilio
	_caja(piloto, Vector3(1.4, 0.02, 1.0), Vector3(0.3, 0.01, 0), Color("8c1010"), "Charco")
	return moto


# --- HUD --------------------------------------------------------------------------

func _texto(pos: Vector2, tam: int, nombre: String, ancho := 0.0) -> Label:
	var l := Label.new()
	l.name = nombre
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", C_TEXTO)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	if ancho > 0.0:
		l.size = Vector2(ancho, tam + 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$HUD.add_child(l)
	return l


func _construir_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	_manubrio = MANUBRIO.new()
	_manubrio.name = "Manubrio"
	_manubrio.size = Vector2(640, 360)
	_manubrio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_manubrio)

	var mini: Control = MINIMAPA.new()
	mini.name = "Minimapa"
	mini.partida = partida
	mini.position = Vector2(500, 36)
	mini.size = Vector2(130, 130)
	hud.add_child(mini)

	_l_vel = _texto(Vector2(10, 6), 22, "Velocidad")
	_l_pedido = _texto(Vector2(10, 36), 10, "Pedido")
	_l_cuenta = _texto(Vector2(10, 52), 10, "Cuenta")
	_l_reloj = _texto(Vector2(0, 6), 22, "Reloj", 640.0)
	_l_hora = _texto(Vector2(500, 8), 14, "Hora")
	_l_derrape = _texto(Vector2(0, 90), 18, "Derrape", 640.0)
	_l_derrape.add_theme_color_override("font_color", Color("ff5050"))

	# Subtítulos con su propia franja de fondo, para que se lean sobre la calle en movimiento.
	_subtitulo = _texto(Vector2(40, 196), 14, "Subtitulo", 560.0)
	_subtitulo.size = Vector2(560, 24)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.7)
	fondo.content_margin_left = 8
	fondo.content_margin_right = 8
	_subtitulo.add_theme_stylebox_override("normal", fondo)
	_subtitulo.visible = false

	_voz = AudioStreamPlayer.new()
	_voz.name = "Voz"
	add_child(_voz)


# --- dibujar la partida -------------------------------------------------------------

func _actualizar_vista(delta: float) -> void:
	var m = partida.moto
	if not _cinematica:
		var cabeceo := sin(Time.get_ticks_msec() / 90.0) * 0.015 * clampf(m.vel / 25.0, 0.0, 1.0)
		_camara.position = Vector3(m.pos.x, ALTURA_OJOS + cabeceo, m.pos.y)
		_camara.rotation = Vector3(0.0, -m.rumbo - PI / 2.0, -_giro_visual * 0.07)

	var ciclo = partida.reloj
	var cielo: Color = ciclo.color_cielo()
	var luz: float = ciclo.luz()
	_entorno.background_color = cielo
	_entorno.fog_light_color = cielo
	_entorno.ambient_light_color = Color("5a6478").lerp(Color("b8b8b8"), luz)
	_entorno.ambient_light_energy = lerpf(0.35, 0.8, luz)
	_sol.light_energy = luz * 0.9
	_farola.visible = ciclo.farola_encendida()
	_farola.light_energy = 2.5

	var p: Dictionary = partida.pedido
	var recoger: bool = partida.fase == partida.RECOGER
	_faro_rest.visible = recoger
	_faro_cli.visible = not recoger
	_faro_rest.position = Vector3(p.restaurante.x, 30, p.restaurante.y)
	_faro_cli.position = Vector3(p.cliente.x, 30, p.cliente.y)

	_manubrio.giro = _giro_visual
	_manubrio.vel_kmh = m.vel_kmh()
	_l_vel.text = "%d km/h" % m.vel_kmh()
	var s := int(ceil(maxf(partida.tiempo_restante, 0.0)))
	_l_reloj.text = "%d:%02d" % [s / 60, s % 60]
	_l_reloj.add_theme_color_override("font_color", Color("ff5050") if s <= 15 else C_TEXTO)
	_l_hora.text = ("☀ " if luz > 0.25 else "☾ ") + ciclo.texto_hora()
	if recoger:
		_l_pedido.text = "Recoge: %s (sigue la columna naranja)" % p.plato
	else:
		_l_pedido.text = "Entrega: %s en %s" % [p.plato, p.direccion]
	_l_cuenta.text = "Entregados: %d   Cancelados: %d" % [partida.entregados, partida.cancelados]
	_l_derrape.text = "¡SE VA DE LADO!" if m.derrapando and not partida.terminada else ""

	_t_subtitulo = maxf(_t_subtitulo - delta, 0.0)
	_subtitulo.visible = _t_subtitulo > 0.0


func _al_evento(nombre: String) -> void:
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
	var dir: Vector2 = m.direccion()
	# Solo queda el subtítulo, abajo, para que no tape la escena.
	for hijo in $HUD.get_children():
		hijo.visible = hijo == _subtitulo and _subtitulo.visible
	_subtitulo.position.y = 310
	# Moto de lado en el andén y el piloto unos metros adelante.
	_moto_caida.visible = true
	_moto_caida.position = Vector3(m.pos.x, ANDEN_ALTO, m.pos.y)
	_moto_caida.rotation = Vector3(0.0, -m.rumbo, 0.0)
	var cuerpo: Node3D = _moto_caida.get_node("Cuerpo")
	cuerpo.rotation = Vector3(deg_to_rad(80), 0, 0)
	var piloto: Node3D = _moto_caida.get_node("Piloto")
	piloto.position = Vector3(3.0, 0.0, 0.8)
	# Cámara a tercera persona, mirando la escena.
	var desde: Vector2 = m.pos - dir * 3.5 + dir.orthogonal() * 2.5
	_camara.rotation.z = 0.0
	var tw := create_tween()
	tw.tween_property(_camara, "position", Vector3(desde.x, 1.8, desde.y), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(_x): _camara.look_at(Vector3(m.pos.x, 0.5, m.pos.y) + Vector3(dir.x, 0, dir.y) * 1.5), 0.0, 1.0, 0.5)
	var final_msg := "%s\nEntregaste %d pedidos antes de irte." % [mensaje, partida.entregados]
	if retraso_resultado <= 0.0:
		terminado.emit("estrellado", final_msg)
		return
	await get_tree().create_timer(retraso_resultado).timeout
	if is_inside_tree():
		terminado.emit("estrellado", final_msg)
