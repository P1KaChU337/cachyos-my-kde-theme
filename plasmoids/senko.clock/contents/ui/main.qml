import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // палитра темы
    readonly property color cHour: "#dcb6f2"
    readonly property color cColon: "#f4b3d3"
    readonly property color cMin: "#f7a8cf"
    readonly property color cDate: "#ffd3b0"

    property date now: new Date()
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    readonly property string hh: Qt.formatTime(now, "HH")
    readonly property string mm: Qt.formatTime(now, "mm")
    readonly property string dateText: {
        const d = Qt.locale().dayName(now.getDay(), Locale.ShortFormat);
        const m = Qt.locale().standaloneMonthName(now.getMonth(), Locale.ShortFormat).replace(".", "");
        return d + ", " + now.getDate() + " " + m;
    }

    toolTipMainText: Qt.locale().toString(now, "dddd, d MMMM yyyy")
    toolTipSubText: Qt.formatTime(now, "HH:mm:ss")

    compactRepresentation: MouseArea {
        id: compact
        Layout.minimumWidth: row.implicitWidth + 16
        Layout.preferredWidth: row.implicitWidth + 16
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Rectangle {
            anchors.centerIn: parent
            width: row.implicitWidth + 16
            height: Math.min(parent.height - 4, 26)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, compact.containsMouse || root.expanded ? 0.09 : 0)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 0
            Text {
                text: root.hh
                color: root.cHour
                font { family: "Nunito"; pixelSize: 19; weight: Font.Black; features: ({ "tnum": 1 }) }
            }
            Text {
                text: ":"
                color: root.cColon
                font { family: "Nunito"; pixelSize: 19; weight: Font.Black }
                Layout.bottomMargin: 3
                leftPadding: 1; rightPadding: 1
                opacity: root.now.getSeconds() % 2 === 0 ? 1 : 0.45
            }
            Text {
                text: root.mm
                color: root.cMin
                font { family: "Nunito"; pixelSize: 19; weight: Font.Black; features: ({ "tnum": 1 }) }
            }
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 21
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 19

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(root.now, "HH:mm")
                color: root.cHour
                font { family: "Nunito"; pixelSize: 34; weight: Font.Black }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.locale().toString(root.now, "dddd, d MMMM")
                color: root.cDate
                font { family: "Nunito"; pixelSize: 15; weight: Font.Bold }
            }
            PlasmaCalendar.MonthView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                today: root.now
                showWeekNumbers: false
            }
        }
    }
}
