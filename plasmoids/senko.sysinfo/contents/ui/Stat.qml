import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// иконка + значение (+ необязательное второе значение через «/»), фиксированная ширина
RowLayout {
    id: stat
    property string icon
    property string value: "–"
    property string unit
    property string sample: "888"
    property string unitSample
    property color valueColor: Kirigami.Theme.textColor
    property string value2
    property string sample2: sample
    property color valueColor2: Kirigami.Theme.textColor
    spacing: 4

    component Num: Text {
        color: Kirigami.Theme.textColor
        font { family: "Nunito"; pixelSize: 13; weight: Font.ExtraBold; features: ({ "tnum": 1 }) }
        Behavior on color { ColorAnimation { duration: 400 } }
    }
    component Small: Text {
        color: Kirigami.Theme.textColor
        opacity: 0.55
        font { family: "Nunito"; pixelSize: 10; weight: Font.Bold }
    }

    Image {
        Layout.alignment: Qt.AlignVCenter
        readonly property int size: 15
        source: Qt.resolvedUrl("../icons/" + stat.icon + ".svg")
        sourceSize: Qt.size(size * 2, size * 2)
        Layout.preferredWidth: size; Layout.preferredHeight: size
        smooth: true
    }
    Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: m1.advanceWidth + (stat.unit ? mu.advanceWidth + 2 : 0)
                       + (stat.value2 ? ms.advanceWidth + m2.advanceWidth : 0)
        implicitHeight: v1.implicitHeight
        TextMetrics { id: m1; font: v1.font; text: stat.sample }
        TextMetrics { id: mu; font: u1.font; text: stat.unitSample || stat.unit }
        TextMetrics { id: ms; font: sep.font; text: " / " }
        TextMetrics { id: m2; font: v1.font; text: stat.sample2 }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            Num { id: v1; text: stat.value; color: stat.valueColor }
            Small { id: u1; text: stat.unit; visible: !!stat.unit; leftPadding: 2; anchors.baseline: v1.baseline }
            Small { id: sep; text: " / "; visible: !!stat.value2; anchors.baseline: v1.baseline }
            Num { text: stat.value2; visible: !!stat.value2; color: stat.valueColor2 }
        }
    }
}
