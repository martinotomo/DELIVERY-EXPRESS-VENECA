# Documento de diseño — Delivery Express

**Autor:** Tomás Ardila Marín
**Versión:** 0.4 — 30/09/2026 (tres motos con dos mejoras cada una, el dinero no se pierde al morir, menú de inicio y aviso de derrape más discreto)
**Estado:** aprobado por Tomás como base. Las decisiones tomadas están en §15.

---

## 1. El juego en tres frases

Eres un domiciliario venezolano que reparte en moto por una ciudad latinoamericana grande, visto
en primera persona desde el manubrio. Recoges pedidos en restaurantes y los entregas en casas y
edificios lo más rápido posible, pasando rozado entre carros, buses y peatones. Si giras en una
esquina más rápido de lo que aguanta tu moto, te montas en el andén, te caes y sale la cinemática
de siempre: **«Has muerto al girar demasiado rápido en la esquina, tu fe era más grande que el
agarre de tu {moto}»**.

**Título:** *Delivery Express* (D13).

**El chiste central:** la prisa (propina, estrellas, tiempo prometido) contra el agarre real de una
moto de bajo cilindraje. Mejorar de moto no te salva: solo te deja llegar más rápido a la misma
esquina.

---

## 2. Referencias

### 2.1 La vista: mods de moto para Doom

Las dos imágenes que mandó Tomás son mods de moto para *Doom*: cámara en primera persona, el
manubrio y las manos con guantes abajo en primer plano, el velocímetro en el centro, calles con
edificios de texturas pixeladas, letreros verdes de vía, y el HUD de *Doom* con números rojos.

De ahí se toma:

| Elemento | Qué se toma |
|---|---|
| Cámara | Primera persona a la altura del manubrio |
| Manubrio | Sprite 2D grande abajo, con manos, espejos y tablero. **Cada moto tiene su propio manubrio y tablero**, así se nota en pantalla con qué moto vas |
| Mundo | Estilo «2,5D» de los 90: calles y edificios en 3D muy simple con texturas pixeladas, y carros, peatones y objetos como sprites planos que siempre miran a la cámara |
| HUD | Números grandes rojos pixelados como en *Doom*: dinero, tiempo, estrellas, gasolina |

### 2.2 La cinemática de muerte: el meme

Las cinco imágenes de contexto son el mismo meme con distinta moto (Yamaha BWS 125, Bajaj Boxer
CT 100, AKT NKD 125, Yamaha Crypton Fi y Kawasaki Ninja 300): el motociclista tendido boca abajo
con casco de colores y jean azul, charco de sangre pixelado, **la moto intacta y parada** al lado
(la moto sobrevive, tú no), caja de texto negra con borde blanco, logo de la marca debajo y «Pulsa
**[START]** para continuar». La cinemática del juego es esa misma composición, pero en la esquina
de la ciudad donde te caíste.

> Las referencias (capturas de TikTok y de mods de *Doom*) son de otros autores y no entran al
> juego: todo se redibuja desde cero (ver §12).

---

## 3. Alcance

La ciudad grande es la parte más ambiciosa del proyecto y la que más fácil se sale de las manos.
Para que se pueda terminar:

- **La ciudad se genera por código**, no se construye a mano: una cuadrícula de manzanas con
  edificios de caja texturizados, andenes, esquinas y semáforos. Cada zona cambia texturas, altura
  de edificios y tráfico (§6).
- **Tres motos** con dos mejoras cada una (§7), en una ciudad de 40 × 80 cuadras (§6).
- **Duración objetivo:** unos 40 minutos para llegar a la Ninja 300 y ver el final. Cada pedido dura
  entre 1 y 3 minutos.

### 3.1 Definición de «terminado»

1. Arranca, se entiende sin explicación y se puede jugar de principio a fin.
2. Las tres motos y sus mejoras se pueden conseguir, y cada moto se siente y se ve distinta
   (manubrio y tablero propios).
3. Cada caída muestra la cinemática del meme con la moto correcta y su nombre.
4. ~~Las voces del domiciliario suenan al recoger, entregar, casi chocar y caerse.~~ Descartado (D28).
5. Menú, opciones que se recuerdan (volumen de música y efectos, pantalla completa, idioma),
   créditos.
