"""Paleta del juego: única fuente de verdad del color (CLAUDE.md §7).

Noche bogotana a lo Doom: negros azulados, grises de concreto, ladrillo, luces de sodio.
Todo lo que generan los scripts de tools/ se cuantiza contra esta lista.
"""

PALETA = {
    # neutros
    "negro": (10, 10, 14),
    "carbon": (28, 28, 34),
    "asfalto_oscuro": (44, 44, 50),
    "asfalto": (62, 62, 68),
    "gris": (92, 92, 96),
    "concreto": (128, 126, 120),
    "concreto_claro": (164, 160, 150),
    "hueso": (206, 200, 186),
    "blanco": (236, 234, 226),
    # ladrillo bogotano
    "ladrillo_oscuro": (92, 38, 28),
    "ladrillo": (138, 58, 38),
    "ladrillo_claro": (176, 88, 56),
    "mortero": (150, 132, 112),
    # fachadas pintadas
    "verde_casa": (70, 112, 92),
    "azul_casa": (62, 92, 132),
    "amarillo_casa": (196, 164, 84),
    # vidrio y cielo
    "vidrio_oscuro": (22, 34, 52),
    "vidrio": (46, 70, 100),
    "vidrio_brillo": (120, 150, 180),
    "cielo_noche": (14, 18, 38),
    # luces
    "sodio": (240, 176, 70),
    "ventana_luz": (250, 214, 120),
    "amarillo_via": (226, 190, 40),
    "rojo": (196, 30, 24),
    "rojo_oscuro": (110, 14, 12),
    "naranja": (224, 112, 32),
    # parque
    "pasto_oscuro": (36, 62, 30),
    "pasto": (58, 92, 42),
    "pasto_claro": (92, 124, 56),
    # moto y domiciliario
    "cromo_oscuro": (84, 88, 96),
    "cromo": (150, 156, 166),
    "cromo_brillo": (214, 220, 228),
    "guante": (104, 76, 50),
    "guante_claro": (148, 110, 72),
    "chaqueta": (170, 60, 30),
    "chaqueta_oscura": (110, 36, 18),
    # pintura de las motos del taller (sin logos: solo el color que las evoca)
    "azul_bwis": (150, 170, 196),
    "azul_bwis_oscuro": (84, 100, 126),
    "verde_ninja": (74, 168, 42),
    "verde_ninja_oscuro": (30, 92, 22),
    # peatones
    "piel_clara": (214, 166, 128),
    "piel": (168, 114, 78),
    "piel_oscura": (112, 72, 48),
}

LISTA = list(PALETA.values())
