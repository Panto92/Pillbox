/*
 * "Liquid" form: a dock made of glass liquid. Under the pointer a drop swells
 * out of the bar, carries the icon up and flows along with a spring.
 * The merging ("metaball") look needs no custom shader: bar and drop are drawn
 * as white shapes, blurred, then cut back to a crisp shape with a threshold mask.
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
    property rect targetScreen: orb.homeScreen()
    readonly property rect screen: targetScreen

    readonly property int count: Math.min(orb.apps.count, 24)
    readonly property int tile: Math.round(orb.cfg.ringIconSize * orb.cfg.dockScale / 100 * 0.9)
    readonly property int gap: Math.round(tile * 0.36)
    readonly property int pad: Math.round(tile * 0.45)
    readonly property int barH: Math.round(tile * 1.32)
    readonly property int rise: Math.round(tile * 0.55)                 // how far the drop lifts an icon
    readonly property int fullW: (count + 1) * (tile + gap) - gap + pad * 2
    readonly property int fullH: barH + rise + Math.round(tile * 0.35)

    // ---- edge (same scheme as the other docks)
    readonly property string edge: orb.cfg.dockEdge
    readonly property bool vertical: edge !== "bottom"
    readonly property real turn: edge === "left" ? 90 : edge === "right" ? -90 : 0
    readonly property real slotAngle: edge === "left" ? 0 : edge === "right" ? Math.PI : -Math.PI / 2
    readonly property int margin: 6
    property bool rebuilding: false
    property Timer rebuildTimer: Timer { interval: 60; onTriggered: dock.rebuilding = false }
    onEdgeChanged: { rebuilding = true; rebuildTimer.restart() }
    onTargetScreenChanged: { rebuilding = true; rebuildTimer.restart() }

    // ---- hiding
    readonly property string hideMode: orb.cfg.dockHide
    readonly property bool open: hoverAny || dock.holdOpen.running || orb.previewVisible
    property bool hoverAny: false
    property bool tall: true
    property Timer holdOpen: Timer { interval: 450 }
    property Timer shrinkLater: Timer { interval: 380; onTriggered: dock.tall = dock.open || dock.hideMode === "never" }
    onOpenChanged: { if (open) { shrinkLater.stop(); tall = true } else shrinkLater.restart() }
    onHideModeChanged: { tall = true; shrinkLater.restart() }
    readonly property int restH: hideMode === "autohide" ? 6 : hideMode === "compact" ? Math.round(fullH * 0.6) : fullH
    readonly property int winH: tall ? fullH : restH
    readonly property bool restVisual: !open && hideMode !== "never"

    // ---- the drop: follows the hovered icon, rests under the active one
    property int hoverIndex: -1
    property int activeIndex: -1
    readonly property int dropIndex: hoverIndex >= 0 ? hoverIndex : activeIndex
    function slotCenter(i) { return pad + (i + 1) * (tile + gap) + tile / 2 }

    type: PlasmaCore.Dialog.Notification
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false
    title: "Pillbox Dock"
    visible: shown && !rebuilding
    readonly property int gapToEdge: hideMode === "autohide" && !tall ? 0 : margin
    x: edge === "left" ? screen.x + gapToEdge
     : edge === "right" ? screen.x + screen.width - width - gapToEdge
     : screen.x + Math.round((screen.width - width) / 2)
    y: vertical ? screen.y + Math.round((screen.height - height) / 2)
     : screen.y + screen.height - height - gapToEdge

    mainItem: Item {
        width: dock.vertical ? dock.winH : dock.fullW
        height: dock.vertical ? dock.fullW : dock.winH
        HoverHandler { onHoveredChanged: { dock.hoverAny = hovered; if (!hovered) { dock.holdOpen.restart(); dock.hoverIndex = -1 } } }

    Item {
        id: frame
        anchors.centerIn: parent
        width: dock.fullW
        height: dock.winH
        rotation: dock.turn

        Rectangle {                                   // "autohide": a thin line at the edge
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
        transformOrigin: Item.Bottom
        scale: dock.restVisual && dock.hideMode === "compact" ? 0.6 : 1
        opacity: dock.restVisual && dock.hideMode === "autohide" ? 0 : 1
        transform: Translate {
            y: dock.restVisual && dock.hideMode === "autohide" ? dock.fullH * 0.8 : 0
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 260 } }

        readonly property real barTop: height - dock.barH - 4

        DropArea {
            anchors.fill: parent
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => { drop.urls.forEach(u => dock.orb.apps.requestAddLauncher(u)); drop.accept() }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => dock.orb.openDockMenu(stage, mouse.x, mouse.y)
        }

        // ---------- the liquid: white shapes -> blur -> threshold mask -> glass fill
        Item {
            id: shapes
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {                                // the bar
                x: dock.pad * 0.3; width: parent.width - dock.pad * 0.6
                y: stage.barTop; height: dock.barH
                radius: height / 2
                color: "white"
            }
            Rectangle {                                // the drop
                id: drop
                readonly property real d: dock.tile * 1.3
                width: d; height: d; radius: d / 2
                color: "white"
                x: (dock.dropIndex >= 0 ? dock.slotCenter(dock.dropIndex) : parent.width / 2) - d / 2
                y: stage.barTop + dock.barH / 2 - d / 2 - (dock.hoverIndex >= 0 ? dock.rise : 0)
                opacity: dock.dropIndex >= 0 ? 1 : 0
                Behavior on x { SpringAnimation { spring: 3.2; damping: 0.22; mass: 0.9 } }
                Behavior on y { SpringAnimation { spring: 3.5; damping: 0.25 } }
            }
        }
        MultiEffect {
            id: blurred
            source: shapes
            anchors.fill: shapes
            visible: false
            layer.enabled: true
            blurEnabled: true
            blur: 1.0
            blurMax: Math.round(dock.tile * 0.45)
        }
        Rectangle {
            id: glass
            anchors.fill: parent
            visible: false
            layer.enabled: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(dock.orb.accent.r * 0.35 + 0.08, dock.orb.accent.g * 0.35 + 0.09, dock.orb.accent.b * 0.35 + 0.11, 0.96) }
                GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.05, 0.07, 0.94) }
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: glass
            maskEnabled: true
            maskSource: blurred
            maskThresholdMin: 0.48
            maskSpreadAtMin: 0.06
            opacity: dock.orb.ghost && !dock.open ? 0.55 : 1
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // glow of the drop in the hovered app's colour
        Rectangle {
            readonly property real d: dock.tile * 1.9
            width: d; height: d; radius: d / 2
            x: drop.x + drop.width / 2 - d / 2
            y: drop.y + drop.height / 2 - d / 2
            color: "transparent"
            opacity: dock.hoverIndex >= 0 ? 0.55 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(dock.glowColor.r, dock.glowColor.g, dock.glowColor.b, 0.35) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        // all applications, at the left end
        LiquidIcon {
            id: liquidAllApps
            pos: -1
            iconSource: "view-app-grid-symbolic"
            onClicked: dock.orb.openLauncher(liquidAllApps)
        }

        Repeater {
            model: dock.orb.apps
            delegate: LiquidIcon {
                id: lslot
                required property int index
                required property var model
                visible: index < dock.count
                pos: index
                iconSource: model.decoration
                windows: model.IsLauncher ? 0 : (model.IsGroupParent ? model.ChildCount : 1)
                active: model.IsActive === true
                minimized: model.IsMinimized === true
                badge: dock.orb.cfg.showBadges ? dock.orb.unreadFor(model.AppId) : 0
                onActiveChanged: if (active) dock.activeIndex = index
                Component.onCompleted: if (active) dock.activeIndex = index
                onHoveredChanged: {
                    if (hovered) { dock.hoverIndex = index; dock.glowColor = tint; dock.orb.slotHovered(lslot, index, model, windows) }
                    else dock.orb.slotLeft()
                }
                onClicked: mouse => { dock.orb.slotLeft(); dock.orb.dockClicked(index, model, mouse, lslot) }
            }
        }
    }
    }
    }

    property color glowColor: orb.accent

    component LiquidIcon: Item {
        id: it
        property int pos: 0                    // slot position (-1 = "all applications")
        property var iconSource
        property int windows: 0
        property bool active: false
        property bool minimized: false
        property int badge: 0
        readonly property bool hovered: hover.hovered
        readonly property real angle: dock.slotAngle
        signal clicked(var mouse)

        // launching: a soft bounce + glow until the first window appears (max 6 s)
        property bool launching: false
        property real bounceY: 0
        onWindowsChanged: if (windows > 0) launching = false
        Timer { running: it.launching; interval: 6000; onTriggered: it.launching = false }
        SequentialAnimation on bounceY {
            running: it.launching
            loops: Animation.Infinite
            NumberAnimation { to: -dock.tile * 0.3; duration: 230; easing.type: Easing.OutQuad }
            NumberAnimation { to: 0; duration: 430; easing.type: Easing.OutBounce }
            PauseAnimation { duration: 220 }
            onRunningChanged: if (!running) it.bounceY = 0
        }

        width: dock.tile; height: dock.tile
        x: dock.slotCenter(pos) - width / 2
        y: stage.barTop + (dock.barH - height) / 2 - (dock.hoverIndex === pos && pos >= 0 ? dock.rise : 0)
        Behavior on y { SpringAnimation { spring: 3.5; damping: 0.25 } }

        Kirigami.ImageColors { id: iconColors; source: it.iconSource }
        onIconSourceChanged: iconColors.update()
        Component.onCompleted: iconColors.update()
        readonly property color tint: {
            const c = iconColors.dominant
            if (!dock.orb.cfg.appColors || c.a === 0 || c.hslSaturation < 0.2) return dock.orb.accent
            return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55), Math.min(Math.max(c.hslLightness, 0.55), 0.7), 1)
        }

        Kirigami.Icon {
            anchors.fill: parent
            rotation: -dock.turn
            source: it.iconSource
            transform: Translate { y: it.bounceY }
            scale: dock.hoverIndex === it.pos && it.pos >= 0 ? 1.12 : 1
            opacity: it.windows > 0 || it.pos < 0 ? 1 : 0.82
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        }
        // window dots, inside the bar under the icon
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + dock.barH * 0.12 + (dock.hoverIndex === it.pos && it.pos >= 0 ? dock.rise : 0)
            spacing: 3
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

        HoverHandler { id: hover }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: mouse => it.clicked(mouse)
        }
    }
}
