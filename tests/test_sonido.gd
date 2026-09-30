extends RefCounted
## El sonido: el motor sube de tono con la velocidad, los bucles son bucles y cada evento suena.

const SONIDO_MOTOR := preload("res://scripts/sonido_motor.gd")
const MOTOS := preload("res://scripts/motos.gd")
const AUDIO := preload("res://scripts/audio.gd")

const BUCLES := ["motor_bws", "motor_nkd", "motor_ninja", "ambiente_dia", "ambiente_noche", "viento", "lluvia"]
const EFECTOS := ["choque", "golpe", "casi", "fundido", "entregado", "recogido", "reparado", "charco"]


func run(t) -> void:
	for n in BUCLES:
		var s: AudioStreamWAV = load("res://assets/sonidos/%s.wav" % n)
		t.check(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s suena en bucle" % n)
	for n in EFECTOS:
		var s: AudioStreamWAV = load("res://assets/sonidos/%s.wav" % n)
		t.check(s != null and s.loop_mode == AudioStreamWAV.LOOP_DISABLED and s.get_length() < 2.5, "%s es un efecto corto" % n)

	for id in MOTOS.ORDEN:
		var datos: Dictionary = MOTOS.get_moto(id)
		t.check(ResourceLoader.exists("res://assets/sonidos/motor_%s.wav" % id), "la %s tiene su motor" % id)
		var sm = SONIDO_MOTOR.new(datos)
		var ralenti: float = sm.rpm_objetivo(0.0, false)
		var tope: float = sm.rpm_objetivo(float(datos.vel_max), true)
		t.check_eq(ralenti, float(datos.rpm_ralenti), "%s parada suena en ralentí" % id)
		t.check(tope > ralenti * 3.0, "%s a tope suena mucho más revolucionada (%d vs %d rpm)" % [id, tope, ralenti])
		t.check(sm.rpm_objetivo(float(datos.vel_max) * 0.1, true) < sm.rpm_objetivo(float(datos.vel_max), true), "%s: despacio más tranquila que rápido" % id)
		t.check(sm.rpm_objetivo(10.0, true) > sm.rpm_objetivo(10.0, false), "%s acelerando suena más que soltando" % id)
		# El tono del bucle queda en un rango que suena bien.
		sm.rpm = float(datos.rpm_ralenti)
		var t_bajo: float = sm.tono()
		sm.rpm = float(datos.rpm_max)
		t.check(t_bajo >= 0.2 and sm.tono() <= 2.0, "%s: tono entre %.2f y %.2f" % [id, t_bajo, sm.tono()])
		t.check(sm.volumen_db(true) > sm.volumen_db(false) - 0.01, "%s: acelerando suena más fuerte" % id)

	# BWS automática: las rpm solo suben con la velocidad.
	var bws = SONIDO_MOTOR.new(MOTOS.get_moto("bws"))
	var sube := true
	var ant := 0.0
	for k in 26:
		var r: float = bws.rpm_objetivo(float(k), true)
		if r < ant:
			sube = false
		ant = r
	t.check(sube, "la BWS (automática) sube de rpm parejo")
	# La NKD tiene cambios: al pasar de cambio las rpm caen.
	var nkd = SONIDO_MOTOR.new(MOTOS.get_moto("nkd"))
	var caidas := 0
	var cambios_vistos := {}
	ant = 0.0
	for k in 300:
		var v := float(k) / 300.0 * float(nkd.moto.vel_max)
		var r: float = nkd.rpm_objetivo(v, true)
		cambios_vistos[nkd.cambio] = true
		if r < ant - 500.0:
			caidas += 1
		ant = r
	t.check_eq(cambios_vistos.size(), 4, "la NKD usa sus 4 cambios")
	t.check_eq(caidas, 3, "y las rpm caen en cada cambio (3 veces)")
	# El tacómetro se mueve suave, no a saltos.
	nkd.rpm = 1500.0
	nkd.advance(0.1, 25.0, true)
	t.check(nkd.rpm < 1500.0 + SONIDO_MOTOR.SUBIR * 0.1 + 1.0, "las rpm suben de a poco")

	# El nodo de audio: cada evento hace su efecto.
	var a = AUDIO.new()
	t.root.add_child(a)
	a.preparar(MOTOS.get_moto("bws"))
	for par in [["estrellado", "choque"], ["charco", "charco"], ["fundido", "fundido"], ["entregado", "entregado"]]:
		a.al_evento(par[0])
		t.check_eq(a.ultimo_efecto, par[1], "el evento %s suena a %s" % par)
	a.ultimo_efecto = ""
	a.al_evento("lluvia")
	t.check_eq(a.ultimo_efecto, "", "los eventos sin efecto no suenan (esos son voces)")
	a.queue_free()