6. Español e inglés.
7. `.exe` de Windows probado en otro PC.
8. `assets/LICENSES.md` y `assets/AI_DISCLOSURE.md` cubren todos los assets.

### 3.2 No-objetivos

Multijugador, bajarse de la moto y caminar, peleas o armas, personalización de la moto, varias
ciudades, clima dinámico complejo, policía que persigue, guardado de varias partidas, Mac/Linux, móvil.

---

## 4. Bucle principal

```
 ┌─► 1. PEDIDO: la app ofrece un pedido (restaurante, cliente, tiempo prometido, pago)
 │   2. RECOGER: ir al restaurante marcado
 │   3. ENTREGAR: cruzar la ciudad. Casi-choques dan propina extra y comentario
 │   4a. ENTREGA: pago + propina + estrellas ─► 5
 │   4b. CAÍDA: cinemática del meme ─► «Pulsa START» ─► reaparece en el restaurante
 │   5. GARAJE: gastar en mejoras (exosto, motor) o ahorrar para la siguiente moto
 └───────────────────────────────────────────────────────────────┘
```

**El dinero no se pierde al morir.** Se va acumulando con cada entrega y la caída solo cuesta el
pedido en curso (no se cobra) y el tiempo de volver. Así morir es el chiste, no un castigo.

El dinero sirve para dos cosas, las dos en el garaje: **mejorar la moto actual** o **comprar la
siguiente** (§7). Llegar a la Ninja 300 toma unos 19 pedidos.

---

## 5. Conducción

### 5.1 Vista y control

Primera persona desde el manubrio. Controles de teclado:

| Acción | Teclado |
|---|---|
| Acelerar | W / ↑ |
| Frenar | S / ↓ |
| Girar | A D / ← → |
| Pito | Espacio (suena ridículo y el domiciliario a veces grita algo con él) |
| Ver el mapa / la app | Tab |
| START / pausa | Enter / Esc |

Al girar, la cámara se inclina un poco y el manubrio gira en pantalla. No hay ratón para mirar:
miras hacia donde va la moto, como en los mods de referencia.

### 5.2 La regla de la esquina (el andén)

Cada moto tiene un **radio de giro mínimo a cada velocidad**, que sale de su agarre:

```
v_segura_giro = √(agarre_moto × factor_superficie × radio_de_giro)
```

- Si giras por debajo de esa velocidad, la moto sigue la curva.
- Si la pasas, la moto se abre hacia afuera: la trayectoria real es más amplia que la que pediste.
- Si al abrirse **la rueda toca el andén** (el bordillo) a más de cierta velocidad, **te caes**:
  cinemática de muerte.
- Tocar el andén despacio solo da un golpe y el domiciliario se queja.

`factor_superficie`: seco 1,0 · pavimento roto 0,8 · mojado 0,7 · aceite o arena 0,5. Las esquinas
peligrosas (mojadas, con aceite) se ven distintas en el suelo.

Así el jugador aprende a frenar antes de cada esquina. Con una moto nueva la velocidad máxima sube
más que el agarre, así que las esquinas hay que volver a aprenderlas.

**El aviso de derrape** (cuando la moto se empieza a ir de lado):

- Va **abajo a la izquierda y pequeño**, no en el centro, para que no tape la calle.
- **No es tan sensible:** solo salta por encima del **75 % de la velocidad máxima** de la moto y
  con el manubrio sostenido a tope. A baja velocidad girar a tope no hace irse de lado.
- Además del aviso, el manubrio tiembla un poco y suena el chirrido de la llanta, para que se
  sienta sin tener que leerlo.

### 5.3 Casi-choques

Pasar a menos de ~1 m de un carro, bus o peatón a buena velocidad cuenta como **casi-choque**:

- suma a una racha de «fe» que da propina extra al entregar;
- el HUD muestra la racha como un número que crece.

Chocar de frente con un carro o bus también es caída (con su propia frase en la cinemática).

### 5.4 El pedido

