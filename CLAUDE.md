# CLAUDE.md — Delivery Express (repo `DELIVERY-EXPRESS-VENECA`)

> Guía para cualquier sesión de Claude Code que trabaje en este repositorio. Condensa lo aprendido
> en los juegos anteriores de Tomás Ardila Marín (MOUSTACHE POV y la F0 de ATTIC, Godot 4.7.2,
> septiembre 2026) y lo adapta a este proyecto: un juego **2D**, trabajado **desde GitHub en la
> nube** y probado en local.
>
> Tomás es estudiante de ingeniería mecánica (Escuela Colombiana de Ingeniería Julio Garavito),
> escribe en español y programa a nivel de curso universitario de Python: explicar sin jerga.

---

## 0. Decisiones de Tomás (mandan sobre todo lo demás)

Numeradas y con fecha. Si una decisión anula una regla de este archivo, la regla se tacha y se
anota por qué; si no, cada sesión nueva leerá la regla vieja y la aplicará.

| # | Fecha | Decisión |
|---|---|---|
| D1 | 29/09/2026 | Juego 2D de motos con humor negro, con las motos latinoamericanas de bajo cilindraje que usan los domiciliarios. |
| D2 | 29/09/2026 | Moto inicial: **Yamaha BWS**. Moto final (la única que no es de domiciliario): **Kawasaki Ninja 300**. |
| D3 | 29/09/2026 | El proyecto vive en GitHub (`martinotomo/juego-motos-2d`; desde D33, `martinotomo/DELIVERY-EXPRESS-VENECA`) y se trabaja casi todo desde la nube. En el PC local solo se prueba: Godot, Audacity y OBS. Esto sustituye la regla de los juegos anteriores «git solo local, sin GitHub». |
| D4 | 29/09/2026 | Motor: Godot **4.7.2** estable, GDScript, renderizador Compatibility. |
| D5 | 29/09/2026 | Es un proyecto de ocio: **preferir siempre herramientas y assets de código abierto o libres** (Godot, Python, Audacity, OBS, Krita, LibreSprite, fuentes OFL, assets CC0). Si algo no lo es, se dice y se propone la alternativa libre. |
| D6 | 29/09/2026 | También se puede trabajar **directamente en el PC de Tomás** (Remote Control de Claude Code en la carpeta del juego) cuando haga falta Godot con ventana, exportar el `.exe` o usar sus programas. |
| D7 | 29/09/2026 | Vista **en primera persona, estilo Doom** (2.5D): se ve el manubrio de la moto y la ciudad de frente, dibujada a baja resolución (320×180) y escalada entera. Sigue siendo «2D como en las imágenes» en el sentido de Doom: mundo de bloques con sprites planos, no 3D realista. Sustituye la vista lateral del primer prototipo. |
| D8 | 29/09/2026 | Mundo: **una ciudad grande tipo Bogotá**, unas 40 cuadras de ancho por 80 de largo, con cuadras de tamaños distintos (cortas y largas) para que no se vea cuadriculada. Se recogen y entregan domicilios, guiados por un **minimapa**. |
| D9 | 29/09/2026 | El chiste central: girar muy rápido hace que la moto se vaya de lado, se monte al andén y se caiga; sale una cinemática y el remate «Has muerto al entrar demasiado rápido en la curva, tu fe era más grande que el agarre de tu <moto>», con el nombre de la moto. |
| D10 | 29/09/2026 | **Día y noche**: un día completo cada 10 minutos, animado de forma continua. |
| D11 | 29/09/2026 | **Frases de estereotipo venezolano** al recoger, entregar, casi estrellarse, etc., como subtítulos. ~~Las graba Tomás; el juego reproduce `assets/voces/<evento>_<n>.wav` si existe.~~ (sustituido por D28: sin voces). |
| D12 | 30/09/2026 | **Giro progresivo**: a velocidad máxima la moto gira lo mismo que en el primer prototipo (0,24 rad/s); al ir más despacio gana maniobrabilidad de forma progresiva (a 7 km/h gira 9 veces más: 2,16 rad/s; ajustado por Tomás el 30/09). Datos en `scripts/motos.gd`. |
| D13 | 30/09/2026 | **Plata, mejoras y motos**: cada entrega paga (tarifa + propina por tiempo sobrante) y la plata se guarda en `user://progreso.cfg`; **morir no la quita**. Tres motos: BWS → NKD 125 → Ninja 300. Cada una con **dos mejoras** (exosto y motor); una moto con todo sigue siendo peor que la siguiente de fábrica (lo comprueba `test_motos`). Precios para ~19 pedidos hasta la Ninja. Hay **menú de inicio** (Jugar, Taller, Salir). El aviso «¡SE VA DE LADO!» va pequeño abajo a la izquierda y solo sale a más del 75 % de la velocidad máxima con el giro a tope sostenido. Datos en `scripts/motos.gd`. |
| D14 | 30/09/2026 | El juego se llama **Delivery Express** (sustituye a «Juego motos»). Vive solo en `project.godot` (`config/name`): ventana, menú y build lo leen de ahí. ~~El repo sigue llamándose `juego-motos-2d`.~~ (D33: ahora `DELIVERY-EXPRESS-VENECA`). |
| D15 | 30/09/2026 | **Fundir el motor**: acelerando a más del 90 % de la velocidad máxima, a los 5 s sale «¡VAS A FUNDIR EL MOTOR!» con cuenta de 5 s (soltar el acelerador lo enfría 5 veces más rápido). Si llega a 0: frenazo en seco, 3 s quieto y una frase de cómo lo reparó; no mata, no quita plata y el pedido sigue con su tiempo corriendo. Datos en `scripts/moto_logic.gd`. |
| D16 | 30/09/2026 | **Sonido y lluvia**. Sonidos generados por código (`tools/gen_sonidos.py`, medidos con `tools/medir_sonidos.py`): motor de cada moto que sube con las rpm (BWS automática; NKD con 4 cambios y Ninja con 6, las rpm caen al pasar de cambio). El motor se sintetiza como explosiones que pasan por un exosto (no tonos puros: sonaban «a nave espacial», Tomás 30/09) con **6 bucles grabados a distintas rpm por moto**, mezclando los dos más cercanos para no deformar el timbre; cada moto suena distinto (BWS monocilíndrica zumbona con correa, NKD monocilíndrica gorda, Ninja bicilíndrica aguda) y `medir_sonidos.py` lo comprueba con un umbral de tonalidad y de brillo por moto. Si aun así suena artificial, la alternativa es grabaciones CC0 registradas en `LICENSES.md`, ciudad de día y de noche, viento según la velocidad, lluvia y efectos (choque, casi, motor fundido, entrega, charco…). Las voces las hace Tomás más adelante. **Lluvia**: rara (la primera a los 6–12 min, luego cada 12–20 min, dura 1–2 min), paga **+30 % por pedido** mientras llueve (aviso abajo a la derecha) y forma **charcos** en la calzada; cada charco quita el 15 % de la velocidad. Datos en `scripts/clima.gd` y `scripts/sonido_motor.gd`. Para probar: **F9** prende/apaga la lluvia y **F10** suma $50.000 (en el taller o en la calle; 5 toques alcanzan para todo), solo en versiones de desarrollo (no en el `.exe`). |
| D17 | 30/09/2026 | **Peatones**: pocos (máx. 3 a la vez, uno nuevo cada 7–15 s, casi siempre por delante de la moto) cruzan por las **cebras**, pintadas en todas las esquinas; llegan y se van por el andén. Sprites planos a lo Doom (`tools/gen_texturas.py`, 3 ropas). **Atropellar** a uno (a más de 1,5 m/s): frenazo en seco, sonido propio, frase del domiciliario, el peatón cae (a lo caricatura, sin sangre), se levanta y grita («Peatón: …»), y **ese pedido pierde la propina** (solo tarifa); no mata ni quita plata. En el minimapa solo se marcan a menos de 60 m. La multa la confirmó Tomás (D19); sin sangre y el minimapa los propuso Claude. Datos en `scripts/peatones.gd`. |
| D18 | 30/09/2026 | La moto inicial se llama **«Bwis»** en todo lo que ve el jugador (menú, taller, HUD, remate «…el agarre de tu Bwis»). Dato en `scripts/motos.gd` (`nombre`); el id interno y los archivos siguen como `bws`. |
| D19 | 30/09/2026 | **Propina: $25 por segundo sobrante** (antes $50); tarifa $5.000, bono de lluvia +30 % y «atropellar quita la propina» (D17, confirmado por Tomás) siguen igual. Los precios de D13 no cambian: con ~100 s de sobra por pedido se pasa de ~$10.000 a ~$7.500 por pedido, unos 25 pedidos (≈50 min) hasta la Ninja con todas las mejoras. |
| D20 | 30/09/2026 | **Taller a lo Need for Speed Most Wanted**: las tres motos en fila sobre una tarima, ←/→ para pasar de una a otra; la escogida sale grande con velocidad y aceleración en barras (hasta dónde llegaría con todas las mejoras), sus dos mejoras y el botón de compra. La que no alcanza sale en sombra con **candado**, «BLOQUEADA» y su precio, y dice cuánto falta; la Ninja pide primero la NKD; ~~la anterior sale «ENTREGADA» (parte de pago)~~ (sustituido por D23). Cada moto con su dibujo de perfil (`assets/ui/motos_taller.png`, desde D32 dibujo propio por código) y **su propio puesto de mando** en primera persona (`manubrio*.png`, rehechos en D24). El velocímetro marca hasta el tope de cada moto. |
| D21 | 30/09/2026 | ~~Los dibujos propios de las motos del taller «están un asco» (Tomás): se usan **las motos de sus imágenes de referencia** (memes de TikTok), recortadas, sin logos (borrados con *inpainting*), reducidas a la paleta y con contorno (`tools/recortar_motos.py`, silueta trazada a mano sobre `docs/referencias/moto_*.png`). **Excepción a §7 y D5 autorizada por Tomás, solo para uso privado**: antes de publicar el juego o repartir el `.exe` hay que cambiarlas por dibujo propio o CC0 (anotado en `LICENSES.md`).~~ (sustituido por D32: dibujo propio en `tools/gen_motos_taller.py`; los recortes y las imágenes de referencia se borraron también del historial). |
| D22 | 30/09/2026 | **Manejo por moto**: antes las tres compartían la curva de giro de D12 medida sobre su propia velocidad máxima, así que a fondo la Ninja cerraba peor que la Bwis (radio 167 m contra 104 m). Ahora cada moto tiene su giro (`giro_lento`, `giro_rapido`), su `agarre` (cuánto aguanta el giro a tope antes de irse de lado) y su `vel_choque` contra el andén: la Bwis queda igual que en D12; la NKD y la Ninja giran más a cualquier velocidad y cierran más a fondo (radios ~104 / 87 / 75 m). Las mejoras no dan el giro de la moto siguiente (lo prueba `test_motos`). Datos en `scripts/motos.gd`. |
| D23 | 30/09/2026 | **Garaje: comprar no entrega la moto anterior** (Tomás). Cada moto comprada se queda tuya con sus mejoras (`tenidas` en `user://progreso.cfg`); en el taller sale «EN TU GARAJE» con el botón **USAR ESTA MOTO**, para bajar de categoría cuando se quiera. Las mejoras se compran con la moto en uso. La Ninja sigue pidiendo primero la NKD. Las partidas guardadas antes del cambio recuperan las motos anteriores (de fábrica: sus mejoras no se habían guardado). Sustituye a «ENTREGADA» de D20. Datos en `scripts/progreso.gd`. |
| D24 | 30/09/2026 | **Puestos de mando nuevos** («se ven muy horribles», Tomás). Cada moto se dibuja por código (`tools/gen_manubrios.py`: se pinta a 4× con volumen y luz desde arriba a la izquierda, se reduce, se le pone contorno y se pasa a la paleta), al estilo de las motos del taller y según cómo se ve de verdad desde el asiento (notas de referencia en `docs/referencias/puestos.md`, solo texto). **Bwis**: cubierta negra con velocímetro análogo de aguja (Tomás lo pidió así, aunque la de verdad es digital), frente plateado, guantera y espejos redondos. **NKD**: manubrio cromado, velocímetro redondo sobre la farola, tanque gris y espejos ovalados. **Ninja**: cúpula verde, parabrisas casi transparente (con el ahumado no se veía la calle, Tomás 30/09), tacómetro y LCD, semimanubrios y espejos angulosos en el carenado. La aguja y los números del tablero los dibuja `scripts/manubrio.gd` (`TABLEROS`): Bwis y NKD con la aguja de velocidad y Ninja con la aguja de revoluciones y la velocidad y el cambio en la pantalla. Para ver la calle de enfrente (Tomás, 30/09) el puesto va más abajo (su borde inferior queda tras la barra de estado) y la vista sube a 1,5 m y mira 0,1 rad hacia abajo; `test_escenas` exige ≥55 px de calle entre el horizonte y el tablero. |
| D25 | 30/09/2026 | **Ciudad con movimiento** (Tomás). **Gente en los andenes**: hasta 30 cerca de la moto (casi todos por delante), dándole la vuelta a su cuadra por el andén, con 6 ropas; son de ambiente, sin atropello aparte (subirse al andén ya estrella la moto). **Semáforos** en los cruces de cada tercera carrera y calle, uno por esquina mirando al que llega, todos sincronizados (ciclo de 20 s: 8 verde, 2 amarillo, 10 rojo; calles y carreras alternan). **Señales**: PARE, peatones y velocidad máxima 50 en algunos cruces sin semáforo. Por ahora **pasarse el rojo no tiene castigo** (propuesto por Claude; si Tomás quiere reglas, se decide como nueva Dn). Datos en `scripts/transeuntes.gd` y `scripts/transito.gd`. |
| D26 | 30/09/2026 | **F2 y F3 cerradas por Claude en un loop autónomo** (Tomás: «termina esas dos… trabaja por tu cuenta»). Valores por defecto que eligió Claude y que Tomás puede cambiar: **(a) Zonas** (`ciudad.zona`): barrio de casas (casi toda la ciudad), centro viejo, industrial de bodegas al occidente y «El Alto» de torres de vidrio al nororiente; bordes que culebrean. **(b) Orientación**: y = norte y **x = occidente**; los **cerros orientales** en x = 0 (la Carrera 1 queda contra ellos, como en Bogotá) son una franja curva sin niebla que sigue a la cámara (`tools/gen_cerros.py`). **(c) Nomenclatura**: «Cl N» / «Kr M», cada sexta vía es avenida («Av», placa verde); placas en las esquinas cercanas y «por dónde va» bajo el minimapa. **(d) Mapa completo con Tab**: detiene la partida mientras está abierto. **(e) Tráfico** (`scripts/trafico.gd`): hasta 14 carros, taxis, buses y camiones cerca de la moto, derecho por su carril, paran en rojo, hacen fila y frenan ante la moto; la mezcla cambia por zona. **Chocar con uno frena en seco, suena y el conductor pita e insulta, ~~pero no mata ni quita plata~~** (matizado por D27: a más del 80 % de la máxima contra un bus o de frente sí mata; nunca quita plata). **(f) Sin diagonales, glorietas ni calles cortadas**: la cuadrícula de D8 se queda (colisión y rutas simples); las avenidas son solo visuales. **(g) Logo** (`tools/gen_logo.py`) en el menú, hecho para «Delivery Express»: si cambia el nombre en `project.godot`, el menú vuelve al título en letras y el generador se niega hasta rehacerlo. **(h) Cinemática ilustrada** por moto (`tools/gen_cinematica.py`): 0,35 s de cámara en 3D y luego el dibujo de la caída con zoom lento; el remate se lee sobre ese dibujo oscurecido. ~~Usa las motos recortadas de D21, así que hereda su «solo uso privado».~~ (D32: ya usa las motos de dibujo propio). Hoja de dirección visual en `docs/direccion_visual/`. |
| D27 | 30/09/2026 | **F2 y F3 aprobadas por Tomás** («está perfecto, está increíble»; fps medidos en su PC: 289 de promedio, 1 % más lento 220; la prueba con la gráfica integrada se descartó por orden suya). **F4 y F5 cerradas por Claude en un loop autónomo** (Tomás: «que no quede nada pendiente»). Valores por defecto que Tomás puede cambiar: **(a) Pedidos** (`partida.TIPOS_PEDIDO`): hamburguesa (normal), sopa y torta (frenar en seco las riega: baja el ESTADO y con él la propina), licor (pesa: la moto frena al 65 %); cada cliente con nombre. **(b) Estrellas** de 1 a 5 con comentario del cliente, según estado, tiempo sobrante y atropello. **(c) Racha de fe**: cada casi-choque (andén, carro, perro) da +10 % de propina, tope 10; se corta al golpear, chocar o atropellar. **(d) Zonas por moto**: Bwis barrio y centro; NKD suma la industrial; Ninja suma El Alto; el 30 % de los pedidos va a las zonas más lejanas de la moto. **(e) Final**: con la Ninja sale el pedido final, un ajiaco para la mamá en la loma de El Alto contra los cerros; «Mijo, llegó frío», pantalla FIN y se puede seguir jugando. **(f) Tres motos** (D13) en vez de las cinco de `DISENO.md`, cada una con su remate. **(g) Peligros fijos** (`scripts/peligros.gd`): huecos (muchos en el barrio y la zona industrial, casi ninguno en El Alto; 3 de cada 4 con una rama o un cono clavado para verlos de lejos) y manchas de aceite (el manubrio gira al 35 % encima). Caer en un hueco a más del 80 % de la máxima mata; despacio, frena en seco y riega el pedido. **(h) Perros** (`scripts/perros.gd`): máx. 2, uno cada 8–18 s cruzando por delante; pegarle a uno a más del 60 % mata, despacio sale corriendo; esquivarlo por poco suma a la racha. **(i) Las caídas de DISENO §5.5**, cada una con su remate y su dibujo por moto: curva, lluvia (andén mojado), hueco, perro, bus (a más del 80 % contra bus o camión) y contravía (a más del 80 % de frente contra cualquier carro). **(j) Avisos** de 12 negocios inventados en las fachadas (de noche prenden los de caja de luz y neón) y **3 vallas** de humor en terrazas de las avenidas (`tools/gen_avisos.py`). **(k) Sonido**: frenazo, pito de la moto (tecla **H**; no sirve para nada, como en la vida real), bache y ladrido; música propia por código (`tools/gen_musica.py`: menú, calle y muerte), ~~que baja cuando habla el domiciliario~~ (D28: ya no hay voces). ~~**(l) Voces provisionales** con espeak-ng (TTS libre por formantes, no IA) en `assets/voces/`, normalizadas (`tools/normalizar_voces.py`, medidas con `tools/medir_voces.py`); Tomás las reemplaza grabándolas con el mismo nombre, siguiendo `docs/voces/GUION.md`.~~ (sustituido por D28). |
| D28 | 30/09/2026 | **F4 y F5 aprobadas por Tomás** («está increíble»), con un solo cambio: **se quitan las voces** (las provisionales «están horribles»). Se borraron `assets/voces/`, `docs/voces/`, `tools/gen_voces.py`, `normalizar_voces.py` y `medir_voces.py`, y el juego ya no reproduce voz ni baja la música; las frases del domiciliario siguen **solo como subtítulos** (`scripts/voces.gd`). No es un pendiente: si Tomás quiere voces más adelante, se decide como nueva Dn. |
| D29 | 30/09/2026 | **F6 cerrada por Claude en un loop** (Tomás: «termina todo F6 y déjame probar»; la F7 espera a que la pruebe). **Pausa con Esc** (pedido de Tomás): en plena partida Esc ya no manda al menú; congela todo (tiempo del pedido, hora, tráfico, peatones, sonidos de la calle; la música sigue) y ofrece Continuar, Opciones y Volver al menú inicial; Esc otra vez reanuda; ya caído (cinemática) Esc sigue yendo al menú (`scripts/pausa.gd`). Valores por defecto de Claude que Tomás puede cambiar: **(a) Opciones** (`scripts/opciones.gd`, `user://opciones.cfg`): volumen general, música y efectos (buses «Musica» y «Efectos»), pantalla completa, idioma y **teclas** (se cambia la letra de acelerar, frenar, izquierda, derecha, pito y mapa; las flechas y el espacio quedan siempre; no deja repetir tecla). Se abren desde el menú y desde la pausa. **(b) Idiomas**: español e inglés; claves = texto en español en `localization/pantallas.csv` (menús) y `localization/textos.csv` (juego); los platos, nombres de clientes, calles y la jerga del domiciliario se quedan en español. **(c) Advertencia** de contenido al abrir, saltable a los 2 s. **(d) Créditos** que suben a 44 px/s: Tomás como creador, herramientas libres, la fuente y ~~la nota de uso privado de D21~~ las licencias y el enlace al repo (D32). **(e)** El menú suma OPCIONES y CRÉDITOS. **(f)** El tema común sigue en `scripts/ui.gd` (no en un `.tres`, §5): hace lo mismo y ya lo usan todas las pantallas. |
| D30 | 30/09/2026 | **F6 aprobada por Tomás** («listo, perfecto») y **F7 hecha por Claude en un loop** («continúa con F7 y termínala»). Valores por defecto de Claude que Tomás puede cambiar: **(a)** versión **1.0.0** en `project.godot` (`config/version`), que va al `.exe`, al zip y al log. **(b)** `.exe` de Windows de 64 bits con el PCK dentro, icono propio (`tools/gen_icono.py`: la caja térmica del logo) y datos de versión a nombre de Tomás; se exporta **también desde la nube** con las plantillas oficiales 4.7.2 (suma SHA-512 comprobada), así que las plantillas del PC solo hacen falta para `tools/build.ps1`. **(c)** `tools/build.sh` (nube/CI) y `tools/build.ps1` (Windows) hacen lo mismo: licencias → importar → pruebas → exportar → **arranque con `--prueba-arranque`** (el juego abre menú, taller y 6 s de calle con la partida guardada sin tocarla, escribe versión, fps y `trucos=false` en el log y se cierra) → zip con `LEEME.txt` (`docs/entrega/`), licencias y `OFL.txt`. ~~**(d)** Es **solo para uso privado** (D21): lo dice el LEEME; no se publica en ningún lado.~~ (sustituido por D32). **(e)** Borrador del clip para TikTok grabado con el Movie Maker de Godot (`tools/clip.gd`, `tools/clip.sh`, horizontal y vertical en MP4); el clip de verdad lo graba Tomás con OBS. **(f)** Que el CI exporte el `.exe` queda para cuando se fusione el CI del PR #2 (esta rama no tiene `.github/`). |
| D31 | 30/09/2026 | **El `.exe` va sin firma y Tomás lo prueba él mismo** («tú genera el .exe… yo lo ejecutaré manualmente… no voy a comprar la firma, no lo vamos a lanzar con Godot otra vez»). En su PC el **Control inteligente de aplicaciones** de Windows 11 bloquea programas sin firma (CodeIntegrity 3077; las plantillas de exportación oficiales no vienen firmadas); qué hacer con eso lo decide Tomás. Se descartó el arreglo de Claude de repartir el Godot oficial firmado renombrado con el `.pck` al lado. Quedan de ese intento: la marca **`entrega`** en el ajuste de exportación (F9/F10 apagadas aunque el `.pck` corra en un binario de desarrollo), `GODOT_LICENSE.txt` y `GODOT_COPYRIGHT.txt` en el zip (Godot va dentro del `.exe`, MIT) y un aviso en el LEEME. `tools/build.ps1` se arregló para **PowerShell 5.1** (el stderr de Godot ya no lo detiene) y tiene `-SinProbar` para cuando Windows no deja abrir el `.exe`. |
| D32 | 01/10/2026 | **El repo se vuelve público, abierto a colaboradores, con versión web** (Tomás: «volver este que ya tenemos público… que tú acomodes todo… agregando lo de la página web»; aprobó juntar los PR #1–#3 en `main`, purgar del historial las imágenes de terceros y de referencia, y las licencias). **(a) Licencias**: código **MIT** (`LICENSE`), arte, sonido y música propios **CC BY 4.0** (`LICENSE-ASSETS.md`), letra OFL; `README.md` (español + inglés) y `CONTRIBUTING.md`. **(b) Motos del taller y caídas dibujadas de nuevo por código** (`tools/gen_motos_taller.py`, sustituye a D21); se borraron `tools/recortar_motos.py` y `docs/referencias/moto_*.png`, y la purga los quitó de todo el historial. **(c) Versión web** (Godot Web sin hilos, para que GitHub Pages sirva sin cabeceras especiales): `tools/build_web.sh` → `build/web-publico/`, probada en Chromium sin ventana con `tools/probar_web.mjs`; `tools/check_publico.py` impide publicar si hay algo sin licencia o de `docs/` en el `.pck`. En el navegador no hay botón Salir, **P** también pausa (Esc saca de la pantalla completa) y perder el foco pausa la partida; las opciones y la plata se guardan en el navegador. **(d) GitHub Pages** desde `main` con `.github/workflows/web.yml` (al principio iba apagado tras la variable `PAGES_ACTIVO`; desde el 02/10/2026 publica en cada push a `main`). **La visibilidad pública, Pages y la rama por defecto los cambia Tomás en Settings.** Valores por defecto de Claude que Tomás puede cambiar: MIT y CC BY 4.0, la regla «nada sobre personas reales con nombre propio» de CONTRIBUTING. |
| D33 | 02/10/2026 | **El repo se renombra a `martinotomo/DELIVERY-EXPRESS-VENECA`** (lo hizo Tomás en Settings; GitHub redirige el nombre viejo). La versión web queda en https://martinotomo.github.io/DELIVERY-EXPRESS-VENECA/ (la exportación usa rutas relativas, así que no depende del nombre). README, créditos y LEEME apuntan al nombre nuevo. El juego sigue llamándose Delivery Express (D14). |
| D34 | 02/10/2026 | **Arreglos de la versión web tras la prueba de Tomás** («no suena nada… tarda unos 10 segundos… la E con tilde se ve horrible… el mapa no ha terminado de cargar»). **(a) Sonido**: en el navegador Godot usaba por defecto el mezclador de muestras, que no conoce los buses «Musica» y «Efectos» que crea `opciones.gd` en tiempo de ejecución, y todo salía mudo; ahora `audio/general/default_playback_type.web=0` (mezclador normal) y `tools/probar_web.mjs` mide el volumen real que llega a los parlantes (`build_web.sh` falla si el menú no suena). **(b) Pantalla de carga** (`scripts/carga.gd`): al darle Jugar el director la muestra antes de armar la ciudad (`main.pantalla_carga`), y la calle la deja encima mientras **precalienta** (`recorrido.precalentar`): dibuja todo una vez (4 direcciones × sol/farola, y una muestra de peatones, carros, perros, charcos y la moto caída) y espera 6 fotogramas rápidos seguidos (tope 25 s); mientras tanto la partida no corre. Barra roja y un consejo del domiciliario. Las pruebas lo apagan salvo `test_web`. **(c) Letra «Delivery Press»** (`tools/gen_fuente.py`): Press Start 2P con Á É Í Ó Ú Ü Ñ del alto de las demás mayúsculas y la tilde de 1 px encima; renombrada porque la OFL reserva el nombre «Press Start 2P». |
| D35 | 02/10/2026 | **Pantalla de carga que se lee y calle precargada** (Tomás: «la pantalla de carga está tardando demasiado… que sepa cómo pierde… que carguen cosas en segundo plano durante el menú… que dure entre 5 a 10 segundos sí o sí»). **(a)** La carga dice **qué te mata** (andén a más de 11 km/h, curva a fondo, hueco a más del 80 %, perro a más del 60 %, bus o camión o de frente a más del 80 %) y **qué te cuesta** (peatón = sin propina, carro despacio, frenazo o hueco despacio riegan el pedido, motor fundido, aceite y charco), más «Morir no te quita la plata» (`scripts/carga.gd`; si cambian las reglas en `partida.gd`, `moto_logic.gd` o `motos.gd`, se cambia ahí). **(b)** Dura **mínimo 6 s al darle Jugar desde el menú y 3 s al reintentar** (valor de Claude: repetir 6 s tras cada caída cansa) y **máximo 10 s**, medido con el reloj de verdad (Godot recorta el delta de los fotogramas lentos y la carga no soltaba). **(c)** Mientras se está en el menú o en el resultado, el director **arma la calle detrás y la precalienta sin verse** (`main.precargar_en_menu`, nodo `Reserva`); al darle Jugar se usa esa. Si cambió la moto, sus mejoras, el final o el idioma, se rehace. **(d)** La ciudad ya no se arma dos veces al entrar (`recorrido.partida` se crea en `_ready`). |

**Pendiente de definir con Tomás** (no inventarlo): la duración
objetivo (los precios de D13 suponen ~40 min hasta la Ninja), el nombre de la moto intermedia (NKD 125 es provisional), la definición de «terminado» y los no-objetivos.

---

## 1. Alcance

- **Un solo chiste, bien ejecutado.** Un juego pequeño terminado vale más que tres grandes empezados.
- El primer día se escribe aquí la **definición de «terminado»** (arranca, se entiende sin
  explicación, se puede volver a jugar, hay `.exe` probado en otro PC, licencias registradas) y los
  **no-objetivos** (multijugador, guardado de partida, mandos, más de dos idiomas, Mac/Linux…).
  Lo que no acerque a «terminado», no se hace.

## 2. Método de trabajo

1. **Fases con puerta de salida, y ninguna se abre sin orden explícita de Tomás:**
   F0 andamiaje y pruebas → F1 prototipo gris del chiste → F2 dirección visual (Claude Design) →
   F3 arte y audio por código → F4 menú, opciones, idiomas, créditos → F5 `.exe` probado fuera.
2. **Primero un plan completo** (sin crear archivos), presentarlo y **parar** hasta tener la orden.
3. **Cada fase acaba en algo que Tomás juega.** En los juegos anteriores cada prueba cambió algo.
4. **El prototipo gris va primero:** si el chiste no funciona con rectángulos grises, el arte no lo
   salva.
5. **Las pruebas son el contrato y se escriben primero** (en rojo, luego el código que las pasa).
   Probarlas al revés: rompiendo algo a propósito, tienen que ponerse en rojo.
6. **«Haz un loop»** = iterar sin preguntar hasta terminar, probado y en commits, y al final dejarle
   el juego listo para jugar.
7. **Verificar el efecto, no el código de salida.** Un comando que devuelve 0 no es evidencia; lo
   es el archivo, el log, la captura, `git status`.
8. **Cerrar cada entrega con una tabla** de qué se hizo (con evidencia: commit, archivo, prueba) y
   qué falta (con el porqué). Respuestas directas a preguntas concretas.

## 3. Flujo nube + local

| Dónde | Qué se hace |
|---|---|
| **Nube** (Claude Code sobre este repo) | Plan, código GDScript, escenas `.tscn`, generadores de assets en `tools/`, pruebas, `CLAUDE.md`. Cada cambio en una rama y un PR; `main` siempre jugable. Si el contenedor puede instalar Godot 4.7.2 para Linux en modo headless, las pruebas se corren también aquí antes de pedir revisión. |
| **Local** (PC de Tomás, Windows 11; Claude puede trabajar ahí con Remote Control, D6) | `git pull` de la rama → `godot --headless --path . --import` → pruebas → jugar. Exportar el `.exe` (las plantillas de exportación están en ese PC). |
| **Godot** (local) | Jugar cada fase y abrir el editor solo para mirar; los cambios se hacen en el repo. |
| **Audacity** (local) | Escuchar, recortar o revisar a oído el audio generado por código. Si se graba o edita algo a mano, el archivo entra con su fila en `LICENSES.md`. |
| **OBS** (local) | Grabar las partidas de prueba para enseñar qué falla (un clip vale más que una descripción) y, al final, el tráiler. |

Reglas del flujo:
- **Lo que se prueba en local se reporta con evidencia:** captura, clip de OBS, o la salida de la
  terminal pegada tal cual.
- **Nada que se cambie en local se queda sin subir.** Si Tomás toca algo en el editor, se hace
  commit y push para que la nube lo vea.
- En Windows, **el repo fuera de OneDrive** (corrompe `.git` y `.godot/`).
- En local, Godot se llama por su ruta completa (winget no crea el alias `godot` sin admin):
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- **No actualizar nada a mitad del juego:** ni Godot ni los drivers de NVIDIA (serie 50).

## 4. Godot sin editor (headless): reglas que costaron caro

| Regla | Qué pasa si se ignora |
|---|---|
| **Prohibido `class_name`**; cargar siempre con `preload("res://...")` | Sin la caché `.godot/` el nombre global no existe y todo revienta en headless |
| **Importar antes de nada:** `godot --headless --path . --import` | PNG, WAV, TTF y CSV no cargan; el error dice «recurso nulo», nunca «falta importar». Obligatorio en copia nueva (y cada `git clone` lo es) o al añadir assets |
| Pixel art 2D: filtro de texturas `nearest` en el proyecto y `texture_filter` nearest en los nodos | Godot suaviza y el pixel art se ve borroso |
| Fuente pixelada: `antialiasing=0` en su `.import` | Letras grises y sucias |
| `.gitattributes` con `* text=auto eol=lf` desde el primer commit | Windows mete CRLF y todo sale «modificado». Arreglo: `git add --renormalize .` |
| Los `.uid` y los `.translation` **sí** van al repo | Godot los regenera y ensucia cada `git status` |
| CSV de traducción: entrecomillar las filas con comas | Esa fila no se traduce y ninguna prueba lo ve |
| Godot 4.7 ya no genera el ejecutable de consola al exportar | Para comprobar que el `.exe` arranca, lanzarlo con `--log-file` y leer ese archivo |
| Escribir archivos de texto con la herramienta de escritura o un heredoc con delimitador entrecomillado, **nunca con cadenas de Python** | Se colaron bytes de control (`\a`, `\b`) y rutas de Windows (`\U`) rompieron scripts |
| Pasos que dependen entre sí, **en serie** | El build y su arreglo lanzados a la vez se pisaron |

## 5. Arquitectura que se puede probar

- **Un solo director** (`scripts/main.gd`) instancia y destruye pantallas; nadie más cambia de
  escena. Una prueba comprueba que solo hay una pantalla viva.
- **Lo que sobrevive a los cambios de pantalla vive en el director** (la música del menú, por
  ejemplo; si vive en el menú, se corta al entrar en Opciones).
- **Cambios de pantalla desde una señal:** con `call_deferred`.
- **La lógica fuera de las escenas:** todo lo que tiene estado (secuencias, tutorial, estado de la
  partida, físicas de la moto que se quieran probar, opciones, créditos) va en un `RefCounted` con
  `advance(delta)` que no depende de fotogramas, señales (`finished`, `prompt_changed`…) y métodos
  como `skip()` / `is_finished()`. La escena solo llama a `advance(delta)` desde `_process`. Así una
  prueba hace `x.advance(1000.0)` y comprueba al instante (el Juego 1 tuvo ~450 comprobaciones en
  menos de un minuto).
- **Datos editables en un solo sitio:** el nombre del juego vive solo en `project.godot`
  (`config/name`); menú, arranque y build lo leen de ahí.
- **Resolución retro sin shaders:** mundo a baja resolución (p. ej. 320×180) y la interfaz aparte a
  640×360 para que el texto se lea; `stretch/mode="viewport"`, `scale_mode="integer"`, ventana
  1280×720. Escalan entero a 1080p, 1440p y 4K.
- **Idiomas (es/en):** `localization/textos.csv` con la clave = el texto en español. En nodos
  `tr()`; en `RefCounted`, `TranslationServer.translate()` y reaccionar a
  `NOTIFICATION_TRANSLATION_CHANGED`. Las pruebas fijan `TranslationServer.set_locale("es")`.
- **Opciones** (volumen, pantalla completa, idioma) en `user://opciones.cfg`, aplicadas al momento.
- **Tema común** de botones y paneles en un solo `.tres`.
- **Créditos** que suben solos (~44 px/s), saltables con ESPACIO, con la pista de salto sobre una
  franja de fondo propia.

## 6. Pruebas

- `tests/run_tests.gd`, corredor propio: `godot --headless --path . -s res://tests/run_tests.gd`,
  **sale 0 solo si todo pasa**. Vigilante de 150 s para que un bloqueo no cuelgue la sesión, filtro
  `--solo=nombre` y comprobación inicial de que los assets están importados.
- **Lo visual se verifica con capturas**, montadas desde la F1: un script lanza Godot en ventana,
  lleva la escena a un momento concreto y monta una hoja de contactos con Pillow. Trampa: parar el
  proceso (`set_process(false)`), posicionar, esperar un fotograma y **entonces** capturar. Mirar
  ampliado y a tamaño real, en los dos idiomas y en varios momentos de cada animación.
- **Lo sonoro se mide con números** (`numpy`/`scipy`) contra umbrales escritos **antes** de
  generar: energía por bandas, duración, RMS, final en silencio, costura del bucle sin clic.
- **Las métricas no sustituyen mirar:** una puerta comprueba lo que le pides, no lo que quieres
  decir.
- Al reutilizar código de juegos anteriores: lista de lo que **no** se copia y una prueba que busque
  términos del juego anterior en todo lo que entra.

## 7. Assets generados por código

Cada textura, sprite, sonido y logo sale de un script de Python en `tools/` que se puede volver a
correr (Python 3.12 con `numpy`, `scipy`, `Pillow`). Iterar es gratis, no hay licencias que
auditar, el repo pesa poco y no hace falta dibujar. Tomás no usa programas de dibujo.

- **Paleta fija** en `tools/paleta.py`: única fuente de verdad del color; todo se cuantiza contra ella.
- **Pixel art:** ruido con `numpy` → cuantizar a la paleta (distancia euclídea) → *dithering*
  ordenado Bayer 4×4. **Semilla fija por archivo.**
- **Formas:** nada de primitivas sueltas encajadas (se ven descoyuntadas) ni de formas perfectas
  (delatan lo generado). Tomás rechaza lo genérico y lo simplón: quiere forma y volumen. Para las
  motos y los domiciliarios, siluetas continuas y reconocibles.
- **Audio:** capas sumadas (golpe grave que cae rápido + cuerpo de ruido filtrado + cola), **fundido
  de coseno de ~0,15 s al final**, y **paso-alto a ~90 Hz** (los altavoces de portátil no suenan por
  debajo de 80 Hz). Definir cada sonido con números antes de generarlo. A Tomás le gusta lo épico,
  tipo tráiler.
- **Nada de audio, imágenes, logos ni marcas con derechos.** Las motos se evocan (silueta, colores
  genéricos) sin logotipos reales; si hace falta un nombre, se decide con Tomás como decisión Dn.

### Claude Design (F2)

| Pieza | Formato para Godot |
|---|---|
| Paleta (16–32 colores) | Hex en texto + PNG de 1 px por color → `tools/paleta.py` |
| Tipografía | Nombre exacto y licencia (OFL/CC0); el `.ttf` se baja y se registra |
| Logo | PNG transparente a 1280×720 y 640×360 |
| HUD y pantallas | Maqueta PNG a 640×360 + piezas a 1× sin suavizado + márgenes 9-slice + hex y tamaños de letra |

Claude Design no es de código abierto (D5): es opcional. La alternativa libre es definir la paleta
y las maquetas por código o en Krita/LibreSprite. No pedirle pixel art de juego (mejor por código). A Tomás darle paso a paso y los prompts en `.txt`.
Guardar referencias en `docs/claude_design/`.

## 8. Licencias y declaración de IA

- `assets/LICENSES.md`: una fila por asset (fuente, autor, licencia, URL, fecha). **Ningún asset
  entra sin su fila.** Si algo es de terceros, preferir CC0 (Kenney).
- `assets/AI_DISCLOSURE.md`: todo lo generado con IA generativa (Claude Design, etc.). Lo generado
  por scripts deterministas se anota aparte por transparencia. El código escrito con asistentes no
  se declara.
- `tools/check_entrega.py` comprueba que ambos registros cubren todo `assets/`, probado en negativo.
- Las ideas y mecánicas no tienen copyright; la expresión sí. Nada calcado de otras obras.
- **Humor negro:** advertencia de contenido al inicio, saltable tras un par de segundos. Temas
  delicados o personas reales se deciden explícitamente con Tomás y se anotan como decisión.

## 9. Build y entrega del `.exe` (en local)

- Plantillas de exportación de **la misma versión exacta** (4.7.2, solo Windows) en
  `%APPDATA%\Godot\export_templates\4.7.2.stable`.
- `export_presets.cfg` con PCK incrustado (un solo `.exe`), icono `.ico` generado por
  `tools/gen_icono.py`, nombre y versión.
- `tools/build.ps1` para en el primer fallo: licencias → importar → pruebas → exportar → comprobar
  arranque (con `--log-file`) → `.zip`.
- Probar en limpio: el PC de otra persona, una VM, o el propio portátil forzando la GPU integrada
  (*Configuración → Pantalla → Gráficos → Ahorro de energía*). SmartScreen avisará «editor
  desconocido»: *Más información → Ejecutar de todas formas*, o desbloquear el zip antes de extraer.
- Steam queda aplazado; si se retoma, ver los contextos originales (100 USD, 30 días de espera,
  5–6 semanas en total, W-8BEN y retención del 30 % desde Colombia).

## 10. Errores ya cometidos

1. Una frase que debía **sustituir** a otra se añadió además en otra pantalla: cuando algo dice
   «sustituye a X», confirmar qué pasa con X.
2. Dar por bueno un paso porque el comando devolvió 0.
3. Personaje de primitivas sueltas → rehecho con formas continuas.
4. Audio con demasiados graves (inaudible en portátil) y demasiado largo → medir antes.
5. Música ligada a una escena que se destruye.
6. Fila de CSV con coma sin comillas.
7. Texto de interfaz encima de contenido en movimiento → darle fondo propio.
8. El script de capturas llegó tarde (F2); va en la F1.

## 11. Chuleta de comandos

```bash
# importar assets (copia nueva, clone o al añadir PNG/WAV/TTF/CSV)
godot --headless --path . --import
# todas las pruebas (0 si pasan); una sola suite: ... run_tests.gd -- --solo=nombre
godot --headless --path . -s res://tests/run_tests.gd
# arrancar unos fotogramas sin ventana
godot --headless --path . --quit-after 30
# licencias y registro de IA
python tools/check_entrega.py
# .exe completo (local, Windows)
powershell -ExecutionPolicy Bypass -File tools\build.ps1
```

---

*Un juego de un solo chiste, terminado, vale más que tres empezados.*
