#!/usr/bin/env bash
# Graba el borrador del clip (tools/clip.gd) y lo deja en MP4: horizontal 1280×720 y vertical
# 1080×1920 para TikTok (el juego arriba del centro, franjas negras). Píxel sin suavizar.
#   GODOT=/ruta/a/godot FFMPEG=/ruta/a/ffmpeg tools/clip.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
FFMPEG="${FFMPEG:-ffmpeg}"
mkdir -p build/clip
CORRER=("$GODOT")
command -v xvfb-run >/dev/null && CORRER=(xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT")
"${CORRER[@]}" --path . --write-movie build/clip/clip.avi --fixed-fps 30 -s res://tools/clip.gd >/dev/null 2>&1
"$FFMPEG" -y -v error -i build/clip/clip.avi -vf "scale=1280:720:flags=neighbor,setsar=1" \
	-c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 160k build/clip/delivery_express_clip.mp4
"$FFMPEG" -y -v error -i build/clip/clip.avi -vf "scale=1080:608:flags=neighbor,pad=1080:1920:0:560:black,setsar=1" \
	-c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 160k build/clip/delivery_express_tiktok.mp4
ls -la build/clip/*.mp4
