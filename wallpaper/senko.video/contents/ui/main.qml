import QtQuick
import QtMultimedia
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

WallpaperItem {
    id: root
    readonly property string videoUrl: root.configuration.VideoUrl
    readonly property bool pauseWhenCovered: root.configuration.PauseWhenCovered
    readonly property real dim: root.configuration.Dim

    // --- есть ли развёрнутое/полноэкранное окно на этом экране и рабочем столе
    TaskManager.VirtualDesktopInfo { id: vdInfo }
    TaskManager.ActivityInfo { id: actInfo }
    TaskManager.TasksModel {
        id: tasks
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        groupMode: TaskManager.TasksModel.GroupDisabled
        virtualDesktop: vdInfo.currentDesktop
        activity: actInfo.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        filterByScreen: false
        filterHidden: true
        filterMinimized: true
        onDataChanged: root.updateCovered()
        onCountChanged: root.updateCovered()
        onRowsInserted: root.updateCovered()
        onRowsRemoved: root.updateCovered()
    }
    property bool covered: false
    function updateCovered() {
        let c = false;
        for (let i = 0; i < tasks.count; i++) {
            const idx = tasks.index(i, 0);
            if (tasks.data(idx, TaskManager.AbstractTasksModel.IsMaximized) || tasks.data(idx, TaskManager.AbstractTasksModel.IsFullScreen)) { c = true; break; }
        }
        covered = c;
    }
    Timer { interval: 400; running: true; repeat: false; onTriggered: root.updateCovered() }

    readonly property bool shouldPlay: !(pauseWhenCovered && covered)

    Rectangle { anchors.fill: parent; color: "#1b1622" }

    MediaPlayer {
        id: player
        source: root.videoUrl
        loops: MediaPlayer.Infinite
        videoOutput: video
        playbackRate: root.configuration.Rate || 1.0
        onSourceChanged: if (root.shouldPlay) play()
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia && root.shouldPlay) play()
    }
    VideoOutput {
        id: video
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: root.dim; visible: root.dim > 0 }

    onShouldPlayChanged: shouldPlay ? player.play() : player.pause()
    Component.onCompleted: if (videoUrl !== "") player.play()
}
