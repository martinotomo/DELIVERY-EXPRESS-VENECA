# Guion de voces — Delivery Express

**Tomás Ardila Marín** · voces del domiciliario venezolano (decisión D11)

> Este archivo lo escribe `python tools/gen_voces.py` a partir de `scripts/voces.gd`. Si se cambia una frase, se cambia en `voces.gd` y se vuelve a correr el script; no edites este archivo a mano.

Son **62 frases** en 22 situaciones. Ahora mismo el juego trae voces de relleno hechas por computador (suenan a robot). Cada archivo que grabes con el **mismo nombre** reemplaza al de relleno, y el juego lo usa sin tocar nada más.

## 1. Qué hay que entregar

- Un archivo **WAV** por frase, en la carpeta `assets/voces/`, con el nombre exacto de la tabla (por ejemplo `recogido_1.wav`).
- **Mono** (un solo canal), **44 100 Hz**, **16 bits**. Si Audacity lo guarda distinto, no pasa nada: `normalizar_voces.py` lo convierte.
- Una sola toma por archivo, sin ruidos antes ni después. El script recorta el silencio sobrante, iguala el volumen de todas y deja 0,1 s de silencio a cada lado.
- Las frases que empiezan por **Peatón:** o **Conductor:** las dice otro personaje: no leas la palabra «Peatón» o «Conductor». Puedes pedírselas a otra persona o cambiar la voz (más aguda o más grave).
- La columna «Cómo decirla» es solo una pista de actuación: dilo como te salga más natural.

## 2. El guion

### Llega un pedido nuevo (`pedido`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `pedido_1.wav` | ¡Epa, llegó la chamba! | gritado, con energía |
| `pedido_2.wav` | Dale, dale, ya voy saliendo, mi amor. | tranquilo, conversado |
| `pedido_3.wav` | Otro pedido, mi pana. La fe no descansa. | tranquilo, conversado |

### Recoger el pedido (`recogido`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `recogido_1.wav` | ¡Epa, chamo! Agarra esa vaina y dale, pues. | gritado, con energía |
| `recogido_2.wav` | Listo el pedido, mi pana. ¡Vuela, vale! | tranquilo, conversado |
| `recogido_3.wav` | Chamo, eso está caliente, no lo vayas a voltear. | tranquilo, conversado |

### Entregar el pedido (`entregado`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `entregado_1.wav` | ¡Entregado, papá! ¿Y la propina? ¿No? Ah, bueno, vale. | gritado, con energía |
| `entregado_2.wav` | Chévere, mi pana. Cinco estrellas... mentira, una. | tranquilo, conversado |
| `entregado_3.wav` | Llegamos vivos, chamo. Eso ya es ganancia. | tranquilo, conversado |

### Entregar tarde (`tarde`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `tarde_1.wav` | Es que había un trancón arrecho, se lo juro. | tranquilo, conversado |
| `tarde_2.wav` | Llegué, llegué... tarde, pero llegué. | tranquilo, conversado |

### El cliente cancela (`cancelado`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `cancelado_1.wav` | Chamo, el cliente canceló. Te tocó comértelo a ti. | tranquilo, conversado |
| `cancelado_2.wav` | Se enfrió la vaina, mi pana. Cancelado. | tranquilo, conversado |

### Buena racha (esquivando sin chocar) (`racha`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `racha_1.wav` | ¡Qué nivel! Nadie me para hoy. | gritado, con energía |
| `racha_2.wav` | ¡Chamo, esquivo como en las películas! | gritado, con energía |
| `racha_3.wav` | La fe está prendida, vale. ¡Propina segura! | tranquilo, conversado |

### Casi se estrella (`casi`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `casi_1.wav` | ¡Na' guará, casi! | gritado, con energía |
| `casi_2.wav` | Fe, mi pana, pura fe. | tranquilo, conversado |
| `casi_3.wav` | ¡Chamo, casi te matas, vale! | gritado, con energía |
| `casi_4.wav` | ¡Épale, épale! Frena esa burra, mi pana. | gritado, con energía |
| `casi_5.wav` | ¡Qué molleja, casi besas el andén! | gritado, con energía |

### Golpe leve contra el andén (`golpe`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `golpe_1.wav` | ¡Epa, epa! Eso no pasó. | gritado, con energía |
| `golpe_2.wav` | Tranquilo, mi pana, que el andén no se movió. | tranquilo, conversado |

### Choque con un carro (`choque`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `choque_1.wav` | ¡Perdón, patrón! Es que el pedido se enfría. | gritado, con energía |
| `choque_2.wav` | ¡Na' guará, chamo, ese carro salió de la nada! | gritado, con energía |
| `choque_3.wav` | Tranquilo, mi pana, que eso con crema dental sale. | tranquilo, conversado |
| `choque_4.wav` | ¡Chamo, frenó en seco! Bueno... frené yo, más bien. | gritado, con energía |

