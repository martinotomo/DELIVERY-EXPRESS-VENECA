extends RefCounted
## Datos de las motos. Unidades: metros y segundos (vel en m/s, acel y freno en m/s²), precios en pesos.
## Única fuente de verdad de cómo anda cada moto, de sus mejoras y de lo que cuestan.
## Regla de Tomás (30/09/2026): una moto con todas sus mejoras sigue siendo peor que la siguiente de fábrica.
## Precios pensados para ~10.000 pesos por pedido (unos 2 min): hasta la Ninja son ~19 pedidos, ~40 min.

const MOTO_INICIAL := "bws"
const ORDEN := ["bws", "nkd", "ninja"]
const MEJORAS := ["exosto", "motor"]
const NOMBRE_MEJORA := {"exosto": "Exosto", "motor": "Motor"}

## Lo que comparten todas: la curva de giro de D12 y el choque contra el andén.
const BASE := {
	"roce": 0.8,        # lo que pierde sin acelerar ni frenar
	# Maniobrabilidad: rad/s con el manubrio a tope. Despacio gira mucho y se pierde de forma
	# progresiva al acelerar; a tope queda igual que en la primera versión (6 m/s² / 25 m/s).
	"giro_lento": 2.7,  # casi parado (a 7 km/h da 9 veces el giro de tope)
	"giro_rapido": 0.24, # a velocidad máxima
	"curva_giro": 0.6,  # <1: se pierde pronto al arrancar y más suave cerca del tope
	"radio": 0.5,       # medio ancho de la moto para chocar con el andén
	"vel_choque": 3.0,  # contra el andén por encima de esto (11 km/h), se mata
}

const MOTOS := {
	"bws": {
		"nombre": "BWS",
		"precio": 0,
		"vel_max": 25.0,    # 90 km/h, y porque va bajando
		"acel": 3.2,        # empuje a baja velocidad; se apaga al acercarse al tope
		"freno": 7.0,
		"mejoras": {
			"exosto": {"precio": 8000, "vel_max": 1.5, "acel": 0.2},
			"motor": {"precio": 12000, "vel_max": 1.5, "acel": 0.5},
		},
	},
	"nkd": {
		"nombre": "NKD 125",
		"precio": 40000,
		"vel_max": 30.5,    # 110 km/h
		"acel": 4.2,
		"freno": 8.0,
		"mejoras": {
			"exosto": {"precio": 15000, "vel_max": 1.5, "acel": 0.3},
			"motor": {"precio": 22000, "vel_max": 2.0, "acel": 0.6},
		},
	},
	"ninja": {
		"nombre": "Ninja 300",
		"precio": 90000,
		"vel_max": 40.0,    # 144 km/h
		"acel": 6.0,
		"freno": 9.0,
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
