/*
 * Pillbox settings centre – a glass window with a sidebar. Every change applies
 * live; the real orb, dock and wallpaper are the preview.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kirigami.primitives as KirigamiPrimitives
import org.kde.kquickcontrols as KQuickControls

Window {
    id: panel

    property var orb
    property bool open: false
    signal closeRequested()

    readonly property var cfg: orb.cfg
    readonly property bool isOrb: cfg.form === "orb"
    readonly property color accent: orb.accent
    readonly property rect home: orb.homeScreen()
    readonly property int winW: Math.min(Kirigami.Units.gridUnit * 50, home.width - Kirigami.Units.gridUnit * 4)
    readonly property int winH: Math.min(Kirigami.Units.gridUnit * 34, home.height - Kirigami.Units.gridUnit * 6)
    property string page: "form"

    // a real top-level window: KWin lets it be moved and resized (Plasma dialogs can't be)
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: i18n("Pillbox Settings")
    width: winW; height: winH
    minimumWidth: Kirigami.Units.gridUnit * 34
    minimumHeight: Kirigami.Units.gridUnit * 22
    x: home.x + Math.round((home.width - winW) / 2)
    y: home.y + Math.round((home.height - winH) / 2)
    visible: open
    onVisibleChanged: if (visible) requestActivate()
    onClosing: close => { close.accepted = false; panel.closeRequested() }

    readonly property var pages: [
        { id: "form",       name: i18n("Form"),        icon: "view-app-grid-symbolic" },
        { id: "color",      name: i18n("Color"),       icon: "color-management" },
        { id: "wallpaper",  name: i18n("Wallpaper"),   icon: "preferences-desktop-wallpaper" },
        { id: "login",      name: i18n("Login screen"), icon: "system-users" },
        { id: "topbar",     name: i18n("Top bar"),     icon: "view-split-top-bottom" },
        { id: "behavior",   name: i18n("Behavior"),    icon: "preferences-system-windows-behavior" },
        { id: "alerts",     name: i18n("Alerts"),      icon: "preferences-desktop-notification-bell" },
        { id: "about",      name: i18n("About"),       icon: "help-about" }
    ]
    // the current time (for the time-of-day slider while it follows the clock)
    property real nowHour: { const d = new Date(); return d.getHours() + d.getMinutes() / 60 }
    property Timer clockTimer: Timer {
        interval: 30000; repeat: true; running: panel.visible; triggeredOnStart: true
        onTriggered: { const d = new Date(); panel.nowHour = d.getHours() + d.getMinutes() / 60 }
    }
    function hhmm(h) { const m = Math.round((h % 1) * 60); return Math.floor(h) + ":" + String(m === 60 ? 0 : m).padStart(2, "0") }

    // each scene's own options; values are stored in wallOpts and written to the wallpaper
    readonly property var sceneTable: ({
        flow:    { name: "Flow",    opts: [{ key: "FlowPalette", def: "time", label: i18n("Colours"), choices: [["time", i18n("Time of day")], ["ocean", i18n("Ocean")], ["sunset", i18n("Sunset")], ["forest", i18n("Forest")], ["mono", i18n("Grey")]] }] },
        horizon: { name: "Horizon", opts: [{ key: "HorizonTone", def: "natural", label: i18n("Tone"), choices: [["natural", i18n("Natural")], ["teal", i18n("Teal")], ["rose", i18n("Rosé")]] }] },
        fogline: { name: "Fogline", opts: [{ key: "FoglineFog", def: "normal", label: i18n("Fog"), hint: i18n("Load makes it denser on top."), choices: [["light", i18n("Light")], ["normal", i18n("Normal")], ["dense", i18n("Dense")]] }] },
        dune:    { name: "Dune",    opts: [{ key: "DuneTone", def: "gold", label: i18n("Sand"), choices: [["gold", i18n("Gold")], ["red", i18n("Red")], ["white", i18n("White")]] }] },
        aurora:  { name: "Aurora",  opts: [{ key: "AuroraColor", def: "mixed", label: i18n("Northern lights"), choices: [["mixed", i18n("Mixed")], ["green", i18n("Green")], ["violet", i18n("Violet")]] },
                                           { key: "AuroraHut", def: "on", label: i18n("Hut by the water"), hint: i18n("Its window lights up with the graphics card."), choices: [["on", i18n("On")], ["off", i18n("Off")]] }] },
        tide:    { name: "Tide",    opts: [{ key: "TideWaves", def: "normal", label: i18n("Sea"), choices: [["calm", i18n("Calm")], ["normal", i18n("Normal")], ["rough", i18n("Rough")]] }] },
        neon:    { name: "Neon",    opts: [{ key: "NeonRain", def: "off", label: i18n("Rain"), hint: i18n("Otherwise it only rains after a new notification."), choices: [["off", i18n("After notifications")], ["on", i18n("Always")]] },
                                           { key: "NeonSigns", def: "mixed", label: i18n("Signs"), choices: [["mixed", i18n("Colourful")], ["pink", i18n("Pink")], ["cyan", i18n("Cyan")]] }] },
        orbit:   { name: "Orbit",   opts: [{ key: "OrbitPlanet", def: "blue", label: i18n("Planet"), choices: [["blue", i18n("Blue")], ["red", i18n("Red")], ["gold", i18n("Gold")]] }] },
        contour: { name: "Contour", opts: [{ key: "ContourDensity", def: "normal", label: i18n("Lines"), choices: [["wide", i18n("Wide")], ["normal", i18n("Normal")], ["fine", i18n("Fine")]] }] },
        grid:    { name: "Grid",    opts: [{ key: "GridGap", def: "normal", label: i18n("Spacing"), choices: [["wide", i18n("Wide")], ["normal", i18n("Normal")], ["fine", i18n("Fine")]] }] }
    })
    readonly property var sceneOptions: sceneTable[cfg.wallScene] ? sceneTable[cfg.wallScene].opts : []
    readonly property string sceneName: sceneTable[cfg.wallScene] ? sceneTable[cfg.wallScene].name : ""
    function optValue(o) { const all = orb.wallOpts(); return all[o.key] !== undefined ? all[o.key] : o.def }
    function setOpt(o, v) { const all = orb.wallOpts(); all[o.key] = v; cfg.wallOpts = JSON.stringify(all); orb.applyWallpaper() }

    readonly property var presets: ["#8fb0c2", "#e0bd6e", "#ff8a4c", "#e88fa6", "#b49cf0", "#7fd3f0", "#7fdcb0", "#eef2f5"]

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: panel.closeRequested()

        Rectangle {                                  // glass
            anchors.fill: parent
            radius: Kirigami.Units.gridUnit
            color: Qt.rgba(0.06, 0.075, 0.095, 0.97)
            border.width: 1
            border.color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.3)
        }
        // grab any empty spot to move the window (controls on top keep their own clicks)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
            onPressed: panel.startSystemMove()
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ------------------------------------------------ sidebar
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                color: Qt.rgba(0, 0, 0, 0.22)
                radius: Kirigami.Units.gridUnit
                Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 1; color: Qt.rgba(1, 1, 1, 0.07) }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: 2
                    RowLayout {
                        Layout.margins: Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing * 2
                        Rectangle {
                            width: 14; height: 14; radius: 7
                            gradient: Gradient { GradientStop { position: 0; color: "white" } GradientStop { position: 1; color: panel.accent } }
                        }
                        Kirigami.Heading { level: 3; text: "Pillbox" }
                    }
                    Repeater {
                        model: panel.pages
                        delegate: QQC2.ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            highlighted: panel.page === modelData.id
                            icon.name: modelData.icon
                            text: modelData.name
                            onClicked: panel.page = modelData.id
                            background: Rectangle {
                                radius: Kirigami.Units.gridUnit * 0.5
                                color: parent.highlighted ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.2)
                                     : parent.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        text: i18n("Changes apply right away.")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.5
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ------------------------------------------------ page
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: Kirigami.Units.gridUnit
                    Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

                    RowLayout {
                        Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        Kirigami.Heading { level: 2; text: panel.pages.find(p => p.id === panel.page).name; Layout.fillWidth: true }
                        QQC2.ToolButton { icon.name: "window-close"; display: QQC2.AbstractButton.IconOnly; text: i18n("Close"); onClicked: panel.closeRequested() }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                        Layout.rightMargin: Kirigami.Units.gridUnit * 1.5
                        Layout.bottomMargin: Kirigami.Units.gridUnit
                        sourceComponent: panel.page === "form" ? formPage : panel.page === "color" ? colorPage
                                       : panel.page === "wallpaper" ? wallPage : panel.page === "login" ? loginPage : panel.page === "topbar" ? topPage
                                       : panel.page === "behavior" ? behaviorPage : panel.page === "alerts" ? alertsPage : aboutPage
                    }
                }
            }
        }
        // edges and corners: drag to resize
        Repeater {
            model: [
                { e: Qt.LeftEdge, c: Qt.SizeHorCursor }, { e: Qt.RightEdge, c: Qt.SizeHorCursor },
                { e: Qt.TopEdge, c: Qt.SizeVerCursor }, { e: Qt.BottomEdge, c: Qt.SizeVerCursor },
                { e: Qt.TopEdge | Qt.LeftEdge, c: Qt.SizeFDiagCursor }, { e: Qt.BottomEdge | Qt.RightEdge, c: Qt.SizeFDiagCursor },
                { e: Qt.TopEdge | Qt.RightEdge, c: Qt.SizeBDiagCursor }, { e: Qt.BottomEdge | Qt.LeftEdge, c: Qt.SizeBDiagCursor }
            ]
            delegate: MouseArea {
                required property var modelData
                readonly property int grip: 8
                readonly property bool l: modelData.e & Qt.LeftEdge
                readonly property bool r: modelData.e & Qt.RightEdge
                readonly property bool t: modelData.e & Qt.TopEdge
                readonly property bool b: modelData.e & Qt.BottomEdge
                x: r ? parent.width - grip : 0
                y: b ? parent.height - grip : 0
                width: (l || r) ? grip : parent.width
                height: (t || b) ? grip : parent.height
                z: (l || r) && (t || b) ? 11 : 10
                cursorShape: modelData.c
                onPressed: panel.startSystemResize(modelData.e)
            }
        }
    }

    // ================================================================ building blocks
    // a group: small caps title + rows
    component Group: ColumnLayout {
        property string title
        default property alias rows: body.data
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        QQC2.Label { text: parent.title.toUpperCase(); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; font.letterSpacing: 1.2; opacity: 0.55; visible: text.length > 0 }
        ColumnLayout { id: body; Layout.fillWidth: true; spacing: 0 }
    }
    // a row: bold label + description on the left, a control on the right
    component SettingRow: Item {
        property string label
        property string hint
        default property alias control: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(texts.implicitHeight, slot.childrenRect.height) + Kirigami.Units.largeSpacing * 2
        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
        ColumnLayout {
            id: texts
            anchors.left: parent.left
            anchors.right: slot.left
            anchors.rightMargin: Kirigami.Units.gridUnit
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            QQC2.Label { text: label; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            QQC2.Label { text: hint; visible: hint.length > 0; opacity: 0.6; font: Kirigami.Theme.smallFont; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
        Item {
            id: slot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width; height: childrenRect.height
        }
    }
    // one segment of a segmented control: a pill that sits exactly inside the track
    component SegButton: Item {
        id: sb
        property string text
        property bool on: false
        signal activated()
        implicitWidth: sbLabel.implicitWidth + Kirigami.Units.gridUnit * 1.3
        implicitHeight: Math.round(sbLabel.implicitHeight + Kirigami.Units.smallSpacing * 2.4)
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sb.on ? panel.accent : sbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }
        Text {
            id: sbLabel
            anchors.centerIn: parent
            text: sb.text
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            font.weight: sb.on ? Font.DemiBold : Font.Normal
            color: sb.on ? "#0b0e12" : Kirigami.Theme.textColor
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: sbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.activated()
        }
    }
    // the track around the segments: same padding on every side
    component SegTrack: Rectangle {
        default property alias buttons: segInner.data
        readonly property int pad: 3
        implicitWidth: segInner.implicitWidth + pad * 2
        implicitHeight: segInner.implicitHeight + pad * 2
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
        Row { id: segInner; x: parent.pad; y: parent.pad; spacing: 2 }
    }
    // segmented choice bound to one config key
    component Segments: SegTrack {
        id: segs
        property string key
        property var options: []             // [[value, label], ...]
        property var target: panel.cfg
        signal picked()
        Repeater {
            model: segs.options
            delegate: SegButton {
                required property var modelData
                text: modelData[1]
                on: segs.target[segs.key] === modelData[0]
                onActivated: { segs.target[segs.key] = modelData[0]; segs.picked() }
            }
        }
    }
    // segmented choice for one scene option (stored in wallOpts)
    component OptChoice: SegTrack {
        id: oc
        property var opt
        readonly property string current: { panel.cfg.wallOpts; return panel.optValue(opt) }
        Repeater {
            model: oc.opt ? oc.opt.choices : []
            delegate: SegButton {
                required property var modelData
                text: modelData[1]
                on: oc.current === modelData[0]
                onActivated: panel.setOpt(oc.opt, modelData[0])
            }
        }
    }
    // a switch that is clearly on (accent colour) or off (grey)
    component PillSwitch: QQC2.AbstractButton {
        id: sw
        checkable: true
        hoverEnabled: true
        implicitWidth: Kirigami.Units.gridUnit * 2.4
        implicitHeight: Kirigami.Units.gridUnit * 1.3
        background: Rectangle {
            radius: height / 2
            color: sw.checked ? panel.accent : sw.hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.16)
            border.width: sw.visualFocus ? 2 : 0; border.color: Kirigami.Theme.focusColor
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            Rectangle {
                readonly property real pad: 3
                width: parent.height - pad * 2; height: width; radius: width / 2
                y: pad
                x: sw.checked ? parent.width - width - pad : pad
                color: sw.checked ? "#0b0e12" : "#e8ecf0"
                Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
            }
        }
        contentItem: Item {}
    }
    component Toggle: PillSwitch {
        property string key
        property var target: panel.cfg
        signal picked()
        checked: target[key] === true
        onToggled: { target[key] = checked; picked() }
    }
    component Slider: RowLayout {
        property string key
        property alias from: s.from
        property alias to: s.to
        property alias step: s.stepSize
        property string unit
        QQC2.Slider { id: s; Layout.preferredWidth: Kirigami.Units.gridUnit * 10; value: panel.cfg[parent.key]; onMoved: panel.cfg[parent.key] = value }
        QQC2.Label { text: s.value + " " + parent.unit; Layout.minimumWidth: Kirigami.Units.gridUnit * 2.6; opacity: 0.8 }
    }
    component Card: QQC2.AbstractButton {
        property bool chosen: false
        property string subtitle
        property Component art
        Layout.fillWidth: true
        implicitHeight: Kirigami.Units.gridUnit * 6
        background: Rectangle {
            radius: Kirigami.Units.gridUnit * 0.6
            color: parent.chosen ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.16) : parent.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
            border.width: parent.chosen ? 1.5 : 1
            border.color: parent.chosen ? panel.accent : Qt.rgba(1, 1, 1, 0.08)
        }
        contentItem: ColumnLayout {
            spacing: 2
            Loader { sourceComponent: art; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: Kirigami.Units.gridUnit * 4; Layout.preferredHeight: Kirigami.Units.gridUnit * 2 }
            QQC2.Label { text: parent.parent.text; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
            QQC2.Label { text: parent.parent.subtitle; font: Kirigami.Theme.smallFont; opacity: 0.65; Layout.alignment: Qt.AlignHCenter }
        }
    }

    // ================================================================ pages
    property Component formPage: Component {
        ColumnLayout {
            spacing: Kirigami.Units.gridUnit
            GridLayout {
                columns: 4; columnSpacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Card { text: "Orb"; subtitle: i18n("floating ball"); chosen: panel.cfg.form === "orb"; onClicked: panel.cfg.form = "orb"
                    art: Component { Item { Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11; gradient: Gradient { GradientStop { position: 0; color: "white" } GradientStop { position: 1; color: panel.accent } } } } } }
                Card { text: "Ember"; subtitle: i18n("seam that unfolds"); chosen: panel.cfg.form === "ember"; onClicked: panel.cfg.form = "ember"
                    art: Component { Item { Rectangle { anchors.centerIn: parent; width: 56; height: 10; radius: 5; color: Qt.rgba(1, 1, 1, 0.1)
                        Row { anchors.centerIn: parent; spacing: 5; Repeater { model: 5; Rectangle { width: 5; height: 5; radius: 2.5; color: index < 3 ? panel.accent : Qt.rgba(1, 1, 1, 0.4) } } } } } } }
                Card { text: "Shelf"; subtitle: i18n("glass ledge"); chosen: panel.cfg.form === "shelf"; onClicked: panel.cfg.form = "shelf"
                    art: Component { Item { Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 60; height: 3; color: Qt.rgba(1, 1, 1, 0.45) }
                        Row { anchors.bottom: parent.bottom; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter; spacing: 5; Repeater { model: 4; Rectangle { width: 11; height: 11; radius: 3; color: index === 1 ? panel.accent : Qt.rgba(1, 1, 1, 0.3) } } } } } }
                Card { text: "Liquid"; subtitle: i18n("liquid glass"); chosen: panel.cfg.form === "liquid"; onClicked: panel.cfg.form = "liquid"
                    art: Component { Item { Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 60; height: 14; radius: 7; color: Qt.rgba(1, 1, 1, 0.14) }
                        Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter; width: 18; height: 18; radius: 9; color: Qt.rgba(1, 1, 1, 0.14) }
                        Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 9; anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 10; radius: 3; color: panel.accent } } } }
            }

            Group {
                title: panel.isOrb ? i18n("Orb") : i18n("Dock")
                SettingRow { visible: panel.isOrb; label: i18n("Ball size"); hint: i18n("Drawn the same size on every screen, 4K included.")
                    Slider { key: "ballScale"; from: 60; to: 200; step: 5; unit: "%" } }
                SettingRow { visible: panel.isOrb; label: i18n("Effect")
                    Segments { key: "effect"; options: [["aura", i18n("Aura")], ["pulse", i18n("Pulse")], ["calm", i18n("Calm")], ["plain", i18n("Plain")]] } }
                SettingRow { visible: panel.isOrb && (panel.cfg.effect === "aura" || panel.cfg.effect === "pulse"); label: i18n("Speed")
                    Slider { key: "effectSpeed"; from: 25; to: 300; step: 25; unit: "%" } }
                SettingRow { visible: panel.isOrb; label: i18n("Ring size"); hint: i18n("The circle of apps around the ball.")
                    Slider { key: "ringScale"; from: 60; to: 150; step: 5; unit: "%" } }
                SettingRow { visible: !panel.isOrb; label: i18n("Position")
                    Segments { key: "dockEdge"; options: [["bottom", i18n("Bottom")], ["left", i18n("Left")], ["right", i18n("Right")]] } }
                SettingRow { visible: !panel.isOrb; label: i18n("Monitor")
                    QQC2.ComboBox {
                        textRole: "text"; valueRole: "value"
                        model: [{ text: i18n("Main monitor"), value: "primary" }, { text: i18n("All monitors"), value: "all" }]
                               .concat(Qt.application.screens.map(sc => ({ text: sc.name + "  (" + sc.width + "×" + sc.height + ")", value: sc.name })))
                        currentIndex: Math.max(0, indexOfValue(panel.cfg.dockScreen))
                        onActivated: panel.cfg.dockScreen = currentValue
                    } }
                SettingRow { visible: !panel.isOrb; label: i18n("At rest"); hint: i18n("Smaller or hidden docks free the space above them.")
                    Segments { key: "dockHide"; options: [["never", i18n("Visible")], ["compact", i18n("Small")], ["autohide", i18n("Hidden")]] } }
                SettingRow { visible: !panel.isOrb; label: i18n("Dock size")
                    Slider { key: "dockScale"; from: 60; to: 160; step: 5; unit: "%" } }
                SettingRow { visible: panel.cfg.form === "shelf"; label: i18n("Reflection on hover")
                    Toggle { key: "shelfReflection" } }
                SettingRow { label: i18n("Icon size")
                    Slider { key: "ringIconSize"; from: 44; to: 80; step: 4; unit: "px" } }
            }
        }
    }

    property Component colorPage: Component {
        ColumnLayout {
            spacing: Kirigami.Units.gridUnit
            Group {
                title: i18n("Accent")
                SettingRow { label: i18n("Color"); hint: i18n("For the orb, the docks and highlights.")
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        enabled: panel.cfg.colorMode !== "system"
                        opacity: enabled ? 1 : 0.4
                        Repeater {
                            model: panel.presets
                            delegate: QQC2.AbstractButton {
                                required property string modelData
                                implicitWidth: Kirigami.Units.gridUnit * 1.5; implicitHeight: implicitWidth
                                onClicked: panel.cfg.customColor = modelData
                                contentItem: Rectangle { radius: width / 2; color: modelData; border.width: Qt.colorEqual(panel.cfg.customColor, modelData) ? 3 : 0; border.color: Kirigami.Theme.textColor }
                            }
                        }
                        KQuickControls.ColorButton {
                            implicitHeight: Kirigami.Units.gridUnit * 1.5
                            color: panel.cfg.customColor; showAlphaChannel: false
                            dialogTitle: i18n("Orb color")
                            onAccepted: c => panel.cfg.customColor = c
                        }
                    } }
                SettingRow { label: i18n("Use the color scheme's accent"); hint: i18n("Follows System Settings → Colors.")
                    PillSwitch { checked: panel.cfg.colorMode === "system"; onToggled: panel.cfg.colorMode = checked ? "system" : "custom" } }
            }
            Group {
                title: i18n("Apps")
                SettingRow { label: i18n("Apps glow in their own icon color"); hint: i18n("Discord blue, Zen orange – in the ring and the docks.")
                    Toggle { key: "appColors" } }
            }
        }
    }

    property Component loginPage: Component {
        ColumnLayout {
            spacing: Kirigami.Units.gridUnit
            Component.onCompleted: panel.orb.checkLogin()
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.75
                text: i18n("The screen where you type your password: a large clock and one glass card on a living atmosphere.")
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: panel.orb.loginState === "nosddm"
                wrapMode: Text.WordWrap
                text: i18n("This system uses a different login manager than SDDM, so the Pillbox login screen can't be used here.")
            }
            // not set up yet
            Group {
                title: i18n("Set up")
                visible: panel.orb.loginState === "missing" || panel.orb.loginState === "working" || panel.orb.loginState === "unknown"
                SettingRow {
                    label: panel.orb.loginState === "working" ? i18n("Setting up…") : i18n("Use the Pillbox login screen")
                    hint: i18n("Asks once for your password, because login screens are installed for the whole system. After that you change it here without a password.")
                    QQC2.Button {
                        text: i18n("Set up…")
                        icon.name: "dialog-password"
                        enabled: panel.orb.loginState === "missing"
                        onClicked: panel.orb.setupLogin()
                    }
                }
            }
            // set up: choose the scene
            Group {
                title: i18n("Background")
                visible: panel.orb.loginState === "ready"
                Item {
                    id: lgBox
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    readonly property int cols: width > Kirigami.Units.gridUnit * 40 ? 4 : 3
                    readonly property real gap: Kirigami.Units.gridUnit
                    readonly property real tileW: Math.floor((width - gap * (cols - 1)) / cols)
                    readonly property real rad: Kirigami.Units.gridUnit * 0.6
                    implicitHeight: lgGrid.implicitHeight
                    Grid {
                        id: lgGrid
                        columns: lgBox.cols
                        columnSpacing: lgBox.gap
                        rowSpacing: Kirigami.Units.gridUnit * 0.8
                        Repeater {
                            model: [
                                { v: "auto", n: i18n("Time of day"), h: i18n("Aurora at night, Horizon by day"), img: "aurora" },
                                { v: "desktop", n: i18n("Like the desktop"), h: i18n("the same as your wallpaper"), img: "" },
                                { v: "flow", n: "Flow", h: i18n("clouds of colour"), img: "flow" },
                                { v: "horizon", n: "Horizon", h: i18n("flat hills, one sun"), img: "horizon" },
                                { v: "fogline", n: "Fogline", h: i18n("misty lake"), img: "fogline" },
                                { v: "dune", n: "Dune", h: i18n("desert"), img: "dune" },
                                { v: "aurora", n: "Aurora", h: i18n("polar night"), img: "aurora" },
                                { v: "tide", n: "Tide", h: i18n("open sea"), img: "tide" },
                                { v: "neon", n: "Neon", h: i18n("city at night"), img: "neon" },
                                { v: "orbit", n: "Orbit", h: i18n("planet in space"), img: "orbit" },
                                { v: "contour", n: "Contour", h: i18n("contour lines"), img: "contour" },
                                { v: "grid", n: "Grid", h: i18n("field of dots"), img: "grid" }
                            ]
                            delegate: QQC2.AbstractButton {
                                id: lt
                                required property var modelData
                                readonly property bool chosen: (panel.cfg.loginScene || "auto") === modelData.v
                                readonly property string img: modelData.v === "desktop" ? (panel.cfg.wallScene && panel.cfg.wallScene !== "keep" ? panel.cfg.wallScene : "") : modelData.img
                                width: lgBox.tileW
                                hoverEnabled: true
                                padding: 0
                                background: null
                                onClicked: { panel.cfg.loginScene = modelData.v; panel.orb.applyLogin() }
                                contentItem: Column {
                                    spacing: Kirigami.Units.smallSpacing
                                    Item {
                                        width: lt.width; height: Math.round(width * 0.58)
                                        scale: lt.pressed ? 0.98 : lt.hovered ? 1.02 : 1
                                        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                                        Rectangle {
                                            anchors.fill: parent; anchors.margins: -4
                                            radius: lgBox.rad + 4; color: "transparent"
                                            border.width: 2; border.color: panel.accent
                                            visible: lt.chosen
                                        }
                                        KirigamiPrimitives.ShadowedImage {
                                            anchors.fill: parent
                                            visible: lt.img.length > 0
                                            source: visible ? Qt.resolvedUrl("../images/wall-" + lt.img + ".jpg") : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            radius: lgBox.rad
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: lt.img.length === 0
                                            radius: lgBox.rad
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                                            Kirigami.Icon { anchors.centerIn: parent; source: "preferences-desktop-wallpaper"; width: parent.height * 0.36; height: width; opacity: 0.7 }
                                        }
                                        // a tiny login card on every tile, so it reads as "login screen"
                                        Rectangle {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: parent.height * 0.08
                                            width: parent.width * 0.3; height: parent.height * 0.3
                                            radius: height * 0.25
                                            color: Qt.rgba(0.06, 0.075, 0.1, 0.62)
                                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.16; width: parent.height * 0.3; height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.25) }
                                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.62; width: parent.width * 0.78; height: parent.height * 0.18; radius: height / 2; color: Qt.rgba(1, 1, 1, 0.14) }
                                        }
                                        Rectangle {
                                            visible: lt.chosen
                                            anchors { top: parent.top; right: parent.right; margins: Kirigami.Units.smallSpacing * 1.5 }
                                            width: Kirigami.Units.gridUnit * 1.2; height: width; radius: width / 2
                                            color: panel.accent
                                            Kirigami.Icon { anchors.centerIn: parent; source: "checkmark"; width: parent.width * 0.65; height: width; color: "#0b0e12"; isMask: true }
                                        }
                                    }
                                    Column {
                                        width: lt.width
                                        topPadding: 2
                                        QQC2.Label { width: parent.width; text: lt.modelData.n; font.weight: Font.DemiBold; elide: Text.ElideRight; color: lt.chosen ? panel.accent : Kirigami.Theme.textColor }
                                        QQC2.Label { width: parent.width; text: lt.modelData.h; font: Kirigami.Theme.smallFont; opacity: 0.6; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Group {
                title: i18n("More")
                visible: panel.orb.loginState === "ready"
                SettingRow { label: i18n("Accent colour"); hint: i18n("The login screen uses the same accent as the orb and changes with it.")
                    Rectangle { width: Kirigami.Units.gridUnit * 1.5; height: width; radius: width / 2; color: panel.accent } }
                SettingRow { label: i18n("Preview"); hint: i18n("Opens the login screen in a window. Close it with Alt+F4.")
                    QQC2.Button { text: i18n("Show"); icon.name: "view-preview"; onClicked: panel.orb.previewLogin() } }
                SettingRow { label: i18n("Update"); hint: i18n("Brings the newest Pillbox version to the login screen. Asks for your password; your choices stay.")
                    QQC2.Button { text: i18n("Update…"); icon.name: "view-refresh"; onClicked: panel.orb.setupLogin() } }
                SettingRow { label: i18n("Remove"); hint: i18n("Back to your previous login screen. Asks for your password.")
                    QQC2.Button { text: i18n("Remove…"); icon.name: "edit-delete"; onClicked: panel.orb.removeLogin() } }
            }
        }
    }

    property Component wallPage: Component {
        ColumnLayout {
            spacing: Kirigami.Units.gridUnit
            Group {
                title: i18n("Atmosphere")
                Item {
                    id: tilesBox
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    readonly property int cols: width > Kirigami.Units.gridUnit * 40 ? 4 : 3
                    readonly property real gap: Kirigami.Units.gridUnit
                    readonly property real tileW: Math.floor((width - gap * (cols - 1)) / cols)
                    readonly property real rad: Kirigami.Units.gridUnit * 0.6
                    implicitHeight: tileGrid.implicitHeight
                    Grid {
                        id: tileGrid
                        columns: tilesBox.cols
                        columnSpacing: tilesBox.gap
                        rowSpacing: Kirigami.Units.gridUnit * 0.8
                        Repeater {
                            model: [
                                { v: "flow", n: "Flow", h: i18n("clouds of colour") },
                                { v: "horizon", n: "Horizon", h: i18n("flat hills, one sun") },
                                { v: "fogline", n: "Fogline", h: i18n("misty lake") },
                                { v: "dune", n: "Dune", h: i18n("desert") },
                                { v: "aurora", n: "Aurora", h: i18n("polar night") },
                                { v: "tide", n: "Tide", h: i18n("open sea") },
                                { v: "neon", n: "Neon", h: i18n("city at night") },
                                { v: "orbit", n: "Orbit", h: i18n("planet in space") },
                                { v: "contour", n: "Contour", h: i18n("contour lines") },
                                { v: "grid", n: "Grid", h: i18n("field of dots") },
                                { v: "keep", n: i18n("Own image"), h: i18n("Plasma's wallpaper") }
                            ]
                            delegate: QQC2.AbstractButton {
                                id: tile
                                required property var modelData
                                readonly property bool chosen: panel.cfg.wallScene === modelData.v
                                width: tilesBox.tileW
                                hoverEnabled: true
                                padding: 0
                                onClicked: { panel.cfg.wallScene = modelData.v; panel.orb.applyWallpaper() }
                                background: null
                                contentItem: Column {
                                    spacing: Kirigami.Units.smallSpacing
                                    Item {
                                        id: thumb
                                        width: tile.width; height: Math.round(width * 0.58)
                                        scale: tile.pressed ? 0.98 : tile.hovered ? 1.02 : 1
                                        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                                        Rectangle {                      // selection ring
                                            anchors.fill: parent; anchors.margins: -4
                                            radius: tilesBox.rad + 4
                                            color: "transparent"
                                            border.width: 2; border.color: panel.accent
                                            visible: tile.chosen
                                        }
                                        KirigamiPrimitives.ShadowedImage {
                                            anchors.fill: parent
                                            visible: tile.modelData.v !== "keep"
                                            source: visible ? Qt.resolvedUrl("../images/wall-" + tile.modelData.v + ".jpg") : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            radius: tilesBox.rad
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                                        }
                                        Rectangle {                      // "own image"
                                            anchors.fill: parent
                                            visible: tile.modelData.v === "keep"
                                            radius: tilesBox.rad
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                                            Kirigami.Icon { anchors.centerIn: parent; source: "preferences-desktop-wallpaper"; width: parent.height * 0.36; height: width; opacity: 0.7 }
                                        }
                                        Rectangle {                      // check badge
                                            visible: tile.chosen
                                            anchors { top: parent.top; right: parent.right; margins: Kirigami.Units.smallSpacing * 1.5 }
                                            width: Kirigami.Units.gridUnit * 1.2; height: width; radius: width / 2
                                            color: panel.accent
                                            Kirigami.Icon { anchors.centerIn: parent; source: "checkmark"; width: parent.width * 0.65; height: width; color: "#0b0e12"; isMask: true }
                                        }
                                    }
                                    Column {
                                        width: tile.width
                                        topPadding: 2
                                        QQC2.Label { width: parent.width; text: tile.modelData.n; font.weight: Font.DemiBold; elide: Text.ElideRight; color: tile.chosen ? panel.accent : Kirigami.Theme.textColor }
                                        QQC2.Label { width: parent.width; text: tile.modelData.h; font: Kirigami.Theme.smallFont; opacity: 0.6; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Group {
                title: panel.sceneOptions.length ? i18n("%1 – own settings", panel.sceneName) : ""
                visible: panel.sceneOptions.length > 0
                Repeater {
                    model: panel.sceneOptions
                    delegate: SettingRow {
                        id: optRow
                        required property var modelData
                        label: modelData.label
                        hint: modelData.hint || ""
                        OptChoice { opt: optRow.modelData }
                    }
                }
            }
            Group {
                title: i18n("Behavior")
                enabled: panel.cfg.wallScene !== "keep"
                opacity: enabled ? 1 : 0.45
                SettingRow { label: i18n("Try it"); hint: i18n("For eight seconds the scene shows how it reacts to full load and a new notification.")
                    QQC2.Button { text: i18n("Play"); icon.name: "media-playback-start"; onClicked: panel.orb.previewWallpaper() } }
                SettingRow {
                    label: i18n("Time of day")
                    hint: panel.cfg.wallFollow ? i18n("Follows the clock. Drag to hold the wallpaper at one time.")
                                               : i18n("Held at %1 – it stays like this.", panel.hhmm(panel.cfg.wallHour))
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        QQC2.Slider {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                            from: 0; to: 23.75; stepSize: 0.25
                            value: panel.cfg.wallFollow ? panel.nowHour : panel.cfg.wallHour
                            onMoved: { panel.cfg.wallHour = value; panel.cfg.wallFollow = false; panel.orb.applyWallpaper() }
                        }
                        QQC2.Label {
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.6
                            text: panel.hhmm(panel.cfg.wallFollow ? panel.nowHour : panel.cfg.wallHour)
                            font.features: { "tnum": 1 }
                            color: panel.cfg.wallFollow ? Kirigami.Theme.textColor : panel.accent
                        }
                        QQC2.Button {
                            text: i18n("Follow the clock")
                            icon.name: "chronometer"
                            enabled: !panel.cfg.wallFollow
                            onClicked: { panel.cfg.wallFollow = true; panel.orb.applyWallpaper() }
                        }
                    } }
                SettingRow { label: i18n("Reacts to your computer"); hint: i18n("Load, graphics card and unread notifications change the scene.")
                    Segments { key: "wallReact"; options: [["off", i18n("Off")], ["subtle", i18n("Subtle")], ["strong", i18n("Strong")]]; onPicked: panel.orb.applyWallpaper() } }
                SettingRow { label: i18n("Motion"); hint: i18n("Calm redraws 8 times a second, lively 20.")
                    Segments { key: "wallMotion"; options: [["calm", i18n("Calm")], ["normal", i18n("Normal")], ["lively", i18n("Lively")]]; onPicked: panel.orb.applyWallpaper() } }
                SettingRow { label: i18n("Pause when covered"); hint: i18n("No cost at all while a maximised or fullscreen window fills the screen.")
                    Toggle { key: "wallPause"; onPicked: panel.orb.applyWallpaper() } }
            }
        }
    }

    property Component topPage: Component {
        ColumnLayout {
            spacing: Kirigami.Units.gridUnit
            Group {
                title: i18n("Load")
                SettingRow { label: i18n("Look"); hint: i18n("How CPU, GPU, memory and temperature appear in the left pill.")
                    Segments { key: "statsStyle"; options: [["rings", i18n("Rings")], ["spark", i18n("Curves")], ["bars", i18n("Bars")], ["numbers", i18n("Numbers")]]
                               onPicked: panel.orb.setWidget("org.pillbox.stats", "style", panel.cfg.statsStyle) } }
                SettingRow { label: "CPU"; Toggle { key: "statsCpu"; onPicked: panel.orb.setWidget("org.pillbox.stats", "showCpu", panel.cfg.statsCpu) } }
                SettingRow { label: "GPU"; Toggle { key: "statsGpu"; onPicked: panel.orb.setWidget("org.pillbox.stats", "showGpu", panel.cfg.statsGpu) } }
                SettingRow { label: i18n("Memory"); Toggle { key: "statsRam"; onPicked: panel.orb.setWidget("org.pillbox.stats", "showRam", panel.cfg.statsRam) } }
                SettingRow { label: i18n("Temperature"); Toggle { key: "statsTemp"; onPicked: panel.orb.setWidget("org.pillbox.stats", "showTemp", panel.cfg.statsTemp) } }
            }
            Group {
                title: i18n("Coming next")
                SettingRow { label: i18n("Arrangements"); hint: i18n("Islands, one capsule, a rail at the screen edge, corners, or a halo around the orb.")
                    QQC2.Label { text: i18n("soon"); opacity: 0.6 } }
                SettingRow { label: i18n("Pillbox icons"); hint: i18n("An own icon set for the system tray: line or duotone.")
                    QQC2.Label { text: i18n("soon"); opacity: 0.6 } }
            }
        }
    }

    property Component behaviorPage: Component {
        ColumnLayout {
            spacing: Kirigami.Units.gridUnit
            Group {
                title: i18n("Windows")
                SettingRow { label: i18n("Hide in fullscreen"); hint: i18n("Games and videos get the whole screen.")
                    Toggle { key: "hideInFullscreen" } }
                SettingRow { label: i18n("Fade over windows"); hint: i18n("Faint while a window lies underneath, full again on hover.")
                    Toggle { key: "ghostOverWindows" } }
                SettingRow { visible: panel.isOrb; label: i18n("Satellites"); hint: i18n("Open windows orbit the ball.")
                    Toggle { key: "showSatellites" } }
            }
            Group {
                title: i18n("Orb")
                visible: panel.isOrb
                SettingRow { label: i18n("Lock position"); hint: i18n("The ball can no longer be dragged by accident.")
                    Toggle { key: "locked" } }
                SettingRow { label: i18n("Reset position"); hint: i18n("Back to the bottom centre of the main monitor.")
                    QQC2.Button { text: i18n("Reset"); icon.name: "edit-reset"; onClicked: { panel.cfg.orbX = -1; panel.cfg.orbY = -1 } } }
            }
        }
    }

    property Component alertsPage: Component {
        ColumnLayout {
            Group {
                title: i18n("Notifications")
                SettingRow { label: i18n("Unread counts"); hint: i18n("On the orb and on each app; clears when you look at the app.")
                    Toggle { key: "showBadges" } }
                SettingRow { label: i18n("Wave of light"); hint: i18n("In the app's colour for each new notification. Never in Do Not Disturb or fullscreen.")
                    Toggle { key: "notificationRipple" } }
            }
        }
    }

    property Component aboutPage: Component {
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            QQC2.Label { text: i18n("A calm, modern desktop for KDE Plasma 6 – only official Plasma interfaces, nothing compiled, measured to cost next to nothing."); wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Group {
                title: i18n("Project")
                SettingRow { label: i18n("Source code and issues"); hint: "github.com/Panto92/Pillbox"
                    QQC2.Button { text: i18n("Open"); icon.name: "internet-web-browser"; onClicked: Qt.openUrlExternally("https://github.com/Panto92/Pillbox") } }
                SettingRow { label: i18n("Licence"); hint: "MIT"; Item { width: 1; height: 1 } }
            }
        }
    }

    // tiny painted previews of the atmospheres
    component WallArt: Item {
        property string scene
        clip: true
        Rectangle {
            anchors.fill: parent; radius: Kirigami.Units.gridUnit * 0.5
            gradient: Gradient {
                GradientStop { position: 0; color: scene === "flow" ? "#2a2147" : scene === "horizon" ? "#5c5a7a" : scene === "fogline" ? "#4c5f72" : "#262b31" }
                GradientStop { position: 1; color: scene === "flow" ? "#0e1220" : scene === "horizon" ? "#c79a86" : scene === "fogline" ? "#a7b6c0" : "#14181c" }
            }
        }
        Repeater {
            model: scene === "flow" ? 3 : 0
            Rectangle { required property int index; x: parent.width * [0.05, 0.45, 0.25][index]; y: parent.height * [0.1, 0.25, 0.45][index]; width: parent.width * 0.55; height: width; radius: width / 2
                color: ["#e8789a", "#5aa7d8", "#9a6ad8"][index]; opacity: 0.35 }
        }
        Rectangle { visible: scene === "horizon"; x: parent.width * 0.62; y: parent.height * 0.22; width: parent.height * 0.18; height: width; radius: width / 2; color: "#ffe6cc" }
        Repeater {
            model: scene === "horizon" ? 3 : 0
            Rectangle { required property int index; anchors.bottom: parent.bottom; width: parent.width; height: parent.height * [0.42, 0.3, 0.17][index]; radius: height
                color: ["#4a4560", "#2f2c40", "#1b1a26"][index] }
        }
        Shape {
            visible: scene === "fogline"; anchors.fill: parent
            ShapePath { strokeColor: "transparent"; fillColor: "#1c2630"
                PathPolyline { path: [Qt.point(0, 0.62 * height), Qt.point(0.2 * width, 0.4 * height), Qt.point(0.38 * width, 0.55 * height), Qt.point(0.6 * width, 0.32 * height), Qt.point(0.8 * width, 0.5 * height), Qt.point(width, 0.42 * height), Qt.point(width, 0.68 * height), Qt.point(0, 0.68 * height)] } }
        }
        Rectangle { visible: scene === "fogline"; y: parent.height * 0.6; width: parent.width; height: parent.height * 0.14; color: Qt.rgba(1, 1, 1, 0.18) }
        Kirigami.Icon { visible: scene === "keep"; anchors.centerIn: parent; source: "preferences-desktop-wallpaper"; width: parent.height * 0.4; height: width; opacity: 0.6 }
    }
}
