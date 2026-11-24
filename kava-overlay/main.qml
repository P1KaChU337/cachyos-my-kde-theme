import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import org.kde.layershell as LayerShell

Window {
    id: win
    // цвета под тему панелей
    property color fillTop: "#dcb6f2"     // лаванда у гребня
    property color fillBottom: "#f4b3d3"  // розовый у низа
    property real fillAlpha: 0.72
    property color crest: "#fbe9ff"       // светлая кромка
    property real crestAlpha: 0.55

    width: Screen.width
    height: waveHeight
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    visible: false

    LayerShell.Window.scope: "kava-overlay"
    LayerShell.Window.layer: LayerShell.Window.LayerBottom
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    Component.onCompleted: visible = true

    function toPoints(p) {
        const out = [];
        if (!p || p.length < 4) return out;
        out.push(Qt.point(p[0], height));
        for (let i = 0; i < p.length; i += 2) out.push(Qt.point(p[i], p[i + 1]));
        out.push(Qt.point(p[p.length - 2], height));
        return out;
    }
    function toCrest(p) {
        const out = [];
        if (!p) return out;
        for (let i = 0; i < p.length; i += 2) out.push(Qt.point(p[i], p[i + 1]));
        return out;
    }

    Item {
        anchors.fill: parent
        opacity: wave.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }

        Repeater {
            model: 2
            delegate: Shape {
                required property int index
                readonly property var src: index === 0 ? wave.left : wave.right
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                antialiasing: true
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: win.height
                        GradientStop { position: 0; color: Qt.rgba(win.fillTop.r, win.fillTop.g, win.fillTop.b, win.fillAlpha) }
                        GradientStop { position: 1; color: Qt.rgba(win.fillBottom.r, win.fillBottom.g, win.fillBottom.b, Math.min(1, win.fillAlpha + 0.12)) }
                    }
                    PathPolyline { path: win.toPoints(src) }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.rgba(win.crest.r, win.crest.g, win.crest.b, win.crestAlpha)
                    strokeWidth: 1.5
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: win.toCrest(src) }
                }
            }
        }
    }
}
