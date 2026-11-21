/*
 * Pillbox Stats – CPU, GPU, RAM and temperature for a panel pill: plain text with bars,
 * rings with the number inside, calm chips, or the older rings / curves / bars / numbers.
 * Every value says what it is (RAM as used / total, which temperature, GPU heat and VRAM).
 * A click opens cards with the last minute and the details.
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
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property int interval: cfg.updateInterval
    readonly property string look: cfg.style || "detail"         // detail | ringtext | chips | rings | spark | bars | numbers
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
        property string text: isNaN(value) ? "–" : Math.round(value) + unit
        property string sub: ""                     // the small text beside or under the value
        property string ringText: text
        property bool bar: true                     // a usage bar makes sense (not for temperature)
        property bool alert: false                  // hot or nearly full: chips tint themselves
        onValueChanged: { if (isNaN(value)) return; const h = hist.slice(-(root.keep - 1)); h.push(value); hist = h }
    }
    Sensors.Sensor { id: cpuSensor;  sensorId: "cpu/all/usage";               updateRateLimit: root.interval }
    Sensors.Sensor { id: gpuSensor;  sensorId: "gpu/all/usage";               updateRateLimit: root.interval }
    Sensors.Sensor { id: ramSensor;  sensorId: "memory/physical/usedPercent"; updateRateLimit: root.interval }
    Sensors.Sensor { id: tempSensor; sensorId: root.cfg.tempSensor;           updateRateLimit: root.interval }
    // details: clock, names, memory in bytes, the graphics card (gpu0 … gpu3, whichever exists)
    Sensors.Sensor { id: cpuFreq;  sensorId: "cpu/all/averageFrequency";   updateRateLimit: root.interval }
    Sensors.Sensor { id: cpuName;  sensorId: "cpu/all/name" }
    Sensors.Sensor { id: cores;    sensorId: "cpu/all/coreCount" }
    Sensors.Sensor { id: threads;  sensorId: "cpu/all/cpuCount" }
    Sensors.Sensor { id: ramUsed;  sensorId: "memory/physical/used";       updateRateLimit: root.interval }
    Sensors.Sensor { id: ramTotal; sensorId: "memory/physical/total" }
    Sensors.Sensor { id: ramCache; sensorId: "memory/physical/cache";      updateRateLimit: root.interval; enabled: root.expanded }
    Sensors.Sensor { id: ramFree;  sensorId: "memory/physical/free";       updateRateLimit: root.interval; enabled: root.expanded }
    Sensors.Sensor { id: vramUsed; sensorId: "gpu/all/usedVram";           updateRateLimit: root.interval }
    Sensors.Sensor { id: vramTotal; sensorId: "gpu/all/totalVram" }
    property string gpuId: ""
    Repeater {
        model: 4
        delegate: Item {
            required property int index
            Sensors.Sensor {
                sensorId: "gpu/gpu" + index + "/name"
                onValueChanged: if (root.gpuId === "" && value && String(value).length) root.gpuId = "gpu/gpu" + index
            }
        }
    }
    Sensors.Sensor { id: gpuName;  sensorId: root.gpuId ? root.gpuId + "/name" : "" }
    Sensors.Sensor { id: gpuTemp;  sensorId: root.gpuId ? root.gpuId + "/temperature" : ""; updateRateLimit: root.interval }
    Sensors.Sensor { id: gpuPower; sensorId: root.gpuId ? root.gpuId + "/power" : "";       updateRateLimit: root.interval; enabled: root.expanded }
    function num(s) { const v = s ? s.value : NaN; return (v === undefined || v === null || v === "" || isNaN(v)) ? NaN : Number(v) }
    function gb(bytes, digits) { return isNaN(bytes) ? "–" : (bytes / 1073741824).toLocaleString(Qt.locale(), "f", digits === undefined ? 1 : digits) }
    function ghz(mhz) { return isNaN(mhz) ? "" : (mhz / 1000).toLocaleString(Qt.locale(), "f", 1) + " GHz" }
    function deg(v) { return isNaN(v) ? "" : Math.round(v) + "°" }
    // ---- disks and tidy-up (read with df / du, only while the panel is open)
    property var disks: []                 // [{ mount, size, used, avail }]
    property real trashB: NaN
    property real thumbsB: NaN
    readonly property string probeCmd: "df -B1 --output=target,size,used,avail -x tmpfs -x devtmpfs -x squashfs -x efivarfs -x overlay 2>/dev/null; "
        + "echo PBTRASH $(du -sb \"$HOME/.local/share/Trash\" 2>/dev/null | cut -f1); echo PBTHUMB $(du -sb \"$HOME/.cache/thumbnails\" 2>/dev/null | cut -f1)"
    P5Support.DataSource {
        id: probe
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.indexOf("PBTRASH") < 0) return           // a tidy-up command finished: measure again
            const out = String(data.stdout || "").split("\n"), list = []
            for (const l of out) {
                const f = l.trim().split(/\s+/)
                if (f[0] === "PBTRASH") { root.trashB = f[1] ? Number(f[1]) : 0; continue }
                if (f[0] === "PBTHUMB") { root.thumbsB = f[1] ? Number(f[1]) : 0; continue }
                if (f.length === 4 && f[0].startsWith("/") && Number(f[1]) > 2e9 && !f[0].startsWith("/boot") && !f[0].startsWith("/snap"))
                    list.push({ mount: f[0], size: Number(f[1]), used: Number(f[2]), avail: Number(f[3]) })
            }
            root.disks = list
        }
    }
    function measure() { probe.connectSource(probeCmd + " # " + Date.now()) }
    Timer { interval: 30000; repeat: true; triggeredOnStart: true; running: root.expanded; onTriggered: root.measure() }
    function tidy(what) {
        const cmd = what === "trash" ? "ktrash6 --empty" : "rm -rf -- \"$HOME/.cache/thumbnails\"/*"
        probe.connectSource(cmd + "; sleep 0.3 # " + Date.now())
        tidyAgain.restart()
    }
    Timer { id: tidyAgain; interval: 1200; onTriggered: root.measure() }
    function diskName(m) { return m === "/" ? i18n("System") : m === "/home" ? i18n("Home") : m.split("/").pop() }

    readonly property real ramTotalB: num(ramTotal)
    // the size printed on the modules: the kernel reports a little less than installed
    readonly property int ramTotalGB: Math.ceil(ramTotalB / 1073741824)
    readonly property real ramUsedB: num(ramUsed)
    readonly property string tempSource: String(cfg.tempSensor).indexOf("gpu") === 0 ? "GPU" : "CPU"
    readonly property var metrics: [
        cpuM, gpuM, ramM, tempM
    ]
    Metric { id: cpuM;  key: "cpu";  label: "CPU"; tone: "#7fd3f0"; sensor: cpuSensor
             sub: root.ghz(root.num(cpuFreq)); alert: value > 90 }
    Metric { id: gpuM;  key: "gpu";  label: "GPU"; tone: "#7fdcb0"; sensor: gpuSensor
             sub: [root.deg(root.num(gpuTemp)), isNaN(root.num(vramUsed)) ? "" : root.gb(root.num(vramUsed)) + " GB"].filter(x => x).join(" · ")
             alert: root.num(gpuTemp) > 80 }
    Metric { id: ramM;  key: "ram";  label: "RAM"; tone: "#b49cf0"; sensor: ramSensor
             text: isNaN(root.ramUsedB) ? (isNaN(value) ? "–" : Math.round(value) + "%") : root.gb(root.ramUsedB)
             sub: isNaN(root.ramTotalB) ? "" : "/ " + root.ramTotalGB + " GB"
             ringText: isNaN(value) ? "–" : Math.round(value) + "%"
             alert: value > 90 }
    Metric { id: tempM; key: "temp"; label: root.tempSource; unit: "°"; max: 100; bar: false; sensor: tempSensor
             tone: tempM.value > 80 ? "#ff7a6a" : tempM.value > 65 ? "#ffb36b" : "#e0bd6e"; alert: value > 80 }
    function shown(m) {
        return m.key === "cpu" ? cfg.showCpu : m.key === "gpu" ? cfg.showGpu : m.key === "ram" ? cfg.showRam : cfg.showTemp
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("System")
    toolTipSubText: i18n("CPU %1 · GPU %2 · RAM %3 · %4", cpuM.text, gpuM.text, ramM.text + " " + ramM.sub, tempM.text)

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
            spacing: root.look === "chips" ? Kirigami.Units.smallSpacing * 1.5 : Kirigami.Units.largeSpacing * (root.look === "numbers" || root.look === "detail" ? 1.6 : 1.3)
            Repeater {
                model: root.metrics
                delegate: Loader {
                    required property var modelData
                    visible: root.shown(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    sourceComponent: ({ detail: detailC, ringtext: ringTextC, chips: chipsC, spark: sparkC, bars: barsC, numbers: numbersC })[root.look] || ringC
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

    component Sub: PC3.Label {
        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.95)
        font.features: { "tnum": 1 }
        opacity: 0.6
    }
    component UsageBar: Rectangle {
        property var m
        implicitWidth: Math.round(root.lineH * 2.1); implicitHeight: 5; radius: 2.5
        color: Qt.rgba(1, 1, 1, 0.09)
        Rectangle {
            width: Math.max(parent.height, parent.width * parent.m.frac); height: parent.height; radius: parent.radius
            color: parent.m.tone
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
    }
    // A – plain text: label, a small usage bar, the value and what it means
    Component {
        id: detailC
        RowLayout {
            property var m: ({ label: "", tone: "white", frac: 0, hist: [], text: "", sub: "", bar: true, max: 100 })
            spacing: Kirigami.Units.smallSpacing * 1.4
            Caption { text: m.label }
            UsageBar { visible: m.bar; m: parent.m; Layout.alignment: Qt.AlignVCenter }
            Value { text: m.text }
            Sub { visible: text.length > 0; text: m.sub }
        }
    }
    // B – a ring with the number inside, the label and its meaning stacked beside it
    Component {
        id: ringTextC
        RowLayout {
            id: rt
            property var m: ({ label: "", tone: "white", frac: 0, hist: [], text: "", ringText: "", sub: "", max: 100 })
            readonly property real d: Math.round(root.lineH * 1.55)
            spacing: Kirigami.Units.smallSpacing * 1.4
            Item {
                implicitWidth: rt.d; implicitHeight: rt.d
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"; strokeColor: Qt.rgba(1, 1, 1, 0.1); strokeWidth: 2.6
                        PathAngleArc { centerX: rt.d / 2; centerY: rt.d / 2; radiusX: rt.d / 2 - 1.6; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        fillColor: "transparent"; strokeColor: rt.m.tone; strokeWidth: 2.6; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: rt.d / 2; centerY: rt.d / 2; radiusX: rt.d / 2 - 1.6; radiusY: radiusX; startAngle: -90; sweepAngle: Math.max(4, 360 * rt.m.frac) }
                    }
                }
                PC3.Label {
                    anchors.centerIn: parent
                    text: rt.m.ringText
                    font.pixelSize: Math.round(rt.d * 0.3); font.weight: Font.DemiBold; font.features: { "tnum": 1 }
                }
            }
            ColumnLayout {
                spacing: -2
                Caption { text: rt.m.key === "temp" ? "TEMP" : rt.m.label }
                Sub { visible: text.length > 0
                      text: rt.m.key === "temp" ? root.tempSource : rt.m.key === "ram" ? rt.m.text + " " + rt.m.sub : rt.m.sub }
            }
        }
    }
    // C – each value in its own calm chip; hot or full tints the chip
    Component {
        id: chipsC
        Rectangle {
            id: chip
            property var m: ({ label: "", tone: "white", frac: 0, hist: [], text: "", sub: "", alert: false, max: 100 })
            implicitWidth: chipRow.implicitWidth + Kirigami.Units.largeSpacing * 1.6
            implicitHeight: Math.round(root.lineH * 1.45)
            radius: height / 2
            color: m.alert ? Qt.rgba(1, 0.48, 0.42, 0.22) : Qt.rgba(1, 1, 1, 0.055)
            Behavior on color { ColorAnimation { duration: 400 } }
            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing * 1.3
                Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: chip.m.tone }
                Caption { text: chip.m.label }
                Value { text: chip.m.text }
                Sub { visible: text.length > 0; text: chip.m.sub }
            }
        }
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
    component Row2: RowLayout {
        property string k
        property string v
        Layout.fillWidth: true
        visible: v.length > 0 && v !== "–"
        PC3.Label { text: parent.k; opacity: 0.6; Layout.fillWidth: true; font: Kirigami.Theme.smallFont }
        PC3.Label { text: parent.v; font.pixelSize: Kirigami.Theme.smallFont.pixelSize; font.weight: Font.Medium; font.features: { "tnum": 1 } }
    }
    component Card: Rectangle {
        id: card
        property var m
        property string title
        property string big
        property string bigSub
        default property alias rows: rowsCol.data
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        radius: Kirigami.Units.gridUnit * 0.8
        color: Qt.rgba(1, 1, 1, 0.045)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
            Caption { text: card.title; Layout.fillWidth: true; elide: Text.ElideRight }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                PC3.Label { text: card.big; font.pixelSize: Kirigami.Units.gridUnit * 1.6; font.weight: Font.Bold; font.features: { "tnum": 1 } }
                PC3.Label { text: card.bigSub; opacity: 0.6; Layout.alignment: Qt.AlignBaseline }
            }
            Item {
                id: bigBox
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
                Shape {
                    id: big
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    readonly property var pts: {
                        const h = card.m.hist, w = bigBox.width, hh = bigBox.height
                        if (h.length < 2 || w <= 0) return []
                        return h.map((v, i) => Qt.point(i * w / (h.length - 1), hh - 1 - Math.max(0, Math.min(1, v / card.m.max)) * (hh - 2)))
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: 0; y2: bigBox.height
                            GradientStop { position: 0; color: Qt.rgba(card.m.tone.r, card.m.tone.g, card.m.tone.b, 0.35) }
                            GradientStop { position: 1; color: Qt.rgba(card.m.tone.r, card.m.tone.g, card.m.tone.b, 0) }
                        }
                        PathPolyline { path: big.pts.length ? [Qt.point(big.pts[0].x, bigBox.height)].concat(big.pts).concat([Qt.point(big.pts[big.pts.length - 1].x, bigBox.height)]) : [] }
                    }
                    ShapePath {
                        fillColor: "transparent"; strokeColor: card.m.tone; strokeWidth: 2; joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: big.pts }
                    }
                }
            }
            ColumnLayout { id: rowsCol; Layout.fillWidth: true; spacing: 2 }
            Item { Layout.fillHeight: true }
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 40
        Layout.preferredHeight: dashCol.implicitHeight + Kirigami.Units.smallSpacing * 2
        Layout.minimumWidth: Kirigami.Units.gridUnit * 32
        Layout.minimumHeight: Layout.preferredHeight
        ColumnLayout {
          id: dashCol
          anchors.fill: parent
          anchors.margins: Kirigami.Units.smallSpacing
          spacing: Kirigami.Units.largeSpacing
          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 13
            spacing: Kirigami.Units.largeSpacing
            Card {
                m: cpuM
                title: "CPU" + (cpuName.value ? " · " + String(cpuName.value).replace(/ ?(\d+-Core|Eight-Core|Six-Core|Quad-Core|Twelve-Core|Sixteen-Core) Processor/, "").replace(/\(R\)|\(TM\)/g, "") : "")
                big: cpuM.text
                Row2 { k: i18n("Clock"); v: root.ghz(root.num(cpuFreq)) }
                Row2 { k: i18n("Cores"); v: isNaN(root.num(cores)) ? "" : i18n("%1 · %2 threads", root.num(cores), root.num(threads)) }
                Row2 { k: i18n("Temperature"); v: root.tempSource === "CPU" ? tempM.text.replace("°", " °C") : "" }
            }
            Card {
                m: gpuM
                title: "GPU" + (gpuName.value ? " · " + String(gpuName.value).replace(/^NVIDIA (GeForce )?|^AMD (Radeon )?/, "") : "")
                big: gpuM.text
                Row2 { k: i18n("Video memory"); v: isNaN(root.num(vramUsed)) ? "" : root.gb(root.num(vramUsed)) + " / " + root.gb(root.num(vramTotal), 0) + " GB" }
                Row2 { k: i18n("Temperature"); v: isNaN(root.num(gpuTemp)) ? "" : Math.round(root.num(gpuTemp)) + " °C" }
                Row2 { k: i18n("Power"); v: isNaN(root.num(gpuPower)) ? "" : Math.round(root.num(gpuPower)) + " W" }
            }
            Card {
                m: ramM
                title: i18n("Memory")
                big: ramM.text
                bigSub: ramM.sub
                Row2 { k: i18n("Programs"); v: isNaN(root.ramUsedB) ? "" : root.gb(root.ramUsedB) + " GB" }
                Row2 { k: i18n("Cache"); v: isNaN(root.num(ramCache)) ? "" : root.gb(root.num(ramCache)) + " GB" }
                Row2 { k: i18n("Free"); v: isNaN(root.num(ramFree)) ? "" : root.gb(root.num(ramFree)) + " GB" }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            // disks: free space per drive
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.alignment: Qt.AlignTop
                implicitHeight: diskCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.gridUnit * 0.8
                color: Qt.rgba(1, 1, 1, 0.045)
                ColumnLayout {
                    id: diskCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.largeSpacing }
                    spacing: Kirigami.Units.smallSpacing * 1.5
                    Caption { text: i18n("Drives") }
                    PC3.Label { visible: root.disks.length === 0; text: i18n("Measuring…"); opacity: 0.6 }
                    Repeater {
                        model: root.disks
                        delegate: ColumnLayout {
                            required property var modelData
                            readonly property real frac: modelData.used / Math.max(1, modelData.size)
                            Layout.fillWidth: true
                            spacing: 3
                            RowLayout {
                                Layout.fillWidth: true
                                PC3.Label { text: root.diskName(parent.parent.modelData.mount); font.weight: Font.DemiBold }
                                PC3.Label { text: parent.parent.modelData.mount; opacity: 0.45; font: Kirigami.Theme.smallFont; Layout.fillWidth: true; elide: Text.ElideMiddle }
                                PC3.Label { text: i18n("%1 GB free of %2 GB", root.gb(parent.parent.modelData.avail, 0), root.gb(parent.parent.modelData.size, 0))
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize; font.features: { "tnum": 1 } }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 6; radius: 3
                                color: Qt.rgba(1, 1, 1, 0.09)
                                Rectangle {
                                    width: Math.max(parent.height, parent.width * parent.parent.frac); height: parent.height; radius: 3
                                    color: parent.parent.frac > 0.9 ? "#ff7a6a" : parent.parent.frac > 0.75 ? "#ffb36b" : "#8fb0c2"
                                }
                            }
                        }
                    }
                }
            }
            // tidy up: things that can safely go, with their size; a second click confirms
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: tidyCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.gridUnit * 0.8
                color: Qt.rgba(1, 1, 1, 0.045)
                ColumnLayout {
                    id: tidyCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.largeSpacing }
                    spacing: Kirigami.Units.smallSpacing
                    Caption { text: i18n("Tidy up") }
                    component TidyRow: RowLayout {
                        id: tr
                        property string what
                        property string label
                        property real bytes
                        property bool armed: false
                        Layout.fillWidth: true
                        Timer { id: disarm; interval: 3500; onTriggered: tr.armed = false }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            PC3.Label { text: tr.label }
                            PC3.Label { text: isNaN(tr.bytes) ? "…" : tr.bytes < 1048576 ? i18n("empty") : (tr.bytes / 1048576).toLocaleString(Qt.locale(), "f", 0) + " MB"
                                opacity: 0.6; font: Kirigami.Theme.smallFont }
                        }
                        PC3.Button {
                            enabled: !isNaN(tr.bytes) && tr.bytes >= 1048576
                            text: tr.armed ? i18n("Sure?") : i18n("Empty")
                            onClicked: { if (!tr.armed) { tr.armed = true; disarm.restart(); return } tr.armed = false; root.tidy(tr.what) }
                        }
                    }
                    TidyRow { what: "trash"; label: i18n("Trash"); bytes: root.trashB }
                    TidyRow { what: "thumbs"; label: i18n("Thumbnail cache"); bytes: root.thumbsB }
                    PC3.Label {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.5; font: Kirigami.Theme.smallFont
                        text: i18n("The memory cache needs no emptying: Linux hands it to programs the moment they need it.")
                    }
                }
            }
          }
        }
    }
}
