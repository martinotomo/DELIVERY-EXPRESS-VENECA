# Documento de diseño — juego de motos

**Autor:** Tomás Ardila Marín
**Versión:** borrador 0.2 — 29/09/2026 (cambia la vista a primera persona y el mapa a una ciudad grande)
**Estado:** propuesta. Nada es definitivo hasta que Tomás lo confirme (ver §15, decisiones abiertas).

---

## 1. El juego en tres frases

Eres un domiciliario venezolano que reparte en moto por una ciudad latinoamericana grande, visto
en primera persona desde el manubrio. Recoges pedidos en restaurantes y los entregas en casas y
edificios lo más rápido posible, pasando rozado entre carros, buses y peatones. Si giras en una
esquina más rápido de lo que aguanta tu moto, te montas en el andén, te caes y sale la cinemática
de siempre: **«Has muerto al girar demasiado rápido en la esquina, tu fe era más grande que el
agarre de tu {moto}»**.

**Título provisional:** *Tu fe era más grande* (alternativas en §15).

**El chiste central:** la prisa (propina, estrellas, tiempo prometido) contra el agarre real de una
moto de bajo cilindraje. Mejorar de moto no te salva: solo te deja llegar más rápido a la misma
esquina. Encima, el domiciliario lo comenta todo en voz alta con su acento venezolano.

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
- **Cinco zonas**, una por moto. Recorrer la ciudad de punta a punta toma unos 3–4 minutos.
- **Duración objetivo:** 30–45 minutos para llegar a la Ninja 300 y ver el final. Cada pedido dura
  entre 1 y 3 minutos.

### 3.1 Definición de «terminado»

1. Arranca, se entiende sin explicación y se puede jugar de principio a fin.
2. Las cinco motos se pueden conseguir y cada una se siente y se ve distinta (manubrio y tablero
   propios).
3. Cada caída muestra la cinemática del meme con la moto correcta y su nombre.
4. Las voces del domiciliario suenan al recoger, entregar, casi chocar y caerse.
5. Menú, opciones que se recuerdan (volumen de voces, música y efectos, pantalla completa, idioma),
   créditos.
6. Español e inglés (las voces solo en español, con subtítulos).
7. `.exe` de Windows probado en otro PC.
8. `assets/LICENSES.md` y `assets/AI_DISCLOSURE.md` cubren todos los assets.

### 3.2 No-objetivos

Multijugador, bajarse de la moto y caminar, peleas o armas, personalización de la moto, varias
ciudades, clima dinámico complejo, ciclo día/noche completo (la ciudad es siempre de noche o
siempre de día, a decidir), policía que persigue, guardado de varias partidas, Mac/Linux, móvil.

---

## 4. Bucle principal

```
 ┌─► 1. PEDIDO: la app ofrece un pedido (restaurante, cliente, tiempo prometido, pago)
 │   2. RECOGER: ir al restaurante marcado. Voz del domiciliario
 │   3. ENTREGAR: cruzar la ciudad. Casi-choques dan propina extra y comentario
 │   4a. ENTREGA: pago + propina + estrellas. Voz del domiciliario ─► 5
 │   4b. CAÍDA: cinemática del meme ─► «Pulsa START» ─► reaparece en el restaurante
 │   5. GARAJE: ahorrar y comprar la siguiente moto (abre la zona siguiente)
 └───────────────────────────────────────────────────────────────┘
```

Una partida son unos 20 pedidos (≈4 por moto). El dinero solo sirve para comprar motos.

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

### 5.3 Casi-choques

Pasar a menos de ~1 m de un carro, bus o peatón a buena velocidad cuenta como **casi-choque**:

- suma a una racha de «fe» que da propina extra al entregar;
- dispara una línea de voz del domiciliario (§8);
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

Ciudad latinoamericana inventada, con aire de Bogotá o Medellín pero sin nombrarlas. Se genera por
código a partir de una cuadrícula con algunas avenidas diagonales y lomas.

| Zona | Moto con la que se abre | Cómo se ve | Peligros |
|---|---|---|---|
| **Barrio** (inicio) | BWS 125 | Casas de ladrillo de 2–3 pisos, tiendas, calles estrechas | Perros, huecos, niños jugando fútbol |
| **Centro** | Boxer CT 100 | Edificios viejos, buses, vendedores ambulantes | Buses, peatones, trancones |
| **Zona industrial** | Crypton Fi | Bodegas, tractomulas, calles anchas | Aceite en el piso, tractomulas |
| **Avenida / autopista** | NKD 125 | Avenida de varios carriles, puentes, letreros verdes de vía | Velocidad alta, esquinas de salida cerradas |
| **Zona rica / loma** | Ninja 300 | Edificios altos de vidrio, curvas de montaña con vista a la ciudad (la curva del meme) | Curvas cerradas, lluvia |

- **Navegación:** una flecha en el tablero y un minimapa en la app (Tab). Los letreros verdes de vía
  nombran las zonas, como en la referencia.
