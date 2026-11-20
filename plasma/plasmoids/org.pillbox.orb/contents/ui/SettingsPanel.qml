/*
 * Pillbox settings centre – a glass window with a sidebar. Every change applies
 * live; the real orb, dock and wallpaper are the preview.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

PlasmaCore.Dialog {
    id: panel

    property var orb
    property bool open: false
    signal closeRequested()

    readonly property var cfg: orb.cfg
    readonly property bool isOrb: cfg.form === "orb"
    readonly property color accent: orb.accent
    readonly property rect screen: orb.homeScreen()
    readonly property int winW: Math.min(Kirigami.Units.gridUnit * 50, screen.width - Kirigami.Units.gridUnit * 4)
    readonly property int winH: Math.min(Kirigami.Units.gridUnit * 34, screen.height - Kirigami.Units.gridUnit * 6)
    property string page: "form"

    type: PlasmaCore.Dialog.PopupMenu
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: false
    title: "Pillbox Settings"
    visible: open
    x: screen.x + Math.round((screen.width - winW) / 2)
    y: screen.y + Math.round((screen.height - winH) / 2)
    onVisibleChanged: if (visible) requestActivate()

    readonly property var pages: [
        { id: "form",       name: i18n("Form"),        icon: "view-app-grid-symbolic" },
        { id: "color",      name: i18n("Color"),       icon: "color-management" },
        { id: "wallpaper",  name: i18n("Wallpaper"),   icon: "preferences-desktop-wallpaper" },
        { id: "topbar",     name: i18n("Top bar"),     icon: "view-split-top-bottom" },
        { id: "behavior",   name: i18n("Behavior"),    icon: "preferences-system-windows-behavior" },
        { id: "alerts",     name: i18n("Alerts"),      icon: "preferences-desktop-notification-bell" },
        { id: "about",      name: i18n("About"),       icon: "help-about" }
    ]
    readonly property var presets: ["#8fb0c2", "#e0bd6e", "#ff8a4c", "#e88fa6", "#b49cf0", "#7fd3f0", "#7fdcb0", "#eef2f5"]

    mainItem: Item {
        width: panel.winW
        height: panel.winH
        focus: true
        Keys.onEscapePressed: panel.closeRequested()

        Rectangle {                                  // glass
            anchors.fill: parent
            radius: Kirigami.Units.gridUnit
            color: Qt.rgba(0.06, 0.075, 0.095, 0.97)
            border.width: 1
            border.color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.3)
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
                                       : panel.page === "wallpaper" ? wallPage : panel.page === "topbar" ? topPage
                                       : panel.page === "behavior" ? behaviorPage : panel.page === "alerts" ? alertsPage : aboutPage
                    }
                }
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
    // segmented choice bound to one config key
    component Segments: Rectangle {
        property string key
        property var options: []             // [[value, label], ...]
        property var target: panel.cfg
        signal picked()
        implicitWidth: segRow.implicitWidth + 6
        implicitHeight: segRow.implicitHeight + 6
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.06)
        Row {
            id: segRow
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: options
                delegate: QQC2.AbstractButton {
                    required property var modelData
                    readonly property bool on: target[key] === modelData[0]
                    implicitWidth: lbl.implicitWidth + Kirigami.Units.gridUnit * 1.2
                    implicitHeight: lbl.implicitHeight + Kirigami.Units.smallSpacing * 2.5
                    onClicked: { target[key] = modelData[0]; picked() }
                    background: Rectangle { radius: height / 2; color: parent.on ? panel.accent : parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent" }
                    contentItem: QQC2.Label { id: lbl; text: modelData[1]; horizontalAlignment: Text.AlignHCenter; color: parent.on ? "#0b0e12" : Kirigami.Theme.textColor; font.weight: parent.on ? Font.DemiBold : Font.Normal }
                }
            }
        }
    }
    component Toggle: QQC2.Switch {
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
                    QQC2.Switch { checked: panel.cfg.colorMode === "system"; onToggled: panel.cfg.colorMode = checked ? "system" : "custom" } }
            }
            Group {
                title: i18n("Apps")
                SettingRow { label: i18n("Apps glow in their own icon color"); hint: i18n("Discord blue, Zen orange – in the ring and the docks.")
                    Toggle { key: "appColors" } }
            }
        }
    }

    property Component wallPage: Component {
        ColumnLayout {
            spacing: Kirigami.Units.gridUnit
            Group {
                title: i18n("Atmosphere")
                GridLayout {
                    columns: 4; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Repeater {
                        model: [
                            { v: "flow", n: "Flow", h: i18n("clouds of colour") },
                            { v: "horizon", n: "Horizon", h: i18n("flat hills, one sun") },
                            { v: "fogline", n: "Fogline", h: i18n("misty lake") },
                            { v: "keep", n: i18n("Own image"), h: i18n("Plasma's wallpaper") }
                        ]
                        delegate: QQC2.AbstractButton {
                            required property var modelData
                            readonly property bool chosen: panel.cfg.wallScene === modelData.v
                            Layout.fillWidth: true
                            implicitHeight: Kirigami.Units.gridUnit * 6.5
                            onClicked: { panel.cfg.wallScene = modelData.v; panel.orb.applyWallpaper() }
                            background: Rectangle {
                                radius: Kirigami.Units.gridUnit * 0.6; clip: true
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.width: parent.chosen ? 2 : 1
                                border.color: parent.chosen ? panel.accent : Qt.rgba(1, 1, 1, 0.08)
                                WallArt { anchors.fill: parent; anchors.margins: 2; scene: modelData.v }
                            }
                            contentItem: ColumnLayout {
                                Item { Layout.fillHeight: true }
                                QQC2.Label { text: modelData.n; font.weight: Font.DemiBold; color: "white"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
                                QQC2.Label { text: modelData.h; font: Kirigami.Theme.smallFont; color: Qt.rgba(1, 1, 1, 0.8); style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5) }
                            }
                        }
                    }
                }
            }
            Group {
                title: i18n("Behavior")
                enabled: panel.cfg.wallScene !== "keep"
                opacity: enabled ? 1 : 0.45
                SettingRow { label: i18n("Follows the time of day"); hint: i18n("Light, stars and colours move with the clock.")
                    Toggle { key: "wallFollow"; onPicked: panel.orb.applyWallpaper() } }
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
            Group {
                title: i18n("Coming next")
                SettingRow { label: i18n("Islands"); hint: i18n("The three pills will unfold into panels: graphs, calendar, a control centre. Choose what each pill shows here.")
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
