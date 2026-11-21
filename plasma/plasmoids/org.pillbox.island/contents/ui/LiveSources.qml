/*
 * Live activities for the island: what is running right now, from Plasma's own sources.
 *   job     – downloads, copies, uploads (Plasma's job tracker, the same as its progress popups)
 *   music   – the current MPRIS player
 *   mic     – an app is recording from a microphone (PulseAudio / PipeWire source outputs)
 *   timer   – Pillbox's own timer, started from the clock panel
 *   charge  – a laptop that was just plugged in (shown for a few seconds)
 * acts is the list, most important first. Every kind can be switched off in the settings.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.plasma5support as P5Support
import org.kde.notification as KNotification

Item {
    id: live
    property var cfg: ({})
    readonly property bool enabledAll: cfg.liveActivities !== false

    // ---------------------------------------------------------------- jobs
    NotificationManager.Notifications {
        id: jobs
        showNotifications: false
        showJobs: true
        showExpired: false
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        onCountChanged: Qt.callLater(live.readJob)
        onRowsInserted: Qt.callLater(live.readJob)
        onRowsRemoved: Qt.callLater(live.readJob)
        onDataChanged: Qt.callLater(live.readJob)
    }
    property var job: null                // { summary, text, percent, app, done }
    property double jobDoneAt: 0
    function readJob() {
        const N = NotificationManager.Notifications
        let found = null
        for (let i = 0; i < jobs.count; ++i) {
            const idx = jobs.index(i, 0)
            const state = jobs.data(idx, N.JobStateRole)
            const pct = jobs.data(idx, N.PercentageRole) || 0
            const one = { summary: jobs.data(idx, N.SummaryRole) || "", text: String(jobs.data(idx, N.BodyRole) || "").replace(/<[^>]*>/g, ""),
                          percent: pct, app: jobs.data(idx, N.ApplicationNameRole) || "", done: state === N.JobStateStopped }
            if (!one.done) { found = one; break }
            if (!found) found = one
        }
        if (found && found.done) {
            // a finished job shows its tick for five seconds, then goes
            if (!job || !job.done) jobDoneAt = Date.now()
            if (Date.now() - jobDoneAt > 5000) found = null
        }
        job = found
    }
    Timer { interval: 1000; repeat: true; running: !!live.job && live.job.done; onTriggered: live.readJob() }

    // ---------------------------------------------------------------- music
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && (player.track || "") !== "" && player.playbackStatus === Mpris.PlaybackStatus.Playing
    Timer { interval: 1000; repeat: true; running: live.playing; onTriggered: if (live.player) live.player.updatePosition() }

    // ---------------------------------------------------------------- microphone in use
    Vol.SourceOutputModel { id: recorders }
    property var micApps: []
    Instantiator {
        model: recorders
        delegate: QtObject {
            required property var model
            readonly property string name: model.Client ? model.Client.name : (model.Name || "")
            readonly property bool counts: !model.VirtualStream && name !== "" && !/plasma|pipewire|pulse|kwin|peak/i.test(name)
        }
        onObjectAdded: Qt.callLater(live.readMics)
        onObjectRemoved: Qt.callLater(live.readMics)
        id: micInst
    }
    function readMics() {
        const out = []
        for (let i = 0; i < micInst.count; ++i) {
            const o = micInst.objectAt(i)
            if (o && o.counts && out.indexOf(o.name) < 0) out.push(o.name)
        }
        micApps = out
    }

    // ---------------------------------------------------------------- timer
    property double timerEnd: 0          // ms since epoch; 0 = no timer
    property double timerTotal: 0
    property double timerPausedLeft: 0   // > 0 while paused
    property double now: Date.now()
    readonly property double timerLeft: timerPausedLeft > 0 ? timerPausedLeft : Math.max(0, timerEnd - now)
    function startTimer(minutes) { timerTotal = minutes * 60000; timerEnd = Date.now() + timerTotal; timerPausedLeft = 0 }
    function addMinute() { if (timerPausedLeft > 0) timerPausedLeft += 60000; else timerEnd += 60000; timerTotal += 60000 }
    function pauseTimer() { if (timerPausedLeft > 0) { timerEnd = Date.now() + timerPausedLeft; timerPausedLeft = 0 } else { timerPausedLeft = timerLeft } }
    function stopTimer() { timerEnd = 0; timerPausedLeft = 0 }
    Timer {
        interval: 1000; repeat: true; running: live.timerEnd > 0
        onTriggered: {
            live.now = Date.now()
            if (live.timerPausedLeft === 0 && live.timerEnd > 0 && live.now >= live.timerEnd) {
                live.timerEnd = 0
                ring.sendEvent()
            }
        }
    }
    KNotification.Notification {
        id: ring
        componentName: "plasma_workspace"
        eventId: "notification"
        title: i18n("Timer")
        text: i18n("Time is up.")
        iconName: "chronometer"
    }

    // ---------------------------------------------------------------- charging (laptops)
    P5Support.DataSource { id: pm; engine: "powermanagement"; connectedSources: ["Battery", "AC Adapter"] }
    readonly property bool plugged: !!(pm.data["AC Adapter"] || {})["Plugged in"]
    readonly property bool hasBattery: !!(pm.data["Battery"] || {})["Has Battery"]
    readonly property int batteryPct: (pm.data["Battery"] || {})["Percent"] || 0
    property bool chargeShow: false
    onPluggedChanged: if (plugged && hasBattery) { chargeShow = true; chargeHide.restart() }
    Timer { id: chargeHide; interval: 6000; onTriggered: live.chargeShow = false }

    // ---------------------------------------------------------------- the list, most important first
    function isOn(kind) { return enabledAll && cfg["live_" + kind] !== false }
    readonly property var acts: {
        const a = []
        if (isOn("mic") && micApps.length) a.push("mic")
        if (isOn("timer") && timerEnd > 0) a.push("timer")
        if (isOn("job") && job) a.push("job")
        if (isOn("music") && playing) a.push("music")
        if (isOn("charge") && chargeShow) a.push("charge")
        return a
    }
    function clock(ms) { const s = Math.max(0, Math.ceil(ms / 1000)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
}
