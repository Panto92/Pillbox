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

        // live preview
        Rectangle {
            Kirigami.FormData.label: i18n("Preview:")
            implicitWidth: Kirigami.Units.gridUnit * 12
            implicitHeight: Kirigami.Units.gridUnit * 8
            radius: Kirigami.Units.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0; color: "#3a4752" }
                GradientStop { position: 1; color: "#12171c" }
            }
            OrbBall {
                anchors.centerIn: parent
                ballSize: Math.round(30 * sizeSlider.value / 100)
                accent: page.previewColor
                effect: page.cfg_effect
                speed: speedSlider.value
                hot: previewHover.hovered
                HoverHandler { id: previewHover }
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
