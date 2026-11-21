/*
 * One live activity, drawn three ways: "small" beside the clock, "bubble" as the round
 * second activity, "big" in the card that opens on hover.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Item {
    id: face
    property var live
    property string kind
    property string mode: "small"            // small | bubble | big
    property real size: 20                    // icon-sized things in small / bubble mode
    // the accent colour, unless it is too dark to read on the glass (then a light steel blue)
    readonly property color accent: Kirigami.Theme.highlightColor.hslLightness > 0.38 ? Kirigami.Theme.highlightColor : "#a9c4d4"
    readonly property color mint: "#7fdcb0"
    readonly property color warn: "#ffb36b"
    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Loader {
        id: loader
        width: face.mode === "big" ? face.width : implicitWidth
        height: implicitHeight
        anchors.verticalCenter: face.mode === "big" ? undefined : parent.verticalCenter
        sourceComponent: face.mode === "big" ? ({ job: jobBig, music: musicBig, timer: timerBig, mic: micBig, charge: chargeBig })[face.kind] || null
                       : face.mode === "bubble" ? ({ job: ringC, music: eqC, timer: timerBubble, mic: micDot, charge: chargeBubble })[face.kind] || null
                       : ({ job: jobSmall, music: musicSmall, timer: timerSmall, mic: micSmall, charge: chargeSmall })[face.kind] || null
    }

    // ---------------------------------------------------------------- shared pieces
    component Ring: Item {
        property real frac: 0
        property color tone: face.accent
        implicitWidth: face.size; implicitHeight: face.size
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: Qt.rgba(1, 1, 1, 0.14); strokeWidth: 2.6
                PathAngleArc { centerX: face.size / 2; centerY: face.size / 2; radiusX: face.size / 2 - 1.5; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: parent.parent.tone; strokeWidth: 2.6; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: face.size / 2; centerY: face.size / 2; radiusX: face.size / 2 - 1.5; radiusY: radiusX; startAngle: -90; sweepAngle: Math.max(3, 360 * parent.parent.frac) }
            }
        }
    }
    component Eq: Row {
        spacing: 2
        height: face.size * 0.7
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: 3; radius: 1.5
                anchors.bottom: parent.bottom
                color: face.accent
                height: 3
                SequentialAnimation on height {
                    running: !!face.live && face.live.playing; loops: Animation.Infinite
                    NumberAnimation { to: face.size * 0.7 - index * 2; duration: 280 + index * 90; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 3; duration: 320 + index * 70; easing.type: Easing.InOutSine }
                }
            }
        }
    }
    component Cover: Item {
        property real side: face.size
        implicitWidth: side; implicitHeight: side
        Image { id: art; anchors.fill: parent; source: face.live && face.live.player ? face.live.player.artUrl : ""; fillMode: Image.PreserveAspectCrop; visible: false; sourceSize.width: 128; asynchronous: true }
        Rectangle { id: artMask; anchors.fill: parent; radius: parent.side * 0.28; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: art; maskEnabled: true; maskSource: artMask; visible: art.status === Image.Ready }
        Rectangle {
            anchors.fill: parent; radius: parent.side * 0.28; visible: art.status !== Image.Ready
            gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(face.accent, 1.2) } GradientStop { position: 1; color: Qt.darker(face.accent, 2.4) } }
        }
    }
    component Small: PC3.Label {
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 1.05
        font.features: { "tnum": 1 }
    }
    component Title: PC3.Label {
        Layout.fillWidth: true
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        color: "#e9eef2"
    }
    component Note: PC3.Label {
        Layout.fillWidth: true
        opacity: 0.65
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        font.features: { "tnum": 1 }
        elide: Text.ElideRight
        color: "#cdd5db"
    }
    component Bar: Rectangle {
        property real frac: 0
        property color tone: face.accent
        Layout.fillWidth: true
        implicitHeight: 5; radius: 2.5
        color: Qt.rgba(1, 1, 1, 0.1)
        Rectangle { width: Math.max(parent.height, parent.width * Math.min(1, parent.frac)); height: parent.height; radius: 2.5; color: parent.tone
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
    }
    component RoundButton: QQC2.AbstractButton {
        id: rb
        property string iconName
        property bool strong: false
        implicitWidth: Kirigami.Units.gridUnit * (strong ? 2.2 : 1.8); implicitHeight: implicitWidth
        hoverEnabled: true
        background: Rectangle { radius: width / 2; color: rb.strong ? face.accent : rb.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08) }
        contentItem: Item { Kirigami.Icon { anchors.centerIn: parent; source: rb.iconName; width: rb.width * 0.5; height: width; isMask: true
            color: rb.strong ? Kirigami.Theme.highlightedTextColor : "#e9eef2" } }
    }

    // ---------------------------------------------------------------- small (beside the clock)
    Component { id: jobSmall; RowLayout { spacing: Kirigami.Units.smallSpacing
        Ring { frac: face.live.job ? face.live.job.percent / 100 : 0; tone: face.live.job && face.live.job.done ? face.mint : face.accent }
        Small { text: face.live.job ? (face.live.job.done ? "✓" : Math.round(face.live.job.percent) + "%") : "" } } }
    Component { id: musicSmall; RowLayout { spacing: Kirigami.Units.smallSpacing * 1.5; Cover {} Eq {} } }
    Component { id: timerSmall; RowLayout { spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon { source: "chronometer-symbolic"; isMask: true; color: face.mint; implicitWidth: face.size * 0.85; implicitHeight: implicitWidth }
        Small { text: face.live.clock(face.live.timerLeft); color: face.mint } } }
    Component { id: micSmall; RowLayout { spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon { source: "audio-input-microphone-symbolic"; isMask: true; color: face.warn; implicitWidth: face.size * 0.85; implicitHeight: implicitWidth }
        Small { text: face.live.micApps[0] || ""; color: face.warn; Layout.maximumWidth: Kirigami.Units.gridUnit * 6; elide: Text.ElideRight } } }
    Component { id: chargeSmall; RowLayout { spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon { source: "battery-charging-symbolic"; isMask: true; color: face.mint; implicitWidth: face.size * 0.85; implicitHeight: implicitWidth }
        Small { text: face.live.batteryPct + "%" } } }

    // ---------------------------------------------------------------- bubble (the second activity)
    Component { id: ringC; Ring { frac: face.live.job ? face.live.job.percent / 100 : 0 } }
    Component { id: eqC; Item { implicitWidth: face.size; implicitHeight: face.size; Eq { anchors.centerIn: parent } } }
    Component { id: timerBubble; Item { implicitWidth: face.size; implicitHeight: face.size
        Small { anchors.centerIn: parent; text: Math.ceil(face.live.timerLeft / 60000) + "′"; color: face.mint } } }
    Component { id: micDot; Item { implicitWidth: face.size; implicitHeight: face.size
        Kirigami.Icon { anchors.centerIn: parent; source: "audio-input-microphone-symbolic"; isMask: true; color: face.warn; width: face.size * 0.8; height: width } } }
    Component { id: chargeBubble; Item { implicitWidth: face.size; implicitHeight: face.size
        Small { anchors.centerIn: parent; text: face.live.batteryPct; color: face.mint } } }

    // ---------------------------------------------------------------- big (the hover card)
    Component { id: jobBig; ColumnLayout { spacing: Kirigami.Units.smallSpacing * 1.5
        Title { text: face.live.job ? (face.live.job.summary || face.live.job.app) : "" }
        RowLayout { Layout.fillWidth: true; spacing: Kirigami.Units.largeSpacing
            Bar { frac: face.live.job ? face.live.job.percent / 100 : 0; tone: face.live.job && face.live.job.done ? face.mint : face.accent }
            Small { text: face.live.job ? (face.live.job.done ? i18n("Done") : Math.round(face.live.job.percent) + "%") : "" } }
        Note { text: face.live.job ? [face.live.job.text, face.live.job.app].filter(x => x).join(" · ") : ""; visible: text.length > 0 } } }
    Component { id: musicBig; ColumnLayout { spacing: Kirigami.Units.smallSpacing * 1.5
        readonly property var p: face.live.player
        RowLayout { Layout.fillWidth: true; spacing: Kirigami.Units.largeSpacing
            Cover { side: Kirigami.Units.gridUnit * 3 }
            ColumnLayout { Layout.fillWidth: true; spacing: 0
                Title { text: p ? p.track : "" }
                Note { text: p ? [p.artist, p.album].filter(x => x).join(" · ") : "" } } }
        RowLayout { Layout.fillWidth: true; spacing: Kirigami.Units.largeSpacing
            Small { text: face.live.clock(p ? p.position / 1000 : 0); opacity: 0.65 }
            Bar { frac: p && p.length > 0 ? p.position / p.length : 0 }
            Small { text: face.live.clock(p ? p.length / 1000 : 0); opacity: 0.65 } }
        RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: Kirigami.Units.largeSpacing
            RoundButton { iconName: "media-skip-backward"; onClicked: p.Previous() }
            RoundButton { iconName: face.live.playing ? "media-playback-pause" : "media-playback-start"; strong: true; onClicked: p.PlayPause() }
            RoundButton { iconName: "media-skip-forward"; onClicked: p.Next() } } } }
    Component { id: timerBig; ColumnLayout { spacing: Kirigami.Units.smallSpacing * 1.5
        Title { text: i18n("Timer") }
        PC3.Label { Layout.alignment: Qt.AlignHCenter; text: face.live.clock(face.live.timerLeft); color: face.mint
            font.pixelSize: Kirigami.Units.gridUnit * 2.2; font.weight: Font.Bold; font.features: { "tnum": 1 } }
        Bar { frac: face.live.timerTotal > 0 ? 1 - face.live.timerLeft / face.live.timerTotal : 0; tone: face.mint }
        RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: Kirigami.Units.largeSpacing
            RoundButton { iconName: "list-add"; onClicked: face.live.addMinute(); QQC2.ToolTip.text: i18n("One minute more"); QQC2.ToolTip.visible: hovered }
            RoundButton { iconName: face.live.timerPausedLeft > 0 ? "media-playback-start" : "media-playback-pause"; strong: true; onClicked: face.live.pauseTimer() }
            RoundButton { iconName: "window-close"; onClicked: face.live.stopTimer() } } } }
    Component { id: micBig; ColumnLayout { spacing: Kirigami.Units.smallSpacing * 1.5
        RowLayout { Layout.fillWidth: true; spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon { source: "audio-input-microphone-symbolic"; isMask: true; color: face.warn; implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth }
            Title { text: i18n("Microphone in use") } }
        Note { text: face.live.micApps.join(", ") } } }
    Component { id: chargeBig; ColumnLayout { spacing: Kirigami.Units.smallSpacing * 1.5
        Title { text: i18n("Charging") }
        RowLayout { Layout.fillWidth: true; spacing: Kirigami.Units.largeSpacing
            Bar { frac: face.live.batteryPct / 100; tone: face.mint }
            Small { text: face.live.batteryPct + "%" } } } }
}
