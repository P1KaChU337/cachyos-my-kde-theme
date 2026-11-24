#!/usr/bin/env bash
# cachyos-my-kde-theme — установщик.
#   ./install.sh              — поставить всё (виджеты, эффекты, шрифты, терминал, каву), панели не трогать
#   ./install.sh --layout     — плюс пересоздать панели и рабочий стол как в теме (удалит текущие панели!)
#   ./install.sh --wallpapers — плюс скачать и подготовить живые обои
set -euo pipefail

THEME="$(cd "$(dirname "$0")" && pwd)"
LAYOUT=0; WALLS=0
for a in "$@"; do
    case "$a" in
        --layout) LAYOUT=1 ;;
        --wallpapers) WALLS=1 ;;
        -h|--help) sed -n 2,6p "$0"; exit 0 ;;
        *) echo "Неизвестный параметр: $a"; exit 1 ;;
    esac
done

say() { printf '\e[1;35m==>\e[0m %s\n' "$*"; }
backup() { [ -e "$1" ] && cp -a "$1" "$1.bak-$(date +%Y%m%d%H%M%S)" || true; }

# ---------- зависимости ----------
say "Проверяю зависимости"
NEED=(plasma6-applets-panel-colorizer cava pyside6 layer-shell-qt qt6-multimedia-ffmpeg qt6-5compat fastfetch fish konsole ffmpeg unzip curl)
MISSING=()
for p in "${NEED[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || MISSING+=("$p"); done
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Не хватает пакетов: ${MISSING[*]}"
    echo "Поставь их, например:  paru -S ${MISSING[*]}   (panel-colorizer есть в AUR/репозитории CachyOS)"
    exit 1
fi
CV=$(pacman -Q plasma6-applets-panel-colorizer | awk '{print $2}')
case "$CV" in 8.1.0*) ;; *) echo "Внимание: патч рассчитан на Panel Colorizer 8.1.0, установлен $CV — может не наложиться." ;; esac

# ---------- шрифты ----------
say "Шрифты: Nunito и Maple Mono NF"
FONTS="$HOME/.local/share/fonts"
if ! fc-list | grep -q "Nunito"; then
    mkdir -p "$FONTS/Nunito"
    curl -sSL -o "$FONTS/Nunito/Nunito[wght].ttf" "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf"
fi
if ! fc-list | grep -q "Maple Mono NF"; then
    mkdir -p "$FONTS/MapleMono"
    curl -sSL -o /tmp/maplemono.zip "https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF.zip"
    unzip -oq /tmp/maplemono.zip -d "$FONTS/MapleMono" && rm -f /tmp/maplemono.zip
fi
fc-cache -f "$FONTS" >/dev/null

