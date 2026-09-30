extends RefCounted
## Datos de las motos. Unidades: metros y segundos (vel en m/s, acel, freno y agarre en m/s²).
## Única fuente de verdad de cómo anda cada moto. En la F1 solo existe la BWS.

const MOTO_INICIAL := "bws"

const MOTOS := {
	"bws": {
		"id": "bws",
		"nombre": "BWS",
		"vel_max": 25.0,    # 90 km/h, y porque va bajando
		"acel": 3.2,        # empuje a baja velocidad; se apaga al acercarse al tope
		"freno": 7.0,
		"roce": 0.8,        # lo que pierde sin acelerar ni frenar
		"agarre": 6.0,      # aceleración lateral máxima antes de irse de lado
		"giro_max": 1.4,    # rad/s con el manubrio a tope, a baja velocidad
		"radio": 0.5,       # medio ancho de la moto para chocar con el andén
		"vel_choque": 3.0,  # contra el andén por encima de esto (11 km/h), se mata
	},
}


static func get_moto(id: String) -> Dictionary:
	return MOTOS.get(id, {})
