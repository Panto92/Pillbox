/*
 * One app in a dock form: a glowing dot at rest, an icon tile when unfolded.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: slot

    property var orb
    property bool expanded: false
    property int tile: 52
    property real delay: 0
    property var iconSource
    property int windows: 0
    property bool pinned: true
    property bool active: false
    property bool minimized: false
    property int badge: 0
    readonly property bool hovered: hover.hovered
    property real angle: -Math.PI / 2                  // direction previews open in
    property real counterTurn: 0                       // keeps the icon upright on side docks
    signal clicked(var mouse)

    // launching: a soft bounce + glow until the first window appears (max 6 s)
    property bool launching: false
    property real bounceY: 0
    onWindowsChanged: if (windows > 0) launching = false
    Timer { running: slot.launching; interval: 6000; onTriggered: slot.launching = false }
    SequentialAnimation on bounceY {
        running: slot.launching
        loops: Animation.Infinite
        NumberAnimation { to: -slot.tile * 0.3; duration: 230; easing.type: Easing.OutQuad }
        NumberAnimation { to: 0; duration: 430; easing.type: Easing.OutBounce }
        PauseAnimation { duration: 220 }
        onRunningChanged: if (!running) slot.bounceY = 0
    }

    width: tile; height: tile

    Behavior on x { SequentialAnimation { PauseAnimation { duration: slot.expanded ? slot.delay : 0 } NumberAnimation { duration: 380; easing.type: Easing.OutBack } } }
    Behavior on y { SequentialAnimation { PauseAnimation { duration: slot.expanded ? slot.delay : 0 } NumberAnimation { duration: 380; easing.type: Easing.OutBack } } }

    // icon colour, like the ring
    Kirigami.ImageColors { id: iconColors; source: slot.iconSource }
    onIconSourceChanged: iconColors.update()
    Component.onCompleted: iconColors.update()
    readonly property color tint: {
        const c = iconColors.dominant
        if (!slot.orb.cfg.appColors || c.a === 0 || c.hslSaturation < 0.2) return slot.orb.accent
        return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55), Math.min(Math.max(c.hslLightness, 0.55), 0.7), 1)
    }
    readonly property bool running: windows > 0

    // at rest: an ember on the seam
    Rectangle {
        anchors.centerIn: parent
        width: slot.running ? 8 : 6; height: width; radius: width / 2
        color: slot.running ? slot.tint : Qt.rgba(1, 1, 1, 0.35)
        opacity: slot.expanded ? 0 : (slot.minimized ? 0.5 : 1)
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // unfolded: tile + icon + window dots
    Item {
        anchors.fill: parent
        opacity: slot.expanded ? 1 : 0
        scale: slot.expanded ? (hover.hovered ? 1.12 : 1) : 0.2
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: slot.expanded ? slot.delay : 0 } NumberAnimation { duration: 260 } } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: slot.tile * 0.28
            color: slot.active ? Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, 0.32)
                 : hover.hovered ? Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, 0.2)
                 : Qt.rgba(1, 1, 1, 0.04)
            border.width: slot.running ? 1.5 : 0
            border.color: Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, slot.active ? 0.95 : 0.6)
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: slot.bounceY
            rotation: slot.counterTurn
            width: Math.round(slot.tile * 0.66); height: width
            source: slot.iconSource
            opacity: slot.running || slot.pinned ? 1 : 0.85
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -7
            spacing: 3
            Repeater {
                model: Math.min(slot.windows, 3)
                Rectangle {
                    width: slot.active ? 12 : 5; height: 4; radius: 2
                    color: slot.minimized ? "transparent" : slot.tint
                    border.width: slot.minimized ? 1 : 0; border.color: "#e6ecf0"
                }
            }
        }
        Rectangle {
            visible: slot.badge > 0
            anchors { right: parent.right; top: parent.top; rightMargin: -5; topMargin: -5 }
            height: 18; width: Math.max(height, badgeText.implicitWidth + 8); radius: height / 2
            color: slot.tint; border.width: 1.5; border.color: "#0d1013"
            Text { id: badgeText; anchors.centerIn: parent; text: slot.badge > 99 ? "99+" : slot.badge; color: "#0d1013"; font.bold: true; font.pixelSize: 11 }
        }
    }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        enabled: slot.expanded
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => slot.clicked(mouse)
    }
}
