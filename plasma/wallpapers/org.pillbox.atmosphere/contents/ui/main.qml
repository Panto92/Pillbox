/*
 * Pillbox Atmosphere – living wallpaper that costs next to nothing.
 *
 * Efficiency rules:
 *  - scenes are built from scene-graph items (gradients, shapes) the GPU only moves
 *    and blends; nothing is repainted pixel by pixel
 *  - colours follow the clock, updated once a minute
 *  - moving parts share ONE slow clock (8 / 12 / 20 fps for calm / normal / lively).
 *    A wallpaper costs mostly through how often the compositor must redraw the whole
 *    screen, not through the drawing itself – measured: render-thread animators at the
 *    monitor's full refresh rate cost far more than a slow timer.
 *  - a maximised or fullscreen window on this screen stops the clock entirely
 *  - system values are read every 3 s, and not at all when "react" is off
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.ksysguard.sensors as Sensors
import org.kde.notificationmanager as NotificationManager
import org.kde.taskmanager as TaskManager

WallpaperItem {
    id: root

    // The settings centre writes this wallpaper's config through Plasma's scripting API.
    // Those writes reach root.configuration, but without change signals – so bindings would
    // only notice on the next scene load. cfg is therefore a plain copy, refreshed once a
    // second when anything differs (a cheap string compare).
    property var cfg: snapshot()
    property string cfgText: JSON.stringify(cfg)
    function snapshot() {
        const c = root.configuration, o = {}
        for (const k of c.keys()) o[k] = c[k]
        return o
    }
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            const s = root.snapshot(), t = JSON.stringify(s)
            if (t === root.cfgText) return
            const before = root.cfg
            root.cfgText = t
            root.cfg = s
            if (s.FollowTime !== before.FollowTime || s.FixedHour !== before.FixedHour) root.hour = root.currentHour()
            if (s.Preview !== before.Preview) { boostAnim.restart(); root.newNotification() }
        }
    }

    // ---- time of day (once a minute)
    function clockHour() { const d = new Date(); return d.getHours() + d.getMinutes() / 60 }
    function currentHour() { return root.cfg.FollowTime ? clockHour() : Number(root.cfg.FixedHour) }
    property real hour: currentHour()
    Timer {
        interval: 60000; repeat: true; running: true
        onTriggered: root.hour = root.currentHour()
    }

    // ---- how much the computer shows through
    readonly property real react: cfg.Reactivity === "off" ? 0 : cfg.Reactivity === "strong" ? 1 : 0.55
    readonly property real motion: cfg.Motion === "calm" ? 0.5 : cfg.Motion === "lively" ? 1.6 : 1
    Sensors.Sensor { id: cpuSensor; sensorId: "cpu/all/usage"; updateRateLimit: 3000; enabled: root.react > 0 }
    Sensors.Sensor { id: gpuSensor; sensorId: "gpu/all/usage"; updateRateLimit: 3000; enabled: root.react > 0 }
    readonly property real cpu: Math.max(boost, react * Math.max(0, Math.min(1, (cpuSensor.value || 0) / 100)))
    readonly property real gpu: Math.max(boost, react * Math.max(0, Math.min(1, (gpuSensor.value || 0) / 100)))

    // "Try it": the settings centre writes a new Preview value; the scene then shows for a
    // few seconds how it reacts to full load and a new notification
    property real boost: 0
    SequentialAnimation {
        id: boostAnim
        NumberAnimation { target: root; property: "boost"; to: 1; duration: 1200; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 5000 }
        NumberAnimation { target: root; property: "boost"; to: 0; duration: 2500; easing.type: Easing.InOutSine }
    }

    NotificationManager.Notifications {
        id: notifications
        showNotifications: true
        showJobs: false
        showExpired: true
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        onRowsInserted: if (root.react > 0) root.newNotification()
    }
    readonly property int unread: react > 0 ? notifications.unreadNotificationsCount : 0
    signal newNotification()

    // ---- pause while a maximised / fullscreen window covers this screen
    property bool covered: false
    TaskManager.VirtualDesktopInfo { id: vdInfo }
    TaskManager.ActivityInfo { id: actInfo }
    TaskManager.TasksModel {
        id: windows
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: true
        virtualDesktop: vdInfo.currentDesktop
        filterByActivity: true
        activity: actInfo.currentActivity
        onDataChanged: coverTimer.restart()
        onRowsInserted: coverTimer.restart()
        onRowsRemoved: coverTimer.restart()
    }
    Timer { id: coverTimer; interval: 300; onTriggered: root.checkCovered() }
    function checkCovered() {
        const A = TaskManager.AbstractTasksModel
        const sx = root.Screen.virtualX, sy = root.Screen.virtualY
        let c = false
        for (let i = 0; i < windows.count; ++i) {
            const idx = windows.makeModelIndex(i)
            if (windows.data(idx, A.IsMinimized) === true) continue
            if (windows.data(idx, A.IsMaximized) !== true && windows.data(idx, A.IsFullScreen) !== true) continue
            const sg = windows.data(idx, A.ScreenGeometry)
            if (sg && sg.x === sx && sg.y === sy) { c = true; break }
        }
        covered = c
    }
    readonly property bool running: !(cfg.PauseWhenCovered && covered) && root.visible

    // the shared clock: seconds of "scene time"; advances only while visible
    property real time: 0
    readonly property int fps: cfg.Motion === "calm" ? 8 : cfg.Motion === "lively" ? 20 : 12
    Timer {
        interval: Math.round(1000 / root.fps); repeat: true
        running: root.running
        onTriggered: root.time += interval / 1000 * (0.6 + root.cpu * 1.2)
    }

    // ---- the scene
    Loader {
        id: scene
        anchors.fill: parent
        readonly property var files: ({ flow: "FlowScene.qml", horizon: "HorizonScene.qml", fogline: "FoglineScene.qml",
                                       dune: "DuneScene.qml", aurora: "AuroraScene.qml", tide: "TideScene.qml",
                                       neon: "NeonScene.qml", yule: "YuleScene.qml", orbit: "OrbitScene.qml", contour: "ContourScene.qml", grid: "GridScene.qml" })
        source: files[root.cfg.Scene] || "FlowScene.qml"
        onLoaded: item.env = root
    }
    Component.onCompleted: coverTimer.restart()
}
