/*
 * "Shelf" form: icons stand on a glass ledge and reflect in it. The icon under
 * the pointer lifts and tilts towards it. Shares all logic with the Orb.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Effects
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmaCore.Dialog {
    id: dock

    property var orb
    property bool shown: true
    readonly property int count: Math.min(orb.apps.count, 24)
    readonly property int tile: Math.round(orb.cfg.ringIconSize * orb.cfg.dockScale / 100)
    readonly property int gap: Math.round(tile * 0.32)
    readonly property int pad: Math.round(tile * 0.5)
    readonly property int ledgeH: Math.round(tile * 0.42)
    readonly property int lift: Math.round(tile * 0.28)
    readonly property int fullW: Math.round(orb.dockSlots * (tile + gap)) - gap + pad * 2
    readonly property int fullH: lift + tile + ledgeH + 14
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
    readonly property int restH: hideMode === "autohide" ? 6 : hideMode === "compact" ? Math.round(fullH * 0.58) : fullH

    // ---- hiding: the window really shrinks at rest, so it never blocks clicks above it
    // never | compact | autohide | smart (= autohide only while a window covers the dock)
    readonly property string hideMode: orb.cfg.dockHide === "smart" ? (orb.dockCovered ? "autohide" : "never") : orb.cfg.dockHide
    readonly property bool open: hoverAny || dock.holdOpen.running || orb.previewVisible
    property bool hoverAny: false
    property bool tall: true
    property Timer holdOpen: Timer { interval: 450 }
    property Timer shrinkLater: Timer { interval: 380; onTriggered: dock.tall = dock.open || dock.hideMode === "never" }
    onOpenChanged: { if (open) { shrinkLater.stop(); tall = true } else shrinkLater.restart() }
    onHideModeChanged: { tall = true; shrinkLater.restart() }
    readonly property int winH: tall ? fullH : restH
    readonly property bool restVisual: !open && hideMode !== "never"   // content in its resting look

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

        // resting line for "autohide": the only thing left at the screen edge
        Rectangle {
            visible: dock.hideMode === "autohide"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 2
            width: Math.min(parent.width * 0.3, 160); height: 3; radius: 1.5
            color: dock.orb.accent
            opacity: dock.restVisual ? 0.8 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }

    Item {
        id: stage
        width: dock.fullW
        height: dock.fullH
        anchors.bottom: parent.bottom
        readonly property real baseY: dock.lift + dock.tile          // where the icons stand
        // resting look: smaller (compact) or slid away (autohide)
        transformOrigin: Item.Bottom
        scale: dock.restVisual && dock.hideMode === "compact" ? 0.58 : 1
        opacity: dock.restVisual && dock.hideMode === "autohide" ? 0 : 1
        transform: Translate {
            y: dock.restVisual && dock.hideMode === "autohide" ? dock.fullH * 0.8 : 0
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 260 } }

        MouseArea {                                          // right click on the shelf itself
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => dock.orb.openDockMenu(stage, mouse.x, mouse.y)
        }

        DropArea {
            anchors.fill: parent
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => { drop.urls.forEach(u => dock.orb.apps.requestAddLauncher(u)); drop.accept() }
        }

        // the glass ledge, seen slightly from above
        Item {
            x: dock.pad * 0.4; width: parent.width - dock.pad * 0.8
            y: stage.baseY - 2; height: dock.ledgeH
            opacity: dock.orb.ghost ? 0.5 : 1
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Rectangle {
                anchors.fill: parent
                radius: 6
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.9, 0.93, 0.95, 0.22) }
                    GradientStop { position: 0.35; color: Qt.rgba(dock.orb.accent.r, dock.orb.accent.g, dock.orb.accent.b, 0.1) }
                    GradientStop { position: 1; color: Qt.rgba(0.05, 0.06, 0.08, 0.55) }
                }
                transform: Rotation { origin.x: width / 2; origin.y: 0; axis { x: 1; y: 0; z: 0 } angle: 52 }
            }
            Rectangle { width: parent.width; height: 1.5; color: Qt.rgba(1, 1, 1, 0.5) }   // bright front edge
        }

        // all applications, at the left end
        ShelfIcon {
            id: shelfAllApps
            index: -1
            iconSource: "view-app-grid-symbolic"
            x: dock.pad
            onClicked: dock.orb.openLauncher(shelfAllApps)
        }

        // between pinned apps and apps that only run
        Rectangle {
            visible: dock.orb.dockGap
            width: 2; height: dock.tile * 0.6; radius: 1
            x: dock.pad + dock.orb.gapPos * (dock.tile + dock.gap) + dock.tile / 2 - 1
            y: stage.baseY - dock.tile * 0.8
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        // the trash at the right end: drop files on it, click to open
        ShelfIcon {
            id: shelfTrash
            visible: dock.orb.cfg.dockTrash !== false
            index: -2
            iconSource: dock.orb.trashFull ? "user-trash-full" : "user-trash"
            x: dock.pad + dock.orb.trashPos * (dock.tile + dock.gap)
            onClicked: mouse => mouse.button === Qt.RightButton ? dock.orb.openDockMenu(shelfTrash, mouse.x, mouse.y) : dock.orb.openTrash()
            DropArea {
                anchors.fill: parent
                onEntered: drag => drag.accepted = drag.hasUrls
                onDropped: drop => { dock.orb.trashUrls(drop.urls); drop.accept() }
            }
        }

        Repeater {
            model: dock.orb.apps
            delegate: ShelfIcon {
                id: sslot
                required property int index
                required property var model
                visible: index < dock.count
                x: dock.pad + dock.orb.slotPos(index) * (dock.tile + dock.gap)
                iconSource: model.decoration
                windows: model.IsLauncher ? 0 : (model.IsGroupParent ? model.ChildCount : 1)
                active: model.IsActive === true
                minimized: model.IsMinimized === true
                badge: dock.orb.cfg.showBadges ? dock.orb.unreadFor(model.AppId) : 0
                attention: model.IsDemandingAttention === true
                progress: dock.orb.progressFor(model.AppId)
                onHoveredChanged: hovered ? dock.orb.slotHovered(sslot, index, model, windows) : dock.orb.slotLeft()
                onClicked: mouse => { dock.orb.slotLeft(); dock.orb.dockClicked(index, model, mouse, sslot) }
            }
        }
    }
    }
    }

    component ShelfIcon: Item {
        id: it
        property int index: 0
        property var iconSource
        property int windows: 0
        property bool active: false
        property bool minimized: false
        property int badge: 0
        property bool attention: false
        property real progress: -1
        readonly property bool hovered: hover.hovered
        readonly property real angle: dock.slotAngle
        property point tiltAt: Qt.point(0.5, 0.5)
        signal clicked(var mouse)

        // launching: a soft bounce + glow until the first window appears (max 6 s)
        property bool launching: false
        property real bounceY: 0
        onWindowsChanged: if (windows > 0) launching = false
        Timer { running: it.launching; interval: 6000; onTriggered: it.launching = false }
        SequentialAnimation on bounceY {
            running: it.launching || it.attention
            loops: Animation.Infinite
            NumberAnimation { to: -dock.tile * 0.3; duration: 230; easing.type: Easing.OutQuad }
            NumberAnimation { to: 0; duration: 430; easing.type: Easing.OutBounce }
            PauseAnimation { duration: 220 }
            onRunningChanged: if (!running) it.bounceY = 0
        }

        width: dock.tile; height: dock.tile
        y: stage.baseY - height - (hover.hovered ? dock.lift : 0)
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

        Kirigami.ImageColors { id: iconColors; source: it.iconSource }
        onIconSourceChanged: iconColors.update()
        Component.onCompleted: iconColors.update()
        readonly property color tint: {
            const c = iconColors.dominant
            if (!dock.orb.cfg.appColors || c.a === 0 || c.hslSaturation < 0.2) return dock.orb.accent
            return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55), Math.min(Math.max(c.hslLightness, 0.55), 0.7), 1)
        }

        // soft glow under running apps
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height / 2 + (hover.hovered ? dock.lift : 0)
            width: parent.width * 0.9; height: parent.height * 0.32; radius: height / 2
            color: Qt.rgba(it.tint.r, it.tint.g, it.tint.b, it.active ? 0.45 : 0.22)
            visible: it.windows > 0 && !it.minimized
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        }

        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            rotation: -dock.turn
            source: it.iconSource
            opacity: dock.orb.ghost && !hover.hovered ? 0.55 : 1
            scale: mouse.dragging ? 1.15 : hover.hovered && dock.orb.cfg.dockZoom ? 1.3 : 1
            transformOrigin: Item.Bottom
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            // tilt towards the pointer
            transform: [
                Translate { x: mouse.dragOffset; y: it.bounceY },
                Rotation { origin.x: icon.width / 2; origin.y: icon.height / 2; axis { x: 0; y: 1; z: 0 }
                           angle: hover.hovered ? (it.tiltAt.x - 0.5) * 34 : 0
                           Behavior on angle { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } },
                Rotation { origin.x: icon.width / 2; origin.y: icon.height / 2; axis { x: 1; y: 0; z: 0 }
                           angle: hover.hovered ? -(it.tiltAt.y - 0.5) * 26 : 0
                           Behavior on angle { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
            ]
        }

        // reflection in the ledge
        MultiEffect {
            source: icon
            width: icon.width; height: icon.height
            y: icon.height + (hover.hovered ? dock.lift * 2 : 0) + 2
            transform: Scale { origin.y: 0; yScale: -0.55 }
            opacity: hover.hovered && dock.orb.cfg.shelfReflection ? 0.34 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            maskEnabled: true
            maskSource: reflMask
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        }
        Rectangle {
            id: reflMask
            width: icon.width; height: icon.height
            visible: false; layer.enabled: true
            gradient: Gradient { GradientStop { position: 0; color: "white" } GradientStop { position: 0.6; color: "transparent" } }
        }

        // window dots on the ledge
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + (hover.hovered ? dock.lift : 0) + dock.ledgeH * 0.45
            spacing: 3
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            Repeater {
                model: Math.min(it.windows, 3)
                Rectangle {
                    width: it.active ? 12 : 5; height: 4; radius: 2
                    color: it.minimized ? "transparent" : it.tint
                    border.width: it.minimized ? 1 : 0; border.color: "#e6ecf0"
                }
            }
        }

        Rectangle {
            visible: it.badge > 0
            anchors { right: parent.right; top: parent.top; rightMargin: -6; topMargin: -6 }
            height: 18; width: Math.max(height, badgeText.implicitWidth + 8); radius: height / 2
            color: it.tint; border.width: 1.5; border.color: "#0d1013"
            rotation: -dock.turn
            Text { id: badgeText; anchors.centerIn: parent; text: it.badge > 99 ? "99+" : it.badge; color: "#0d1013"; font.bold: true; font.pixelSize: 11 }
        }

        SlotProgress {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width * 0.8
            value: it.progress
            tint: it.tint
        }

        HoverHandler {
            id: hover
            onPointChanged: if (hovered) it.tiltAt = Qt.point(point.position.x / it.width, point.position.y / it.height)
        }
        SlotMouse {
            id: mouse
            orb: dock.orb
            index: it.index
            step: dock.tile + dock.gap
            frame: stage
            onTapped: m => it.clicked(m)
        }
    }
}