### Un conductor le pita (lo dice el conductor) (`pito`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `pito_1.wav` | Conductor: ¡Piiii! ¡Mire por dónde va, domiciliario! | voz de conductor bravo, pitando |
| `pito_2.wav` | Conductor: ¡Me rayó el carro! ¡Venga, venga! | voz de conductor bravo, pitando |
| `pito_3.wav` | Conductor: ¡Otro de estos en moto! ¡Piiiii! | voz de conductor bravo, pitando |
| `pito_4.wav` | Conductor: ¡La vía no es suya, joven! | voz de conductor bravo, pitando |

### Atropella a un peatón (`atropello`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `atropello_1.wav` | ¡Épale! ¡Perdón, señor! Es que el pedido se enfría. | gritado, con energía |
| `atropello_2.wav` | ¡Na' guará, chamo, la cebra es pa' ellos, no pa' uno! | gritado, con energía |
| `atropello_3.wav` | Tranquila, señora, que eso no fue nada... ¿verdad? | preguntando, medio en chiste |
| `atropello_4.wav` | ¡Ay, vale! Se me atravesó... bueno, yo me le atravesé. | gritado, con energía |
| `atropello_5.wav` | Chamo, la propina de este pedido se fue con ese señor. | tranquilo, conversado |

### El peatón atropellado grita (lo dice el peatón) (`grito`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `grito_1.wav` | Peatón: ¡Mire por dónde anda, domiciliario! | voz de peatón indignado (otra persona o voz cambiada) |
| `grito_2.wav` | Peatón: ¡Le voy a poner una estrella, desgraciado! | voz de peatón indignado (otra persona o voz cambiada) |
| `grito_3.wav` | Peatón: ¡Esto va pa' las redes, sonría! | voz de peatón indignado (otra persona o voz cambiada) |
| `grito_4.wav` | Peatón: ¡Uy, no, qué pecado! ¡Casi me mata! | voz de peatón indignado (otra persona o voz cambiada) |

### Se riega la comida (`regado`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `regado_1.wav` | ¡Na' guará, se regó el sancocho! | gritado, con energía |
| `regado_2.wav` | Chamo, eso ya es mitad sopa, mitad maleta. | tranquilo, conversado |
| `regado_3.wav` | La torta ahora es un mapa, mi pana. | tranquilo, conversado |

### Cae en un hueco (`bache`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `bache_1.wav` | ¡Ay, mi columna! Ese hueco tiene nombre propio. | gritado, con energía |
| `bache_2.wav` | ¡Epa! Ese hueco ya estaba cuando yo llegué al país. | gritado, con energía |

### Un perro se le atraviesa (`perro`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `perro_1.wav` | ¡Quítate, Firulais, que voy con prisa! | gritado, con energía |
| `perro_2.wav` | ¡Perrito, perrito, no me mires así! | gritado, con energía |

### Se funde el motor (`fundido`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `fundido_1.wav` | ¡Se fundió el motor, chamo! Huele a pollo quemado. | gritado, con energía |
| `fundido_2.wav` | ¡Na' guará! Le diste tan duro que se murió la burra. | gritado, con energía |

### Repara el motor (`reparado`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `reparado_1.wav` | Listo, le eché agua de la botella y un rezo. ¡Dale! | tranquilo, conversado |
| `reparado_2.wav` | Reparado con cinta, un chicle y fe, mi pana. | tranquilo, conversado |
| `reparado_3.wav` | Le soplé al motor como a un cartucho viejo. ¡Arrancó! | tranquilo, conversado |

### Empieza a llover (`lluvia`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `lluvia_1.wav` | ¡Se largó el aguacero, chamo! Al menos la app paga más. | gritado, con energía |
| `lluvia_2.wav` | Llueve, mi pana. Bono por mojarse... y por los charcos. | tranquilo, conversado |

### Deja de llover (`escampo`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `escampo_1.wav` | Escampó, vale. Se acabó el bono. | tranquilo, conversado |
| `escampo_2.wav` | Ya paró de llover. Ahora a secarse con el viento. | tranquilo, conversado |

### Compra moto nueva (`moto_nueva`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `moto_nueva_1.wav` | ¡Mírala! Ahora sí llego más rápido... a la misma esquina. | gritado, con energía |
| `moto_nueva_2.wav` | Moto nueva, fe nueva, mi pana. | tranquilo, conversado |

### Se mata (antes del remate) (`estrellado`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `estrellado_1.wav` | Ay, no, chamo... se nos fue el pana. | tranquilo, conversado |
| `estrellado_2.wav` | Otro más pa' la estadística, vale. | tranquilo, conversado |

### Final del juego (`final`)

