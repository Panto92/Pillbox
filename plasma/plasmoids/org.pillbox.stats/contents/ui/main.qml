/*
 * Pillbox Stats – compact system readout for a panel "pill".
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    readonly property int interval: Plasmoid.configuration.updateInterval

    function fmt(sensor, unit) {
        const v = sensor.value
        return (v === undefined || v === null || isNaN(v)) ? "–" : Math.round(v) + unit
    }

    readonly property string cpuText: fmt(cpuSensor, "%")
    readonly property string gpuText: fmt(gpuSensor, "%")
    readonly property string ramText: fmt(ramSensor, "%")
    readonly property string tempText: fmt(tempSensor, "°C")

    Sensors.Sensor { id: cpuSensor;  sensorId: "cpu/all/usage";               updateRateLimit: root.interval }
    Sensors.Sensor { id: gpuSensor;  sensorId: "gpu/all/usage";               updateRateLimit: root.interval }
    Sensors.Sensor { id: ramSensor;  sensorId: "memory/physical/usedPercent"; updateRateLimit: root.interval }
    Sensors.Sensor { id: tempSensor; sensorId: Plasmoid.configuration.tempSensor; updateRateLimit: root.interval }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    toolTipMainText: i18n("System")
    toolTipSubText: i18n("CPU %1 · GPU %2 · RAM %3 · %4", cpuText, gpuText, ramText, tempText)

    fullRepresentation: RowLayout {
        spacing: Kirigami.Units.largeSpacing * 1.5
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth

        Stat { visible: Plasmoid.configuration.showCpu;  text: "CPU " + root.cpuText }
        Stat { visible: Plasmoid.configuration.showGpu;  text: "GPU " + root.gpuText }
        Stat { visible: Plasmoid.configuration.showRam;  text: "RAM " + root.ramText }
        Stat { visible: Plasmoid.configuration.showTemp; text: root.tempText }
    }

    component Stat: PC3.Label {
        font.family: Kirigami.Theme.fixedWidthFont.family
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.85
        Layout.alignment: Qt.AlignVCenter
    }
}