- Tipos de pedido que cambian cómo se conduce: **hamburguesa** (normal), **sopa o sancocho** (si
  frenas en seco se riega y baja la propina), **torta de cumpleaños** (igual, más delicada),
  **pedido de licor** (pesa más: frena peor).
- **Pago** = tarifa base + propina. La propina sube con la racha de casi-choques y baja con el
  retraso y con el estado del pedido.
- Al entregar, el cliente pone de 1 a 5 estrellas con un comentario en la app (humor).

### 5.5 Variantes de caída

Todas usan el formato del meme. Borradores:

| Causa | Frase |
|---|---|
| Esquina demasiado rápido (andén) | «…tu fe era más grande que el agarre de tu {moto}.» (la principal) |
| Hueco | «…el hueco llevaba ahí más tiempo que tu {moto}.» |
| Bus | «…el bus también tenía fe.» |
| Perro que se atraviesa | «…el perro sobrevivió. El pedido no.» |
| Lluvia | «…tu fe era impermeable. Tus llantas no.» |
| Contravía | «…la contravía era un atajo. Para el más allá.» |

El humor apunta a la fe y a la prisa, no a burlarse de las víctimas reales.

---

## 6. La ciudad

Ciudad inventada **parecida a Bogotá**, pero más pequeña: **40 calles de ancho por 80 de largo**.
Como en Bogotá, las **calles** van de oriente a occidente y las **carreras** de norte a sur, numeradas,
y las direcciones son del tipo «Calle 45 # 12-30». Los cerros quedan al oriente, como referencia
para orientarse.

**Que no se vea cuadriculada:**

- Las cuadras **no son todas iguales**: unas más largas, otras más cortas (entre ~0,6 y 1,6 veces la
  cuadra normal), con semilla fija para que la ciudad sea siempre la misma.
- Algunas calles se cortan o no continúan, hay diagonales y avenidas anchas que rompen la cuadrícula,
  glorietas y algunos parques que ocupan varias cuadras.
- Cada zona cambia texturas, altura de edificios y tráfico.

**Tamaño y rendimiento:** con cuadras de ~100 m la ciudad mide unos 4 × 8 km; cruzarla de punta a
punta toma varios minutos incluso con la Ninja. Se genera por código y **solo se dibujan las
cuadras cercanas** a la moto (por trozos), para que corra en PCs modestos.

| Zona | Moto con la que se abre | Cómo se ve | Peligros |
|---|---|---|---|
| **Barrio** (inicio) | Bwis 125 | Casas de ladrillo de 2–3 pisos, tiendas, calles estrechas | Perros, huecos, niños jugando fútbol |
| **Centro** | Bwis 125 | Edificios viejos, buses, vendedores ambulantes | Buses, peatones, trancones |
| **Zona industrial** | NKD 125 | Bodegas, tractomulas, calles anchas | Aceite en el piso, tractomulas |
| **Avenida / autopista** | NKD 125 | Avenida de varios carriles, puentes, letreros verdes de vía | Velocidad alta, esquinas de salida cerradas |
| **Zona rica / loma** | Ninja 300 | Edificios altos de vidrio, curvas de montaña con vista a la ciudad (la curva del meme) | Curvas cerradas, lluvia |

La columna «se abre» es de dónde salen los pedidos: con cada moto aparecen pedidos más lejos y
mejor pagados. Se puede andar por toda la ciudad desde el principio.

- **Minimapa:** en una esquina de la pantalla, siempre visible, girando con la moto. Marca la ruta
  hasta el restaurante o el cliente (el camino más corto por las calles, recalculado si te desvías),
  como un GPS. Con Tab se abre el mapa completo en la app.
- **Letreros:** en cada esquina, el número de la calle y la carrera; los letreros verdes de vía
  nombran las zonas, como en la referencia.
- **Tráfico:** carros y buses siguen carriles simples; peatones cruzan en esquinas. Todos son
  sprites planos que miran a la cámara.
- **Día y noche:** la ciudad pasa de día a noche y de noche a día **cada 10 minutos**, con una
  animación continua a lo largo de esos 10 minutos (el sol baja, el cielo cambia de color, se
  prenden el alumbrado naranja, las ventanas y las farolas de los carros). Un ciclo completo dura
  20 minutos. De noche se ve menos y las farolas de las motos importan (la NKD ve más lejos).

