/*
 * Pillbox settings panel – opens on the desktop, every change applies live,
 * so the real orb/dock is the preview. Shows only the options of the chosen form.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

PlasmaCore.Dialog {
    id: panel

    property var orb                      // root item: cfg + accent + homeScreen()
    property bool open: false
    signal closeRequested()

    readonly property var cfg: orb.cfg
    readonly property bool isOrb: cfg.form === "orb"
    readonly property rect screen: orb.homeScreen()
    readonly property int panelW: Kirigami.Units.gridUnit * 27

    type: PlasmaCore.Dialog.PopupMenu
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: false          // stays open while you watch the changes
    title: "Pillbox Settings"
    visible: open
    x: screen.x + Math.round((screen.width - panelW) / 2)
    y: screen.y + Math.round(screen.height * 0.18)
    onVisibleChanged: if (visible) requestActivate()

    readonly property var presets: [
        { name: i18n("Fog"), color: "#8fb0c2" }, { name: i18n("Gold"), color: "#e0bd6e" },
        { name: i18n("Ember"), color: "#ff8a4c" }, { name: i18n("Rose"), color: "#e88fa6" },
        { name: i18n("Violet"), color: "#b49cf0" }, { name: i18n("Ice"), color: "#7fd3f0" },
        { name: i18n("Mint"), color: "#7fdcb0" }, { name: i18n("White"), color: "#eef2f5" }
    ]
    readonly property var forms: [
        { value: "orb",   name: i18n("Orb"),    hint: i18n("floating ball"),        icon: "media-record" },
        { value: "ember", name: i18n("Ember"),  hint: i18n("seam that unfolds"),    icon: "view-more-horizontal-symbolic" },
        { value: "shelf", name: i18n("Shelf"),  hint: i18n("glass ledge"),          icon: "view-app-grid-symbolic" },
        { value: "liquid", name: i18n("Liquid"), hint: i18n("coming soon"),         icon: "color-picker-white", soon: true }
    ]

    mainItem: Item {
        width: panel.panelW
        height: Math.min(content.implicitHeight + Kirigami.Units.gridUnit * 2, panel.screen.height * 0.7)
        focus: true
        Keys.onEscapePressed: panel.closeRequested()

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.gridUnit
            color: Qt.rgba(0.05, 0.06, 0.08, 0.95)
            border.width: 1
            border.color: Qt.rgba(panel.orb.accent.r, panel.orb.accent.g, panel.orb.accent.b, 0.35)
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Kirigami.Heading { level: 3; text: i18n("Customize Pillbox"); Layout.fillWidth: true }
                QQC2.ToolButton { icon.name: "window-close"; display: QQC2.AbstractButton.IconOnly; text: i18n("Close"); onClicked: panel.closeRequested() }
            }
            QQC2.TabBar {
                id: tabs
                Layout.fillWidth: true
                QQC2.TabButton { text: i18n("Form") }
                QQC2.TabButton { text: i18n("Color") }
                QQC2.TabButton { text: i18n("Behavior") }
                QQC2.TabButton { text: i18n("Alerts") }
            }

            StackLayout {
                currentIndex: tabs.currentIndex
                Layout.fillWidth: true

                // ------------------------------------------------ form
                ColumnLayout {
                    spacing: Kirigami.Units.largeSpacing
                    GridLayout {
                        columns: 4
                        columnSpacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true
                        Repeater {
                            model: panel.forms
                            delegate: QQC2.AbstractButton {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: Kirigami.Units.gridUnit * 4.6
                                enabled: !modelData.soon
                                readonly property bool chosen: panel.cfg.form === modelData.value
                                onClicked: panel.cfg.form = modelData.value
                                background: Rectangle {
                                    radius: Kirigami.Units.gridUnit * 0.6
                                    color: parent.chosen ? Qt.rgba(panel.orb.accent.r, panel.orb.accent.g, panel.orb.accent.b, 0.22)
                                         : parent.hovered ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: parent.chosen ? 1.5 : 1
                                    border.color: parent.chosen ? panel.orb.accent : Qt.rgba(1, 1, 1, 0.1)
                                }
                                contentItem: ColumnLayout {
                                    spacing: 2
                                    opacity: parent.enabled ? 1 : 0.45
                                    Kirigami.Icon { source: modelData.icon; Layout.alignment: Qt.AlignHCenter; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth; color: panel.orb.accent; isMask: true }
                                    QQC2.Label { text: modelData.name; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                                    QQC2.Label { text: modelData.hint; font: Kirigami.Theme.smallFont; opacity: 0.7; Layout.alignment: Qt.AlignHCenter }
                                }
                            }
                        }
                    }

                    Kirigami.FormLayout {
                        Layout.fillWidth: true
                        // ---- orb
                        SliderRow { visible: panel.isOrb; label: i18n("Ball size:"); key: "ballScale"; from: 60; to: 200; step: 5; unit: "%" }
                        QQC2.ComboBox {
                            visible: panel.isOrb
                            Kirigami.FormData.label: i18n("Effect:")
                            textRole: "text"; valueRole: "value"
                            model: [
                                { text: i18n("Aura – rotating ring of light"), value: "aura" },
                                { text: i18n("Pulse – strong breathing"), value: "pulse" },
                                { text: i18n("Calm – still ring of light"), value: "calm" },
                                { text: i18n("Plain – just the ball"), value: "plain" }
                            ]
                            currentIndex: Math.max(0, indexOfValue(panel.cfg.effect))
                            onActivated: panel.cfg.effect = currentValue
                        }
                        SliderRow { visible: panel.isOrb; label: i18n("Speed:"); key: "effectSpeed"; from: 25; to: 300; step: 25; unit: "%" }
                        SliderRow { visible: panel.isOrb; label: i18n("Ring size:"); key: "ringScale"; from: 60; to: 150; step: 5; unit: "%" }
                        // ---- docks
                        QQC2.ComboBox {
                            visible: !panel.isOrb
                            Kirigami.FormData.label: i18n("Position:")
                            textRole: "text"; valueRole: "value"
                            model: [
                                { text: i18n("Bottom"), value: "bottom" },
                                { text: i18n("Left"), value: "left" },
                                { text: i18n("Right"), value: "right" }
                            ]
                            currentIndex: Math.max(0, indexOfValue(panel.cfg.dockEdge))
                            onActivated: panel.cfg.dockEdge = currentValue
                        }
                        QQC2.ComboBox {
                            visible: !panel.isOrb
                            Kirigami.FormData.label: i18n("Monitor:")
                            textRole: "text"; valueRole: "value"
                            model: [{ text: i18n("Main monitor"), value: "primary" }, { text: i18n("All monitors"), value: "all" }]
                                   .concat(Qt.application.screens.map(sc => ({ text: sc.name + "  (" + sc.width + "×" + sc.height + ")", value: sc.name })))
                            currentIndex: Math.max(0, indexOfValue(panel.cfg.dockScreen))
                            onActivated: panel.cfg.dockScreen = currentValue
                        }
                        SliderRow { visible: !panel.isOrb; label: i18n("Dock size:"); key: "dockScale"; from: 60; to: 160; step: 5; unit: "%" }
                        QQC2.ComboBox {
                            visible: !panel.isOrb
                            Kirigami.FormData.label: i18n("Dock at rest:")
                            textRole: "text"; valueRole: "value"
                            model: [
                                { text: i18n("Always visible"), value: "never" },
                                { text: i18n("Small until the pointer comes"), value: "compact" },
                                { text: i18n("Hidden – a thin line stays at the edge"), value: "autohide" }
                            ]
                            currentIndex: Math.max(0, indexOfValue(panel.cfg.dockHide))
                            onActivated: panel.cfg.dockHide = currentValue
                        }
                        QQC2.CheckBox {
                            visible: panel.cfg.form === "shelf"
                            text: i18n("Reflection on hover")
                            checked: panel.cfg.shelfReflection
                            onToggled: panel.cfg.shelfReflection = checked
                        }
                        // ---- both
                        SliderRow { label: i18n("Icon size:"); key: "ringIconSize"; from: 44; to: 80; step: 4; unit: "px" }
                    }
                }

                // ------------------------------------------------ colour
                Kirigami.FormLayout {
                    QQC2.RadioButton {
                        Kirigami.FormData.label: i18n("Color:")
                        text: i18n("Custom color")
                        checked: panel.cfg.colorMode !== "system"
                        onToggled: if (checked) panel.cfg.colorMode = "custom"
                    }
                    Flow {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                        spacing: Kirigami.Units.smallSpacing
                        enabled: panel.cfg.colorMode !== "system"
                        opacity: enabled ? 1 : 0.4
                        Repeater {
                            model: panel.presets
                            delegate: QQC2.AbstractButton {
                                required property var modelData
                                width: Kirigami.Units.gridUnit * 1.7; height: width
                                QQC2.ToolTip.text: modelData.name; QQC2.ToolTip.visible: hovered; QQC2.ToolTip.delay: 400
                                onClicked: panel.cfg.customColor = modelData.color
                                contentItem: Rectangle {
                                    radius: width / 2; color: modelData.color
                                    border.width: Qt.colorEqual(panel.cfg.customColor, modelData.color) ? 3 : 1
                                    border.color: Qt.colorEqual(panel.cfg.customColor, modelData.color) ? Kirigami.Theme.textColor : Qt.rgba(0, 0, 0, 0.3)
                                }
                            }
                        }
                        KQuickControls.ColorButton {
                            height: Kirigami.Units.gridUnit * 1.7
                            color: panel.cfg.customColor
                            showAlphaChannel: false
                            dialogTitle: i18n("Orb color")
                            onAccepted: c => panel.cfg.customColor = c
                        }
                    }
                    QQC2.RadioButton {
                        text: i18n("Color scheme accent")
                        checked: panel.cfg.colorMode === "system"
                        onToggled: if (checked) panel.cfg.colorMode = "system"
                    }
                    QQC2.CheckBox {
                        text: i18n("Apps glow in their own icon color")
                        checked: panel.cfg.appColors
                        onToggled: panel.cfg.appColors = checked
                    }
                }

                // ------------------------------------------------ behaviour
                Kirigami.FormLayout {
                    QQC2.CheckBox {
                        Kirigami.FormData.label: i18n("Windows:")
                        text: i18n("Hide while a fullscreen app is in front (games, video)")
                        checked: panel.cfg.hideInFullscreen; onToggled: panel.cfg.hideInFullscreen = checked
                    }
                    QQC2.CheckBox {
                        text: i18n("Fade out over windows, full again on hover")
                        checked: panel.cfg.ghostOverWindows; onToggled: panel.cfg.ghostOverWindows = checked
                    }
                    QQC2.CheckBox {
                        visible: panel.isOrb
                        text: i18n("Show open windows as satellites")
                        checked: panel.cfg.showSatellites; onToggled: panel.cfg.showSatellites = checked
                    }
                    QQC2.CheckBox {
                        visible: panel.isOrb
                        Kirigami.FormData.label: i18n("Orb:")
                        text: i18n("Lock position")
                        checked: panel.cfg.locked; onToggled: panel.cfg.locked = checked
                    }
                    QQC2.Button {
                        visible: panel.isOrb
                        text: i18n("Reset position")
                        icon.name: "edit-reset"
                        onClicked: { panel.cfg.orbX = -1; panel.cfg.orbY = -1 }
                    }
                }

                // ------------------------------------------------ alerts
                Kirigami.FormLayout {
                    QQC2.CheckBox {
                        Kirigami.FormData.label: i18n("Notifications:")
                        text: i18n("Show unread counts on the orb and in the ring")
                        checked: panel.cfg.showBadges; onToggled: panel.cfg.showBadges = checked
                    }
                    QQC2.CheckBox {
                        text: i18n("Wave of light for new notifications (not in Do Not Disturb)")
                        checked: panel.cfg.notificationRipple; onToggled: panel.cfg.notificationRipple = checked
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Changes apply right away.")
                font: Kirigami.Theme.smallFont
                opacity: 0.55
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // a labelled slider bound straight to one config key
    component SliderRow: RowLayout {
        property string label
        property string key
        property alias from: slider.from
        property alias to: slider.to
        property alias step: slider.stepSize
        property string unit
        Kirigami.FormData.label: label
        QQC2.Slider {
            id: slider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 11
            value: panel.cfg[parent.key]
            onMoved: panel.cfg[parent.key] = value
        }
        QQC2.Label { text: slider.value + " " + parent.unit; Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5 }
    }
}
