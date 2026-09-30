extends RefCounted
## Los remates de cada final. El de la curva es el chiste central del juego.


static func muerte_curva(nombre_moto: String) -> String:
	return "Has muerto al entrar demasiado rápido en la curva,\ntu fe era más grande que el agarre de tu %s." % nombre_moto


static func sin_tiempo() -> String:
	return "Se acabó el tiempo.\nEl cliente canceló el pedido y la app te cobró el domicilio a ti."


static func entregado(segundos_sobrantes: float) -> String:
	return "Pedido entregado con %d s de sobra.\nEl cliente te puso una estrella: «llegó frío»." % int(segundos_sobrantes)
