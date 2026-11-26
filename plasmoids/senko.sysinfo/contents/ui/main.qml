import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // CPU package temperature (x86_pkg_temp) — the hottest point of the die, what throttling uses.
    // ksystemstats only offers per-core average/max, which reads ~10 °C lower under load.
    QtObject { id: cpuTemp; property real value: 0 }
    P5Support.DataSource {
        id: pkgTemp
        engine: "executable"
        readonly property string cmd: "sh -c 'for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && { cat $z/temp; break; }; done'"
        onNewData: (source, data) => {
            const v = parseInt(data["stdout"]);
            if (isFinite(v)) cpuTemp.value = v / 1000;
            disconnectSource(source);
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: pkgTemp.connectSource(pkgTemp.cmd) }
    Sensors.Sensor { id: cpuLoad; sensorId: "cpu/all/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuTemp; sensorId: "gpu/gpu0/temperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuLoad; sensorId: "gpu/gpu0/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuPower; sensorId: "gpu/gpu0/power"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuName; sensorId: "gpu/gpu0/name" }
    Sensors.Sensor { id: memPct; sensorId: "memory/physical/usedPercent"; updateRateLimit: 2000 }
    Sensors.Sensor { id: memUsed; sensorId: "memory/physical/used"; updateRateLimit: 2000 }
    Sensors.Sensor { id: memTotal; sensorId: "memory/physical/total" }
    Sensors.Sensor { id: fan1; sensorId: "lmsensors/lenovo_wmi_other-virtual-0/fan1"; updateRateLimit: 2000 }
    Sensors.Sensor { id: fan2; sensorId: "lmsensors/lenovo_wmi_other-virtual-0/fan2"; updateRateLimit: 2000 }
    Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: 1500 }
    Sensors.Sensor { id: up; sensorId: "network/all/upload"; updateRateLimit: 1500 }

    function num(s) { const v = Number(s.value); return isFinite(v) ? v : 0 }

    // скорость: возвращает [число, единица], коротко
    function speed(bps) {
        const k = bps / 1024;
        if (k < 1) return ["0", "K/s"];
        if (k < 100) return [k.toFixed(k < 10 ? 1 : 0), "K/s"];
        if (k < 1024) return [k.toFixed(0), "K/s"];
        const m = k / 1024;
        return [m.toFixed(m < 10 ? 1 : 0), "M/s"];
    }
    function tempColor(t) {
        if (t >= 88) return "#ff7a8a";
        if (t >= 75) return "#ffc27a";
        return Kirigami.Theme.textColor;
    }

    readonly property var dn: speed(num(down))
    readonly property var upv: speed(num(up))
    readonly property real fanRpm: Math.max(num(fan1), num(fan2))

    toolTipMainText: "Система"
    toolTipSubText: "CPU: " + Math.round(num(cpuTemp)) + " °C, загрузка " + Math.round(num(cpuLoad)) + " %"
        + "\nGPU: " + Math.round(num(gpuTemp)) + " °C, загрузка " + Math.round(num(gpuLoad)) + " %, " + Math.round(num(gpuPower)) + " Вт"
        + "\nПамять: " + (num(memUsed) / 1073741824).toFixed(1) + " / " + (num(memTotal) / 1073741824).toFixed(1) + " ГБ"
        + "\nВентиляторы: " + Math.round(num(fan1)) + " / " + Math.round(num(fan2)) + " об/мин"
        + "\nСеть: ↓ " + down.formattedValue + "   ↑ " + up.formattedValue

    fullRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth + 12
        Layout.preferredWidth: row.implicitWidth + 12
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: exec.connectSource("plasma-systemmonitor")
        P5Support.DataSource {
            id: exec
            engine: "executable"
            onNewData: (source) => disconnectSource(source)
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 21
            Stat { icon: "cpu"; value: Math.round(root.num(cpuTemp)) + "°"; sample: "88°"; valueColor: root.tempColor(root.num(cpuTemp)) }
            Stat { icon: "gpu"; value: Math.round(root.num(gpuTemp)) + "°"; sample: "88°"; valueColor: root.tempColor(root.num(gpuTemp)) }
            Stat { icon: "ram"; value: Math.round(root.num(memPct)); unit: "%"; sample: "88"; unitSample: "%" }
            Stat { icon: "fan"; value: (root.fanRpm / 1000).toFixed(1); unit: "k"; sample: "8.8"; unitSample: "k" }
            RowLayout {
                spacing: 7
                Stat { icon: "down"; value: root.dn[0]; unit: root.dn[1]; sample: "888"; unitSample: "K/s" }
                Stat { icon: "up"; value: root.upv[0]; unit: root.upv[1]; sample: "888"; unitSample: "K/s" }
            }
        }
    }
}
