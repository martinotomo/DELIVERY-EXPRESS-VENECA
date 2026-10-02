// Prueba la exportación web en Chromium sin ventana (Playwright): carga, primer clic (audio),
// menú, calle, pausa con P y con Esc, fps, y que las opciones sigan ahí al recargar la página.
//   node tools/probar_web.mjs build/web capturas/web
// Necesita playwright (npm) y un servidor: lo levanta él mismo con python3 -m http.server.
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright"); // NODE_PATH=$(npm root -g) si está global
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const carpeta = process.argv[2] || "build/web";
const salida = process.argv[3] || "capturas/web";
fs.mkdirSync(salida, { recursive: true });
const puerto = 8765;
const servidor = spawn("python3", ["-m", "http.server", String(puerto), "--bind", "127.0.0.1"], { cwd: carpeta, stdio: "ignore" });
await new Promise((r) => setTimeout(r, 800));
const perfil = fs.mkdtempSync(path.join(os.tmpdir(), "perfil-web-"));
const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
const resultado = { errores: [] };

async function abrir() {
	const ctx = await chromium.launchPersistentContext(perfil, {
		headless: true,
		viewport: { width: 1280, height: 720 },
		args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--autoplay-policy=user-gesture-required"],
	});
	const page = ctx.pages()[0] || (await ctx.newPage());
	const log = [];
	page.on("console", (m) => log.push(m.text()));
	page.on("pageerror", (e) => resultado.errores.push(String(e)));
	await page.addInitScript(() => {
		// Vigila los AudioContext que crea Godot para saber si el sonido arrancó tras el clic.
		const Orig = window.AudioContext;
		window.__audios = [];
		window.AudioContext = function (...a) { const c = new Orig(...a); window.__audios.push(c); return c; };
		window.AudioContext.prototype = Orig.prototype;
		// Y si de verdad sale sonido: todo lo que llega a los parlantes pasa también por un
		// analizador, que guarda el volumen (RMS) más alto que ha oído.
		window.__rms = 0;
		const conectar = AudioNode.prototype.connect;
		AudioNode.prototype.connect = function (destino, ...resto) {
			if (destino instanceof AudioDestinationNode) {
				const an = this.context.createAnalyser();
				an.fftSize = 2048;
				conectar.call(this, an);
				const buf = new Float32Array(2048);
				setInterval(() => {
					an.getFloatTimeDomainData(buf);
					let s = 0;
					for (const v of buf) s += v * v;
					window.__rms = Math.max(window.__rms, Math.sqrt(s / buf.length));
				}, 50);
			}
			return conectar.call(this, destino, ...resto);
		};
		window.__fps = () => new Promise((res) => {
			let n = 0; const t0 = performance.now();
			const paso = () => { n++; if (performance.now() - t0 < 3000) requestAnimationFrame(paso); else res(n / ((performance.now() - t0) / 1000)); };
			requestAnimationFrame(paso);
		});
	});
	const t0 = Date.now();
	await page.goto(`http://127.0.0.1:${puerto}/index.html`);
	const hasta = Date.now() + 120000;
	while (!log.some((l) => l.startsWith("Delivery Express")) && Date.now() < hasta) await esperar(200);
	return { ctx, page, log, t0 };
}

const tecla = async (page, k, ms = 400) => { await page.keyboard.press(k); await esperar(ms); };

// --- Primera visita.
let { ctx, page, log, t0 } = await abrir();
resultado.segundos_hasta_arrancar = (Date.now() - t0) / 1000;
await esperar(1500);
// Lo que baja el navegador: los archivos de la carpeta (y cuánto pesan comprimidos con gzip, como
// los sirve GitHub Pages).
const zlib = await import("node:zlib");
resultado.archivos = Object.fromEntries(fs.readdirSync(carpeta).map((f) => {
	const d = fs.readFileSync(path.join(carpeta, f));
	return [f, { mb: +(d.length / 1e6).toFixed(2), mb_gzip: +(zlib.gzipSync(d, { level: 6 }).length / 1e6).toFixed(2) }];
}));
resultado.linea_version = log.find((l) => l.startsWith("Delivery Express"));
resultado.linea_opciones_1 = log.find((l) => l.startsWith("opciones:"));
await page.screenshot({ path: `${salida}/1_advertencia.png` });
resultado.audio_antes_del_clic = await page.evaluate(() => window.__audios.map((c) => c.state));
await page.mouse.click(640, 360);
await esperar(2500);
resultado.audio_despues_del_clic = await page.evaluate(() => window.__audios.map((c) => c.state));
resultado.audio_rms_menu = await page.evaluate(() => window.__rms); // la música del menú
// El clic ya saltó la advertencia (cualquier tecla o clic pasados los 2 s).
await page.screenshot({ path: `${salida}/2_menu.png` });
// Ayuda desde el menú (Jugar, Taller, Ayuda): ida y vuelta con Esc.
await tecla(page, "ArrowDown", 1500);
await tecla(page, "ArrowDown", 1500);
await tecla(page, "Enter", 3000);
await page.screenshot({ path: `${salida}/2b_ayuda.png` });
await tecla(page, "Escape", 3000);
resultado.log_menu = log.filter((l) => l.startsWith("calle precalentada"));
await tecla(page, "Enter", 500); // JUGAR
await page.screenshot({ path: `${salida}/3_carga.png` });
{
	// La pantalla de carga dura al menos 6 s (para leer) y como mucho 10; luego la calle.
	const hasta = Date.now() + 90000;
	while (!log.some((l) => l.startsWith("calle lista")) && Date.now() < hasta) await esperar(250);
	resultado.log_carga = log.find((l) => l.startsWith("calle lista"));
	await esperar(1000);
}
await page.keyboard.down("ArrowUp");
await esperar(2500);
resultado.fps_calle = Math.round(await page.evaluate(() => window.__fps()));
await page.screenshot({ path: `${salida}/3b_calle.png` });
await page.keyboard.up("ArrowUp");
await tecla(page, "p", 700);
await page.screenshot({ path: `${salida}/4_pausa_p.png` });
await tecla(page, "p", 700);
await page.screenshot({ path: `${salida}/5_sigue.png` });
await tecla(page, "Escape", 700);
await page.screenshot({ path: `${salida}/6_pausa_esc.png` });
// Opciones desde la pausa (Continuar, Ayuda, Opciones): bajar el volumen general un paso (queda en 95 %).
await tecla(page, "ArrowDown", 1500);
await tecla(page, "ArrowDown", 1500);
await tecla(page, "Enter", 2000); // a 1 fps (Chromium sin GPU) el foco llega un fotograma después
await tecla(page, "ArrowLeft", 1500);
await page.screenshot({ path: `${salida}/7_opciones.png` });
await esperar(1500);
await ctx.close();

// --- Segunda visita, mismo navegador: las opciones deben seguir.
({ ctx, page, log, t0 } = await abrir());
resultado.segundos_hasta_arrancar_2 = (Date.now() - t0) / 1000;
await esperar(1000);
resultado.linea_opciones_2 = log.find((l) => l.startsWith("opciones:"));
resultado.errores_script = log.filter((l) => l.includes("SCRIPT ERROR"));
await ctx.close();
servidor.kill();
console.log(JSON.stringify(resultado, null, 2));
