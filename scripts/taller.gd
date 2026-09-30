extends Control
## Taller: comprar el exosto y el motor de la moto actual, o la moto siguiente.

signal volver

const UI := preload("res://scripts/ui.gd")
const MOTOS := preload("res://scripts/motos.gd")
const PROGRESO := preload("res://scripts/progreso.gd")

var progreso
var _botones := {}
var _l_moto: Label
var _l_datos: Label
var _l_plata: Label


func _ready() -> void:
	UI.fondo(self)
	UI.texto(self, "TALLER", Vector2(0, 24), 24, UI.C_ROJO, 640.0, "Titulo")
	_l_moto = UI.texto(self, "", Vector2(0, 66), 16, UI.C_TEXTO, 640.0, "Moto")
	_l_datos = UI.texto(self, "", Vector2(0, 92), 8, UI.C_GRIS, 640.0, "Datos")
	_l_plata = UI.texto(self, "", Vector2(0, 112), 16, UI.C_AMARILLO, 640.0, "Plata")
	var col := UI.columna(self, Vector2(120, 150), 400.0)
	for mej in MOTOS.MEJORAS:
		var b := UI.boton(col, "", "Mejora_" + mej)
		b.pressed.connect(_comprar_mejora.bind(mej))
		_botones[mej] = b
	var b_moto := UI.boton(col, "", "ComprarMoto")
	b_moto.pressed.connect(_comprar_moto)
	_botones["moto"] = b_moto
	var b_volver := UI.boton(col, "VOLVER", "Volver")
	b_volver.pressed.connect(func(): volver.emit())
	UI.texto(self, "Morir no quita la plata.", Vector2(0, 312), 8, UI.C_GRIS, 640.0)
	UI.texto(self, "Con todas las mejoras, sigue siendo peor que la siguiente moto.", Vector2(0, 326), 8, UI.C_GRIS, 640.0)
	actualizar()
	b_volver.grab_focus.call_deferred()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		volver.emit()


func actualizar() -> void:
	if progreso == null:
		return
	var m: Dictionary = progreso.datos_moto()
	_l_moto.text = m.nombre
	_l_datos.text = "Velocidad máxima %d km/h   Aceleración %.1f" % [roundi(float(m.vel_max) * 3.6), float(m.acel)]
	_l_plata.text = PROGRESO.pesos(progreso.dinero)
	for mej in MOTOS.MEJORAS:
		var b: Button = _botones[mej]
		var nombre: String = MOTOS.NOMBRE_MEJORA[mej].to_upper()
		if progreso.tiene_mejora(mej):
			b.text = "%s  (ya instalado)" % nombre
		else:
			b.text = "%s  %s" % [nombre, PROGRESO.pesos(progreso.precio_mejora(mej))]
		b.disabled = not progreso.puede_mejorar(mej)
	var sig: String = progreso.siguiente_moto()
	var bm: Button = _botones["moto"]
	if sig == "":
		bm.text = "YA TIENES LA ÚLTIMA MOTO"
		bm.disabled = true
	else:
		var nueva := MOTOS.get_moto(sig)
		bm.text = "COMPRAR %s  %s" % [str(nueva.nombre).to_upper(), PROGRESO.pesos(int(nueva.precio))]
		bm.disabled = not progreso.puede_comprar_moto()


func _comprar_mejora(nombre: String) -> void:
	progreso.comprar_mejora(nombre)
	actualizar()


func _comprar_moto() -> void:
	progreso.comprar_moto()
	actualizar()