- **Tráfico:** carros y buses siguen carriles simples; peatones cruzan en esquinas. Todos son
  sprites planos que miran a la cámara.
- **Día o noche:** a decidir (§15). La noche encaja con el meme y esconde lo simple de los edificios.

---

## 7. Las motos (progresión)

Valores **de juego** (escala 1–10), no fichas técnicas. La velocidad crece más rápido que el
agarre: eso es el chiste.

| # | Moto | Personalidad | Vel. máx | Acel. | Freno | Agarre | Manubrio y tablero |
|---|---|---|---|---|---|---|---|
| 1 | **Yamaha BWS 125** (inicial) | Scooter de llantas gordas, estable pero lenta | 3 | 4 | 5 | 6 | Manubrio alto con carenaje, tablero redondo |
| 2 | **Bajaj Boxer CT 100** | La moto de domicilios por excelencia, indestructible | 4 | 3 | 3 | 5 | Manubrio recto, velocímetro análogo sencillo |
| 3 | **Yamaha Crypton Fi** | Semiautomática, ligera, nerviosa | 5 | 5 | 4 | 5 | Manubrio con carenaje, tablero de aguja |
| 4 | **AKT NKD 125** | Clásica, farola grande | 6 | 5 | 5 | 5 | Farola redonda visible abajo, velocímetro redondo |
| 5 | **Kawasaki Ninja 300** (final) | La soñada, bicilíndrica, mucho más rápida | 10 | 9 | 7 | 7 | Semimanubrios bajos, tablero digital, parabrisas |

Precio de cada moto: lo que se gana con unos 4 pedidos bien hechos con la anterior (se afina
jugando). En el garaje cada moto muestra sus barras y, como chiste, una barra de **FE** que siempre
es la más larga.

---

## 8. Las voces del domiciliario

El protagonista es un domiciliario venezolano que habla todo el tiempo. El humor está en la jerga,
la actitud y la seguridad total en sí mismo (la «fe»), **con cariño y no para humillar**: nada de
chistes sobre la migración, la pobreza o la nacionalidad como insulto. Es el pana que se cree el
mejor piloto de la ciudad.

| Momento | Ejemplos (borrador) |
|---|---|
| Aceptar pedido | «¡Epa, llegó la chamba!», «Dale, dale, ya voy saliendo, mi amor» |
| Recoger | «¿Esto es lo del 302? Chévere, pana», «Burda de pesada esta vaina» |
| Casi-choque | «¡Na' guará, casi!», «¡Ay, chamo! Ese bus me quería», «Fe, mi pana, pura fe» |
| Racha larga | «¡Qué nivel! Nadie me para hoy» |
| Golpe leve con el andén | «¡Epa, epa! Eso no pasó» |
| Entregar | «Cinco estrellitas, ¿oíste?», «Llegó calientico, mi reina» |
| Entrega tarde | «Es que había un trancón arrecho, se lo juro» |
| Caída (antes de la cinemática) | Un grito corto que se corta |
| Moto nueva | «¡Mírala! Ahora sí voy a llegar más rápido» (a la misma esquina) |

- Cada momento tiene 4–6 variantes para que no se repitan; nunca dos voces seguidas en menos de
  ~3 s.
- **Cómo se graban:** la opción recomendada es que Tomás o un amigo las grabe con Audacity (libre, y
  más gracioso que una voz sintética). Alternativa sin grabar: un sintetizador de voz de código
  abierto (p. ej. Piper), verificando la licencia de cada voz.
- La cinemática de muerte también se puede **narrar en voz**, leyendo el nombre de la moto, como
  pidió Tomás.
- Todas las voces llevan subtítulo (sirve también para la versión en inglés).

---

## 9. Pantallas

1. **Advertencia de contenido** (humor negro, sangre pixelada, muertes de tráfico), saltable tras
   2 s.
2. **Menú principal:** vista en primera persona con la moto parada en la esquina del barrio.
3. **App de pedidos:** celular pixelado con el pedido, el pago, el tiempo y el minimapa.
4. **Conducción** (§5), con el HUD estilo *Doom*.
5. **Entrega:** pago, propina, estrellas y comentario del cliente.
6. **Cinemática de muerte:** la ilustración del meme en la esquina donde caíste, la frase con el
   nombre de la moto y «Pulsa [START] para continuar».
7. **Garaje:** motos compradas y por comprar.
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
  moto (azul claro BWS, negro y rojo Boxer, negro y plata Crypton, gris NKD, verde lima Ninja).
- **Assets por código** (paleta → cuantizar → *dithering*): texturas de fachadas, asfalto, andenes,
  letreros; sprites de carros, buses y peatones.
- **Los manubrios** son el asset más visible y el más difícil: cinco sprites grandes con manos y
  tablero. Primero por código (polígonos por piezas, rasterizados a la paleta); si no alcanza, se
  retocan a mano con LibreSprite o Krita.
- **Fuente:** pixelada con licencia OFL. Una estilo *Doom* para los números del HUD y una
  monoespaciada tipo la del meme para la caja de texto.
