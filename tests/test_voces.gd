extends RefCounted
## Frases por evento: hoy son subtítulos; Tomás grabará las voces.

const VOCES := preload("res://scripts/voces.gd")


func run(t) -> void:
	for e in ["recogido", "entregado", "casi", "golpe", "cancelado", "estrellado", "fundido", "reparado", "lluvia", "escampo"]:
		t.check(VOCES.FRASES.has(e) and VOCES.FRASES[e].size() >= 2, "hay al menos 2 frases para «%s»" % e)
	var v = VOCES.new(7)
	var a: String = v.frase("casi")
	var b: String = v.frase("casi")
	t.check(a != b, "no repite la misma frase dos veces seguidas")
	t.check_eq(v.frase("no-existe"), "", "evento sin frases devuelve vacío")
	t.check_eq(VOCES.ruta_audio("casi", 0), "res://assets/voces/casi_1.wav", "cada frase tiene su ruta de audio prevista")
	# F5: cada situación tiene al menos una voz grabada (hoy, provisionales de espeak-ng; D27).
	var sin_voz: Array[String] = []
	for e in VOCES.FRASES:
		if not ResourceLoader.exists(VOCES.ruta_audio(e, 0)):
			sin_voz.append(e)
	t.check(sin_voz.is_empty(), "cada situación tiene su voz en assets/voces (faltan: %s)" % ", ".join(sin_voz))
