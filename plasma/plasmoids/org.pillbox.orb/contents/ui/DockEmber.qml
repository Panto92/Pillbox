/*
 * "Ember" form: at rest a thin seam of glowing dots at the bottom edge
 * (bright = running, dim = pinned). Hover it and the icons unfold from the
 * centre outwards. Shares all logic (apps, clicks, previews, badges) with the Orb.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmaCore.Dialog {
    id: dock

    property var orb                       // the Orb root item (models + actions)
    property bool shown: true
    readonly property bool expanded: open
    readonly property int count: Math.min(orb.apps.count, 24)
    readonly property int tile: Math.round(orb.cfg.ringIconSize * orb.cfg.dockScale / 100 * 0.85)
    readonly property int gap: Math.round(tile * 0.22)
    readonly property int pad: Math.round(tile * 0.3)
    // the window is always big enough for the unfolded dock; only the seam is drawn at rest
    readonly property int fullW: (count + 1) * (tile + gap) - gap + pad * 2
    readonly property int fullH: tile + pad * 2 + 10
    property rect targetScreen: orb.homeScreen()             // the monitor this dock lives on
    readonly property rect screen: targetScreen

    // ---- edge: the dock is laid out as a bottom dock and turned to its edge as a whole;
    //      icons turn back so they always stand upright
    readonly property string edge: orb.cfg.dockEdge                     // bottom | left | right
    readonly property bool vertical: edge !== "bottom"
    readonly property real turn: edge === "left" ? 90 : edge === "right" ? -90 : 0
    readonly property real slotAngle: edge === "left" ? 0 : edge === "right" ? Math.PI : -Math.PI / 2   // previews open inwards
    readonly property int margin: 6

    // Plasma does not resize a dialog reliably when width and height swap roles at once
    // (edge change): rebuild the window for a moment so it always matches its edge
    property bool rebuilding: false
    property Timer rebuildTimer: Timer { interval: 60; onTriggered: dock.rebuilding = false }
    onEdgeChanged: { rebuilding = true; rebuildTimer.restart() }
    onTargetScreenChanged: { rebuilding = true; rebuildTimer.restart() }

    // ---- hiding: the window really shrinks at rest, so it never blocks clicks above it
    // Ember always folds to its seam; "autohide" also hides the seam behind a thin line
    readonly property string hideMode: orb.cfg.dockHide === "autohide" ? "autohide" : "compact"
    readonly property bool open: hoverAny || dock.holdOpen.running || orb.previewVisible
    property bool hoverAny: false
    property bool tall: true
    property Timer holdOpen: Timer { interval: 450 }
    property Timer shrinkLater: Timer { interval: 380; onTriggered: dock.tall = dock.open }
    onOpenChanged: { if (open) { shrinkLater.stop(); tall = true } else shrinkLater.restart() }
    onHideModeChanged: { tall = true; shrinkLater.restart() }
    readonly property int restH: hideMode === "autohide" ? 6 : 26
    readonly property int winH: tall ? fullH : restH

    type: PlasmaCore.Dialog.Notification
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false
    title: "Pillbox Dock"
    visible: shown && !rebuilding
    readonly property int gapToEdge: hideMode === "autohide" && !tall ? 0 : margin
    // positioned from the window's *actual* size, so it hugs its edge even while
    // Plasma is still catching up with a resize (never spills onto a neighbour monitor)
    x: edge === "left" ? screen.x + gapToEdge
     : edge === "right" ? screen.x + screen.width - width - gapToEdge
     : screen.x + Math.round((screen.width - width) / 2)
    y: vertical ? screen.y + Math.round((screen.height - height) / 2)
     : screen.y + screen.height - height - gapToEdge

    mainItem: Item {
        width: dock.vertical ? dock.winH : dock.fullW
        height: dock.vertical ? dock.fullW : dock.winH
    Item {
        id: frame
        anchors.centerIn: parent
        width: dock.fullW
        height: dock.winH
        rotation: dock.turn
        HoverHandler { onHoveredChanged: { dock.hoverAny = hovered; if (!hovered) dock.holdOpen.restart() } }

        Rectangle {                                   // "autohide": a thin line at the edge
            visible: dock.hideMode === "autohide"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 2
            width: Math.min(parent.width * 0.3, 160); height: 3; radius: 1.5
            color: dock.orb.accent
            opacity: dock.open ? 0 : 0.8
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }

    Item {
        id: stage
        width: dock.fullW
        height: dock.fullH
        anchors.bottom: parent.bottom
        opacity: !dock.open && dock.hideMode === "autohide" ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 260 } }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => dock.orb.openDockMenu(stage, mouse.x, mouse.y)
        }

        DropArea {
            anchors.fill: parent
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => { drop.urls.forEach(u => dock.orb.apps.requestAddLauncher(u)); drop.accept() }
        }

        // glass pill behind everything: a thin seam at rest, the full dock when unfolded
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: dock.expanded ? parent.width : dock.count * 14 + 34
            height: dock.expanded ? dock.tile + dock.pad * 2 : 16
            radius: height / 2
            color: Qt.rgba(0.05, 0.06, 0.08, dock.expanded ? 0.82 : 0.7)
            border.width: 1
            border.color: Qt.rgba(dock.orb.accent.r, dock.orb.accent.g, dock.orb.accent.b, dock.expanded ? 0.3 : 0.18)
            opacity: dock.orb.ghost && !dock.expanded ? 0.55 : 1
            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // "all applications" sits at the left end
        Item {
            id: allApps
            readonly property real cx: dock.expanded ? dock.pad + dock.tile / 2 : (parent.width - pill.width) / 2 + 12
            x: cx - width / 2
            y: dock.expanded ? parent.height - dock.pad - dock.tile : parent.height - 8 - height / 2
            width: dock.expanded ? dock.tile : 6; height: width
            Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; radius: width * 0.3; color: Qt.rgba(1, 1, 1, dock.expanded ? 0.06 : 0.25) }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width * 0.55; height: width
                source: "view-app-grid-symbolic"
                rotation: -dock.turn
                opacity: dock.expanded ? 0.85 : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }
            MouseArea { anchors.fill: parent; enabled: dock.expanded; onClicked: dock.orb.openLauncher() }
        }

        Repeater {
            model: dock.orb.apps
            delegate: DockSlot {
                id: dslot
                required property int index
                required property var model
                visible: index < dock.count
                orb: dock.orb
                expanded: dock.expanded
                tile: dock.tile
                // unfolded: in a row; at rest: a dot on the seam. Unfold staggered from the centre.
                readonly property real fullX: dock.pad + (index + 1) * (dock.tile + dock.gap)
                readonly property real seamX: (parent.width - pill.width) / 2 + 24 + index * 14
                x: dock.expanded ? fullX : seamX - tile / 2 + 3
                y: dock.expanded ? parent.height - dock.pad - dock.tile : parent.height - 8 - tile / 2
                delay: Math.abs(index - dock.count / 2) * 22
                iconSource: model.decoration
                angle: dock.slotAngle
                counterTurn: -dock.turn
                windows: model.IsLauncher ? 0 : (model.IsGroupParent ? model.ChildCount : 1)
                pinned: model.IsLauncher === true || model.HasLauncher === true
                active: model.IsActive === true
                minimized: model.IsMinimized === true
                badge: dock.orb.cfg.showBadges ? dock.orb.unreadFor(model.AppId) : 0
                onHoveredChanged: hovered ? dock.orb.slotHovered(dslot, index, model, windows) : dock.orb.slotLeft()
                onClicked: mouse => { dock.orb.slotLeft(); dock.orb.dockClicked(index, model, mouse, dslot) }
            }
        }
    }
    }
    }
}
