import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property date now: new Date()
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    readonly property int hour: now.getHours()
    readonly property string greeting: hour < 5 ? "доброй ночи" : hour < 12 ? "доброе утро" : hour < 18 ? "добрый день" : hour < 23 ? "добрый вечер" : "доброй ночи"

    fullRepresentation: Item {
        Layout.preferredWidth: 480
        Layout.preferredHeight: 190
        Layout.minimumWidth: 300
        Layout.minimumHeight: 150

        ColumnLayout {
            id: col
            anchors.centerIn: parent
            spacing: -8
            visible: false
            layer.enabled: true

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(root.now, "HH:mm")
                color: "white"
                font { family: "Nunito"; pixelSize: 112; weight: Font.Black; features: ({ "tnum": 1 }) }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.locale().toString(root.now, "dddd, d MMMM")
                color: "white"
                font { family: "Nunito"; pixelSize: 26; weight: Font.ExtraBold }
            }
        }

        // мягкая тёмная подложка, чтобы читалось на светлых обоях
        MultiEffect {
            x: col.x; y: col.y + 3; width: col.width; height: col.height
            source: col
            colorization: 1
            colorizationColor: "#2a1428"
            brightness: -0.85
            blurEnabled: true
            blurMax: 24
            autoPaddingEnabled: false
            blur: 0.45
            opacity: 0.75
        }
        // градиент лаванда → розовый → персик по форме текста
        GE.LinearGradient {
            x: col.x; y: col.y; width: col.width; height: col.height
            source: col
            start: Qt.point(0, 0)
            end: Qt.point(col.width * 0.25, col.height)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#e4c2fa" }
                GradientStop { position: 0.5; color: "#f6aed4" }
                GradientStop { position: 1.0; color: "#ffcfa8" }
            }
        }
    }
}