- Revisión con hojas de capturas automáticas desde la F1, a tamaño real y ampliadas.

---

## 11. Audio

Efectos y música sintetizados por código y definidos con números antes de generarse. Las voces
(§8) se graban o se sintetizan aparte.

| Sonido | Descripción | Requisito medible (borrador) |
|---|---|---|
| Motor de cada moto | Tono que sube con las RPM. BWS: zumbido de CVT; Boxer, Crypton, NKD: monocilíndrico «pum-pum»; Ninja: bicilíndrico agudo | Fundamental 30–250 Hz según RPM; paso-alto a 90 Hz; bucle sin clic |
| Frenazo | Chirrido de llanta | 0,4–1,0 s, ≥ 50 % de la energía sobre 1 kHz |
| Golpe con el andén | Golpe seco corto | ≤ 0,5 s |
| Caída | Golpe + metal arrastrándose + silencio | ≤ 1,5 s, final en silencio |
| Pito | Pito ridículo de moto pequeña | ≤ 0,5 s |
| Ciudad | Ambiente de tráfico, pitos lejanos | Bucle sin clic, bajito |
| Música de conducción | Ritmo latino en 8 bits (cumbia o salsa con sintetizador), bajito | −18 dB respecto a los efectos; se baja cuando habla el domiciliario |
| Música de muerte | **Épica y trágica, exagerada** (el contraste es el chiste) | Acordes menores, entra con la cinemática |

---

## 12. Contenido, marcas y tono

- **Tono:** humor negro sobre la prisa y la fe del domiciliario, no burla de las víctimas ni de los
  venezolanos. Advertencia de contenido al inicio.
- **Marcas reales:** los modelos (BWS, Boxer, Crypton, NKD, Ninja) y los logos (Yamaha, Bajaj, AKT,
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
| Audacity | GPL | PC | Grabar las voces y revisar el audio |
| OBS Studio | GPL | PC | Grabar partidas de prueba y tráiler |
| LibreSprite / Krita | GPL | PC | Solo si hay que retocar sprites a mano |
| Piper (opcional) | MIT (cada voz con su licencia) | PC | Voces sintéticas si no se graban |
| Fuentes | SIL OFL | — | Interfaz |

Claude Code escribe el código en la nube desde el repositorio; lo que necesita ventana, sonido,
micrófono o programas del PC se hace en el PC de Tomás.

---

## 14. Plan de trabajo por fases

Cada fase termina en algo que Tomás juega en su PC con Godot. Ninguna fase empieza sin su orden.

| Fase | Qué sale | Criterio de salida |
|---|---|---|
| **F0** Andamiaje | Proyecto Godot 4.7.2 (Compatibility), `.gitattributes`, `.gitignore`, corredor de pruebas, `CLAUDE.md`, registros de licencias | Pruebas en verde en headless; arranca |
| **F1** Prototipo gris | Unas pocas manzanas de cajas grises, moto en primera persona, regla de la esquina y el andén, caída con texto plano, script de capturas | Tomás juega y confirma que frenar antes de la esquina es divertido |
| **F2** Dirección visual | Paleta, fuentes, maqueta del HUD, un manubrio y la cinemática de muerte | Tomás aprueba el look |
| **F3** Ciudad | Generador de la ciudad con las cinco zonas, tráfico y peatones | Se recorre de punta a punta sin errores |
| **F4** Arte y audio | Texturas, los cinco manubrios, cinemática ilustrada, motores, efectos, música | Capturas y medidas de audio aprobadas |
| **F5** Contenido | Pedidos, economía, garaje, casi-choques, voces, final | Se juega de principio a fin |
| **F6** Menús | Menú, opciones, idiomas, créditos, advertencia | Lista de §3.1 casi completa |
| **F7** Entrega | `.exe` y `.zip` | Probado en otro PC |

---

## 15. Decisiones abiertas

| # | Pregunta | Recomendación |
|---|---|---|
| D-pendiente 1 | ¿Nombres reales de las motos o parodia? | Reales mientras sea privado; parodia antes de publicar |
| D-pendiente 2 | ¿La ciudad de día o de noche? | Noche: encaja con el meme y el alumbrado naranja da carácter |
| D-pendiente 3 | ¿Voces grabadas o sintéticas? | Grabadas por Tomás o un amigo con Audacity |
| D-pendiente 4 | ¿Orden de las motos intermedias? | Boxer → Crypton → NKD (§7) |
| D-pendiente 5 | ¿Final? | Último pedido con la Ninja en la loma de la zona rica, la curva del meme. Se puede completar; la clienta es la mamá del domiciliario y el pedido llegó frío |
| D-pendiente 6 | ¿Título? | *Tu fe era más grande*. Otras: *Llegó frío*, *Fe > Agarre*, *Domicilio final* |
| D-pendiente 7 | ¿Soporte de mando? | Solo teclado en la v1 |
| D-pendiente 8 | ¿Tamaño de la ciudad? | Cinco zonas generadas por código, 3–4 min de punta a punta. Crecer solo si la F1 sale divertida |
