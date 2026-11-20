/*
 * Pillbox Orb – a floating, draggable ball that replaces the dock.
 * Behaviour spec: docs/orb.md
 *
 * Windows owned by this widget (all frameless, transparent, above normal windows):
 *   orbWin   the ball itself – the only part that takes pointer input at rest
 *   satWin   click-through: open windows orbiting the ball as satellites
 *   ringWin  the launcher ring around the ball (focusable, closes when focus leaves)
 *   overlay  click-through, spans all monitors, draws the ball while it is dragged
 *
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.plasma5support as P5Support
import QtCore
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    compactRepresentation: Item { implicitWidth: 1; implicitHeight: 1 }
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // appearance (Orb settings page); sizes are logical pixels, so they follow the display scale
    readonly property var cfg: Plasmoid.configuration
    readonly property color accent: cfg.colorMode === "system" ? vivid(Kirigami.Theme.highlightColor) : cfg.customColor
    readonly property int ballSize: Math.round(30 * cfg.ballScale / 100)
    readonly property real k: ballSize / 30                          // scale factor for everything around the ball
    readonly property int orbSize: ballSize + 6                      // input window: only the ball takes clicks
    readonly property int satSize: Math.ceil(ballSize * 5)           // click-through window: ball visuals + satellites
    // a too dark or grey scheme accent would make a dull orb: lift it
    function vivid(c) {
        return c.hslLightness < 0.5 ? Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.35), 0.62, 1) : c
    }

    property bool dragging: false
    property point dragPos: Qt.point(0, 0)            // global pointer position while dragging
    property bool orbHover: false
    property bool dropHover: false
    property bool ringOpen: false
    property double ringClosedAt: 0
    // the ring takes keyboard focus when it opens, which deactivates the user's window.
    // So remember which app was in front *before* opening and decide clicks by that.
    property string frontAppId: ""

    readonly property var apps: appsModel                          // for the dock forms
    readonly property bool previewVisible: preview.visible
    readonly property bool orbForm: cfg.form !== "ember" && cfg.form !== "shelf" && cfg.form !== "liquid"

    readonly property point orbPos: clampPos(Plasmoid.configuration.orbX, Plasmoid.configuration.orbY)
    readonly property point orbCenter: Qt.point(orbPos.x + orbSize / 2, orbPos.y + orbSize / 2)

    // ---------------------------------------------------------------- notifications
    // Unread = created after you last looked at that app (its window became active)
    // and not yet read in Plasma's notification centre.
    readonly property bool dnd: NotificationManager.Server.inhibited
    property var unreadByApp: ({})                 // appKey -> count
    property int unreadTotal: 0
    property var seenByApp: ({})                   // appKey -> ms timestamp

    function appKey(s) {
        return s ? String(s).toLowerCase().replace(/\.desktop$/, "").replace(/^applications:/, "") : ""
    }
    function unreadFor(appId) {
        const k = appKey(appId)
        if (!k) return 0
        let n = 0
        for (const key in unreadByApp)
            if (key === k || key.indexOf(k) >= 0 || k.indexOf(key) >= 0) n += unreadByApp[key]
        return n
    }

    NotificationManager.Notifications {
        id: notifModel
        showNotifications: true
        showJobs: true
        showExpired: true
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        limit: 0
        onRowsInserted: (parent, first, last) => root.notificationsAdded(first, last)
        onRowsRemoved: countTimer.restart()
        onDataChanged: countTimer.restart()
    }
    Timer { id: countTimer; interval: 150; onTriggered: root.recount() }

    function recount() {
        const N = NotificationManager.Notifications
        const map = {}
        let total = 0
        for (let i = 0; i < notifModel.rowCount(); ++i) {
            const idx = notifModel.index(i, 0)
            if (notifModel.data(idx, N.TypeRole) !== N.NotificationType) continue
            if (notifModel.data(idx, N.ReadRole) === true) continue
            const key = appKey(notifModel.data(idx, N.DesktopEntryRole) || notifModel.data(idx, N.ApplicationNameRole))
            const created = notifModel.data(idx, N.CreatedRole)
            if (seenByApp[key] && created && created.getTime() <= seenByApp[key]) continue
            map[key] = (map[key] || 0) + 1
            total++
        }
        unreadByApp = map
        unreadTotal = total
    }
    function notificationsAdded(first, last) {
        countTimer.restart()
        if (dnd || hidden || !cfg.notificationRipple) return
        const N = NotificationManager.Notifications
        for (let i = first; i <= last; ++i) {
            const idx = notifModel.index(i, 0)
            if (notifModel.data(idx, N.TypeRole) !== N.NotificationType) continue
            const created = notifModel.data(idx, N.CreatedRole)
            if (created && Date.now() - created.getTime() > 10000) continue      // history loaded at start-up
            ripple.play(notifModel.data(idx, N.ApplicationIconNameRole) || notifModel.data(idx, N.IconNameRole) || "")
            return
        }
    }
    // looking at an app clears its badge
    function markSeen(appId) {
        const k = appKey(appId)
        if (!k) return
        const m = Object.assign({}, seenByApp); m[k] = Date.now(); seenByApp = m
        Plasmoid.configuration.notificationsSeen = JSON.stringify(m)
        countTimer.restart()
    }
    Connections {
        target: winModel
        function onActiveTaskChanged() {
            const id = winModel.data(winModel.activeTask, TaskManager.AbstractTasksModel.AppId)
            if (id) root.markSeen(id)
        }
    }
    Component.onCompleted: {
        try { seenByApp = JSON.parse(Plasmoid.configuration.notificationsSeen || "{}") } catch (e) { seenByApp = {} }
        countTimer.restart()
        envTimer.restart()
    }

    // the pulsing orb means "something waits for you": a click goes straight there
    function jumpToAttention() {
        for (let i = 0; i < winModel.count; ++i) {
            const idx = winModel.makeModelIndex(i)
            if (winModel.data(idx, TaskManager.AbstractTasksModel.IsDemandingAttention) === true) {
                winModel.requestActivate(idx)
                return true
            }
        }
        return false
    }

    // ---------------------------------------------------------------- environment
    // fullscreenHere: an active fullscreen window covers the orb -> hide completely (games, video)
    // covered:        any window lies under the orb -> "ghost" (faint until hovered)
    property bool fullscreenHere: false
    property bool covered: false
    readonly property bool hidden: fullscreenHere && cfg.hideInFullscreen && !dragging
    readonly property bool ghost: covered && cfg.ghostOverWindows && !orbHover && !ringOpen && !dragging

    function updateEnvironment() {
        const r = ballSize
        const ox = orbCenter.x - r, oy = orbCenter.y - r, ow = r * 2, oh = r * 2
        let cov = false, full = false
        for (let i = 0; i < winModel.count; ++i) {
            const idx = winModel.makeModelIndex(i)
            if (winModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true) continue
            const g = winModel.data(idx, TaskManager.AbstractTasksModel.Geometry)
            if (!g || g.width <= 0) continue
            const hit = g.x < ox + ow && g.x + g.width > ox && g.y < oy + oh && g.y + g.height > oy
            if (!hit) continue
            cov = true
            if (winModel.data(idx, TaskManager.AbstractTasksModel.IsFullScreen) === true
                && winModel.data(idx, TaskManager.AbstractTasksModel.IsActive) === true) full = true
        }
        covered = cov
        fullscreenHere = full
        if (full) closeRing()
    }
    Timer { id: envTimer; interval: 120; onTriggered: root.updateEnvironment() }
    Connections {
        target: winModel
        function onDataChanged() { envTimer.restart() }
        function onRowsInserted() { envTimer.restart() }
        function onRowsRemoved() { envTimer.restart() }
        function onActiveTaskChanged() { envTimer.restart() }
    }
    onOrbCenterChanged: envTimer.restart()

    // ---------------------------------------------------------------- geometry
    function screens() {
        return Qt.application.screens.map(sc => Qt.rect(sc.virtualX, sc.virtualY, sc.width, sc.height))
    }
    function desktopRect() {
        const all = screens()
        let x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity
        all.forEach(r => { x1 = Math.min(x1, r.x); y1 = Math.min(y1, r.y); x2 = Math.max(x2, r.x + r.width); y2 = Math.max(y2, r.y + r.height) })
        return all.length ? Qt.rect(x1, y1, x2 - x1, y2 - y1) : Qt.rect(0, 0, 1920, 1080)
    }
    function homeScreen() {
        const c = Plasmoid.containment
        return c ? c.screenGeometry : Qt.rect(0, 0, 1920, 1080)
    }
    function screenAt(cx, cy) {
        let best = homeScreen(), bestD = Infinity
        screens().forEach(r => {
            const dx = Math.max(r.x - cx, 0, cx - (r.x + r.width)), dy = Math.max(r.y - cy, 0, cy - (r.y + r.height))
            const d = dx * dx + dy * dy
            if (d < bestD) { bestD = d; best = r }
        })
        return best
    }
    // keep a box of the given size fully on the monitor nearest to its centre
    function clampBox(x, y, w, h) {
        const r = screenAt(x + w / 2, y + h / 2)
        return Qt.point(Math.max(r.x, Math.min(x, r.x + r.width - w)), Math.max(r.y, Math.min(y, r.y + r.height - h)))
    }
    function clampPos(x, y) {
        if (x < 0 && y < 0) {
            const h = homeScreen()
            return Qt.point(h.x + Math.round(h.width / 2 - orbSize / 2), h.y + h.height - orbSize - 90)
        }
        return clampBox(x, y, orbSize, orbSize)
    }

    // ---------------------------------------------------------------- system actions
    function invokeShortcut(component, name) {
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/component/" + component,
            iface: "org.kde.kglobalaccel.Component",
            member: "invokeShortcut",
            arguments: [new DBus.string(name)]
        })
    }
    property bool launcherOpen: false
    property point launcherOrigin: orbCenter
    // item: what was clicked (dock icon, hub button) – the launcher grows out of it
    function openLauncher(item) {
        closeRing()
        if (item && item.mapToGlobal) launcherOrigin = item.mapToGlobal(item.width / 2, item.height / 2)
        else launcherOrigin = orbForm ? orbCenter : Qt.point(homeScreen().x + homeScreen().width / 2, homeScreen().y + homeScreen().height)
        launcherOpen = true
    }
    function toggleOverview() { closeRing(); invokeShortcut("kwin", "Overview") }
    function showAppWindows(index) {
        // activate one window of the app, then let KWin present all windows of that class
        appsModel.requestActivate(appsModel.makeModelIndex(index))
        exposeTimer.restart()
    }
    Timer { id: exposeTimer; interval: 180; onTriggered: root.invokeShortcut("kwin", "ExposeClass") }

    function toggleRing() {
        if (ringOpen) { closeRing(); return }
        if (Date.now() - ringClosedAt < 250) return      // the click that just closed it
        const id = appsModel.data(appsModel.activeTask, TaskManager.AbstractTasksModel.AppId)
        frontAppId = id ? String(id) : ""
        ringOpen = true
    }
    function closeRing() {
        previewShow.stop(); preview.close()
        if (!ringOpen) return
        ringOpen = false
        ringClosedAt = Date.now()
    }

    Connections {
        target: Plasmoid
        function onActivated() { root.toggleRing() }   // the widget's global shortcut
    }

    // ---------------------------------------------------------------- models
    TaskManager.VirtualDesktopInfo { id: vdInfo }
    TaskManager.ActivityInfo { id: actInfo }

    // ring: pinned apps first (fixed order), then running unpinned apps; one entry per app
    TaskManager.TasksModel {
        id: appsModel
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        launchInPlace: true
        separateLaunchers: false
        sortMode: TaskManager.TasksModel.SortManual
        filterByActivity: true
        activity: actInfo.currentActivity
        filterByVirtualDesktop: true
        virtualDesktop: vdInfo.currentDesktop
        launcherList: Plasmoid.configuration.launchers
        onLauncherListChanged: Plasmoid.configuration.launchers = launcherList
    }

    // satellites: every window on this desktop / activity
    TaskManager.TasksModel {
        id: winModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortManual
        filterByActivity: true
        activity: actInfo.currentActivity
        filterByVirtualDesktop: true
        virtualDesktop: vdInfo.currentDesktop
        hideActivatedLaunchers: true
    }

    // ---------------------------------------------------------------- the ball
    PlasmaCore.Dialog {
        id: orbWin
        type: PlasmaCore.Dialog.Notification
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        hideOnWindowDeactivate: false
        title: "Pillbox Orb"
        visible: !root.hidden && root.orbForm
        x: root.orbPos.x
        y: root.orbPos.y

        mainItem: Item {
            id: orbItem
            width: root.orbSize; height: root.orbSize

            // minimise target: KWin animates minimised windows into this item
            Item { id: minimizeTarget; anchors.centerIn: parent; width: root.ballSize; height: root.ballSize }

            DropArea {
                id: drop
                anchors.fill: parent
                onContainsDragChanged: root.dropHover = containsDrag
                onEntered: drag => drag.accepted = drag.hasUrls
                onDropped: drop => {
                    drop.urls.forEach(u => appsModel.requestAddLauncher(u))
                    drop.accept()
                }
            }

            MouseArea {
                id: grabArea
                anchors.fill: parent
                // while dragging this reaches far beyond the window, so the grab cursor stays everywhere
                anchors.margins: root.dragging ? -20000 : 0
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                containmentMask: QtObject {
                    function contains(point: point): bool {
                        if (root.dragging) return true
                        const c = grabArea.mapFromItem(null, root.orbSize / 2, root.orbSize / 2)
                        return Math.hypot(point.x - c.x, point.y - c.y) <= root.ballSize / 2 + 3
                    }
                }
                cursorShape: (pressed && (pressedButtons & Qt.LeftButton) && !Plasmoid.configuration.locked) ? Qt.ClosedHandCursor : Qt.ArrowCursor
                onContainsMouseChanged: root.orbHover = containsMouse && !root.dragging

                property point pressPos
                function winPos(mouse) { return mapToItem(null, mouse.x, mouse.y) }

                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton) { root.closeRing(); orbMenu.open(mouse.x, mouse.y); return }
                    pressPos = winPos(mouse)
                }
                onPositionChanged: mouse => {
                    if (!(pressedButtons & Qt.LeftButton) || Plasmoid.configuration.locked) return
                    const w = winPos(mouse)
                    if (!root.dragging && Math.hypot(w.x - pressPos.x, w.y - pressPos.y) > 4) {
                        root.dragging = true
                        root.closeRing()
                    }
                    if (root.dragging)
                        root.dragPos = Qt.point(orbWin.x + w.x, orbWin.y + w.y)
                }
                onReleased: mouse => {
                    if (root.dragging) {
                        const p = root.clampPos(root.dragPos.x - pressPos.x, root.dragPos.y - pressPos.y)
                        Plasmoid.configuration.orbX = p.x
                        Plasmoid.configuration.orbY = p.y
                        root.dragging = false
                        return
                    }
                    if (mouse.button === Qt.LeftButton) {
                        if (!root.ringOpen && winModel.anyTaskDemandsAttention && root.jumpToAttention()) return
                        root.toggleRing()
                    }
                    else if (mouse.button === Qt.MiddleButton) root.toggleOverview()
                }
                onCanceled: root.dragging = false
            }
        }
    }

    PlasmaExtras.Menu {
        id: orbMenu
        visualParent: orbWin.mainItem
        PlasmaExtras.MenuItem {
            text: i18n("All applications")
            icon: "application-menu"
            onClicked: root.openLauncher()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Window overview")
            icon: "view-grid"
            onClicked: root.toggleOverview()
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: i18n("Lock position")
            icon: Plasmoid.configuration.locked ? "object-locked" : "object-unlocked"
            checkable: true
            checked: Plasmoid.configuration.locked
            onClicked: Plasmoid.configuration.locked = !Plasmoid.configuration.locked
        }
        PlasmaExtras.MenuItem {
            text: i18n("Customize…")
            icon: "configure"
            onClicked: root.settingsOpen = true
        }
    }

    // ---------------------------------------------------------------- satellites (click-through)
    PlasmaCore.Dialog {
        id: satWin
        type: PlasmaCore.Dialog.Notification
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
        hideOnWindowDeactivate: false
        title: "Pillbox Orb Satellites"
        visible: !root.dragging && !root.hidden && root.orbForm
        x: root.orbCenter.x - root.satSize / 2
        y: root.orbCenter.y - root.satSize / 2

        mainItem: Item {
            width: root.satSize; height: root.satSize
            // ghost mode fades only the ball and the satellites; news (badge, ripple, progress) stays visible
            readonly property real ghostOpacity: root.ghost ? 0.3 : 1

            OrbBall {
                anchors.centerIn: parent
                width: root.ballSize * 2.15; height: width
                ballSize: root.ballSize
                accent: root.accent
                effect: root.cfg.effect
                speed: root.cfg.effectSpeed
                hot: root.orbHover || root.dropHover || root.ringOpen
                alert: winModel.anyTaskDemandsAttention
                opacity: winModel.anyTaskDemandsAttention ? 1 : parent.ghostOpacity
                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            }

            // new notification: a ring of light in the app's colour runs outwards
            Rectangle {
                id: ripple
                property color tint: root.accent
                function play(icon) {
                    rippleColors.source = icon
                    rippleColors.update()
                    rippleStart.restart()
                }
                Kirigami.ImageColors { id: rippleColors }
                Timer {
                    id: rippleStart; interval: 60
                    onTriggered: {
                        const c = rippleColors.dominant
                        ripple.tint = (c.a === 0 || c.hslSaturation < 0.2) ? root.accent
                                    : Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.6), 0.62, 1)
                        rippleAnim.restart()
                    }
                }
                anchors.centerIn: parent
                width: root.ballSize; height: width; radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: tint
                opacity: 0
                ParallelAnimation {
                    id: rippleAnim
                    NumberAnimation { target: ripple; property: "width"; from: root.ballSize; to: root.satSize * 0.95; duration: 1100; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.95; to: 0; duration: 1100; easing.type: Easing.InQuad }
                    NumberAnimation { target: ripple; property: "border.width"; from: 4; to: 1; duration: 1100 }
                }
            }

            // running job (download, copy): progress arc around the ball
            Shape {
                anchors.centerIn: parent
                width: root.ballSize * 1.45; height: width
                visible: notifModel.activeJobsCount > 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.14); strokeWidth: 2.5; fillColor: "transparent"
                    PathAngleArc { centerX: root.ballSize * 0.725; centerY: centerX; radiusX: root.ballSize * 0.66; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: root.accent; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: root.ballSize * 0.725; centerY: centerX; radiusX: root.ballSize * 0.66; radiusY: radiusX; startAngle: -90; sweepAngle: Math.max(4, notifModel.jobsPercentage * 3.6) }
                }
            }

            // unread count
            Rectangle {
                visible: root.cfg.showBadges && root.unreadTotal > 0
                x: parent.width / 2 + root.ballSize * 0.28
                y: parent.height / 2 - root.ballSize * 0.72
                height: Math.max(16, root.ballSize * 0.55); width: Math.max(height, badgeText.implicitWidth + 8)
                radius: height / 2
                color: root.accent
                border.width: 1.5; border.color: "#0d1013"
                PC3.Label {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.unreadTotal > 99 ? "99+" : root.unreadTotal
                    color: "#0d1013"; font.bold: true
                    font.pixelSize: parent.height * 0.62
                }
            }

            Repeater {
                model: root.cfg.showSatellites ? winModel : null
                delegate: Item {
                    id: sat
                    required property int index
                    required property var model
                    readonly property real radius: ((root.orbHover || root.ringOpen ? 34 : 27) + (index % 3) * 9) * root.k
                    anchors.centerIn: parent
                    width: 0; height: 0
                    opacity: parent.ghostOpacity
                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                    RotationAnimator on rotation {
                        from: (sat.index * 137) % 360; to: from + 360
                        duration: (root.orbHover ? 26000 : 13000) + sat.index * 3100
                        loops: Animation.Infinite; running: true
                    }

                    Rectangle {
                        id: dot
                        readonly property bool active: sat.model.IsActive === true
                        readonly property bool minimized: sat.model.IsMinimized === true
                        readonly property bool attention: sat.model.IsDemandingAttention === true
                        readonly property real size: (active ? 9 : 7) * Math.max(0.8, root.k)
                        x: sat.radius - size / 2; y: -size / 2
                        width: size; height: size; radius: size / 2
                        color: attention ? "#d9a35b" : minimized ? "transparent" : root.accent
                        border.width: minimized ? 1.5 : 0
                        border.color: "#e6ecf0"
                        opacity: active ? 1 : 0.8
                        scale: 0
                        Component.onCompleted: scale = 1
                        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
                        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on height { NumberAnimation { duration: 200 } }
                        SequentialAnimation on opacity {
                            running: dot.attention; loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 450 }
                            NumberAnimation { to: 1; duration: 450 }
                        }
                    }

                    // every window minimises into the ball
                    function publish() {
                        if (typeof winModel === "undefined" || !winModel || sat.index < 0) return   // delegate already torn down
                        winModel.requestPublishDelegateGeometry(winModel.makeModelIndex(sat.index), Qt.rect(0, 0, root.ballSize, root.ballSize), minimizeTarget)
                    }
                    Component.onCompleted: Qt.callLater(publish)
                    onIndexChanged: Qt.callLater(publish)
                }
            }
        }
    }

    // ---------------------------------------------------------------- ring
    PlasmaCore.Dialog {
        id: ringWin
        type: PlasmaCore.Dialog.PopupMenu
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        title: "Pillbox Orb Ring"
        visible: root.ringOpen

        // up to 14 slots: one ring. More: 10 inside, the rest (max 20) on an outer ring
        readonly property int maxApps: 29
        readonly property real rs: root.cfg.ringScale / 100                         // ring scale
        readonly property int tile: Math.round(root.cfg.ringIconSize * rs)
        readonly property int slots: Math.min(appsModel.count, maxApps) + 1           // + the "add" slot
        readonly property int innerCount: slots > 14 ? 10 : slots
        readonly property int outerCount: slots - innerCount
        readonly property real step: tile + 18
        readonly property real r1: Math.max(tile * 1.9, innerCount * step / (2 * Math.PI))
        readonly property real r2: outerCount > 0 ? Math.max(r1 + tile + 20, outerCount * step / (2 * Math.PI)) : r1
        readonly property real radius: r2                                               // outermost ring
        readonly property int boxSize: Math.ceil(r2 * 2 + tile * 2 + 60)
        readonly property point pos: root.clampBox(root.orbCenter.x - boxSize / 2, root.orbCenter.y - boxSize / 2, boxSize, boxSize)
        function ringOf(i) { return i < innerCount ? 0 : 1 }
        x: pos.x
        y: pos.y

        onVisibleChanged: {
            if (visible) { ringItem.hovered = -1; ringItem.forceActiveFocus(); requestActivate() }
            else if (root.ringOpen) root.closeRing()                       // lost focus
        }

        mainItem: Item {
            id: ringItem
            width: ringWin.boxSize; height: ringWin.boxSize
            focus: true
            property int hovered: -1
            property string hoveredName: ""
            property string hoveredInfo: ""
            Keys.onEscapePressed: root.closeRing()

            // the ball's position inside the ring (ring may be shifted at screen edges)
            readonly property point centre: Qt.point(root.orbCenter.x - ringWin.x, root.orbCenter.y - ringWin.y)

            // faint disc behind the icons
            Rectangle {
                x: ringItem.centre.x - width / 2; y: ringItem.centre.y - height / 2
                width: ringWin.radius * 2 + ringWin.tile + 34; height: width; radius: width / 2
                color: Qt.rgba(0.05, 0.06, 0.08, 0.55)
                border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                border.width: 1
                scale: root.ringOpen ? 1 : 0.6
                opacity: root.ringOpen ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            // hub: hovered app, or buttons for all apps / overview
            Item {
                x: ringItem.centre.x - width / 2; y: ringItem.centre.y - height / 2
                width: Math.round(96 * ringWin.rs); height: width
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    spacing: 2
                    visible: ringItem.hovered >= 0
                    PC3.Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.weight: Font.DemiBold; text: ringItem.hoveredName }
                    PC3.Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; opacity: 0.7; font: Kirigami.Theme.smallFont; text: ringItem.hoveredInfo }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: ringItem.hovered < 0
                    PC3.ToolButton { id: hubAllApps; icon.name: "application-menu"; display: PC3.AbstractButton.IconOnly; text: i18n("All applications"); PC3.ToolTip.text: text; PC3.ToolTip.visible: hovered; onClicked: root.openLauncher(hubAllApps) }
                    PC3.ToolButton { icon.name: "view-grid"; display: PC3.AbstractButton.IconOnly; text: i18n("Window overview"); PC3.ToolTip.text: text; PC3.ToolTip.visible: hovered; onClicked: root.toggleOverview() }
                }
            }

            Repeater {
                model: appsModel
                delegate: RingSlot {
                    id: slotDelegate
                    required property int index
                    required property var model
                    visible: index < ringWin.maxApps
                    slotIndex: ringWin.ringOf(index) === 0 ? index : index - ringWin.innerCount
                    slotCount: ringWin.ringOf(index) === 0 ? ringWin.innerCount : ringWin.outerCount
                    ringRadius: ringWin.ringOf(index) === 0 ? ringWin.r1 : ringWin.r2
                    angleOffset: ringWin.ringOf(index) === 0 ? 0 : 180 / Math.max(1, ringWin.outerCount)
                    tile: ringWin.tile
                    useAppColor: root.cfg.appColors
                    centre: ringItem.centre
                    open: root.ringOpen
                    accent: root.accent
                    iconSource: model.decoration
                    windows: model.IsLauncher ? 0 : (model.IsGroupParent ? model.ChildCount : 1)
                    pinned: model.IsLauncher === true || model.HasLauncher === true
                    running: windows > 0
                    front: windows > 0 && root.frontAppId !== "" && model.AppId === root.frontAppId
                    minimized: model.IsMinimized === true
                    highlighted: ringItem.hovered === index
                    badge: root.cfg.showBadges ? root.unreadFor(model.AppId) : 0
                    onEntered: {
                        ringItem.hovered = index
                        ringItem.hoveredName = model.AppName || model.display
                        ringItem.hoveredInfo = windows === 0 ? i18n("launch") : i18np("%1 window", "%1 windows", windows)
                        root.slotHovered(slotDelegate, index, model, windows)
                    }
                    onExited: { if (ringItem.hovered === index) ringItem.hovered = -1; root.slotLeft() }
                    onClicked: mouse => { root.slotLeft(); root.slotClicked(index, model, mouse, slotDelegate) }
                }
            }

            RingSlot {
                id: addSlotItem
                slotIndex: ringWin.outerCount > 0 ? ringWin.outerCount - 1 : ringWin.slots - 1
                slotCount: ringWin.outerCount > 0 ? ringWin.outerCount : ringWin.innerCount
                ringRadius: ringWin.outerCount > 0 ? ringWin.r2 : ringWin.r1
                angleOffset: ringWin.outerCount > 0 ? 180 / Math.max(1, ringWin.outerCount) : 0
                tile: ringWin.tile
                centre: ringItem.centre
                open: root.ringOpen
                accent: root.accent
                addSlot: true
                iconSource: "list-add"
                highlighted: ringItem.hovered === 9999
                onEntered: { ringItem.hovered = 9999; ringItem.hoveredName = i18n("Add"); ringItem.hoveredInfo = i18n("drag onto the orb") }
                onExited: if (ringItem.hovered === 9999) ringItem.hovered = -1
                onClicked: root.openLauncher(addSlotItem)
            }
        }
    }

    // ---------------------------------------------------------------- full-screen launcher
    LauncherOverlay {
        appletInterface: root
        tasksModel: appsModel
        accent: root.accent
        area: root.screenAt(root.orbCenter.x, root.orbCenter.y)
        open: root.launcherOpen
        origin: root.launcherOrigin
        onCloseRequested: root.launcherOpen = false
    }

    // ---------------------------------------------------------------- live previews
    property var previewRequest: null

    function slotHovered(item, index, m, windows) {
        previewHide.stop()
        if (windows === 0) { previewShow.stop(); preview.close(); return }
        previewRequest = { item: item, index: index, isGroup: m.IsGroupParent === true, name: m.AppName || m.display, icon: m.decoration }
        // already showing another app: switch right away, otherwise wait a moment
        if (preview.visible) showPreview(); else previewShow.restart()
    }
    function slotLeft() {
        previewShow.stop()
        previewHide.restart()
    }
    function showPreview() {
        const r = previewRequest
        if (!r || (orbForm && !ringOpen)) return
        preview.appRow = r.index
        preview.isGroup = r.isGroup
        preview.appName = r.name
        preview.appIcon = r.icon
        preview.angle = r.item.angle
        preview.anchorItem = r.item
        preview.open()                       // first time: fade in; already open: glide over
    }
    Timer { id: previewShow; interval: 350; onTriggered: root.showPreview() }
    Timer { id: previewHide; interval: 320; onTriggered: if (!preview.hovered) preview.close() }

    PreviewPopup {
        id: preview
        visible: false
        tasksModel: appsModel
        accent: root.accent
        onActivated: { close(); root.closeRing() }
        onHoveredChanged: hovered ? previewHide.stop() : previewHide.restart()
    }

    // ---------------------------------------------------------------- ring actions
    property int menuIndex: -1
    property var menuModel: ({ launcher: false, pinned: false, windows: 0, canNew: false, url: "" })

    function slotClicked(index, m, mouse, item) {
        const idx = appsModel.makeModelIndex(index)
        const windows = m.IsLauncher ? 0 : (m.IsGroupParent ? m.ChildCount : 1)
        if (mouse.button === Qt.RightButton) {
            menuIndex = index
            menuModel = { launcher: m.IsLauncher === true, pinned: m.IsLauncher === true || m.HasLauncher === true, windows: windows,
                          canNew: m.CanLaunchNewInstance !== false, url: m.LauncherUrlWithoutIcon }
            appMenu.visualParent = item
            appMenu.open(mouse.x, mouse.y)
            return
        }
        if (mouse.button === Qt.MiddleButton) {
            appsModel.requestNewInstance(idx)
            closeRing(); return
        }
        if (windows === 0) {                                               // launch
            appsModel.requestActivate(idx)
            if (item && item.launching !== undefined) item.launching = true   // dock icon bounces until the window is there
            if (orbForm && cfg.notificationRipple !== false) ripple.play(m.decoration)
        }
        else if (windows > 1) showAppWindows(index)                       // present all its windows
        else if (m.AppId === frontAppId) appsModel.requestToggleMinimized(idx)   // was in front: into the orb
        else appsModel.requestActivate(idx)                                      // background or minimised: bring it back
        closeRing()
    }

    function dockClicked(index, m, mouse, item) {
        const id = appsModel.data(appsModel.activeTask, TaskManager.AbstractTasksModel.AppId)
        frontAppId = id ? String(id) : ""
        slotClicked(index, m, mouse, item)
    }

    function openDockMenu(item, x, y) {
        dockMenu.visualParent = item
        dockMenu.open(x, y)
    }
    PlasmaExtras.Menu {
        id: dockMenu
        PlasmaExtras.MenuItem { text: i18n("All applications"); icon: "application-menu"; onClicked: root.openLauncher() }
        PlasmaExtras.MenuItem { text: i18n("Window overview"); icon: "view-grid"; onClicked: root.toggleOverview() }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: i18n("Customize…"); icon: "configure"; onClicked: root.settingsOpen = true }
    }

    // wallpaper on every desktop, driven from the settings centre. The script runs in a
    // separate qdbus6 process: calling plasmashell's own DBus interface from inside
    // plasmashell crashes the DBus QML plugin when the reply arrives. Clicks are
    // collected for a moment, and the plugin is only switched when it really changes
    // (switching rebuilds the whole scene).
    function applyWallpaper() { wallTimer.restart() }
    function wallOpts() { try { return JSON.parse(cfg.wallOpts || "{}") } catch (e) { return {} } }
    function wallOptsScript() {
        const o = wallOpts(); let js = ""
        for (const k in o) {
            const key = String(k).replace(/[^A-Za-z]/g, ""), val = String(o[k]).replace(/[^a-z]/g, "")
            if (key.length) js += " d.writeConfig(\"" + key + "\", \"" + val + "\");"
        }
        return js
    }
    property bool wallPreviewPending: false
    function previewWallpaper() { wallPreviewPending = true; wallTimer.restart() }
    property Timer wallTimer: Timer {
        interval: 200
        onTriggered: {
            const c = root.cfg
            let js
            if (c.wallScene === "keep") {
                js = "desktops().forEach(function(d){ if (d.wallpaperPlugin == \"org.pillbox.atmosphere\") d.wallpaperPlugin = \"org.kde.image\"; });"
            } else {
                const str = v => "\"" + String(v).replace(/[^a-z]/g, "") + "\""
                js = "desktops().forEach(function(d){ if (d.wallpaperPlugin != \"org.pillbox.atmosphere\") d.wallpaperPlugin = \"org.pillbox.atmosphere\";"
                   + " d.currentConfigGroup = [\"Wallpaper\", \"org.pillbox.atmosphere\", \"General\"];"
                   + " d.writeConfig(\"Scene\", " + str(c.wallScene) + ");"
                   + " d.writeConfig(\"FollowTime\", " + (c.wallFollow ? "true" : "false") + ");"
                   + " d.writeConfig(\"Reactivity\", " + str(c.wallReact) + ");"
                   + " d.writeConfig(\"Motion\", " + str(c.wallMotion) + ");"
                   + " d.writeConfig(\"PauseWhenCovered\", " + (c.wallPause ? "true" : "false") + ");"
                   + " d.writeConfig(\"FixedHour\", " + Number(c.wallHour).toFixed(2) + ");"
                   + root.wallOptsScript()
                   + (root.wallPreviewPending ? " d.writeConfig(\"Preview\", \"" + Date.now() + "\");" : "")
                   + " });"
                root.wallPreviewPending = false
            }
            root.shell.connectSource("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '" + js + "'")
        }
    }
    property P5Support.DataSource shell: P5Support.DataSource {
        engine: "executable"
        onNewData: (source, data) => disconnectSource(source)
    }

    // ---------------------------------------------------------------- login screen
    // Set up once with root (pkexec), then the choices live in a file the user owns:
    // /var/lib/pillbox-login/theme.conf.user – no password needed to change them.
    readonly property string loginDir: String(StandardPaths.writableLocation(StandardPaths.GenericDataLocation)).replace("file://", "") + "/pillbox/login"
    readonly property string loginFile: "/var/lib/pillbox-login/theme.conf.user"
    property string loginState: "unknown"          // unknown | nosddm | missing | ready | working
    function checkLogin() {
        // other systems may use another login manager (GDM, LightDM …): then say so instead of offering a button
        loginProbe.connectSource("if ! systemctl is-enabled --quiet sddm 2>/dev/null && ! command -v sddm >/dev/null; then echo PBLOGIN=nosddm; "
                                 + "elif test -w " + loginFile + " && test -d /usr/share/sddm/themes/pillbox; then echo PBLOGIN=ready; else echo PBLOGIN=missing; fi # " + Date.now())
    }
    function setupLogin() { loginState = "working"; loginProbe.connectSource("pkexec " + loginDir + "/install-login.sh; echo PBLOGIN=done # " + Date.now()) }
    function removeLogin() { loginState = "working"; loginProbe.connectSource("pkexec " + loginDir + "/install-login.sh --remove; echo PBLOGIN=done # " + Date.now()) }
    function previewLogin() { shell.connectSource("sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/pillbox") }
    function applyLogin() {
        if (loginState !== "ready") return
        let scene = String(cfg.loginScene || "auto").replace(/[^a-z]/g, "")
        if (scene === "desktop") scene = cfg.wallScene && cfg.wallScene !== "keep" ? String(cfg.wallScene).replace(/[^a-z]/g, "") : "auto"
        const a = accent, hex = "#" + [a.r, a.g, a.b].map(v => ("0" + Math.round(v * 255).toString(16)).slice(-2)).join("")
        shell.connectSource("printf '[General]\\nscene=%s\\naccent=%s\\n' '" + scene + "' '" + hex + "' > " + loginFile + " # " + Date.now())
    }
    property P5Support.DataSource loginProbe: P5Support.DataSource {
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            const out = String(data.stdout || "")
            if (out.indexOf("PBLOGIN=nosddm") >= 0) root.loginState = "nosddm"
            else if (out.indexOf("PBLOGIN=ready") >= 0) root.loginState = "ready"
            else if (out.indexOf("PBLOGIN=missing") >= 0) root.loginState = "missing"
            else if (out.indexOf("PBLOGIN=done") >= 0) { root.checkLogin(); applyAfterSetup.restart() }
        }
    }
    property Timer applyAfterSetup: Timer { interval: 800; onTriggered: root.applyLogin() }
    onAccentChanged: if (loginState === "ready") applyLogin()

    property bool settingsOpen: false
    SettingsPanel {
        orb: root
        open: root.settingsOpen
        onCloseRequested: root.settingsOpen = false
    }

    // which monitors get a dock: the main one, all, or one chosen by name
    readonly property var dockScreens: {
        const all = Qt.application.screens
        const rect = sc => Qt.rect(sc.virtualX, sc.virtualY, sc.width, sc.height)
        if (cfg.dockScreen === "all") return all.map(rect)
        const named = all.find(sc => sc.name === cfg.dockScreen)
        return [named ? rect(named) : homeScreen()]
    }
    Instantiator {
        model: root.cfg.form === "ember" ? root.dockScreens : []
        delegate: DockEmber {
            required property var modelData
            orb: root
            targetScreen: modelData
            shown: !root.hidden
        }
    }
    Instantiator {
        model: root.cfg.form === "liquid" ? root.dockScreens : []
        delegate: DockLiquid {
            required property var modelData
            orb: root
            targetScreen: modelData
            shown: !root.hidden
        }
    }
    Instantiator {
        model: root.cfg.form === "shelf" ? root.dockScreens : []
        delegate: DockShelf {
            required property var modelData
            orb: root
            targetScreen: modelData
            shown: !root.hidden
        }
    }

    PlasmaExtras.Menu {
        id: appMenu
        PlasmaExtras.MenuItem {
            text: i18n("New window")
            icon: "window-new"
            visible: !root.menuModel.launcher && root.menuModel.canNew
            onClicked: { appsModel.requestNewInstance(appsModel.makeModelIndex(root.menuIndex)); root.closeRing() }
        }
        PlasmaExtras.MenuItem {
            text: i18n("Show all windows")
            icon: "view-grid"
            visible: root.menuModel.windows > 1
            onClicked: { root.closeRing(); root.showAppWindows(root.menuIndex) }
        }
        PlasmaExtras.MenuItem {
            text: root.menuModel.pinned ? i18n("Unpin from orb") : i18n("Pin to orb")
            icon: root.menuModel.pinned ? "window-unpin" : "window-pin"
            onClicked: {
                if (root.menuModel.pinned) appsModel.requestRemoveLauncher(root.menuModel.url)
                else appsModel.requestAddLauncher(root.menuModel.url)
            }
        }
        PlasmaExtras.MenuItem { separator: true; visible: !root.menuModel.launcher }
        PlasmaExtras.MenuItem {
            text: root.menuModel.windows > 1 ? i18n("Close all") : i18n("Close")
            icon: "window-close"
            visible: !root.menuModel.launcher
            onClicked: { appsModel.requestClose(appsModel.makeModelIndex(root.menuIndex)); root.closeRing() }
        }
    }

    // ---------------------------------------------------------------- drag overlay (click-through, all monitors)
    PlasmaCore.Dialog {
        id: overlay
        type: PlasmaCore.Dialog.Notification
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
        hideOnWindowDeactivate: false
        title: "Pillbox Orb Drag"
        visible: root.dragging
        x: root.desktopRect().x
        y: root.desktopRect().y
        mainItem: Item {
            width: root.desktopRect().width; height: root.desktopRect().height
            OrbBall {
                ballSize: root.ballSize
                accent: root.accent
                effect: root.cfg.effect
                speed: root.cfg.effectSpeed
                hot: true
                width: root.orbSize; height: root.orbSize
                x: root.dragPos.x - overlay.x - grabArea.pressPos.x
                y: root.dragPos.y - overlay.y - grabArea.pressPos.y
            }
        }
    }
}