---

## 7. Las motos y sus mejoras

Solo **tres motos**, para que el juego no se alargue. Cada una tiene **dos mejoras**: **exosto** y
**motor**.

| # | Moto | Personalidad | Manubrio y tablero |
|---|---|---|---|
| 1 | **Yamaha Bwis 125** (inicial) | Scooter de llantas gordas, estable pero lenta | Manubrio alto con carenaje, tablero redondo |
| 2 | **AKT NKD 125** | Clásica de domicilios, farola grande | Farola redonda visible abajo, velocímetro redondo |
| 3 | **Kawasaki Ninja 300** (final) | La soñada, bicilíndrica, mucho más rápida | Semimanubrios bajos, tablero digital, parabrisas |

### 7.1 Reglas de progresión

1. **La moto mejorada es la base de la siguiente:** las mejoras suben la moto actual, pero **una moto
   con las dos mejoras sigue siendo peor que la siguiente de fábrica**, en velocidad máxima y en
   aceleración. Una prueba automática lo comprueba con los valores del juego.
2. **Las mejoras suben velocidad y aceleración, no el agarre.** Llegas más rápido a la misma
   esquina: el chiste se mantiene.
   - **Exosto:** sobre todo aceleración (y suena más duro).
   - **Motor:** sobre todo velocidad máxima.
3. **Qué se puede comprar:** exosto y motor de la moto actual (en cualquier orden) o saltar
   directo a la siguiente moto si alcanza el dinero. Las mejoras no pasan a la moto nueva.
4. **Precios:** ver la tabla de §7.2. Un pedido paga unos $10.000.

### 7.2 Valores

Los números viven en un solo archivo del juego, `scripts/motos.gd`, y **ese archivo manda**: si se
afinan jugando, esta tabla se actualiza después. Valores actuales del prototipo:

| Moto | Precio | Exosto | Motor | Vel. máx. de fábrica | Vel. máx. con las dos mejoras |
|---|---|---|---|---|---|
| Bwis 125 | (inicial) | $8.000 | $12.000 | 90 km/h | 101 km/h |
| NKD 125 | $40.000 | $15.000 | $22.000 | 110 km/h | 122 km/h |
| Ninja 300 | $90.000 | $25.000 | $35.000 | 144 km/h | 162 km/h |

Con unos $10.000 por pedido, llegar a la Ninja toma unos 19 pedidos (≈40 minutos).

En el garaje cada moto muestra sus barras y, como chiste, una barra de **FE** que siempre es la más
larga.

---

## 8. ~~Las voces del domiciliario~~ (descartado, D28)

Tomás quitó las voces del juego el 30/09/2026: no se graban, no se sintetizan y no quedan como
pendiente. Solo Tomás puede volver a pedirlas. Los mensajes de texto en pantalla se mantienen como
están.

---

## 9. Pantallas

1. **Advertencia de contenido** (humor negro, sangre pixelada, muertes de tráfico), saltable tras
   2 s.
2. **Menú de inicio:** el título del juego sobre la vista en primera persona con la moto parada en
   una esquina del barrio (y el ciclo de día y noche corriendo de fondo). Opciones: **Jugar**,
   **Garaje** y **Salir** (Opciones y Créditos se añaden en la F6).
3. **App de pedidos:** celular pixelado con el pedido, el pago, el tiempo y el minimapa.
4. **Conducción** (§5), con el HUD estilo *Doom*.
5. **Entrega:** pago, propina, estrellas y comentario del cliente.
6. **Cinemática de muerte:** la ilustración del meme en la esquina donde caíste, la frase con el
   nombre de la moto y «Pulsa [START] para continuar».
7. **Garaje:** la moto actual con sus dos mejoras, la siguiente moto con su precio y el dinero
   acumulado.
8. **Opciones, créditos.**

Un único director (`main.gd`) cambia entre pantallas, como en los juegos anteriores.

---

## 10. Dirección de arte

