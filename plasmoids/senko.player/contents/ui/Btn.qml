import QtQuick

MouseArea {
    id: btn
    property string icon
    property real iconScale: 0.62
    width: 24; height: 24
    hoverEnabled: true
    opacity: enabled ? 1 : 0.35
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(1, 1, 1, btn.pressed ? 0.16 : (btn.containsMouse ? 0.09 : 0))
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Image {
        anchors.centerIn: parent
        readonly property int s: Math.round(btn.width * btn.iconScale)
        width: s; height: s
        sourceSize: Qt.size(s * 2, s * 2)
        source: Qt.resolvedUrl("../icons/" + btn.icon + ".svg")
        smooth: true
        scale: btn.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
}
