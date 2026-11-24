#!/usr/bin/env bash
# Улучшение живых обоев: Real-ESRGAN (детализация) + RIFE (30 -> 60 к/с), бесшовная склейка, 1920x1200.
# Использование: [W=1920 H=1200] [SET_WALLPAPER=1] enhance-wallpaper.sh <исходное видео> <результат.mp4>
set -euo pipefail

SRC="${1:?укажи исходное видео}"
OUT="${2:?укажи, куда сохранить .mp4}"
W="${W:-1920}"; H="${H:-1200}"
AI="${AI_DIR:-$HOME/.local/opt/ai-video}"
ESR="$AI/esr/realesrgan-ncnn-vulkan"
RIFE_DIR="$AI/rife-ncnn-vulkan-20221029-ubuntu"
# нейросети (Real-ESRGAN, RIFE) — готовые сборки с GitHub, скачиваются один раз
if [ ! -x "$ESR" ] || [ ! -d "$RIFE_DIR" ]; then
    echo "==> скачиваю Real-ESRGAN и RIFE в $AI"
    mkdir -p "$AI/esr"
    curl -sSL -o "$AI/esr.zip" https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip
    curl -sSL -o "$AI/rife.zip" https://github.com/nihui/rife-ncnn-vulkan/releases/download/20221029/rife-ncnn-vulkan-20221029-ubuntu.zip
    (cd "$AI/esr" && unzip -oq ../esr.zip) && (cd "$AI" && unzip -oq rife.zip)
    rm -f "$AI/esr.zip" "$AI/rife.zip"
fi
RIFE="$RIFE_DIR/rife-ncnn-vulkan"
WORK="$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/wp-enhance.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
chmod +x "$ESR" "$RIFE"
mkdir -p "$WORK/in" "$WORK/up" "$WORK/fit" "$WORK/rife"

echo "==> 1/5 бесшовная склейка и раскадровка"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$SRC")
OFF=$(python3 -c "print(round($DUR - 2, 3))")
ffmpeg -v error -y -i "$SRC" -filter_complex \
  "[0:v]split[a][b];[a]trim=start=1,setpts=PTS-STARTPTS[m];[b]trim=0:1,setpts=PTS-STARTPTS[h];[m][h]xfade=transition=fade:duration=1:offset=$OFF,format=rgb24[v]" \
  -map "[v]" "$WORK/in/%05d.png"
N=$(ls "$WORK/in" | wc -l)
echo "    кадров: $N"

echo "==> 2/5 Real-ESRGAN x2 (видеокарта)"
"$ESR" -i "$WORK/in" -o "$WORK/up" -n realesr-animevideov3 -s 2 -f png

echo "==> 3/5 подгонка под ${W}x${H}"
ffmpeg -v error -y -framerate 30 -i "$WORK/up/%05d.png" \
  -vf "scale=-2:$H:flags=lanczos,crop=$W:$H" "$WORK/fit/%05d.png"
# первый кадр в конец — чтобы RIFE дорисовал переход для бесшовного цикла
cp "$WORK/fit/00001.png" "$WORK/fit/$(printf %05d $((N + 1))).png"

echo "==> 4/5 RIFE 30 -> 60 к/с (видеокарта)"
MODEL="$RIFE_DIR/rife-v4.6"; [ -d "$MODEL" ] || MODEL="$RIFE_DIR/rife-v4"
"$RIFE" -i "$WORK/fit" -o "$WORK/rife" -m "$MODEL" -n $(( 2 * (N + 1) )) -f %05d.png
# последние 2 кадра — это снова первый кадр, выкидываем
ls "$WORK/rife" | sort | tail -n 2 | while read -r f; do rm -f "$WORK/rife/$f"; done

echo "==> 5/5 сборка видео"
ffmpeg -v error -y -framerate 60 -i "$WORK/rife/%05d.png" \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -movflags +faststart "$OUT"
ffprobe -v error -show_entries stream=width,height,r_frame_rate -show_entries format=duration -of compact "$OUT"

if [ "${SET_WALLPAPER:-0}" = 1 ]; then
    echo "==> ставлю на рабочий стол"
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
      "for (const d of desktops()) { d.currentConfigGroup = ['Wallpaper','senko.video','General']; d.writeConfig('VideoUrl', 'file://$OUT'); d.reloadConfig(); }" >/dev/null
fi
echo "Готово: $OUT"
