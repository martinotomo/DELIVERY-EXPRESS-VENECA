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
		"¡Chamo, casi te matas, vale!",
		"¡Épale, épale! Frena esa burra, mi pana.",
		"¡Qué molleja, casi besas el andén!",
	],
	"cancelado": [
		"Chamo, el cliente canceló. Te tocó comértelo a ti.",
		"Se enfrió la vaina, mi pana. Cancelado.",
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