| Archivo | Frase | Cómo decirla |
|---|---|---|
| `final_1.wav` | ¿Mamá? ¿Usted fue la que pidió? | preguntando, medio en chiste |
| `final_2.wav` | Llegó frío, mamá, pero llegó con fe. | tranquilo, conversado |

## 3. Cómo grabar (Audacity, paso a paso)

**Antes de empezar**

1. Busca el cuarto más «muerto» que tengas: con cama, cortinas, ropa o cojines. Las paredes desnudas hacen eco. Un clóset lleno de ropa es un estudio excelente.
2. Apaga ventilador, aire y todo lo que zumbe. Cierra la ventana.
3. Pon el micrófono a **un palmo (15–20 cm)** de la boca, un poco de lado para que las «p» y las «b» no soplen dentro. Si es el micrófono del portátil o de los audífonos, igual sirve: mantén siempre la misma distancia.
4. En Audacity: arriba, junto al micrófono, elige tu micrófono y **1 canal (mono)**. Abajo a la izquierda, **Frecuencia del proyecto: 44100 Hz**.
5. Graba una frase gritada de prueba y mira la barra de nivel (arriba): lo más alto debe quedar alrededor de **−6 dB** y nunca tocar el rojo (0 dB). Si toca el rojo, baja el volumen del micrófono o aléjate un poco; si casi no se mueve, acércate.

**Grabando**

6. Graba **5 segundos de silencio** al principio (quieto, sin hablar): sirve para quitar el ruido de fondo después.
7. Di cada frase **tres veces seguidas**, con un par de segundos de pausa entre cada una, y di el nombre del archivo antes («recogido uno»). Así luego eliges la mejor.
8. Exagera: el personaje es un venezolano que habla todo el tiempo y con cariño. Sonríe mientras hablas (se nota en la voz). Si te equivocas, sigue y repite; se corta después.
9. Graba por bloques (por ejemplo, una situación de la tabla cada vez) y guarda el proyecto (*Archivo → Guardar proyecto*) de vez en cuando.

**Limpiando**

10. **Quitar el ruido de fondo**: selecciona el trozo de silencio del principio → *Efecto → Reducción de ruido y reparación → Reducción de ruido → Obtener perfil de ruido*. Luego selecciona toda la pista (Ctrl+A) → otra vez *Reducción de ruido* → deja los valores (12 dB, 6, 3) → *Aceptar*. Si la voz queda «metálica», deshaz (Ctrl+Z) y repite con 6 dB.
11. Escucha las tres tomas de una frase, **selecciona la mejor** con el ratón (un poquito antes de que empiece a hablar y un poquito después de que termine).
12. *Archivo → Exportar → Exportar audio seleccionado…* (o *Exportar selección*). Tipo: **WAV (Microsoft)**, Codificación: **PCM de 16 bits con signo**, Canales: **Mono**, Frecuencia: **44100 Hz**. Nombre: el de la tabla, por ejemplo `recogido_1.wav`, dentro de `assets/voces/`. Si pregunta por metadatos, *Aceptar* sin llenar nada.
13. Repite 11–12 con cada frase. No hace falta subir el volumen ni igualarlo a mano: eso lo hace el script del paso siguiente.

## 4. Después de grabar: dejar los archivos listos

Abre una terminal en la carpeta del juego y corre, en este orden:

```bash
python tools/normalizar_voces.py     # ajusta tus grabaciones al formato del juego
python tools/medir_voces.py          # comprueba que todas están bien (0 = todo bien)
```

- `normalizar_voces.py` convierte a mono 44,1 kHz 16 bits, recorta el silencio, quita los graves que los portátiles no suenan (debajo de 90 Hz), iguala el volumen de todas las frases y deja 0,1 s de silencio a cada lado. Avisa si una grabación **satura** (se grabó demasiado fuerte: hay que repetirla), si es **muy bajita** o **muy larga**, y dice qué archivos faltan. Se puede correr las veces que quieras: lo que ya está bien no lo vuelve a tocar.
- Si guardaste las grabaciones en otra carpeta, pásala: `python tools/normalizar_voces.py C:/ruta/de/mis/grabaciones` (las deja en `assets/voces/`).
- `medir_voces.py` revisa cada archivo esperado: que exista, que sea mono 44,1 kHz, que su volumen medio esté a ±2 dB del objetivo (−20 dBFS), que el pico no pase de −1 dBFS y que empiece y termine en silencio. Solo dice «todo bien» (y sale con 0) si pasan todos.
- Después, abre Godot (o corre `godot --headless --path . --import`) para que importe los WAV nuevos, y juega.
- **Cuidado**: `python tools/gen_voces.py` rehace las voces de robot, pero **no pisa** tus grabaciones (solo reescribe los archivos que él mismo hizo).
- Cada archivo tuyo necesita su fila en `assets/LICENSES.md` (autor: Tomás Ardila Marín, grabación propia) antes de repartir el juego.
