import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showGpu: showGpu.checked
    property alias cfg_showRam: showRam.checked
    property alias cfg_showTemp: showTemp.checked
    property alias cfg_tempSensor: tempSensor.text
    property alias cfg_updateInterval: updateInterval.value
    property string cfg_style

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Look:")
            textRole: "text"; valueRole: "value"
            model: [{ text: i18n("Rings"), value: "rings" }, { text: i18n("Curves"), value: "spark" },
                    { text: i18n("Bars"), value: "bars" }, { text: i18n("Numbers"), value: "numbers" }]
            currentIndex: Math.max(0, indexOfValue(cfg_style))
            onActivated: cfg_style = currentValue
        }
        QQC2.CheckBox { id: showCpu; Kirigami.FormData.label: i18n("Show:"); text: i18n("CPU usage") }
        QQC2.CheckBox { id: showGpu; text: i18n("GPU usage") }
        QQC2.CheckBox { id: showRam; text: i18n("Memory usage") }
        QQC2.CheckBox { id: showTemp; text: i18n("Temperature") }

        QQC2.TextField {
            id: tempSensor
            Kirigami.FormData.label: i18n("Temperature sensor:")
            placeholderText: "cpu/all/maximumTemperature"
        }
        QQC2.Label {
            text: i18n("Any sensor id from “kstatsviewer --list”, e.g. gpu/gpu1/temperature")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        QQC2.SpinBox {
            id: updateInterval
            Kirigami.FormData.label: i18n("Update every (ms):")
            from: 500; to: 10000; stepSize: 500
        }
    }
}