- **Técnica:** 3D muy simple en Godot (calles y edificios de caja) dibujado a baja resolución, con
  todo lo demás en sprites 2D. Es la misma base del juego 1 (MOUSTACHE POV era un *boomer shooter*
  en primera persona): se reutilizan el controlador en primera persona, el `SubViewport` de baja
  resolución y el pixel art sin suavizado.
- **Resolución:** mundo a 320×180 (el look grueso de *Doom*), interfaz y cinemáticas a 640×360.
  Ambas escalan entero a 720p, 1080p, 1440p y 4K.
- **Paleta fija** (~32 colores) en `tools/paleta.py`: ladrillo, concreto, asfalto, verdes de los
  letreros, naranjas del alumbrado de sodio, rojos del HUD y la sangre, y el color propio de cada
  moto (azul claro Bwis, gris NKD, verde lima Ninja).
- **Assets por código** (paleta → cuantizar → *dithering*): texturas de fachadas, asfalto, andenes,
  letreros; sprites de carros, buses y peatones.
- **Los manubrios** son el asset más visible y el más difícil: tres sprites grandes con manos y
  tablero. Primero por código (polígonos por piezas, rasterizados a la paleta); si no alcanza, se
  retocan a mano con LibreSprite o Krita.
- **Fuente:** pixelada con licencia OFL. Una estilo *Doom* para los números del HUD y una
  monoespaciada tipo la del meme para la caja de texto.
- Revisión con hojas de capturas automáticas desde la F1, a tamaño real y ampliadas.

---

## 11. Audio

Efectos y música sintetizados por código y definidos con números antes de generarse. El juego no
lleva voces (D28).

| Sonido | Descripción | Requisito medible (borrador) |
|---|---|---|
| Motor de cada moto | Tono que sube con las RPM. Bwis: zumbido de CVT; NKD: monocilíndrico «pum-pum»; Ninja: bicilíndrico agudo. El exosto mejorado suena más duro | Fundamental 30–250 Hz según RPM; paso-alto a 90 Hz; bucle sin clic |
| Frenazo | Chirrido de llanta | 0,4–1,0 s, ≥ 50 % de la energía sobre 1 kHz |
| Golpe con el andén | Golpe seco corto | ≤ 0,5 s |
| Caída | Golpe + metal arrastrándose + silencio | ≤ 1,5 s, final en silencio |
| Pito | Pito ridículo de moto pequeña | ≤ 0,5 s |
| Ciudad | Ambiente de tráfico, pitos lejanos | Bucle sin clic, bajito |
| Música de conducción | Ritmo latino en 8 bits (cumbia o salsa con sintetizador), bajito | −18 dB respecto a los efectos |
| Música de muerte | **Épica y trágica, exagerada** (el contraste es el chiste) | Acordes menores, entra con la cinemática |

---

## 12. Contenido, marcas y tono

- **Tono:** humor negro sobre la prisa y la fe del domiciliario, no burla de las víctimas ni de los
  venezolanos. Advertencia de contenido al inicio.
- **Marcas reales:** los modelos (Bwis, NKD, Ninja) y los logos (Yamaha, AKT,
  Kawasaki) son marcas registradas. Para un `.exe` entre amigos el riesgo es bajo; para publicar,
  mejor nombres parodia reconocibles («Yamajá Bwis», «Kawasuki Ninya 300») y logos inventados. Los
  nombres viven en un solo archivo de datos para cambiarlos con una línea.
- **App de domicilios:** una inventada (nombre provisional «RapiYa»), sin copiar la interfaz de
  ninguna real.
- **Referencias de *Doom*:** solo la idea de la vista. Nada de sus texturas, HUD, sonidos ni
  personajes; el HUD se diseña propio con números rojos pixelados.

---

## 13. Herramientas (todo de código abierto)

Es un proyecto de ocio, así que se usa software libre siempre que se pueda:

| Herramienta | Licencia | Dónde | Para qué |
|---|---|---|---|
| Godot 4.7.2 | MIT | PC y nube (headless) | Motor |
| Python 3 + numpy, scipy, Pillow | Libres | Nube y PC | Generar arte y audio, medir |
| Git + GitHub | GPL / servicio gratuito | Nube y PC | Código y versiones |
| Audacity | GPL | PC | Revisar el audio generado |
| OBS Studio | GPL | PC | Grabar partidas de prueba y tráiler |
| LibreSprite / Krita | GPL | PC | Solo si hay que retocar sprites a mano |
| Fuentes | SIL OFL | — | Interfaz |

