/*
 * Pillbox Stats – CPU, GPU, RAM and temperature for a panel pill, as rings, curves,
 * bars or plain numbers. A click opens the last minute as large curves.
 * Updates every 2 s; nothing animates in between.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property int interval: cfg.updateInterval
    readonly property string look: cfg.style || "rings"          // rings | spark | bars | numbers
    readonly property int keep: 30                                // history points (1 minute at 2 s)

    // ---- the four values and their recent history
    component Metric: QtObject {
        property string key
        property string label
        property string unit: "%"
        property color tone
        property real max: 100
        property var sensor
        property var hist: []
        readonly property real value: { const v = sensor ? sensor.value : NaN; return (v === undefined || v === null || isNaN(v)) ? NaN : v }
        readonly property real frac: isNaN(value) ? 0 : Math.max(0, Math.min(1, value / max))
        readonly property string text: isNaN(value) ? "–" : Math.round(value) + unit
        onValueChanged: { if (isNaN(value)) return; const h = hist.slice(-(root.keep - 1)); h.push(value); hist = h }
    }
    Sensors.Sensor { id: cpuSensor;  sensorId: "cpu/all/usage";               updateRateLimit: root.interval }
    Sensors.Sensor { id: gpuSensor;  sensorId: "gpu/all/usage";               updateRateLimit: root.interval }
    Sensors.Sensor { id: ramSensor;  sensorId: "memory/physical/usedPercent"; updateRateLimit: root.interval }
    Sensors.Sensor { id: tempSensor; sensorId: root.cfg.tempSensor;           updateRateLimit: root.interval }
    readonly property var metrics: [
        cpuM, gpuM, ramM, tempM
    ]
    Metric { id: cpuM;  key: "cpu";  label: "CPU"; tone: "#7fd3f0"; sensor: cpuSensor }
    Metric { id: gpuM;  key: "gpu";  label: "GPU"; tone: "#7fdcb0"; sensor: gpuSensor }
    Metric { id: ramM;  key: "ram";  label: "RAM"; tone: "#b49cf0"; sensor: ramSensor }
    Metric { id: tempM; key: "temp"; label: "TEMP"; unit: "°"; max: 100; tone: tempM.value > 80 ? "#ff7a6a" : tempM.value > 65 ? "#ffb36b" : "#e0bd6e"; sensor: tempSensor }
    function shown(m) {
        return m.key === "cpu" ? cfg.showCpu : m.key === "gpu" ? cfg.showGpu : m.key === "ram" ? cfg.showRam : cfg.showTemp
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("System")
    toolTipSubText: i18n("CPU %1 · GPU %2 · RAM %3 · %4", cpuM.text, gpuM.text, ramM.text, tempM.text)

    // ---------------------------------------------------------------- in the pill
    compactRepresentation: MouseArea {
        id: pill
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing * (root.look === "numbers" ? 1.6 : 1.3)
            Repeater {
                model: root.metrics
                delegate: Loader {
                    required property var modelData
                    visible: root.shown(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    sourceComponent: root.look === "spark" ? sparkC : root.look === "bars" ? barsC : root.look === "numbers" ? numbersC : ringC
                    onLoaded: item.m = modelData
                }
            }
        }
    }

    readonly property int lineH: Math.round(Kirigami.Units.gridUnit * 1.05)
    component Caption: PC3.Label {
        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.92)
        font.letterSpacing: 0.6
        font.weight: Font.Medium
        opacity: 0.55
    }
    component Value: PC3.Label {
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

    // a ring that fills with the value; the label sits beside it
    Component {
        id: ringC
        RowLayout {
            id: ringCRoot
            property var m: ({ label: "", tone: "white", frac: 0, hist: [], text: "", max: 100 })
            spacing: Kirigami.Units.smallSpacing
            Item {
                implicitWidth: root.lineH; implicitHeight: root.lineH
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"; strokeColor: Qt.rgba(1, 1, 1, 0.13); strokeWidth: 2.6; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: root.lineH / 2; centerY: root.lineH / 2; radiusX: root.lineH / 2 - 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        fillColor: "transparent"; strokeColor: m.tone; strokeWidth: 2.6; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: root.lineH / 2; centerY: root.lineH / 2; radiusX: root.lineH / 2 - 2; radiusY: radiusX; startAngle: -90; sweepAngle: Math.max(4, 360 * m.frac) }
                    }
                }
            }
            Caption { text: m.label }
        }
    }
    // a tiny curve of the last minute plus the value
    Component {
        id: sparkC
        RowLayout {
            id: sparkCRoot
            property var m: ({ label: "", tone: "white", frac: 0, hist: [], text: "", max: 100 })
            spacing: Kirigami.Units.smallSpacing
            Caption { text: m.label }
            Shape {
                implicitWidth: root.lineH * 2.6; implicitHeight: root.lineH * 0.8
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeColor: m.tone; strokeWidth: 1.6; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                    PathPolyline {
                        path: {
                            const h = m.hist, w = root.lineH * 2.6, hh = root.lineH * 0.8
                            if (h.length < 2) return [Qt.point(0, hh - 1), Qt.point(w, hh - 1)]
                            return h.map((v, i) => Qt.point(i * w / (h.length - 1), hh - 1 - Math.max(0, Math.min(1, v / m.max)) * (hh - 2)))
                        }
                    }
                }
            }
            Value { text: m.text }
        }
    }
    // eight small bars, newest brightest
    Component {
        id: barsC
        RowLayout {
            id: barsCRoot
            property var m: ({ label: "", tone: "white", frac: 0, hist: [], text: "", max: 100 })
            spacing: Kirigami.Units.smallSpacing
            Caption { text: m.label }
            Row {
                spacing: 2
                Layout.preferredHeight: root.lineH * 0.85
                Repeater {
                    model: 8
                    Rectangle {
                        required property int index
                        readonly property var h: barsCRoot.m.hist.slice(-8)
                        readonly property real v: index - (8 - h.length) >= 0 ? h[index - (8 - h.length)] : 0
                        anchors.bottom: parent.bottom
                        width: 3; radius: 1.5
                        height: Math.max(2, (root.lineH * 0.85) * Math.max(0, Math.min(1, v / barsCRoot.m.max)))
                        color: barsCRoot.m.tone
                        opacity: 0.3 + index * 0.1
                    }
                }
            }
        }
    }
    // plain numbers, but set like a dashboard: small label, strong tabular value
    Component {
        id: numbersC
        RowLayout {
            id: numbersCRoot
            property var m: ({ label: "", tone: "white", frac: 0, hist: [], text: "", max: 100 })
            spacing: Kirigami.Units.smallSpacing
            Rectangle { width: 5; height: 5; radius: 2.5; color: m.tone; Layout.alignment: Qt.AlignVCenter }
            Caption { text: m.label }
            Value { text: m.text }
        }
    }

    // ---------------------------------------------------------------- the panel on click
    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: Kirigami.Units.gridUnit * 15
        GridLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            columns: 2
            rowSpacing: Kirigami.Units.largeSpacing
            columnSpacing: Kirigami.Units.largeSpacing
            Repeater {
                model: root.metrics
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Kirigami.Units.gridUnit * 0.7
                    color: Qt.rgba(1, 1, 1, 0.05)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: 2
                        RowLayout {
                            Caption { text: tile.modelData.label; Layout.fillWidth: true }
                            PC3.Label { text: tile.modelData.text; font.pixelSize: Kirigami.Units.gridUnit * 1.1; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                        }
                        Item {
                            id: bigBox
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        Shape {
                            id: big
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            readonly property var pts: {
                                const h = tile.modelData.hist, w = bigBox.width, hh = bigBox.height
                                if (h.length < 2 || w <= 0) return []
                                return h.map((v, i) => Qt.point(i * w / (h.length - 1), hh - 1 - Math.max(0, Math.min(1, v / tile.modelData.max)) * (hh - 2)))
                            }
                            ShapePath {
                                strokeColor: "transparent"
                                fillGradient: LinearGradient {
                                    x1: 0; y1: 0; x2: 0; y2: bigBox.height
                                    GradientStop { position: 0; color: Qt.rgba(tile.modelData.tone.r, tile.modelData.tone.g, tile.modelData.tone.b, 0.35) }
                                    GradientStop { position: 1; color: Qt.rgba(tile.modelData.tone.r, tile.modelData.tone.g, tile.modelData.tone.b, 0) }
                                }
                                PathPolyline { path: big.pts.length ? [Qt.point(big.pts[0].x, bigBox.height)].concat(big.pts).concat([Qt.point(big.pts[big.pts.length - 1].x, bigBox.height)]) : [] }
                            }
                            ShapePath {
                                fillColor: "transparent"; strokeColor: tile.modelData.tone; strokeWidth: 2; joinStyle: ShapePath.RoundJoin
                                PathPolyline { path: big.pts }
                            }
                        }
                        }
                    }
                }
            }
        }
    }
}
