/*
 * Orb settings: size, colour, effect – with a live preview.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: page

    property alias cfg_ballScale: sizeSlider.value
    property string cfg_colorMode
    property color cfg_customColor
    property string cfg_effect
    property string cfg_form
    property string cfg_dockHide
    property string cfg_dockHideDefault
    property string cfg_formDefault
    property alias cfg_effectSpeed: speedSlider.value
    property alias cfg_showSatellites: satBox.checked
    property alias cfg_ringIconSize: iconSlider.value
    property alias cfg_ringScale: ringScaleSlider.value
    property alias cfg_appColors: appColorBox.checked
    property alias cfg_hideInFullscreen: fullscreenBox.checked
    property alias cfg_ghostOverWindows: ghostBox.checked
    property alias cfg_showBadges: badgeBox.checked
    property alias cfg_notificationRipple: rippleBox.checked
    property string cfg_notificationsSeen
    property alias cfg_locked: lockBox.checked
    property int cfg_orbX
    property int cfg_orbY
    property var cfg_launchers           // edited from the ring, kept here so the dialog keeps it
    property var cfg_launchersDefault

    // defaults the dialog's "Defaults" button needs to know about
    property int cfg_ballScaleDefault
    property string cfg_colorModeDefault
    property color cfg_customColorDefault
    property string cfg_effectDefault
    property int cfg_effectSpeedDefault
    property bool cfg_showSatellitesDefault
    property int cfg_ringIconSizeDefault
    property int cfg_ringScaleDefault
    property bool cfg_appColorsDefault
    property bool cfg_hideInFullscreenDefault
    property bool cfg_ghostOverWindowsDefault
    property bool cfg_showBadgesDefault
    property bool cfg_notificationRippleDefault
    property string cfg_notificationsSeenDefault
    property bool cfg_lockedDefault
    property int cfg_orbXDefault
    property int cfg_orbYDefault

    readonly property var presets: [
        { name: i18n("Fog"),   color: "#8fb0c2" },
        { name: i18n("Gold"),    color: "#e0bd6e" },
        { name: i18n("Ember"),    color: "#ff8a4c" },
        { name: i18n("Rose"),    color: "#e88fa6" },
        { name: i18n("Violet"), color: "#b49cf0" },
        { name: i18n("Ice"),     color: "#7fd3f0" },
        { name: i18n("Mint"),    color: "#7fdcb0" },
        { name: i18n("White"),    color: "#eef2f5" }
    ]
    readonly property color previewColor: cfg_colorMode === "system" ? Kirigami.Theme.highlightColor : cfg_customColor

    Kirigami.FormLayout {

        QQC2.ComboBox {
            id: formBox
            Kirigami.FormData.label: i18n("Form:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Orb – floating ball you can place anywhere"), value: "orb" },
                { text: i18n("Ember – glowing seam that unfolds into a dock"), value: "ember" },
                { text: i18n("Shelf – icons on a glass ledge that tilt towards you"), value: "shelf" },
                { text: i18n("Liquid – a dock of liquid glass with a drop that follows you"), value: "liquid" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_form))
            onActivated: page.cfg_form = currentValue
        }

        QQC2.ComboBox {
            id: hideBox
            Kirigami.FormData.label: i18n("Dock at rest:")
            enabled: page.cfg_form !== "orb"
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Always visible"), value: "never" },
                { text: i18n("Small until the pointer comes"), value: "compact" },
                { text: i18n("Hidden – a thin line stays at the edge"), value: "autohide" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_dockHide))
            onActivated: page.cfg_dockHide = currentValue
        }

        Item { Kirigami.FormData.isSection: true }

        // live preview of the chosen form
        Rectangle {
            id: previewBox
            Kirigami.FormData.label: i18n("Preview:")
            implicitWidth: Kirigami.Units.gridUnit * (page.cfg_form === "orb" ? 12 : 20)
            implicitHeight: Kirigami.Units.gridUnit * 8
            radius: Kirigami.Units.cornerRadius
            clip: true
            gradient: Gradient {
                GradientStop { position: 0; color: "#3a4752" }
                GradientStop { position: 1; color: "#12171c" }
            }
            HoverHandler { id: previewHover }
            readonly property bool hot: previewHover.hovered
            readonly property var sampleIcons: ["utilities-terminal", "system-file-manager", "internet-web-browser", "applications-graphics", "preferences-system"]
            readonly property int tile: Math.round(iconSlider.value * 0.55)

            OrbBall {
                visible: page.cfg_form === "orb"
                anchors.centerIn: parent
                ballSize: Math.round(30 * sizeSlider.value / 100)
                accent: page.previewColor
                effect: page.cfg_effect
                speed: speedSlider.value
                hot: previewBox.hot
            }

            // Ember: a seam of embers that unfolds on hover
            Item {
                visible: page.cfg_form === "ember"
                anchors.fill: parent
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: Kirigami.Units.gridUnit
                    width: previewBox.hot ? previewBox.sampleIcons.length * (previewBox.tile + 8) + 24 : previewBox.sampleIcons.length * 12 + 26
                    height: previewBox.hot ? previewBox.tile + 16 : 14
                    radius: height / 2
                    color: Qt.rgba(0.05, 0.06, 0.08, 0.8)
                    border.color: Qt.rgba(page.previewColor.r, page.previewColor.g, page.previewColor.b, 0.3)
                    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                    Row {
                        anchors.centerIn: parent
                        spacing: previewBox.hot ? 8 : 6
                        Repeater {
                            model: previewBox.sampleIcons
                            Item {
                                required property string modelData
                                required property int index
                                width: previewBox.hot ? previewBox.tile : 6; height: width
                                Behavior on width { SequentialAnimation { PauseAnimation { duration: previewBox.hot ? Math.abs(index - 2) * 30 : 0 } NumberAnimation { duration: 320; easing.type: Easing.OutBack } } }
                                Rectangle { anchors.fill: parent; radius: width / 2; color: index < 3 ? page.previewColor : Qt.rgba(1, 1, 1, 0.35); visible: !previewBox.hot }
                                Kirigami.Icon { anchors.fill: parent; source: parent.modelData; visible: previewBox.hot }
                            }
                        }
                    }
                }
            }

            // Shelf: icons on a glass ledge; the hovered one lifts and reflects
            Item {
                visible: page.cfg_form === "shelf"
                anchors.fill: parent
                readonly property real baseY: height - Kirigami.Units.gridUnit * 1.6
                Rectangle {
                    x: parent.width * 0.08; width: parent.width * 0.84; y: parent.baseY; height: Kirigami.Units.gridUnit * 0.9
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0.9, 0.93, 0.95, 0.22) }
                        GradientStop { position: 1; color: Qt.rgba(0.05, 0.06, 0.08, 0.55) }
                    }
                    Rectangle { width: parent.width; height: 1.5; color: Qt.rgba(1, 1, 1, 0.5) }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.baseY - previewBox.tile
                    spacing: Math.round(previewBox.tile * 0.35)
                    Repeater {
                        model: previewBox.sampleIcons
                        Item {
                            required property string modelData
                            required property int index
                            width: previewBox.tile; height: width
                            readonly property bool up: shelfHover.hovered
                            HoverHandler { id: shelfHover }
                            Kirigami.Icon {
                                id: shelfIcon
                                width: parent.width; height: width
                                y: parent.up ? -previewBox.tile * 0.28 : 0
                                source: parent.modelData
                                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            }
                            Kirigami.Icon {
                                width: parent.width; height: width
                                y: parent.height + 2 + (parent.up ? previewBox.tile * 0.28 : 0)
                                source: parent.modelData
                                opacity: parent.up ? 0.3 : 0
                                transform: Scale { yScale: -0.5 }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                    }
                }
            }

            QQC2.Label {
                anchors { right: parent.right; bottom: parent.bottom; margins: Kirigami.Units.smallSpacing }
                visible: page.cfg_form !== "orb" && !previewBox.hot
                text: i18n("hover me")
                opacity: 0.5
                font: Kirigami.Theme.smallFont
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Size:")
            QQC2.Slider {
                id: sizeSlider
                from: 60; to: 200; stepSize: 5
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }
            QQC2.Label { text: i18n("%1 %", sizeSlider.value) }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.RadioButton {
            Kirigami.FormData.label: i18n("Color:")
            text: i18n("Custom color")
            checked: page.cfg_colorMode !== "system"
            onToggled: if (checked) page.cfg_colorMode = "custom"
        }
        Flow {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            spacing: Kirigami.Units.smallSpacing
            enabled: page.cfg_colorMode !== "system"
            opacity: enabled ? 1 : 0.4
            Repeater {
                model: page.presets
                delegate: QQC2.AbstractButton {
                    required property var modelData
                    width: Kirigami.Units.gridUnit * 1.8; height: width
                    QQC2.ToolTip.text: modelData.name
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: 400
                    Accessible.name: modelData.name
                    onClicked: page.cfg_customColor = modelData.color
                    contentItem: Rectangle {
                        radius: width / 2
                        color: modelData.color
                        border.width: Qt.colorEqual(page.cfg_customColor, modelData.color) ? 3 : 1
                        border.color: Qt.colorEqual(page.cfg_customColor, modelData.color) ? Kirigami.Theme.textColor : Qt.rgba(0, 0, 0, 0.3)
                    }
                }
            }
            KQuickControls.ColorButton {
                height: Kirigami.Units.gridUnit * 1.8
                color: page.cfg_customColor
                showAlphaChannel: false
                dialogTitle: i18n("Orb color")
                onAccepted: c => page.cfg_customColor = c
                QQC2.ToolTip.text: i18n("Pick any color")
                QQC2.ToolTip.visible: hovered
            }
        }
        QQC2.RadioButton {
            text: i18n("Color scheme accent")
            checked: page.cfg_colorMode === "system"
            onToggled: if (checked) page.cfg_colorMode = "system"
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: effectBox
            Kirigami.FormData.label: i18n("Effect:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Aura – rotating ring of light"), value: "aura" },
                { text: i18n("Pulse – strong breathing"), value: "pulse" },
                { text: i18n("Calm – still ring of light"), value: "calm" },
                { text: i18n("Plain – just the ball"), value: "plain" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_effect))
            onActivated: page.cfg_effect = currentValue
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Speed:")
            enabled: page.cfg_effect === "aura" || page.cfg_effect === "pulse"
            QQC2.Label { text: i18n("slow") }
            QQC2.Slider { id: speedSlider; from: 25; to: 300; stepSize: 25; Layout.preferredWidth: Kirigami.Units.gridUnit * 9 }
            QQC2.Label { text: i18n("fast") }
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: i18n("Ring size:")
            QQC2.Slider { id: ringScaleSlider; from: 60; to: 150; stepSize: 5; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
            QQC2.Label { text: i18n("%1 %", ringScaleSlider.value) }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Ring:")
            QQC2.Label { text: i18n("Icon size") }
            QQC2.Slider { id: iconSlider; from: 44; to: 80; stepSize: 4; Layout.preferredWidth: Kirigami.Units.gridUnit * 9 }
            QQC2.Label { text: i18n("%1 px", iconSlider.value) }
        }
        QQC2.CheckBox {
            id: appColorBox
            text: i18n("Apps glow in their own icon color")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: satBox
            Kirigami.FormData.label: i18n("Behavior:")
            text: i18n("Show open windows as satellites")
        }
        QQC2.CheckBox {
            id: fullscreenBox
            text: i18n("Hide while a fullscreen app is in front (games, video)")
        }
        QQC2.CheckBox {
            id: ghostBox
            text: i18n("Fade out over windows, full again on hover")
        }
        QQC2.CheckBox {
            id: badgeBox
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Show unread counts on the orb and in the ring")
        }
        QQC2.CheckBox {
            id: rippleBox
            text: i18n("Wave of light for new notifications (not in Do Not Disturb)")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: lockBox
            text: i18n("Lock position")
        }
        QQC2.Button {
            text: i18n("Reset position")
            icon.name: "edit-reset"
            onClicked: { page.cfg_orbX = -1; page.cfg_orbY = -1 }
        }
    }
}
