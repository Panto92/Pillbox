/*
 * The card under the clock pill that shows the running activity in full, while the
 * pointer rests on the pill or on the card itself.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmaCore.Dialog {
    id: card
    property var live
    property string kind
    property Item anchorItem
    property bool wanted: false          // the pill is hovered
    property bool hovered: false
    readonly property bool show: wanted || hovered

    type: PlasmaCore.Dialog.Notification
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false
    visible: false

    readonly property int cardW: Kirigami.Units.gridUnit * 19
    function place() {
        if (!anchorItem) return
        const w = anchorItem.Window.window
        if (!w) return
        x = Math.round(w.x + w.width / 2 - cardW / 2)
        y = Math.round(w.y + w.height + Kirigami.Units.smallSpacing)
    }
    // open at once, close a moment later so the pointer can travel from the pill to the card
    onShowChanged: { if (show && kind) { place(); visible = true; shape.out = true; hideTimer.stop() } else hideTimer.restart() }
    onKindChanged: if (!kind) { shape.out = false; visible = false }
    property Timer hideTimer: Timer { interval: 350; onTriggered: if (!card.show) { shape.out = false; closeTimer.restart() } }
    property Timer closeTimer: Timer { interval: 220; onTriggered: if (!card.show) card.visible = false }

    mainItem: Item {
        width: card.cardW
        height: body.implicitHeight + Kirigami.Units.largeSpacing * 2.4
        HoverHandler { onHoveredChanged: card.hovered = hovered }
        Rectangle {
            id: shape
            property bool out: false
            anchors.fill: parent
            radius: Kirigami.Units.gridUnit * 1.2
            color: Qt.rgba(0.063, 0.078, 0.102, 0.95)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.09)
            opacity: out ? 1 : 0
            scale: out ? 1 : 0.94
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            LiveFace {
                id: body
                live: card.live
                kind: card.kind
                mode: "big"
                x: Kirigami.Units.largeSpacing * 1.2
                y: Kirigami.Units.largeSpacing * 1.2
                width: parent.width - Kirigami.Units.largeSpacing * 2.4
            }
        }
    }
}
