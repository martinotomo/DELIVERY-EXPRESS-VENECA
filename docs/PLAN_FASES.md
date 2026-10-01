# Plan por fases — juego de motos del domiciliario

> Tomás Ardila Marín · 29/09/2026 · versión 1.0, aprobada por Tomás.
>
> Desarrolla la tabla de fases F0–F7 de `docs/DISENO.md` §14 (decisión D6): para cada fase, **qué
> se entrega, qué pruebas la cierran y qué hace Tomás en su PC**. El *qué es el juego* vive en
> `DISENO.md`; si algo no coincide, manda `DISENO.md` y este archivo se corrige. Ninguna fase
> empieza sin la orden de Tomás.

---

## 0. Cómo se trabaja

**Reparto nube / PC local**

| Dónde | Qué |
|---|---|
| **Nube (repositorio en GitHub + Claude Code)** | Código, escenas, generador de la ciudad, generadores de arte y audio en Python, pruebas headless, CI, documentos, PRs |
| **PC de Tomás** | Jugar cada fase en Godot 4.7.2, escuchar el audio (Audacity), grabar partidas y clips (OBS), exportar y probar el `.exe` |

**La ida y vuelta de cada fase:** Claude abre un PR → el CI pasa a verde → Tomás hace `git pull`,
juega y comenta (mejor con un clip de OBS) → se ajusta → Tomás aprueba → se fusiona. Cuando haga
falta, Claude también puede trabajar directamente en la carpeta del juego en el PC de Tomás
(Remote Control) para lanzar Godot con ventana, leer sus errores o exportar.

**Herramientas, todas open source** (D7): Godot 4.7.2 (MIT), Python con numpy, scipy y Pillow,
Git, Audacity, OBS, y Krita o LibreSprite solo si algo hace falta a mano. Fuentes y assets de
terceros solo OFL o CC0. Claude Design no es libre: queda como opción, no como requisito.

**Reglas que valen para todas las fases** (vienen del Juego 1, detalle en `CLAUDE.md`):
- Pruebas primero, y cada prueba se ve en rojo al menos una vez.
- La lógica con estado vive en objetos `RefCounted` con `advance(delta)` y señales, fuera de las
  escenas, para poder probarla sin jugar.
- Todo asset nuevo entra con su fila en `assets/LICENSES.md` (y en `AI_DISCLOSURE.md` si aplica).
- Lo visual se revisa con hojas de capturas, ampliadas y a tamaño real; el audio, con medidas
  escritas antes de generarlo.

---

## F0 — Andamiaje, pruebas y CI

**Entrega**
- Proyecto Godot 4.7.2, GDScript, renderizador Compatibility. Mundo a **480×270** en un
  `SubViewport` con filtro `nearest`; interfaz aparte a 960×540. Escala entera, ventana 1280×720.
- Estructura de carpetas: `scenes/`, `scripts/`, `tests/`, `tools/`, `assets/`, `docs/`.
- `tests/run_tests.gd` adaptado del Juego 1 (vigilante de 150 s, `--solo=`, comprobación de que
  los assets están importados) y una primera suite que comprueba el proyecto.
- `assets/LICENSES.md`, `assets/AI_DISCLOSURE.md` y `tools/check_entrega.py` (probado quitando una
  fila a propósito).
- **GitHub Actions**: descarga Godot 4.7.2 para Linux, importa, corre las pruebas y el chequeo de
  licencias en cada PR.
- Escena `Main` mínima que arranca y muestra el nombre del juego leído de `project.godot`.

**Criterios de salida**
1. CI en verde en el PR de la F0, y visto en rojo al menos una vez con una prueba rota a propósito.
2. En el PC de Tomás (fuera de OneDrive): `godot --headless --path . --import` y
   `godot --headless --path . -s res://tests/run_tests.gd` salen 0.
3. El proyecto abre en el editor de Tomás sin avisos y al darle Play sale la pantalla de `Main`.

**Tomás en su PC:** clonar, correr los dos comandos, abrir y darle Play.

---

## F1 — Prototipo gris: conducir y caerse

**Entrega**
- Unas pocas cuadras de cajas grises **de distintos largos**, calles con andén y bordillo, una
  glorieta o una esquina cerrada.
- Vista en primera persona con un manubrio de rectángulos grises que gira en pantalla y cámara que
  se inclina al girar. Controles de teclado de `DISENO.md` §5.1.
