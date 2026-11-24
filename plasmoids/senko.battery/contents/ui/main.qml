import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
        interval: 0
    }
    readonly property var bat: pm.data["Battery"] || ({})
    readonly property int percent: bat["Percent"] !== undefined ? bat["Percent"] : 0
    readonly property string state: bat["State"] || ""
    readonly property bool plugged: !!(pm.data["AC Adapter"] && pm.data["AC Adapter"]["Plugged in"])
    readonly property bool charging: state === "Charging"
    readonly property real remainingMs: bat["Remaining msec"] || 0

    readonly property color levelColor: percent <= 15 ? "#f28fad" : percent <= 35 ? "#ffc27a" : "#a6e3b8"
    readonly property color levelColor2: percent <= 15 ? "#f7a8c2" : percent <= 35 ? "#ffe0a8" : "#96dfe0"

    function fmtTime(ms) {
        const m = Math.round(ms / 60000);
        return m >= 60 ? Math.floor(m / 60) + " ч " + (m % 60) + " мин" : m + " мин";
    }
    toolTipMainText: "Батарея " + percent + "%"
    toolTipSubText: charging ? "Заряжается" + (remainingMs > 0 ? ", до полной " + fmtTime(remainingMs) : "")
        : plugged ? (state === "FullyCharged" ? "Заряжена, от сети" : "От сети, не заряжается (режим сбережения батареи)")
        : (remainingMs > 0 ? "Осталось примерно " + fmtTime(remainingMs) : "От батареи")

    fullRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth + 8
        Layout.preferredWidth: row.implicitWidth + 8
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: exec.connectSource("kcmshell6 kcm_powerdevilprofilesconfig")
        P5Support.DataSource { id: exec; engine: "executable"; onNewData: (s) => disconnectSource(s) }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 5

            // батарейка
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 22; implicitHeight: 12
                Rectangle {
                    id: shell
                    width: 19; height: 12; radius: 3.5
                    color: "transparent"
                    border.width: 1.6
                    border.color: Qt.rgba(1, 1, 1, 0.55)
                    Rectangle {
                        x: 2.5; y: 2.5
                        height: parent.height - 5
                        radius: 1.8
                        width: Math.max(2, (parent.width - 5) * Math.min(100, root.percent) / 100)
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: root.levelColor }
                            GradientStop { position: 1; color: root.levelColor2 }
                        }
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }
                Rectangle {
                    anchors.left: shell.right; anchors.leftMargin: 1
                    anchors.verticalCenter: shell.verticalCenter
                    width: 2; height: 5; radius: 1
                    color: Qt.rgba(1, 1, 1, 0.55)
                }
                // молния при зарядке / вилка от сети
                Text {
                    anchors.centerIn: shell
                    visible: root.plugged
                    text: root.charging ? "" : ""
                    color: "#231b29"
                    style: Text.Outline; styleColor: "#fbe9ff"
                    font { family: "Maple Mono NF"; pixelSize: 9; weight: Font.Bold }
                }
            }
        }
    }
}
