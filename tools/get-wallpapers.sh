#!/usr/bin/env bash
# Скачивает живые обои темы и подгоняет их под экран.
#  - Winter Cherry Blossom (YouTube) -> улучшение через enhance-wallpaper.sh (Real-ESRGAN + RIFE, 60 к/с)
#  - Fox Anime Girl Shooting Stars (MoeWalls) -> пережатие под экран
# Использование: [NO_AI=1] get-wallpapers.sh [папка]   (по умолчанию ~/.local/share/wallpapers/senko-live)
set -euo pipefail

DEST="${1:-$HOME/.local/share/wallpapers/senko-live}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DEST"
read -r SW SH < <(python3 - <<'EOF'
import subprocess, re
try:
    out = subprocess.run(["kscreen-doctor", "-o"], capture_output=True, text=True).stdout
    m = re.search(r"Geometry: \d+,\d+ (\d+)x(\d+)", re.sub(r"\x1b\[[0-9;]*m", "", out))
    print(m.group(1), m.group(2))
except Exception:
    print(1920, 1080)
EOF
)
echo "Экран: ${SW}x${SH}"

# --- yt-dlp во временном окружении
VENV="${XDG_CACHE_HOME:-$HOME/.cache}/senko-ytdlp"
if [ ! -x "$VENV/bin/yt-dlp" ]; then
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q yt-dlp
fi

echo "==> Winter Cherry Blossom"
"$VENV/bin/yt-dlp" -q -f "bv*[ext=mp4]/bv*" -o "$DEST/winter-cherry-blossom-src.%(ext)s" \
    "https://www.youtube.com/watch?v=1t8Y1l9FIHY"
if [ "${NO_AI:-0}" = 1 ]; then
    ffmpeg -v error -y -i "$DEST/winter-cherry-blossom-src.mp4" -an \
        -vf "scale=-2:$SH:flags=lanczos,crop=$SW:$SH" -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p \
        "$DEST/winter-cherry-blossom-60fps.mp4"
else
    W="$SW" H="$SH" bash "$HERE/enhance-wallpaper.sh" "$DEST/winter-cherry-blossom-src.mp4" "$DEST/winter-cherry-blossom-60fps.mp4"
fi

echo "==> Fox Anime Girl Shooting Stars (MoeWalls)"
PAGE="https://moewalls.com/anime/fox-anime-girl-shooting-stars-live-wallpaper/"
DU=$(curl -sL -A "Mozilla/5.0" "$PAGE" | grep -oE 'id="moe-download" data-id ="[0-9]+" data-url="[^"]+"' | sed 's/.*data-url="//;s/"$//')
curl -sL -A "Mozilla/5.0" -e "https://moewalls.com/" "https://go.moewalls.com/download.php?video=$DU" -o "$DEST/fox-girl-shooting-stars-src.mp4"
ffmpeg -v error -y -i "$DEST/fox-girl-shooting-stars-src.mp4" -an \
    -vf "scale=-2:$SH:flags=lanczos,crop=$SW:$SH" -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p \
    "$DEST/fox-girl-shooting-stars.mp4"

rm -f "$DEST"/*-src.*
echo "Готово: $DEST"