# ---------- виджеты, обои-плагин, эффекты ----------
say "Виджеты и плагин живых обоев"
PL="$HOME/.local/share/plasma/plasmoids"; mkdir -p "$PL"
for w in "$THEME"/plasmoids/*; do rm -rf "$PL/$(basename "$w")"; cp -r "$w" "$PL/"; done
mkdir -p "$HOME/.local/share/plasma/wallpapers"
rm -rf "$HOME/.local/share/plasma/wallpapers/senko.video"
cp -r "$THEME/wallpaper/senko.video" "$HOME/.local/share/plasma/wallpapers/"

say "Эффекты KWin"
EF="$HOME/.local/share/kwin/effects"; mkdir -p "$EF"
for e in "$THEME"/kwin-effects/*; do rm -rf "$EF/$(basename "$e")"; cp -r "$e" "$EF/"; done

mkdir -p "$HOME/.local/share/cachyos-my-kde-theme"
cp "$THEME"/assets/* "$HOME/.local/share/cachyos-my-kde-theme/"

# ---------- Panel Colorizer + патч ----------
say "Panel Colorizer: копия в ~/.local и патч (вогнутые углы, анимация, якоря попапов)"
SYS=/usr/share/plasma/plasmoids/luisbocanegra.panel.colorizer
LOC="$PL/luisbocanegra.panel.colorizer"
rm -rf "$LOC"; cp -r "$SYS" "$LOC"
( cd "$LOC" && for p in "$THEME"/panel-colorizer/patches/*.patch; do patch -p1 -s < "$p"; done )
mkdir -p "$HOME/.config/panel-colorizer/presets"
cp -r "$THEME"/panel-colorizer/presets/* "$HOME/.config/panel-colorizer/presets/"

# ---------- кава ----------
say "Аудио-визуализатор (kava-overlay)"
KV="$HOME/.local/share/kava-overlay"; mkdir -p "$KV"
cp "$THEME"/kava-overlay/kava-overlay.py "$THEME"/kava-overlay/main.qml "$KV/"
chmod +x "$KV/kava-overlay.py"
mkdir -p "$HOME/.config/autostart"
sed "s|@HOME@|$HOME|g" "$THEME/kava-overlay/kava-overlay.desktop" > "$HOME/.config/autostart/kava-overlay.desktop"

# ---------- терминал ----------
say "Konsole, fish, fastfetch"
mkdir -p "$HOME/.local/share/konsole" "$HOME/.config/fish/functions" "$HOME/.config/fastfetch"
cp "$THEME"/konsole/* "$HOME/.local/share/konsole/"
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile Senko.profile
for f in "$THEME"/fish/functions/*.fish; do backup "$HOME/.config/fish/functions/$(basename "$f")"; cp "$f" "$HOME/.config/fish/functions/"; done
backup "$HOME/.config/fastfetch/config.jsonc"
cp "$THEME/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"

# ---------- настройки KDE ----------
say "Шрифты интерфейса и анимации KWin"
backup "$HOME/.config/kdeglobals"; backup "$HOME/.config/kwinrc"
f() { echo "$1,$2,-1,5,$3,0,0,0,0,0,0,0,0,0,0,1"; }
kwriteconfig6 --group General --key font "$(f Nunito 10 500)"
kwriteconfig6 --group General --key menuFont "$(f Nunito 10 500)"
kwriteconfig6 --group General --key toolBarFont "$(f Nunito 10 500)"
kwriteconfig6 --group General --key smallestReadableFont "$(f Nunito 9 500)"
kwriteconfig6 --group General --key fixed "$(f 'Maple Mono NF' 10 400)"
kwriteconfig6 --group WM --key activeFont "$(f Nunito 10 700)"
kwriteconfig6 --group KDE --key AnimationDurationFactor 0.8
for kv in glideEnabled=true scaleEnabled=false maximizeEnabled=false smoothmaximizeEnabled=true popupzoomEnabled=true fadingpopupsEnabled=false; do
    kwriteconfig6 --file kwinrc --group Plugins --key "${kv%%=*}" "${kv#*=}"
done
kwriteconfig6 --file kwinrc --group Effect-glide --key Duration 280
kwriteconfig6 --file kwinrc --group Effect-slidingpopups --key SlideInTime 200
kwriteconfig6 --file kwinrc --group Effect-slidingpopups --key SlideOutTime 220
kwriteconfig6 --file kwinrc --group Effect-wobblywindows --key ResizeWobble false
for v in gtk-3.0 gtk-4.0; do
    [ -f "$HOME/.config/$v/settings.ini" ] && sed -i 's/^gtk-font-name=.*/gtk-font-name=Nunito,  10/' "$HOME/.config/$v/settings.ini"
done
gsettings set org.gnome.desktop.interface font-name 'Nunito 10' 2>/dev/null || true
gsettings set org.gnome.desktop.interface monospace-font-name 'Maple Mono NF 10' 2>/dev/null || true
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:1 int32:0 || true
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

# ---------- обои ----------
WALLDIR="$HOME/.local/share/wallpapers/senko-live"
if [ "$WALLS" = 1 ]; then
    say "Живые обои (это займёт несколько минут)"
    bash "$THEME/tools/get-wallpapers.sh" "$WALLDIR"
fi

# ---------- раскладка панелей ----------
if [ "$LAYOUT" = 1 ]; then
    say "Пересоздаю панели и рабочий стол"
    backup "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"; backup "$HOME/.config/plasmashellrc"
    JS=$(mktemp --suffix=.js)
    python3 - "$THEME" "$JS" "$HOME" "$(whoami)@$(hostname)" "$WALLDIR/winter-cherry-blossom-60fps.mp4" <<'EOF'
import json, sys, os
theme, out, home, label, wall = sys.argv[1:6]
presets = {}
for name in ("Senko Top", "Senko Dock"):
    with open(os.path.join(theme, "panel-colorizer/presets", name, "settings.json")) as f:
        presets[name] = json.load(f)["globalSettings"]
js = open(os.path.join(theme, "layout/apply-layout.js")).read()
js = js.replace("@HOME@", home).replace("@LABEL@", label).replace("@THEME@", theme).replace("@WALL@", wall)
js = "const PRESET_JSON = " + json.dumps(presets, ensure_ascii=False) + ";\n" + js
open(out, "w").write(js)
EOF
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$JS")"
    rm -f "$JS"
fi

say "Перезапуск оболочки и кавы"
systemctl --user restart plasma-plasmashell.service || true
pgrep -f "kava-overlay/kava-overlay.py" >/dev/null || (setsid nohup "$KV/kava-overlay.py" >/dev/null 2>&1 &)

say "Готово! Открой новое окно Konsole, чтобы увидеть терминал."
[ "$LAYOUT" = 1 ] || echo "Панели не трогал. Чтобы собрать их как в теме: ./install.sh --layout"
