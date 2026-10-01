extends RefCounted
## Frases por evento: solo subtítulos (D28: sin voces).

const VOCES := preload("res://scripts/voces.gd")


func run(t) -> void:
	for e in ["recogido", "entregado", "casi", "golpe", "cancelado", "estrellado", "fundido", "reparado", "lluvia", "escampo"]:
		t.check(VOCES.FRASES.has(e) and VOCES.FRASES[e].size() >= 2, "hay al menos 2 frases para «%s»" % e)
	var v = VOCES.new(7)
	var a: String = v.frase("casi")
	var b: String = v.frase("casi")
	t.check(a != b, "no repite la misma frase dos veces seguidas")
	t.check_eq(v.frase("no-existe"), "", "evento sin frases devuelve vacío")
	# D28: Tomás quitó las voces. Las frases quedan solo como subtítulos, sin ningún audio.
	t.check(not DirAccess.dir_exists_absolute("res://assets/voces"), "no hay carpeta de voces (D28)")
	t.check(not (VOCES.new(1) as Object).has_method("ruta_audio"), "el juego ya no busca audios de voz")