Claude Code escribe el código en la nube desde el repositorio; lo que necesita ventana, sonido,
micrófono o programas del PC se hace en el PC de Tomás.

---

## 14. Plan de trabajo por fases

Cada fase termina en algo que Tomás juega en su PC con Godot. Ninguna fase empieza sin su orden.

| Fase | Qué sale | Criterio de salida |
|---|---|---|
| **F0** Andamiaje | Proyecto Godot 4.7.2 (Compatibility), `.gitattributes`, `.gitignore`, corredor de pruebas, `CLAUDE.md`, registros de licencias | Pruebas en verde en headless; arranca |
| **F1** Prototipo gris | Unas pocas cuadras de cajas grises (de distintos largos), moto en primera persona, regla de la esquina y el andén, caída con texto plano, script de capturas | Tomás juega y confirma que frenar antes de la esquina es divertido |
| **F2** Dirección visual | Paleta, fuentes, maqueta del HUD, un manubrio y la cinemática de muerte | Tomás aprueba el look |
| **F3** Ciudad | Generador de la ciudad de 40 × 80 cuadras irregulares con sus zonas, carga por trozos, minimapa con ruta, ciclo día/noche, tráfico y peatones | Se recorre de punta a punta sin errores ni tirones, y el minimapa lleva a cualquier dirección |
| **F4** Arte y audio | Texturas, los tres manubrios, cinemática ilustrada, motores, efectos, música | Capturas y medidas de audio aprobadas |
| **F5** Contenido | Pedidos, dinero acumulado, garaje con mejoras, casi-choques, final | Se juega de principio a fin |
| **F6** Menús | Menú de inicio, opciones, idiomas, créditos, advertencia | Lista de §3.1 casi completa |
| **F7** Entrega | `.exe` y `.zip` | Probado en otro PC |

---

## 15. Decisiones

### 15.1 Tomadas

| # | Decisión |
|---|---|
| D1 | Vista en primera persona tipo *Doom*: mundo de aspecto 2D con sprites, como en las imágenes de referencia |
| D2 | Ciudad parecida a Bogotá, 40 calles × 80 carreras, con cuadras de distinto largo para que no se vea cuadriculada |
| D3 | Minimapa que guía hasta el restaurante y el cliente |
| D4 | Día y noche cambian cada 10 minutos con una animación continua |
| D5 | ~~Las voces del domiciliario las graba Tomás~~ Anulada por D28 |
| D6 | Fases F0–F7 como en §14 |
| D7 | Todo con herramientas de código abierto |
| D8 (30/09) | Solo tres motos: Bwis 125 → NKD 125 → Ninja 300 |
| D9 (30/09) | Dos mejoras por moto, exosto y motor. La moto con las dos mejoras sigue siendo peor que la siguiente de fábrica |
| D10 (30/09) | El dinero se acumula y no se pierde al morir |
| D11 (30/09) | Menú de inicio |
| D12 (30/09) | El aviso de derrape va abajo a la izquierda, más pequeño, y solo salta por encima del 75 % de la velocidad máxima |
| D13 (30/09) | El juego se llama **Delivery Express** |
| D14 (30/09) | La moto inicial se escribe **Bwis** (no «BWS») en todo el juego |
| D28 (30/09) | Se quitan las voces del juego por completo. No quedan pendientes; solo Tomás puede volver a pedirlas |

### 15.2 Abiertas (con la recomendación que se sigue mientras tanto)

| # | Pregunta | Recomendación |
|---|---|---|
| D-pendiente 1 | ¿Nombres reales de las motos o parodia? | Reales mientras sea privado; parodia antes de publicar |
| D-pendiente 2 | ¿Final? | Último pedido con la Ninja en la loma de los cerros, la curva del meme. Se puede completar; la clienta es la mamá del domiciliario y el pedido llegó frío |
| D-pendiente 3 | ¿Soporte de mando? | Solo teclado en la v1 |