- La BWS con su física en un `RefCounted`: velocidad, aceleración, freno, agarre y la **regla de la
  esquina** de §5.2 (`v_segura_giro = √(agarre × superficie × radio)`); señales `caida`, `golpe`,
  `casi_choque`.
- Caída → cinemática provisional (imagen fija gris) → caja de texto con el remate y el nombre de
  la moto → «Pulsa START» → reinicio.
- Script de captura con hoja de contactos desde esta fase.

**Criterios de salida**
1. Pruebas de la física: por debajo de `v_segura_giro` la moto sigue la curva; por encima se abre;
   si se abre hasta el andén a más del umbral, emite `caida` con el nombre de la moto; despacio,
   solo `golpe`.
2. De la caída a volver a conducir en menos de 3 s tras pulsar START.
3. Hoja de capturas: recta, giro, esquina y pantalla de caída.
4. **Tomás lo juega** y confirma que frenar antes de la esquina es divertido, que la primera
   persona no marea y que el remate hace gracia en gris.

**Tomás en su PC:** jugar 10 minutos y grabar con OBS una caída y algo que no le guste.

---

## F2 — Dirección visual

Por código por defecto (paleta en `tools/paleta.py`, maquetas renderizadas con Pillow), o con
Krita/LibreSprite. Claude Design solo si Tomás lo prefiere.

**Entrega** (en `docs/direccion_visual/`)
- Paleta de 32 colores de ciudad tipo Bogotá: ladrillo, fachadas de colores, asfalto, andén, cielo
  gris de día, naranja de alumbrado de noche, rojo de la cinemática.
- Fuente pixelada OFL/CC0 y logo con el título provisional.
- Maqueta del HUD a resolución de interfaz: velocímetro, reloj del pedido, dinero, racha de
  casi-choques y **minimapa**.
- Un manubrio completo (el de la BWS) en pixel art como sprite en primera persona.
- La cinemática de caída de la BWS: el domiciliario tirado y la moto al lado, recreando la
  composición del meme **con dibujo propio**, sin logos.

**Criterios de salida**
1. Tomás aprueba la paleta, el HUD, el manubrio y la cinemática.
2. Todo lo nuevo en `LICENSES.md` / `AI_DISCLOSURE.md` y `check_entrega.py` en verde.

**Tomás en su PC:** revisar las maquetas y decidir.

---

## F3 — La ciudad

**Entrega**
- Generador por código, con semilla fija, en dos pasos: primero un sector de unas 10 × 20 cuadras
  para afinar, luego la ciudad completa de **40 calles × 80 carreras**.
  - Calles de oriente a occidente y carreras de norte a sur, numeradas; direcciones «Calle 45 # 12-30».
  - Cuadras de largo variable (0,6 a 1,6 veces la normal), calles que se cortan, diagonales,
    avenidas anchas, glorietas y parques.
  - Las cinco zonas de `DISENO.md` §6 (barrio, centro, industrial, avenida, zona rica/loma), que se
    distinguen por altura y color de edificios y por tráfico.
  - Cerros al oriente como referencia visual.
- **Carga por trozos**: solo se dibujan y simulan las cuadras cercanas a la moto.
- **Minimapa** siempre visible que gira con la moto y marca la ruta más corta por las calles,
  recalculada al desviarse. Mapa completo con Tab.
- Letreros de calle y carrera en cada esquina.
- **Ciclo de día y noche**: cada 10 minutos cambia de día a noche o al revés, con animación
  continua (cielo, luz, alumbrado, ventanas, farolas). El reloj vive en un `RefCounted`.
- Tráfico y peatones sencillos como sprites planos que miran a la cámara.

**Criterios de salida**
1. Pruebas del generador: la misma semilla da la misma ciudad; todas las calles están conectadas;
   los largos de cuadra varían dentro del rango; toda dirección «Calle X # Y-Z» existe.
2. Prueba del minimapa: la ruta es la más corta y se recalcula al desviarse.
3. Prueba del reloj: a los 10 min es de noche, a los 20 vuelve el día, y la luz cambia sin saltos
   entre un fotograma y el siguiente.
4. Rendimiento **medido**: 60 fps recorriendo la ciudad de punta a punta en el portátil de Tomás
   con la gráfica integrada, sin tirones al cargar trozos.
5. Tomás recorre la ciudad de día y de noche y confirma que no se ve cuadriculada y que el minimapa
   lo lleva a donde tiene que ir.

**Tomás en su PC:** recorrerla, grabar con OBS un trayecto de día y uno de noche.

---

## F4 — Arte y audio

