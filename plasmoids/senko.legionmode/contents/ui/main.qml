import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Legion power-mode ring: same colours as the power button LED (Fn+Q).
// low-power = blue, balanced = white, performance = red, custom (our lenovo-tune) = purple.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property var modes: [
        { id: "low-power",   name: "Тихий",          sub: "power-saver, тихие кулеры",    color: "#5590ff", glow: "#2a64ff",
          cmd: "powerprofilesctl set power-saver" },
        { id: "balanced",    name: "Баланс",         sub: "заводской сбалансированный",   color: "#ffffff", glow: "#ffffff",
          cmd: "powerprofilesctl set balanced" },
        { id: "performance", name: "Производительность", sub: "заводской: 97°C / 115 Вт", color: "#ff1f3d", glow: "#ff0026",
          cmd: "powerprofilesctl set performance" },
        { id: "custom",      name: "Игровой",        sub: "наш: 93°C / 70 Вт, −130 мВ",   color: "#c27bff", glow: "#a44dff",
          cmd: "systemctl start lenovo-tune.service" }
    ]

    property string profile: ""
    property string pending: ""          // mode we asked for, until sysfs confirms
    property int cpuTemp: 0
    property int gpuTemp: 0
    property bool onAC: true

    function modeOf(id) {
        for (let i = 0; i < modes.length; i++) if (modes[i].id === id) return modes[i];
        return { id: id, name: id || "…", sub: "", color: "#8a8296", glow: "#5c5466", cmd: "" };
    }
    readonly property var cur: modeOf(pending !== "" ? pending : profile)
    readonly property color ringColor: cur.color
    readonly property color glowColor: cur.glow

    // ---- polling -------------------------------------------------------
    // helper prints: profile / cpu °C / gpu °C / AC online  (contents/code/legion-status)
    readonly property string pollCmd: "sh '" + Qt.resolvedUrl("../code/legion-status").toString().replace("file://", "") + "'"

    P5Support.DataSource {
        id: poll
        engine: "executable"
        onNewData: (source, data) => {
            const lines = (data["stdout"] || "").trim().split("\n");
            if (lines.length >= 1 && lines[0] !== "") {
                root.profile = lines[0].trim();
                if (root.pending === root.profile) root.pending = "";
            }
            if (lines.length >= 2) root.cpuTemp = parseInt(lines[1]) || 0;
            if (lines.length >= 3) root.gpuTemp = parseInt(lines[2]) || 0;
            if (lines.length >= 4) root.onAC = lines[3].trim() === "1";
            disconnectSource(source);
        }
    }
    Timer {
        interval: root.expanded ? 1000 : 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: poll.connectSource(root.pollCmd)
    }
    Timer { id: pendingTimeout; interval: 8000; onTriggered: root.pending = "" }

    P5Support.DataSource { id: exec; engine: "executable"; onNewData: (s) => disconnectSource(s) }
    function setMode(id) {
        const m = modeOf(id);
        if (!m.cmd) return;
        pending = id;
        pendingTimeout.restart();
        exec.connectSource(m.cmd);
    }
    function cycle() {
        // like Fn+Q, but the purple custom mode is part of the loop
        const order = ["low-power", "balanced", "performance", "custom"];
        let i = order.indexOf(cur.id);
        setMode(order[(i + 1) % order.length]);
    }

    toolTipMainText: "Режим Legion: " + cur.name
    toolTipSubText: "CPU " + cpuTemp + "°C · GPU " + gpuTemp + "°C\nЛКМ — меню, колёсико — переключить"

    // ---- the ring ------------------------------------------------------
    component LegionRing: Item {
        id: ring
        // Legion logo: thick ring cut by three straight slots (down, upper-left, upper-right)
        property color color: root.ringColor
        property color glow: root.glowColor
        property real glowSize: 4
        property bool lit: true
        implicitWidth: 18; implicitHeight: 18

        Behavior on color { ColorAnimation { duration: 350 } }
        Behavior on glow { ColorAnimation { duration: 350 } }
        onColorChanged: canvas.requestPaint()
        onGlowChanged: canvas.requestPaint()

        Canvas {
            id: canvas
            // plenty of room around the ring so the glow is never clipped to a square
            anchors.centerIn: parent
            width: ring.width + ring.glowSize * 6
            height: ring.height + ring.glowSize * 6
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2, cy = height / 2;
                const R = Math.min(ring.width, ring.height) / 2;
                const r = R * 0.585;                 // inner hole, as in the logo
                // ring (annulus) with glow
                ctx.save();
                ctx.shadowColor = ring.glow;
                ctx.shadowBlur = ring.lit ? ring.glowSize * 2 : 0;
                ctx.fillStyle = ring.color;
                ctx.beginPath();
                ctx.arc(cx, cy, R, 0, 2 * Math.PI, false);
                ctx.fill();
                ctx.restore();
                // cut the hole and the three slots (120° apart: down, upper-left, upper-right)
                ctx.globalCompositeOperation = "destination-out";
                ctx.fillStyle = "black";
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI, false);
                ctx.fill();
                ctx.strokeStyle = "black";
                ctx.lineWidth = R * 0.27;
                ctx.lineCap = "butt";
                const angles = [90, 210, 330];
                for (let i = 0; i < 3; i++) {
                    const a = angles[i] * Math.PI / 180;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(a) * r * 0.5, cy + Math.sin(a) * r * 0.5);
                    ctx.lineTo(cx + Math.cos(a) * (R + 0.5), cy + Math.sin(a) * (R + 0.5));
                    ctx.stroke();
                }
                ctx.globalCompositeOperation = "source-over";
            }
        }
    }

    compactRepresentation: MouseArea {
        id: compact
        Layout.minimumWidth: 30
        Layout.preferredWidth: 30
        Layout.fillHeight: true
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => mouse.button === Qt.MiddleButton ? root.cycle() : (root.expanded = !root.expanded)
        onWheel: (wheel) => root.cycle()

        Rectangle {
            anchors.centerIn: parent
            width: 28; height: Math.min(parent.height - 4, 26)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, compact.containsMouse || root.expanded ? 0.09 : 0)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        LegionRing {
            anchors.centerIn: parent
            width: 17; height: 17
            glowSize: 3
            opacity: root.pending !== "" ? 0.55 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    fullRepresentation: Item {
        id: popup
        Layout.preferredWidth: Kirigami.Units.gridUnit * 17
        Layout.preferredHeight: col.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: col.implicitHeight + Kirigami.Units.largeSpacing * 2

        // background comes from the "Senko Glass" Plasma theme (glassy, terminal colour)

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: 8

            RowLayout {
                spacing: 12
                LegionRing { width: 34; height: 34; glowSize: 5; Layout.preferredWidth: 34; Layout.preferredHeight: 34; Layout.margins: 4 }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: root.cur.name
                        color: root.ringColor
                        font { family: "Nunito"; pixelSize: 20; weight: Font.Black }
                        Behavior on color { ColorAnimation { duration: 350 } }
                    }
                    Text {
                        text: "CPU " + root.cpuTemp + "°C  ·  GPU " + root.gpuTemp + "°C" + (root.onAC ? "" : "  ·  от батареи")
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font { family: "Nunito"; pixelSize: 12; weight: Font.Bold; features: ({ "tnum": 1 }) }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            Repeater {
                model: root.modes
                delegate: MouseArea {
                    id: item
                    required property var modelData
                    readonly property bool active: root.cur.id === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    hoverEnabled: true
                    onClicked: root.setMode(modelData.id)

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: item.active ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, item.containsMouse ? 0.06 : 0)
                        border.width: item.active ? 1.2 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 12; Layout.preferredHeight: 12
                            width: 12; height: 12; radius: 6
                            color: item.modelData.color
                            opacity: 1
                            scale: item.active ? 1.15 : 0.9
                            Behavior on scale { NumberAnimation { duration: 150 } }
                            layer.enabled: false
                        }
                        Column {
                            spacing: -1
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                text: item.modelData.name
                                color: item.active ? item.modelData.color : "#f4efff"
                                font { family: "Nunito"; pixelSize: 14; weight: Font.ExtraBold }
                            }
                            Text {
                                text: item.modelData.sub
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font { family: "Nunito"; pixelSize: 11; weight: Font.DemiBold }
                            }
                        }
                        Text {
                            visible: item.active
                            text: root.pending === item.modelData.id ? "…" : "●"
                            color: item.modelData.color
                            font { family: "Nunito"; pixelSize: 12; weight: Font.Black }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
