import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool hasPlayer: !!player && (player.track !== "" || player.playbackStatus === Mpris.PlaybackStatus.Playing)
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string title: player ? (player.track || player.identity || "") : ""
    readonly property string artist: player ? (player.artist || "") : ""

    Plasmoid.status: hasPlayer ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: title
    toolTipSubText: artist + (player && player.album ? " — " + player.album : "") + (player ? "\n" + player.identity : "")

    // позиция обновляется по запросу
    Timer {
        interval: 1000; repeat: true
        running: root.playing && root.player && root.player.length > 0
        onTriggered: root.player.updatePosition()
    }

    fullRepresentation: Item {
        id: full
        readonly property int textWidth: 135
        readonly property int contentWidth: root.hasPlayer ? row.implicitWidth + 8 : 0
        Layout.minimumWidth: widthAnim
        Layout.preferredWidth: widthAnim
        Layout.maximumWidth: widthAnim
        Layout.fillHeight: true
        property real widthAnim: contentWidth
        Behavior on widthAnim { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        clip: true

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: 4
            spacing: 6
            opacity: root.hasPlayer ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // обложка
            Item {
                Layout.alignment: Qt.AlignVCenter
                width: 22; height: 22
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#5a4766" }
                        GradientStop { position: 1; color: "#6b4a5e" }
                    }
                    visible: art.status !== Image.Ready
                    Image {
                        anchors.centerIn: parent
                        width: 14; height: 14; sourceSize: Qt.size(28, 28)
                        source: Qt.resolvedUrl("../icons/note.svg")
                    }
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player ? root.player.artUrl : ""
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                Kirigami.ShadowedTexture {
                    anchors.fill: parent
                    source: art.status === Image.Ready ? art : null
                    visible: art.status === Image.Ready
                    radius: 6
                    color: "transparent"
                }
            }

            // название — исполнитель + полоска прогресса
            MouseArea {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: full.textWidth
                implicitHeight: 24
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.player && root.player.canRaise) root.player.Raise()
                Item {
                    id: textClip
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -1
                    height: label.implicitHeight
                    clip: true
                    Row {
                        id: label
                        spacing: 0
                        property bool overflow: implicitWidth > textClip.width
                        x: 0
                        Text {
                            text: root.title
                            color: "#f3e6fb"
                            font { family: "Nunito"; pixelSize: 13; weight: Font.ExtraBold }
                        }
                        Text {
                            text: root.artist ? "  ·  " + root.artist : ""
                            color: "#f4b3d3"
                            opacity: 0.85
                            font { family: "Nunito"; pixelSize: 12; weight: Font.Bold }
                        }
                        // бегущая строка только при наведении, чтобы панель не перерисовывалась постоянно
                        SequentialAnimation on x {
                            running: label.overflow && hoverArea.hovered
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) label.x = 0
                            PauseAnimation { duration: 600 }
                            NumberAnimation { to: textClip.width - label.implicitWidth; duration: Math.max(1500, (label.implicitWidth - textClip.width) * 28); easing.type: Easing.InOutSine }
                            PauseAnimation { duration: 900 }
                            NumberAnimation { to: 0; duration: Math.max(1500, (label.implicitWidth - textClip.width) * 28); easing.type: Easing.InOutSine }
                        }
                    }
                }
                // мягкое затухание текста справа
                Rectangle {
                    anchors.right: textClip.right; anchors.top: textClip.top; anchors.bottom: textClip.bottom
                    width: 18
                    visible: label.overflow
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: "#231b29" }
                    }
                }
                HoverHandler { id: hoverArea }
                // прогресс
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                    height: 2; radius: 1
                    color: Qt.rgba(1, 1, 1, 0.12)
                    visible: root.player && root.player.length > 0
                    Rectangle {
                        height: parent.height; radius: 1
                        width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#dcb6f2" }
                            GradientStop { position: 1; color: "#f7a8cf" }
                        }
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Btn { icon: "prev"; enabled: !!root.player && root.player.canGoPrevious; onClicked: root.player.Previous() }
                Btn { icon: root.playing ? "pause" : "play"; iconScale: 0.7; enabled: !!root.player && (root.player.canPlay || root.player.canPause); onClicked: root.player.PlayPause() }
                Btn { icon: "next"; enabled: !!root.player && root.player.canGoNext; onClicked: root.player.Next() }
            }
        }

        // колесо мыши — громкость плеера
        WheelHandler {
            onWheel: (event) => {
                if (!root.player) return;
                const v = root.player.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05);
                root.player.volume = Math.max(0, Math.min(1, v));
            }
        }
    }
}
