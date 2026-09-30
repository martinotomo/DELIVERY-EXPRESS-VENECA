extends RefCounted
## Frases por evento. En la F1 salen como subtítulos; Tomás grabará las voces y cada una
## irá en assets/voces/<evento>_<n>.wav (con su fila en LICENSES.md).

const FRASES := {
	"recogido": [
		"¡Epa, chamo! Agarra esa vaina y dale, pues.",
		"Listo el pedido, mi pana. ¡Vuela, vale!",
		"Chamo, eso está caliente, no lo vayas a voltear.",
	],
	"entregado": [
		"¡Entregado, papá! ¿Y la propina? ¿No? Ah, bueno, vale.",
		"Chévere, mi pana. Cinco estrellas... mentira, una.",
		"Llegamos vivos, chamo. Eso ya es ganancia.",
	],
	"casi": [
		"¡Na' guará, casi!",
		"Fe, mi pana, pura fe.",
		"¡Chamo, casi te matas, vale!",
		"¡Épale, épale! Frena esa burra, mi pana.",
		"¡Qué molleja, casi besas el andén!",
	],
	"golpe": [
		"¡Epa, epa! Eso no pasó.",
		"Tranquilo, mi pana, que el andén no se movió.",
	],
	"cancelado": [
		"Chamo, el cliente canceló. Te tocó comértelo a ti.",
		"Se enfrió la vaina, mi pana. Cancelado.",
	],
	"fundido": [
		"¡Se fundió el motor, chamo! Huele a pollo quemado.",
		"¡Na' guará! Le diste tan duro que se murió la burra.",
	],
	"reparado": [
		"Listo, le eché agua de la botella y un rezo. ¡Dale!",
		"Reparado con cinta, un chicle y fe, mi pana.",
		"Le soplé al motor como a un cartucho viejo. ¡Arrancó!",
	],
	"lluvia": [
		"¡Se largó el aguacero, chamo! Al menos la app paga más.",
		"Llueve, mi pana. Bono por mojarse... y por los charcos.",
	],
	"escampo": [
		"Escampó, vale. Se acabó el bono.",
		"Ya paró de llover. Ahora a secarse con el viento.",
	],
	"atropello": [
		"¡Épale! ¡Perdón, señor! Es que el pedido se enfría.",
		"¡Na' guará, chamo, la cebra es pa' ellos, no pa' uno!",
		"Tranquila, señora, que eso no fue nada... ¿verdad?",
		"¡Ay, vale! Se me atravesó... bueno, yo me le atravesé.",
		"Chamo, la propina de este pedido se fue con ese señor.",
	],
	"grito": [
		"Peatón: ¡Mire por dónde anda, domiciliario!",
		"Peatón: ¡Le voy a poner una estrella, desgraciado!",
		"Peatón: ¡Esto va pa' las redes, sonría!",
		"Peatón: ¡Uy, no, qué pecado! ¡Casi me mata!",
	],
	"choque": [
		"¡Perdón, patrón! Es que el pedido se enfría.",
		"¡Na' guará, chamo, ese carro salió de la nada!",
		"Tranquilo, mi pana, que eso con crema dental sale.",
		"¡Chamo, frenó en seco! Bueno... frené yo, más bien.",
	],
	"pito": [
		"Conductor: ¡Piiii! ¡Mire por dónde va, domiciliario!",
		"Conductor: ¡Me rayó el carro! ¡Venga, venga!",
		"Conductor: ¡Otro de estos en moto! ¡Piiiii!",
		"Conductor: ¡La vía no es suya, joven!",
	],
	"estrellado": [
		"Ay, no, chamo... se nos fue el pana.",
		"Otro más pa' la estadística, vale.",
	],
}

var _rng := RandomNumberGenerator.new()
var _ultima := {}


func _init(semilla := 0) -> void:
	_rng.seed = semilla


## Una frase del evento, sin repetir la anterior de ese mismo evento.
func frase(evento: String) -> String:
	var lista: Array = FRASES.get(evento, [])
	if lista.is_empty():
		return ""
	var k := _rng.randi_range(0, lista.size() - 1)
	if lista.size() > 1 and k == _ultima.get(evento, -1):
		k = (k + 1) % lista.size()
	_ultima[evento] = k
	return lista[k]


static func ruta_audio(evento: String, indice: int) -> String:
	return "res://assets/voces/%s_%d.wav" % [evento, indice + 1]
