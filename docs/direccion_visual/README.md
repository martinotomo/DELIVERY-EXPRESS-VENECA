# Dirección visual (F2)

Piezas de la dirección visual hechas por código (CLAUDE.md §7): cada una sale de un script de
`tools/` con semilla fija y solo con colores de `tools/paleta.py`. Volver a correr el script da
exactamente lo mismo.

| Archivo | Qué es | Cómo se genera |
|---|---|---|
| `assets/ui/logo.png` | Logo «DELIVERY EXPRESS» a 640×360, fondo transparente, para el menú. | `python tools/gen_logo.py` |
| `assets/ui/logo_1280.png` | El mismo logo al doble (1280×720), sin suavizar. | `python tools/gen_logo.py` |
| `docs/direccion_visual/logo_preview.png` | El logo sobre el azul de la noche, solo para mirarlo. | `python tools/gen_logo.py` |
| `assets/texturas/cerros.png` | Panorama de los cerros orientales (1024×160, cielo transparente), se repite a lo ancho sin costura. | `python tools/gen_cerros.py` |
| `assets/texturas/cerros_luz.png` | Máscara de noche de los cerros: lucecitas de los barrios, postes de la carretera y la capilla del pico. | `python tools/gen_cerros.py` |
| `assets/texturas/fachada_bodega.png` | Fachada de bodega industrial (128×128 = 8 m × 6,4 m, como las demás fachadas). | `fachada_bodega()` en `tools/gen_texturas.py` |
| `assets/texturas/fachada_bodega_luz.png` | Máscara de noche de la bodega: dos ventanitas altas y el bombillo de la cortina. | `fachada_bodega()` en `tools/gen_texturas.py` |

## Cómo está hecho cada uno

- **Logo.** Las letras son la fuente Press Start 2P (OFL, `assets/fuentes/`) a 8 px; cada píxel se
  vuelve un bloque (7 px en DELIVERY, 5 px en EXPRESS) y el texto se inclina en escalera. La cara
  lleva un degradé cálido por franjas (amarillo → sodio → naranja) con costuras tramadas, brillo
  arriba, fondo extruido hacia abajo a la derecha y contorno negro. EXPRESS va en una cinta roja
  inclinada, y una caja térmica de domiciliario (genérica, sin marca) deja estela de velocidad.
- **Cerros.** Tres filas de crestas hechas con sumas de senos de frecuencia entera (por eso empalman
  los bordes): atrás, bruma azulada con los dos picos altos y una capillita; en medio, monte verde
  con quebradas, derrumbes de tierra y una carretera en zigzag; adelante, copas de árboles y barrios
  de ladrillo en las faldas. Cada fila se cuantiza solo con sus colores para que no se ensucie.
- **Bodega.** Lámina acanalada (cada costilla, un color de la paleta, para que se lea limpia),
  franja amarilla desteñida, zócalo de concreto con barro, cortina metálica enrollable con candado,
  ventanitas altas con reja y chorreones de óxido.

Colores que se agregaron a la paleta para los cerros: `cerro_bruma`, `cerro_lejano`, `cerro_medio`
y `monte_oscuro`.
