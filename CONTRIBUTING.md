# Cómo colaborar

¡Gracias por querer meterle la mano! Delivery Express es un proyecto de ocio: lo importante es
que siga siendo **un juego pequeño, terminado y con un solo chiste bien hecho**.

*English speakers: issues and PRs in English are welcome; the code and docs are in Spanish.*

## Antes de empezar

1. Lee [`CLAUDE.md`](CLAUDE.md): §0 son las **decisiones** del proyecto (numeradas D1, D2…) y
   mandan sobre todo lo demás; §4 son las reglas de Godot sin editor que ya costaron caro.
2. Para una idea grande (mecánica nueva, otra moto, cambiar el estilo), abre primero un *issue*
   para hablarla. Si se acepta, entra como una decisión nueva en `CLAUDE.md`.

## Al hacer un cambio

- **Godot 4.7.2** exacto, GDScript y el renderizador *Compatibility*.
- **Nada de `class_name`**: se carga con `preload("res://...")` (sin la caché `.godot/` el
  nombre global no existe y todo falla sin editor).
- **La lógica va fuera de las escenas**, en un `RefCounted` con `advance(delta)`, para poder
  probarla sin jugar.
- **Primero la prueba, en rojo**, y luego el código que la pasa. Corre todo antes del PR:

  ```bash
  godot --headless --path . --import
  godot --headless --path . -s res://tests/run_tests.gd
  python3 tools/check_entrega.py
  ```

- **Assets por código.** Cada imagen o sonido nuevo sale de un script en `tools/` que se pueda
  volver a correr, con los colores de `tools/paleta.py`. Nada de imágenes, sonidos, logos o
  marcas con derechos; nada calcado de otras obras. Si de verdad hace falta algo de afuera,
  que sea CC0 u OFL.
- **Cada asset entra con su fila** en `assets/LICENSES.md` (y en `assets/AI_DISCLOSURE.md` si se
  hizo con IA). `tools/check_entrega.py` lo comprueba y `tools/check_publico.py` revisa que la
  versión web se pueda publicar.
- **Textos que ve el jugador** en español, con su traducción al inglés en
  `localization/textos.csv` o `localization/pantallas.csv` (la clave es el texto en español; las
  filas con comas, entre comillas).
- Lo visual se mira con capturas (`tools/capturas.gd`), no solo con pruebas.
- Archivos de texto en UTF-8 con fin de línea LF (`.gitattributes` lo pide). Los `.uid` y los
  `.translation` sí van al repo.

## El PR

- Un tema por PR, contra `main`, explicando qué se ve distinto al jugar (mejor con una captura o
  un clip).
- El CI corre las pruebas con Godot 4.7.2; tiene que quedar en verde.
- Al aportar, aceptas que tu código salga con licencia MIT y tu arte o sonido con CC BY 4.0,
  como el resto del proyecto.

## Respeto

Humor negro sí; nada sobre personas reales con nombre propio. Trata bien a los demás en los
*issues* y PRs.
