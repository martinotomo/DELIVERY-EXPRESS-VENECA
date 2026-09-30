extends RefCounted
## Datos de las motos. Unidades: metros y segundos (vel en m/s, acel y freno en m/s²), precios en pesos.
## Única fuente de verdad de cómo anda cada moto, de sus mejoras y de lo que cuestan.
## Regla de Tomás (30/09/2026): una moto con todas sus mejoras sigue siendo peor que la siguiente de fábrica.
## Precios pensados para ~10.000 pesos por pedido (unos 2 min): hasta la Ninja son ~19 pedidos, ~40 min.

const MOTO_INICIAL := "bws"
const ORDEN := ["bws", "nkd", "ninja"]
const MEJORAS := ["exosto", "motor"]
const NOMBRE_MEJORA := {"exosto": "Exosto", "motor": "Motor"}

## Lo que comparten todas; cada moto puede cambiar lo suyo (el giro y el agarre, D22).
const BASE := {
	"roce": 0.8,        # lo que pierde sin acelerar ni frenar
	# Maniobrabilidad: rad/s con el manubrio a tope. Despacio gira mucho y se pierde de forma
	# progresiva al acelerar; a tope queda igual que en la primera versión (6 m/s² / 25 m/s).
	"giro_lento": 2.7,  # casi parado (a 7 km/h da 9 veces el giro de tope)
	"giro_rapido": 0.24, # a velocidad máxima
	"curva_giro": 0.6,  # <1: se pierde pronto al arrancar y más suave cerca del tope
	"radio": 0.5,       # medio ancho de la moto para chocar con el andén
	"vel_choque": 3.0,  # contra el andén por encima de esto (11 km/h), se mata
	"agarre": 1.0,      # cuánto aguanta el giro a tope antes de irse de lado (multiplica DERRAPE_SOSTENIDO)
}

## El remate de la caída en la curva (D9): el chiste central, con el nombre de cada moto.
const REMATE := "Has muerto al entrar demasiado rápido en la curva, tu fe era más grande que el agarre de tu %s."

const MOTOS := {
	"bws": {
		"nombre": "Bwis", # así la llama Tomás (30/09); el id interno sigue siendo "bws"
		"precio": 0,
		# Zonas a las que llegan sus pedidos (DISENO §7): cada moto abre una más (D27).
		"zonas": ["barrio", "centro"],
		"vel_max": 25.0,    # 90 km/h, y porque va bajando
		"acel": 3.2,        # empuje a baja velocidad; se apaga al acercarse al tope
		"freno": 7.0,
		# Manejo (D12): la de BASE, como la ajustó Tomás. A tope, curva de ~104 m de radio.
		# Sonido: automática (CVT), gira alto y parejo. Hay un bucle por cada rpm de rpm_muestras
		# (assets/sonidos/motor_<id>_<rpm>.wav, de tools/gen_sonidos.py: mismas cifras allá).
		"cambios": 0, "rpm_ralenti": 1700.0, "rpm_max": 8500.0,
		"rpm_muestras": [1700, 2350, 3240, 4470, 6160, 8500],
		"mejoras": {
			"exosto": {"precio": 8000, "vel_max": 1.5, "acel": 0.2},
			"motor": {"precio": 12000, "vel_max": 1.5, "acel": 0.5},
		},
	},
	"nkd": {
		"nombre": "NKD 125",
		"precio": 40000,
		"zonas": ["barrio", "centro", "industrial"],
		"vel_max": 30.5,    # 110 km/h
		"acel": 4.2,
		"freno": 8.0,
		# Manejo (D22): gira mejor que la Bwis a cualquier velocidad y cierra más a fondo (~88 m).
		"giro_lento": 3.0, "giro_rapido": 0.35, "agarre": 1.3, "vel_choque": 3.5,
		"cambios": 4, "rpm_ralenti": 1500.0, "rpm_max": 9500.0,
		"rpm_muestras": [1500, 2170, 3140, 4540, 6570, 9500],
		"mejoras": {
			"exosto": {"precio": 15000, "vel_max": 1.5, "acel": 0.3},
			"motor": {"precio": 22000, "vel_max": 2.0, "acel": 0.6},
		},
	},
	"ninja": {
		"nombre": "Ninja 300",
		"precio": 90000,
		"zonas": ["barrio", "centro", "industrial", "rica"],
		"vel_max": 40.0,    # 144 km/h
		"acel": 6.0,
		"freno": 9.0,
		# Manejo (D22): la mejor; a 144 km/h cierra la curva más que las otras a su tope (~76 m).
		"giro_lento": 3.3, "giro_rapido": 0.53, "agarre": 1.6, "vel_choque": 4.0,
		"cambios": 6, "rpm_ralenti": 1800.0, "rpm_max": 13000.0,
		"rpm_muestras": [1800, 2670, 3970, 5890, 8750, 13000],
		"mejoras": {
			"exosto": {"precio": 25000, "vel_max": 2.0, "acel": 0.4},
			"motor": {"precio": 35000, "vel_max": 3.0, "acel": 0.8},
		},
	},
}


## La moto de fábrica, con los campos comunes. Vacío si no existe.
static func get_moto(id: String) -> Dictionary:
	if not MOTOS.has(id):
		return {}
	var m: Dictionary = BASE.duplicate()
	m.merge(MOTOS[id], true)
	m["id"] = id
	if not m.has("remate"):
		m["remate"] = REMATE % m.nombre
	return m


## La moto con las mejoras compradas sumadas (mejoras: {"exosto": true, ...}).
static func con_mejoras(id: String, mejoras: Dictionary) -> Dictionary:
	var m := get_moto(id)
	if m.is_empty():
		return m
	for nombre in MEJORAS:
		if mejoras.get(nombre, false):
			var mej: Dictionary = m.mejoras[nombre]
			m.vel_max = float(m.vel_max) + float(mej.vel_max)
			m.acel = float(m.acel) + float(mej.acel)
	return m


## La que sigue en la lista, o "" si es la última.
static func siguiente(id: String) -> String:
	var i := ORDEN.find(id)
	return ORDEN[i + 1] if i >= 0 and i + 1 < ORDEN.size() else ""