**Entrega**
- Texturas de la ciudad por código, cuantizadas a la paleta: fachadas por zona, ventanas, asfalto
  con marcas y huecos, andenes, superficies peligrosas (mojado, aceite), letreros verdes de vía,
  avisos de negocios con nombres inventados.
- Los **cinco manubrios y tableros** de `DISENO.md` §7 como sprites en primera persona.
- Las cinco cinemáticas de caída ilustradas (una por moto) y las variantes de §5.5.
- Sprites de carros, buses, peatones y perros.
- Sonido por código: motor por moto (la BWS suena a licuadora, la Ninja a moto de verdad), frenazo,
  golpe, pito ridículo, ambiente de ciudad de día y de noche, música.

**Criterios de salida**
1. Cada sonido con su prueba de números escritos **antes** de generarlo: duración, energía por
   bandas, paso-alto a ~90 Hz, final sin clic, bucle sin salto.
2. Hojas de capturas de manubrios, fachadas por zona, día y noche y cinemáticas, revisadas.
3. Tomás juega y escucha en su portátil y aprueba.
4. `check_entrega.py` en verde con todos los archivos de `assets/`.

**Tomás en su PC:** escuchar con Audacity lo que no le convenza y grabar una partida con OBS.

---

## F5 — Contenido: pedidos, economía y garaje

**Entrega**
- Pedidos según `DISENO.md` §5.4: restaurante → recoger → dirección → entregar; tipos de pedido
  (hamburguesa, sopa, torta, licor) que cambian la conducción; pago, propina y estrellas.
- Racha de casi-choques que sube la propina.
- Garaje con la escalera BWS → Boxer CT 100 → Crypton Fi → NKD 125 → Ninja 300, todas en **un solo
  archivo de datos** (estadísticas, precio, remate), y las zonas que abre cada moto.
- Final (según lo que se decida en `DISENO.md` §15.2).
- Guardado del progreso (dinero, moto, pedidos hechos).
- **Sin voces (D28, 30/09/2026):** Tomás las quitó del juego y no quedan pendientes. Las líneas
  de texto en pantalla se mantienen.

**Criterios de salida**
1. Prueba que simula una partida entera con `advance()` y llega a la Ninja 300 con unos 20
   pedidos, sin quedarse sin dinero ni bloqueada.
2. Prueba de que cada moto tiene estadísticas, precio y remate.
3. Tomás juega de la BWS a la Ninja y se afinan precios y agarres con lo que diga.

**Tomás en su PC:** jugar la partida completa.

---

## F6 — Menús, opciones, idiomas y créditos

**Entrega**
- `Main` como único director de pantallas: menú, opciones, créditos, pausa, final. La música vive
  en `Main`.
- Opciones: volumen de música y efectos por separado, pantalla completa, idioma. Se guardan
  en `user://opciones.cfg`.
- Advertencia de contenido al arrancar (humor negro, caídas, sangre), saltable a los 2 s.
- Español, y además inglés si se decide, con `localization/textos.csv` (clave = texto en español,
  filas con coma entre comillas).

**Criterios de salida**
1. Prueba de que solo hay una pantalla viva a la vez y de que la música no se corta al entrar en
   Opciones.
2. Capturas de todas las pantallas en cada idioma, sin textos sin traducir ni solapados.
3. Opciones y progreso se recuerdan al cerrar y reabrir.
4. La lista de «terminado» de `DISENO.md` §3.1 casi completa.

---

## F7 — Entrega

**Entrega**
- `export_presets.cfg` (PCK incrustado, icono propio) y script de build: licencias → importar →
  pruebas → exportar → comprobar arranque con `--log-file` → zip.
- El CI también exporta el `.exe` de Windows y lo deja descargable en el PR.
- Un clip corto grabado con OBS (caídas con varias motos), pensado para TikTok, que es de donde
  viene el meme.

**Criterios de salida**
1. El `.exe` arranca en otro PC (o en el portátil forzado a la gráfica integrada) en menos de 10 s
   y va fluido.
2. Lista del Juego 1 superada: icono, menú con música, cambio de idioma sin cortar la música,
   opciones y progreso recordados, partida completa jugable, botones del final funcionando.
3. `LICENSES.md` y `AI_DISCLOSURE.md` completos y `check_entrega.py` en verde.

**Tomás en su PC:** probar el `.zip` en otro computador y grabar el clip.

---

*Un juego pequeño terminado vale más que tres empezados. La ciudad completa llega solo cuando
conducir y caerse ya funcionen en gris.*
