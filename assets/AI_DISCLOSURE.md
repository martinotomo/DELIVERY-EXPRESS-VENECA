# Declaración de IA

## Generado con IA generativa

Nada hecho por el proyecto con IA generativa. Ojo: `ui/motos_taller.png` sale de capturas de memes de
terceros (ver `LICENSES.md`, D21) cuyo origen no se conoce; pueden estar hechas con IA generativa.

## Generado por scripts deterministas (por transparencia)

Estos archivos salen de código que se puede volver a correr, sin IA generativa de imágenes ni de audio.
El código de los scripts se escribió con ayuda de Claude Code.

| Archivo | Script |
|---|---|
| texturas/asfalto.png | `tools/gen_texturas.py` |
| texturas/anden.png | `tools/gen_texturas.py` |
| texturas/pasto.png | `tools/gen_texturas.py` |
| texturas/linea_h.png | `tools/gen_texturas.py` |
| texturas/linea_v.png | `tools/gen_texturas.py` |
| texturas/cebra_h.png | `tools/gen_texturas.py` |
| texturas/cebra_v.png | `tools/gen_texturas.py` |
| texturas/peatones.png | `tools/gen_texturas.py` |
| texturas/senal_pare.png | `tools/gen_texturas.py` |
| texturas/senal_peatones.png | `tools/gen_texturas.py` |
| texturas/senal_velocidad.png | `tools/gen_texturas.py` |
| texturas/fachada_ladrillo.png | `tools/gen_texturas.py` |
| texturas/fachada_ladrillo_luz.png | `tools/gen_texturas.py` |
| texturas/fachada_concreto.png | `tools/gen_texturas.py` |
| texturas/fachada_concreto_luz.png | `tools/gen_texturas.py` |
| texturas/fachada_vidrio.png | `tools/gen_texturas.py` |
| texturas/fachada_vidrio_luz.png | `tools/gen_texturas.py` |
| texturas/fachada_casa.png | `tools/gen_texturas.py` |
| texturas/fachada_casa_luz.png | `tools/gen_texturas.py` |
| ui/manubrio.png | `tools/gen_manubrios.py` |
| ui/manubrio_nkd.png | `tools/gen_manubrios.py` |
| ui/manubrio_ninja.png | `tools/gen_manubrios.py` |
| ui/motos_taller.png | `tools/recortar_motos.py` (recorte y pixelado de imágenes de terceros, ver arriba) |
| sonidos/motor_bws_1700.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_bws_2350.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_bws_3240.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_bws_4470.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_bws_6160.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_bws_8500.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_nkd_1500.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_nkd_2170.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_nkd_3140.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_nkd_4540.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_nkd_6570.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_nkd_9500.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_ninja_1800.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_ninja_2670.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_ninja_3970.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_ninja_5890.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_ninja_8750.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/motor_ninja_13000.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/ambiente_dia.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/ambiente_noche.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/viento.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/lluvia.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/choque.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/golpe.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/casi.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/fundido.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/entregado.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/recogido.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/reparado.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/charco.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/atropello.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| texturas/fachada_bodega.png | `tools/gen_texturas.py` |
| texturas/fachada_bodega_luz.png | `tools/gen_texturas.py` |
| texturas/cerros.png | `tools/gen_cerros.py` |
| texturas/cerros_luz.png | `tools/gen_cerros.py` |
| texturas/vehiculos.png | `tools/gen_vehiculos.py` |
| texturas/vehiculos_grandes.png | `tools/gen_vehiculos.py` |
| ui/logo.png | `tools/gen_logo.py` |
| ui/logo_1280.png | `tools/gen_logo.py` |
| ui/cinematica_bws.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_nkd.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_ninja.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| sonidos/choque_carro.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/pito.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| musica/conduccion.wav | `tools/gen_musica.py` (síntesis con numpy/scipy) |
| musica/menu.wav | `tools/gen_musica.py` (síntesis con numpy/scipy) |
| musica/muerte.wav | `tools/gen_musica.py` (síntesis con numpy/scipy) |
| sonidos/bache.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/frenazo.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/ladrido.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| sonidos/pito_moto.wav | `tools/gen_sonidos.py` (síntesis con numpy/scipy) |
| texturas/aceite.png | `tools/gen_avisos.py` (dibujo por código; negocios y marcas inventados) |
| texturas/avisos.png | `tools/gen_avisos.py` (dibujo por código; negocios y marcas inventados) |
| texturas/avisos_luz.png | `tools/gen_avisos.py` (dibujo por código; negocios y marcas inventados) |
| texturas/hueco.png | `tools/gen_avisos.py` (dibujo por código; negocios y marcas inventados) |
| texturas/marcas_hueco.png | `tools/gen_marcas_hueco.py` (dibujo por código) |
| texturas/perros.png | `tools/gen_avisos.py` (dibujo por código; negocios y marcas inventados) |
| texturas/vallas.png | `tools/gen_avisos.py` (dibujo por código; negocios y marcas inventados) |
| ui/cinematica_bus_bws.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_bus_ninja.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_bus_nkd.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_contravia_bws.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_contravia_ninja.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_contravia_nkd.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_hueco_bws.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_hueco_ninja.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_hueco_nkd.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_lluvia_bws.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_lluvia_ninja.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_lluvia_nkd.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_perro_bws.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_perro_ninja.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| ui/cinematica_perro_nkd.png | `tools/gen_cinematica.py` (dibujo por código; reutiliza el recorte de `ui/motos_taller.png`, D21) |
| voces/atropello_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/atropello_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/atropello_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/atropello_4.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/atropello_5.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/bache_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/bache_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/cancelado_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/cancelado_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/casi_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/casi_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/casi_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/casi_4.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/casi_5.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/choque_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/choque_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/choque_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/choque_4.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/entregado_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/entregado_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/entregado_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/escampo_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/escampo_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/estrellado_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/estrellado_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/final_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/final_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/fundido_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/fundido_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/golpe_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/golpe_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/grito_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/grito_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/grito_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/grito_4.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/lluvia_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/lluvia_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/moto_nueva_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/moto_nueva_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/pedido_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/pedido_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/pedido_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/perro_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/perro_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/pito_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/pito_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/pito_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/pito_4.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/racha_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/racha_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/racha_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/recogido_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/recogido_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/recogido_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/regado_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/regado_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/regado_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/reparado_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/reparado_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/reparado_3.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/tarde_1.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |
| voces/tarde_2.wav | `tools/gen_voces.py` + `tools/normalizar_voces.py` (voz sintética por formantes, **provisional** hasta que Tomás las grabe (D11); espeak-ng es GPLv3, su salida no queda bajo la GPL) |

## De terceros, sin IA

| Archivo | Nota |
|---|---|
| fuentes/PressStart2P-Regular.ttf | Fuente OFL descargada de Google Fonts |
| fuentes/OFL.txt | Texto de la licencia |
