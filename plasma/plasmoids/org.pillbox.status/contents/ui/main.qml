/*
 * Pillbox Status – music, sound, Bluetooth, network, power and the session in one calm pill, each with its own panel.
 * Music appears only while a player is open. Built on Plasma's own models (MPRIS,
 * PulseAudio, NetworkManager, system sensors); nothing here talks to hardware directly.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.sessions as Sessions
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.batterymonitor as BatteryMonitor
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property color accent: Kirigami.Theme.highlightColor
    property string page: "sound"                     // music | sound | bt | net | session

    // ---------------------------------------------------------------- music
    Mpris.Mpris2Model { id: mpris }
    Vol.SinkModel { id: sinks }
    Vol.SinkInputModel { id: sinkInputs }
    readonly property var player: quitting ? null : mpris.currentPlayer
    readonly property bool hasPlayer: !!player && (player.track || "") !== ""
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    Timer { interval: 1000; repeat: true; running: root.playing && root.expanded && root.page === "music"; onTriggered: root.player.updatePosition() }

    // ---------------------------------------------------------------- sound
    // let go of the sound server before the app quits: it is torn down after our items,
    // and bindings that still follow it would update items that are already gone
    property bool quitting: false
    Connections { target: Qt.application; function onAboutToQuit() { root.quitting = true } }
    readonly property var sink: quitting ? null : Vol.PreferredDevice.sink
    readonly property real normal: Vol.PulseAudio.NormalVolume
    readonly property int volume: sink ? Math.round(sink.volume / normal * 100) : 0
    readonly property bool muted: !sink || sink.muted
    function setVolume(p) { if (sink) { sink.volume = Math.round(Math.max(0, Math.min(100, p)) / 100 * normal); if (sink.muted && p > 0) sink.muted = false } }
    function volumeIcon() {
        if (muted || volume === 0) return "audio-volume-muted"
        return volume < 34 ? "audio-volume-low" : volume < 67 ? "audio-volume-medium" : "audio-volume-high"
    }

    // ---------------------------------------------------------------- bluetooth
    readonly property var bt: BluezQt.Manager
    readonly property bool btPresent: !quitting && bt.adapters.length > 0
    readonly property bool btOn: btPresent && bt.bluetoothOperational
    readonly property var btConnected: btOn ? bt.devices.filter(d => d.connected) : []
    function setBluetooth(on) {
        if (on && bt.bluetoothBlocked) bt.bluetoothBlocked = false
        bt.adapters.forEach(a => a.powered = on)
        if (!on) bt.bluetoothBlocked = true
    }
    function btIcon() { return !btOn ? "network-bluetooth-inactive" : btConnected.length ? "network-bluetooth-activated" : "network-bluetooth" }

    // ---------------------------------------------------------------- session
    Sessions.SessionManagement { id: sm }

    // ---------------------------------------------------------------- power
    BatteryMonitor.PowerProfilesControl { id: profiles }
    BatteryMonitor.InhibitionControl { id: inhibit }
    P5Support.DataSource { id: pm; engine: "powermanagement"; connectedSources: ["Battery"]; interval: 0 }
    readonly property var battery: pm.data["Battery"] || ({})
    readonly property bool hasBattery: !!battery["Has Battery"]
    readonly property int batteryPct: battery["Percent"] || 0
    readonly property bool charging: battery["State"] === "Charging" || battery["State"] === "FullyCharged"
    function batteryIcon() {
        const lvl = Math.round(batteryPct / 10) * 10
        return "battery-" + String(lvl).padStart(3, "0") + (charging ? "-charging" : "")
    }
    KCoreAddons.KUser { id: me }

    // ---------------------------------------------------------------- network
    PlasmaNM.NetworkStatus { id: netStatus }
    PlasmaNM.ConnectionIcon { id: netIcon }
    PlasmaNM.EnabledConnections { id: nmEnabled }
    PlasmaNM.Handler { id: nmHandler }
    Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: 1000; enabled: root.expanded && root.page === "net" }
    Sensors.Sensor { id: up;   sensorId: "network/all/upload";   updateRateLimit: 1000; enabled: root.expanded && root.page === "net" }
    readonly property bool online: netStatus.connectivity === 4 || (netStatus.activeConnections || "").length > 0 && !netIcon.connectionIcon.includes("disconnected")
    function rate(v) {
        if (v === undefined || v === null || isNaN(v)) return "–"
        return v >= 1048576 ? (v / 1048576).toFixed(1) + " MB/s" : (v / 1024).toFixed(0) + " KB/s"
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("Status")
    toolTipSubText: (hasPlayer ? player.track + " · " : "") + i18n("Volume %1 %", volume)

    // ---------------------------------------------------------------- in the pill
    compactRepresentation: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Layout.minimumWidth: implicitWidth
        component PillButton: MouseArea {
            id: pb
            property string target
            property alias icon: ic.source
            default property alias extra: side.data
            Layout.fillHeight: true
            Layout.preferredWidth: lay.implicitWidth
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: ev => {
                if (ev.button === Qt.MiddleButton) { if (target === "sound" && root.sink) root.sink.muted = !root.sink.muted; else if (target === "music" && root.player) root.player.PlayPause(); return }
                if (root.expanded && root.page === target) root.expanded = false
                else { root.page = target; root.expanded = true }
            }
            RowLayout {
                id: lay
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon { id: ic; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth; opacity: pb.containsMouse || (root.expanded && root.page === pb.target) ? 1 : 0.85 }
                Row { id: side; spacing: 2 }
            }
        }
        PillButton {
            visible: root.hasPlayer
            target: "music"
            icon: root.player && root.player.iconName ? root.player.iconName : "media-playback-start"
            // three small bars that dance while music plays
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: 2; radius: 1
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    color: root.accent
                    height: 4
                    SequentialAnimation on height {
                        running: root.playing; loops: Animation.Infinite
                        NumberAnimation { to: 10 - index * 2; duration: 260 + index * 90 }
                        NumberAnimation { to: 3; duration: 300 + index * 70 }
                    }
                }
            }
        }
        PillButton {
            target: "sound"
            icon: root.volumeIcon()
            onWheel: ev => root.setVolume(root.volume + (ev.angleDelta.y > 0 ? 5 : -5))
        }
        PillButton { visible: root.btPresent; target: "bt"; icon: root.btIcon() }
        PillButton { target: "net"; icon: netIcon.connectionIcon || "network-wired" }
        PillButton {
            visible: root.hasBattery
            target: "session"
            icon: root.batteryIcon()
            PC3.Label { text: root.batteryPct + "%"; font.pixelSize: Kirigami.Theme.smallFont.pixelSize; font.features: { "tnum": 1 }
                color: root.batteryPct <= 15 && !root.charging ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor }
        }
        PillButton { target: "session"; icon: "system-shutdown" }
    }

    // ---------------------------------------------------------------- the panels
    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        Layout.preferredHeight: pages.implicitHeight + tabs.height + Kirigami.Units.largeSpacing * 3
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight
        Row {                                                     // small tabs to hop between the panels
            id: tabs
            anchors.horizontalCenter: parent.horizontalCenter
            y: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: [{ p: "music", n: i18n("Music"), show: root.hasPlayer }, { p: "sound", n: i18n("Sound"), show: true }, { p: "bt", n: i18n("Bluetooth"), show: root.btPresent }, { p: "net", n: i18n("Network"), show: true }, { p: "session", n: i18n("Power"), show: true }]
                delegate: QQC2.AbstractButton {
                    id: tab
                    required property var modelData
                    visible: modelData.show
                    readonly property bool on: root.page === modelData.p
                    width: lbl.implicitWidth + Kirigami.Units.gridUnit * 1.4; height: Kirigami.Units.gridUnit * 1.5
                    onClicked: root.page = modelData.p
                    background: Rectangle { radius: height / 2; color: tab.on ? root.accent : tab.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent" }
                    contentItem: PC3.Label { id: lbl; text: tab.modelData.n; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        color: tab.on ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; font.weight: tab.on ? Font.DemiBold : Font.Normal }
                }
            }
        }
        Loader {
            id: pages
            anchors { top: tabs.bottom; topMargin: Kirigami.Units.largeSpacing; left: parent.left; right: parent.right; margins: Kirigami.Units.smallSpacing }
            sourceComponent: root.page === "music" && root.hasPlayer ? musicPage : root.page === "net" ? netPage : root.page === "session" ? sessionPage : root.page === "bt" && root.btPresent ? btPage : soundPage
        }
    }

    component Caption: PC3.Label { font.pixelSize: Kirigami.Theme.smallFont.pixelSize; font.letterSpacing: 1.1; opacity: 0.55; font.capitalization: Font.AllUppercase }
    component Round: QQC2.AbstractButton {
        id: rb
        property string iconName
        property bool strong: false
        property real size: Kirigami.Units.gridUnit * 2
        implicitWidth: size; implicitHeight: size
        background: Rectangle { radius: width / 2; color: rb.strong ? root.accent : rb.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            scale: rb.pressed ? 0.92 : 1; Behavior on scale { NumberAnimation { duration: 90 } } }
        contentItem: Item { Kirigami.Icon { anchors.centerIn: parent; source: rb.iconName; width: rb.size * 0.5; height: width
            color: rb.strong ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; isMask: rb.strong } }
    }
    function clock(us) { const s = Math.max(0, Math.floor((us || 0) / 1e6)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    // ---------------------------------------------------------------- music
    Component {
        id: musicPage
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Item {                                               // the cover, with its own blurred glow behind
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.82
                Image { id: art; anchors.fill: parent; source: root.player ? root.player.artUrl : ""; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true; sourceSize.width: 512 }
                MultiEffect { anchors.fill: parent; anchors.margins: -Kirigami.Units.gridUnit; source: art; blurEnabled: true; blur: 1; blurMax: 64; opacity: 0.55; visible: art.status === Image.Ready }
                Rectangle { id: coverMask; anchors.fill: parent; radius: Kirigami.Units.gridUnit; visible: false; layer.enabled: true }
                MultiEffect { anchors.fill: parent; source: art; maskEnabled: true; maskSource: coverMask; visible: art.status === Image.Ready }
                Rectangle {
                    anchors.fill: parent; radius: Kirigami.Units.gridUnit; visible: art.status !== Image.Ready
                    gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(root.accent, 1.2) } GradientStop { position: 1; color: Qt.darker(root.accent, 2.6) } }
                    Kirigami.Icon { anchors.centerIn: parent; source: "media-optical-audio"; width: parent.width * 0.3; height: width; opacity: 0.6 }
                }
            }
            ColumnLayout {
                spacing: 0
                PC3.Label { Layout.fillWidth: true; text: root.player ? root.player.track : ""; font.pixelSize: Kirigami.Units.gridUnit * 1.15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                PC3.Label { Layout.fillWidth: true; text: root.player ? [root.player.artist, root.player.album].filter(x => x).join(" · ") : ""; opacity: 0.6; elide: Text.ElideRight }
            }
            // progress as a little waveform: bars before the play head are lit
            Item {
                id: wave
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
                readonly property real frac: root.player && root.player.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0
                readonly property string seed: root.player ? root.player.track : ""
                Row {
                    anchors.fill: parent
                    spacing: 2
                    Repeater {
                        model: 44
                        Rectangle {
                            required property int index
                            readonly property real r: { let h = 0; const s = wave.seed + index; for (let i = 0; i < s.length; ++i) h = (h * 31 + s.charCodeAt(i)) % 997; return h / 997 }
                            width: (wave.width - 43 * 2) / 44
                            height: wave.height * (0.25 + 0.75 * (0.5 + 0.5 * Math.sin(index * 0.55)) * (0.45 + r * 0.55))
                            anchors.verticalCenter: parent.verticalCenter
                            radius: width / 2
                            color: index / 44 <= wave.frac ? root.accent : Kirigami.Theme.textColor
                            opacity: index / 44 <= wave.frac ? 1 : 0.22
                        }
                    }
                }
            }
            RowLayout {
                PC3.Label { text: root.clock(root.player ? root.player.position : 0); opacity: 0.6; font.features: { "tnum": 1 } }
                Item { Layout.fillWidth: true }
                PC3.Label { text: root.clock(root.player ? root.player.length : 0); opacity: 0.6; font.features: { "tnum": 1 } }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing
                Round { iconName: "media-playlist-shuffle"; opacity: root.player && root.player.shuffle ? 1 : 0.5; onClicked: root.player.shuffle = !root.player.shuffle }
                Round { iconName: "media-skip-backward"; enabled: root.player && root.player.canGoPrevious; onClicked: root.player.Previous() }
                Round { iconName: root.playing ? "media-playback-pause" : "media-playback-start"; strong: true; size: Kirigami.Units.gridUnit * 2.8; onClicked: root.player.PlayPause() }
                Round { iconName: "media-skip-forward"; enabled: root.player && root.player.canGoNext; onClicked: root.player.Next() }
                Round { iconName: "window"; enabled: root.player && root.player.canRaise; onClicked: { root.player.Raise(); root.expanded = false } }
            }
        }
    }

    // ---------------------------------------------------------------- sound
    Component {
        id: soundPage
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Item {                                               // the big ring: wheel or drag along it
                id: ring
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                Layout.preferredHeight: Layout.preferredWidth
                // what the ring shows: follows the pointer at once while dragging, glides otherwise;
                // the sound server only gets the newest value every few frames
                property real shown: root.muted ? 0 : root.volume
                property bool dragging: false
                property real want: 0
                Behavior on shown { enabled: !ring.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Binding on shown { when: ring.dragging; value: ring.want; restoreMode: Binding.RestoreBindingOrValue }
                Timer { id: settle; interval: 400; onTriggered: ring.dragging = false }
                Timer { id: push; interval: 40; onTriggered: root.setVolume(Math.round(ring.want)) }
                function drive(v) { want = Math.max(0, Math.min(100, v)); if (!push.running) push.start() }
                readonly property real frac: shown / 100
                readonly property real stroke: Kirigami.Units.gridUnit * 0.75
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.08); strokeWidth: ring.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.width / 2 - ring.stroke; radiusY: radiusX; startAngle: 135; sweepAngle: 270 }
                    }
                    ShapePath {
                        strokeColor: root.accent; strokeWidth: ring.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.width / 2 - ring.stroke; radiusY: radiusX; startAngle: 135; sweepAngle: Math.max(0.5, 270 * ring.frac) }
                    }
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    PC3.Label { Layout.alignment: Qt.AlignHCenter; text: root.muted && !ring.dragging ? "–" : Math.round(ring.shown); font.pixelSize: Kirigami.Units.gridUnit * 3; font.weight: Font.Bold; font.features: { "tnum": 1 } }
                    Caption { Layout.alignment: Qt.AlignHCenter; text: root.muted ? i18n("Muted") : i18n("Volume") }
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    // angle on the 270° arc → 0..100; the gap at the bottom snaps to the nearer end
                    function at(m) {
                        let a = Math.atan2(m.y - height / 2, m.x - width / 2) * 180 / Math.PI
                        a = (a - 135 + 720) % 360
                        if (a > 270) a = a > 315 ? 0 : 270
                        ring.drive(a / 270 * 100)
                    }
                    onPressed: m => { ring.want = ring.shown; ring.dragging = true; at(m) }
                    onPositionChanged: m => { if (pressed) at(m) }
                    onReleased: { push.stop(); root.setVolume(Math.round(ring.want)); settle.restart() }   // wait for the server before letting go
                    onCanceled: ring.dragging = false
                    onWheel: ev => root.setVolume(root.volume + (ev.angleDelta.y > 0 ? 2 : -2))
                }
                Round { anchors { right: parent.right; bottom: parent.bottom } iconName: root.muted ? "audio-volume-muted" : "audio-volume-high"
                    onClicked: if (root.sink) root.sink.muted = !root.sink.muted }
            }
            Caption { text: i18n("Output") }
            Repeater {
                model: root.quitting ? null : sinks
                delegate: QQC2.AbstractButton {
                    id: dev
                    required property var model
                    readonly property bool on: model.PulseObject && model.PulseObject.default
                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.gridUnit * 2.4
                    onClicked: model.PulseObject.default = true
                    background: Rectangle { radius: Kirigami.Units.gridUnit * 0.7
                        color: dev.on ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16) : dev.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        border.width: dev.on ? 1 : 0; border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45) }
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon { Layout.leftMargin: Kirigami.Units.smallSpacing; source: dev.model.IconName || "audio-card"; implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth }
                        PC3.Label { Layout.fillWidth: true; text: dev.model.Description; elide: Text.ElideRight; font.weight: dev.on ? Font.DemiBold : Font.Normal }
                    }
                }
            }
            Caption { text: i18n("Apps"); visible: streams.count > 0 }
            Repeater {
                id: streams
                model: root.quitting ? null : sinkInputs
                delegate: RowLayout {
                    id: st
                    required property var model
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon { source: st.model.IconName || "audio-x-generic"; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth; Layout.leftMargin: Kirigami.Units.smallSpacing }
                    PC3.Label { text: st.model.Client ? st.model.Client.name : st.model.Name; Layout.preferredWidth: Kirigami.Units.gridUnit * 5; elide: Text.ElideRight }
                    PC3.Slider {
                        Layout.fillWidth: true
                        from: 0; to: root.normal; value: st.model.Volume
                        onMoved: st.model.PulseObject.volume = Math.round(value)
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- bluetooth
    Component {
        id: btPage
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            // big switch card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.gridUnit * 4
                radius: Kirigami.Units.gridUnit
                color: root.btOn ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing
                    Rectangle {
                        implicitWidth: Kirigami.Units.gridUnit * 2.6; implicitHeight: implicitWidth; radius: width / 2
                        color: root.btOn ? root.accent : Qt.rgba(1, 1, 1, 0.08)
                        Kirigami.Icon { anchors.centerIn: parent; source: "network-bluetooth"; width: parent.width * 0.55; height: width
                            color: root.btOn ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; isMask: true }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PC3.Label { text: i18n("Bluetooth"); font.weight: Font.DemiBold; font.pixelSize: Kirigami.Units.gridUnit * 1.05 }
                        PC3.Label { Layout.fillWidth: true; elide: Text.ElideRight; opacity: 0.65
                            text: !root.btOn ? i18n("Off") : root.btConnected.length ? i18np("%1 device connected", "%1 devices connected", root.btConnected.length) : i18n("On, nothing connected") }
                    }
                    PC3.Switch { checked: root.btOn; onToggled: root.setBluetooth(checked) }
                }
            }
            Caption { visible: root.btOn; text: i18n("Your devices") }
            Repeater {
                model: root.btOn ? root.bt.devices.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name)) : []
                delegate: QQC2.AbstractButton {
                    id: bdev
                    required property var modelData
                    readonly property var d: modelData
                    property bool busy: false
                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.gridUnit * 2.8
                    onClicked: {
                        busy = true
                        const call = d.connected ? d.disconnectFromDevice() : d.connectToDevice()
                        if (call) call.finished.connect(() => bdev.busy = false); else busy = false
                    }
                    background: Rectangle { radius: Kirigami.Units.gridUnit * 0.7
                        color: bdev.d.connected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14) : bdev.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        border.width: bdev.d.connected ? 1 : 0; border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4) }
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon { Layout.leftMargin: Kirigami.Units.smallSpacing; source: bdev.d.icon || "network-bluetooth"
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth; opacity: bdev.d.connected ? 1 : 0.6 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            PC3.Label { Layout.fillWidth: true; text: bdev.d.name; elide: Text.ElideRight; font.weight: bdev.d.connected ? Font.DemiBold : Font.Normal }
                            PC3.Label { Layout.fillWidth: true; font: Kirigami.Theme.smallFont; opacity: 0.6
                                text: bdev.busy ? (bdev.d.connected ? i18n("Disconnecting…") : i18n("Connecting…")) : bdev.d.connected ? i18n("Connected") : i18n("Click to connect") }
                        }
                        // battery as a small pill gauge
                        Row {
                            visible: bdev.d.connected && !!bdev.d.battery
                            spacing: Kirigami.Units.smallSpacing
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            readonly property int pct: bdev.d.battery ? bdev.d.battery.percentage : 0
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Kirigami.Units.gridUnit * 1.5; height: Kirigami.Units.gridUnit * 0.65; radius: height / 2
                                color: Qt.rgba(1, 1, 1, 0.1)
                                Rectangle { width: Math.max(height, parent.width * parent.parent.pct / 100); height: parent.height; radius: height / 2
                                    color: parent.parent.pct <= 15 ? Kirigami.Theme.negativeTextColor : root.accent }
                            }
                            PC3.Label { text: parent.pct + " %"; font.pixelSize: Kirigami.Theme.smallFont.pixelSize; font.features: { "tnum": 1 } }
                        }
                        PC3.BusyIndicator { visible: bdev.busy; running: visible; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
                    }
                }
            }
            PC3.Label {
                visible: root.btOn && root.bt.devices.filter(d => d.paired).length === 0
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; opacity: 0.6
                text: i18n("No devices paired yet")
            }
            PC3.Button {
                Layout.fillWidth: true
                icon.name: "list-add"; text: i18n("Add a device…")
                onClicked: { KCM.KCMLauncher.openSystemSettings("kcm_bluetooth"); root.expanded = false }
            }
        }
    }

    // ---------------------------------------------------------------- session
    Component {
        id: sessionPage
        ColumnLayout {
            id: sess
            spacing: Kirigami.Units.largeSpacing
            // the action waiting for a second click, and how long it waits
            property string armed: ""
            Timer { id: disarm; interval: 3500; onTriggered: sess.armed = "" }
            function run(a) {
                const skip = Sessions.SessionManagement.Skip
                if (a === "lock") sm.lock()
                else if (a === "sleep") sm.suspend()
                else if (a === "hibernate") sm.hibernate()
                else if (a === "switch") sm.switchUser()
                else if (a === "logout") sm.requestLogout(skip)
                else if (a === "reboot") sm.requestReboot(skip)
                else if (a === "off") sm.requestShutdown(skip)
                root.expanded = false
            }
            // battery (laptops only)
            RowLayout {
                visible: root.hasBattery
                spacing: Kirigami.Units.largeSpacing
                Item {
                    implicitWidth: Kirigami.Units.gridUnit * 4.2; implicitHeight: Kirigami.Units.gridUnit * 2
                    Rectangle {                                   // a pill-shaped battery gauge
                        anchors.fill: parent; radius: height / 2; color: Qt.rgba(1, 1, 1, 0.08)
                        Rectangle {
                            width: Math.max(height, parent.width * root.batteryPct / 100); height: parent.height; radius: height / 2
                            color: root.batteryPct <= 15 && !root.charging ? Kirigami.Theme.negativeTextColor : root.accent
                            Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
                        }
                        Kirigami.Icon { visible: root.charging; anchors.centerIn: parent; source: "battery-charging-symbolic"; width: parent.height * 0.6; height: width }
                    }
                }
                ColumnLayout {
                    spacing: 0
                    PC3.Label { text: root.batteryPct + " %"; font.pixelSize: Kirigami.Units.gridUnit * 1.4; font.weight: Font.Bold; font.features: { "tnum": 1 } }
                    PC3.Label { opacity: 0.6; font: Kirigami.Theme.smallFont
                        text: root.battery["State"] === "FullyCharged" ? i18n("Fully charged") : root.charging ? i18n("Charging") : i18n("On battery") }
                }
            }
            // power profile, as three big segments
            ColumnLayout {
                visible: profiles.isPowerProfileDaemonInstalled && profiles.profiles.length > 0
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Caption { text: i18n("Power profile") }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: ["power-saver", "balanced", "performance"].filter(p => profiles.profiles.indexOf(p) >= 0)
                        delegate: QQC2.AbstractButton {
                            id: prof
                            required property string modelData
                            readonly property bool on: profiles.activeProfile === modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: Kirigami.Units.gridUnit * 3.4
                            hoverEnabled: true
                            onClicked: profiles.setProfile(modelData)
                            background: Rectangle { radius: Kirigami.Units.gridUnit * 0.8
                                color: prof.on ? root.accent : prof.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } } }
                            contentItem: ColumnLayout {
                                spacing: 2
                                Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; source: "power-profile-" + prof.modelData + "-symbolic"
                                    implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth
                                    color: prof.on ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; isMask: true }
                                PC3.Label { Layout.alignment: Qt.AlignHCenter; font: Kirigami.Theme.smallFont
                                    color: prof.on ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                    text: prof.modelData === "power-saver" ? i18n("Power saver") : prof.modelData === "performance" ? i18n("Performance") : i18n("Balanced") }
                            }
                        }
                    }
                }
                PC3.Label { visible: profiles.degradationReason !== "" || profiles.inhibitionReason !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont; opacity: 0.6; text: i18n("Performance is limited right now.") }
            }
            // keep the screen awake
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "system-suspend-uninhibited"; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PC3.Label { text: i18n("Stay awake") }
                    PC3.Label { Layout.fillWidth: true; elide: Text.ElideRight; font: Kirigami.Theme.smallFont; opacity: 0.6
                        text: inhibit.isManuallyInhibited ? i18n("No sleep and no screen lock until you switch it off") : i18n("Sleep and screen lock as usual") }
                }
                PC3.Switch {
                    checked: inhibit.isManuallyInhibited
                    onToggled: checked ? inhibit.inhibit(i18n("Stay awake was switched on in Pillbox")) : inhibit.uninhibit()
                }
            }
            Kirigami.Separator { Layout.fillWidth: true }
            RowLayout {                                         // who is logged in
                spacing: Kirigami.Units.largeSpacing
                Rectangle {
                    implicitWidth: Kirigami.Units.gridUnit * 3; implicitHeight: implicitWidth; radius: width / 2
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                    clip: true
                    Image { id: face; anchors.fill: parent; source: me.faceIconUrl; fillMode: Image.PreserveAspectCrop; visible: false; sourceSize.width: 128 }
                    Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
                    MultiEffect { anchors.fill: parent; source: face; maskEnabled: true; maskSource: faceMask; visible: face.status === Image.Ready }
                    PC3.Label { anchors.centerIn: parent; visible: face.status !== Image.Ready; text: (me.fullName || me.loginName || "?").charAt(0).toUpperCase()
                        font.pixelSize: Kirigami.Units.gridUnit * 1.4; font.weight: Font.Bold }
                }
                ColumnLayout {
                    spacing: 0
                    PC3.Label { text: me.fullName || me.loginName; font.weight: Font.DemiBold; font.pixelSize: Kirigami.Units.gridUnit * 1.1 }
                    PC3.Label { text: me.loginName + "@" + me.host; opacity: 0.6; font: Kirigami.Theme.smallFont }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: Kirigami.Units.smallSpacing; columnSpacing: Kirigami.Units.smallSpacing
                uniformCellWidths: true
                Repeater {
                    model: [
                        { a: "lock", n: i18n("Lock"), i: "system-lock-screen", ok: sm.canLock },
                        { a: "sleep", n: i18n("Sleep"), i: "system-suspend", ok: sm.canSuspend },
                        { a: "hibernate", n: i18n("Hibernate"), i: "system-suspend-hibernate", ok: sm.canHibernate },
                        { a: "switch", n: i18n("Switch user"), i: "system-switch-user", ok: sm.canSwitchUser },
                        { a: "logout", n: i18n("Log out"), i: "system-log-out", ok: sm.canLogout, ask: true },
                        { a: "reboot", n: i18n("Restart"), i: "system-reboot", ok: sm.canReboot, ask: true },
                        { a: "off", n: i18n("Shut down"), i: "system-shutdown", ok: sm.canShutdown, ask: true }
                    ].filter(e => e.ok)
                    delegate: QQC2.AbstractButton {
                        id: act
                        required property var modelData
                        readonly property bool armed: sess.armed === modelData.a
                        Layout.fillWidth: true
                        implicitHeight: Kirigami.Units.gridUnit * 4.6
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.ask && !armed) { sess.armed = modelData.a; disarm.restart(); return }
                            sess.run(modelData.a)
                        }
                        background: Rectangle {
                            radius: Kirigami.Units.gridUnit * 0.9
                            color: act.armed ? (act.modelData.a === "off" ? Kirigami.Theme.negativeTextColor : root.accent)
                                 : act.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                            scale: act.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: 90 } }
                            // the remaining time to confirm, as a thin line along the bottom
                            Rectangle {
                                visible: act.armed
                                anchors { left: parent.left; bottom: parent.bottom; margins: Kirigami.Units.smallSpacing * 1.5 }
                                height: 3; radius: 1.5; color: Kirigami.Theme.highlightedTextColor; opacity: 0.7
                                NumberAnimation on width { running: act.armed; from: act.width - Kirigami.Units.smallSpacing * 3; to: 0; duration: disarm.interval }
                            }
                        }
                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; source: act.modelData.i; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth
                                color: act.armed ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor; isMask: act.armed }
                            PC3.Label { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: act.width - Kirigami.Units.smallSpacing * 2; elide: Text.ElideRight
                                text: act.armed ? i18n("Click again") : act.modelData.n; font: Kirigami.Theme.smallFont
                                color: act.armed ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- network
    Component {
        id: netPage
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            // the hub: this computer in the middle, the connection above, the internet beyond
            Item {
                id: hub
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.78
                readonly property point me: Qt.point(width / 2, height * 0.62)
                readonly property point link: Qt.point(width / 2, height * 0.2)
                readonly property point web: Qt.point(width * 0.86, height * 0.2)
                readonly property real busy: Math.min(1, ((down.value || 0) + (up.value || 0)) / 2097152)
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {                                   // a faint orbit around the computer
                        strokeColor: Qt.rgba(1, 1, 1, 0.06); strokeWidth: 1; fillColor: "transparent"
                        PathAngleArc { centerX: hub.me.x; centerY: hub.me.y; radiusX: hub.height * 0.42; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.online ? 0.6 : 0.2); strokeWidth: 1.5; fillColor: "transparent"
                        strokeStyle: root.online ? ShapePath.SolidLine : ShapePath.DashLine
                        startX: hub.me.x; startY: hub.me.y
                        PathLine { x: hub.link.x; y: hub.link.y }
                        PathLine { x: hub.web.x; y: hub.web.y }
                    }
                }
                // packets travelling along the line, faster when more data flows
                Repeater {
                    model: root.online ? 3 : 0
                    Rectangle {
                        required property int index
                        property real p: 0
                        width: 6; height: 6; radius: 3; color: index === 1 ? Kirigami.Theme.textColor : root.accent
                        x: hub.me.x + (hub.link.x - hub.me.x) * p - 3; y: hub.me.y + (hub.link.y - hub.me.y) * (index === 1 ? 1 - p : p) - 3
                        NumberAnimation on p { from: 0; to: 1; loops: Animation.Infinite; duration: 2600 - hub.busy * 1900 + index * 400; running: root.expanded }
                    }
                }
                component Node: ColumnLayout {
                    property point at
                    property string iconName
                    property string label
                    property bool big: false
                    property bool dim: false
                    x: at.x - width / 2; y: at.y - (big ? Kirigami.Units.gridUnit * 2 : Kirigami.Units.gridUnit * 1.3)
                    spacing: 2
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Kirigami.Units.gridUnit * (parent.big ? 4 : 2.6); implicitHeight: implicitWidth; radius: width / 2
                        opacity: parent.dim ? 0.4 : 1
                        color: parent.big ? root.accent : Qt.rgba(1, 1, 1, 0.07)
                        border.width: parent.big ? 0 : 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                        Kirigami.Icon { anchors.centerIn: parent; source: parent.parent.iconName; width: parent.width * 0.5; height: width
                            color: Kirigami.Theme.highlightedTextColor; isMask: parent.parent.big }
                    }
                    PC3.Label { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: hub.width * 0.45; text: parent.label; elide: Text.ElideRight; font: Kirigami.Theme.smallFont; opacity: 0.7 }
                }
                Node { at: hub.me; big: true; iconName: "computer"; label: i18n("This computer") }
                Node { at: hub.link; iconName: netIcon.connectionIcon || "network-wired"; dim: !root.online
                    label: (netStatus.activeConnections || i18n("Not connected")).split("\n")[0].replace(/<[^>]*>/g, "") }
                Node { at: hub.web; iconName: "globe"; label: i18n("Internet"); dim: netStatus.connectivity !== 4 }
            }
            RowLayout {
                Layout.fillWidth: true
                component Speed: ColumnLayout {
                    property string label
                    property string value
                    Layout.fillWidth: true
                    spacing: 0
                    Caption { text: parent.label }
                    PC3.Label { text: parent.value; font.pixelSize: Kirigami.Units.gridUnit * 1.1; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                }
                Speed { label: i18n("Download"); value: root.rate(down.value) }
                Speed { label: i18n("Upload"); value: root.rate(up.value) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                PC3.Button {
                    Layout.fillWidth: true
                    icon.name: nmEnabled.wirelessEnabled ? "network-wireless-on" : "network-wireless-off"
                    text: nmEnabled.wirelessEnabled ? i18n("Wi-Fi on") : i18n("Wi-Fi off")
                    checkable: true; checked: nmEnabled.wirelessEnabled
                    visible: nmEnabled.wirelessHwEnabled
                    onClicked: nmHandler.enableWireless(checked)
                }
                PC3.Button {
                    Layout.fillWidth: true
                    icon.name: "configure"; text: i18n("Network settings")
                    onClicked: { KCM.KCMLauncher.openSystemSettings("kcm_networkmanagement"); root.expanded = false }
                }
            }
        }
    }
}
