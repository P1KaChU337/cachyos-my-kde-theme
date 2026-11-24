import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page
    property alias cfg_VideoUrl: urlField.text
    property alias cfg_PauseWhenCovered: pauseBox.checked
    property alias cfg_Dim: dimSlider.value
    property alias cfg_Rate: rateSlider.value

    Row {
        Kirigami.FormData.label: "Видео:"
        spacing: Kirigami.Units.smallSpacing
        QQC2.TextField { id: urlField; width: Kirigami.Units.gridUnit * 20 }
        QQC2.Button { text: "Выбрать…"; icon.name: "document-open"; onClicked: dlg.open() }
    }
    FileDialog {
        id: dlg
        nameFilters: ["Видео (*.mp4 *.webm *.mkv *.mov)"]
        onAccepted: urlField.text = selectedFile
    }
    QQC2.CheckBox { id: pauseBox; Kirigami.FormData.label: "Пауза:"; text: "под развёрнутыми окнами" }
    QQC2.Slider { id: dimSlider; Kirigami.FormData.label: "Затемнение:"; from: 0; to: 0.7; stepSize: 0.05 }
    QQC2.Slider { id: rateSlider; Kirigami.FormData.label: "Скорость:"; from: 0.5; to: 1.5; stepSize: 0.05 }
}
