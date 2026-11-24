// Раскладка панелей и рабочего стола для cachyos-my-kde-theme.
// Запускается из install.sh через PlasmaShell.evaluateScript; @HOME@, @LABEL@ и @THEME@ подставляются скриптом.
// ВНИМАНИЕ: удаляет все существующие панели.

const HOME = "@HOME@";
const PRESETS = HOME + "/.config/panel-colorizer/presets/";

function presetSettings(name) {
    // globalSettings берутся из файла пресета, install.sh вставляет их сюда как JSON
    return PRESET_JSON[name];
}

for (const p of panels()) p.remove();

// ---------- верхняя панель ----------
const top = new Panel("org.kde.panel");
top.location = "top";
top.height = 31;
top.floating = false;
top.alignment = "center";
top.lengthMode = "fill";
top.hiding = "none";

const kickoff = top.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", HOME + "/.local/share/cachyos-my-kde-theme/cachyos_fox.png");
kickoff.writeConfig("menuLabel", "@LABEL@");
kickoff.writeConfig("systemFavorites", "suspend,hibernate,reboot,shutdown");
kickoff.globalShortcut = "Alt+F1";

top.addWidget("org.kde.plasma.marginsseparator");
top.addWidget("senko.sysinfo");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("senko.clock");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("senko.player");
top.addWidget("senko.battery");
top.addWidget("org.kde.plasma.systemtray");
top.addWidget("org.kde.plasma.colorpicker");

const topColorizer = top.addWidget("luisbocanegra.panel.colorizer");
topColorizer.currentConfigGroup = ["General"];
topColorizer.writeConfig("globalSettings", JSON.stringify(presetSettings("Senko Top")));
topColorizer.writeConfig("presetAutoloading", JSON.stringify({
    enabled: true,
    normal: PRESETS + "Senko Top",
    maximized: PRESETS + "Senko Top Maximized",
    fullscreenWindow: PRESETS + "Senko Top Maximized"
}));
topColorizer.writeConfig("lastPreset", PRESETS + "Senko Top");
topColorizer.writeConfig("hideWidget", true);
topColorizer.writeConfig("animatePropertyChanges", true);
topColorizer.writeConfig("animationDuration", 380);

// ---------- док снизу ----------
const dock = new Panel("org.kde.panel");
dock.location = "bottom";
dock.height = 48;
dock.floating = false;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.hiding = "dodgewindows";

function spacer(panel) {
    const s = panel.addWidget("org.kde.plasma.panelspacer");
    s.currentConfigGroup = ["General"];
    s.writeConfig("expanding", false);
    s.writeConfig("length", 4);
}
spacer(dock);
const tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.konsole.desktop",
    "applications:firefox.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.plasma-systemmonitor.desktop"
]);
spacer(dock);

const dockColorizer = dock.addWidget("luisbocanegra.panel.colorizer");
dockColorizer.currentConfigGroup = ["General"];
dockColorizer.writeConfig("globalSettings", JSON.stringify(presetSettings("Senko Dock")));
dockColorizer.writeConfig("presetAutoloading", JSON.stringify({ enabled: true, normal: PRESETS + "Senko Dock" }));
dockColorizer.writeConfig("lastPreset", PRESETS + "Senko Dock");
dockColorizer.writeConfig("hideWidget", true);
dockColorizer.writeConfig("animatePropertyChanges", true);
dockColorizer.writeConfig("animationDuration", 380);

// ---------- рабочий стол: живые обои + часы по центру ----------
for (const d of desktops()) {
    d.wallpaperPlugin = "senko.video";
    d.currentConfigGroup = ["Wallpaper", "senko.video", "General"];
    d.writeConfig("VideoUrl", "file://@WALL@");
    d.writeConfig("Dim", 0.12);
    d.writeConfig("PauseWhenCovered", true);
    for (const w of d.widgets()) {
        if (w.type === "senko.deskclock") w.remove();
    }
    const g = screenGeometry(d.screen);
    d.addWidget("senko.deskclock", Math.round(g.width / 2 - 240), Math.round(g.height / 2 - 220), 480, 190);
}
