/*
 * Pillbox Island – the centre pill. A calm clock that grows into an island when a
 * notification arrives; a click opens calendar and notification history.
 *
 * Notifications: Plasma stays the notification server (history, Do Not Disturb,
 * sounds). For every app whose notification the island shows, Plasma's own popup is
 * switched off through Plasma's official per-app setting ("Show popups", the same
 * switch as in System Settings → Notifications). Every app switched off this way is
 * remembered here and switched back on when Pillbox is removed. An app that has never
 * sent a notification before shows Plasma's popup once; from then on it uses the island.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ---------------------------------------------------------------- clock
    property date now: new Date()
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: { const d = new Date(); if (d.getMinutes() !== root.now.getMinutes() || d.getDate() !== root.now.getDate()) root.now = d }
    }
    toolTipMainText: now.toLocaleDateString(Qt.locale(), "dddd, d. MMMM yyyy")
    toolTipSubText: unread > 0 ? i18np("%1 unread notification", "%1 unread notifications", unread) : ""

    // ---------------------------------------------------------------- notifications
    readonly property int showPopupsFlag: NotificationManager.Settings.ShowPopups
    NotificationManager.Settings { id: nset; live: true }

    // everything that arrives: used to adopt new apps and to count unread
    NotificationManager.Notifications {
        id: allNotes
        showNotifications: true
        showJobs: false
        showExpired: true
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        onRowsInserted: (parent, first, last) => {
            for (let i = first; i <= last; ++i) {
                const idx = index(i, 0)
                root.adopt(data(idx, NotificationManager.Notifications.DesktopEntryRole) || "",
                           data(idx, NotificationManager.Notifications.NotifyRcNameRole) || "")
            }
        }
    }
    readonly property int unread: allNotes.unreadNotificationsCount
    function markRead() { allNotes.lastRead = new Date() }

    // switch Plasma's popup off for an app the island takes over – only if the user
    // hadn't already switched it off (then the island stays quiet for it, too)
    function adopt(entry, service) {
        if (!cfg.islandNotifications) return
        if (entry && entry.charAt(0) === "@") return      // "@other" etc. are Plasma's catch-all groups, not apps
        if (entry) {
            const list = cfg.suppressedApps || []
            if (list.indexOf(entry) >= 0) return
            const b = nset.applicationBehavior(entry)
            if (b & showPopupsFlag) {
                nset.setApplicationBehavior(entry, b & ~showPopupsFlag)
                nset.save()
                cfg.suppressedApps = list.concat([entry])
            }
        } else if (service) {
            const list = cfg.suppressedServices || []
            if (list.indexOf(service) >= 0) return
            const b = nset.serviceBehavior(service)
            if (b & showPopupsFlag) {
                nset.setServiceBehavior(service, b & ~showPopupsFlag)
                nset.save()
                cfg.suppressedServices = list.concat([service])
            }
        }
    }
    // give every app back its own popups (when the island is switched off)
    function releaseAll() {
        (cfg.suppressedApps || []).forEach(e => nset.setApplicationBehavior(e, nset.applicationBehavior(e) | showPopupsFlag));
        (cfg.suppressedServices || []).forEach(s => nset.setServiceBehavior(s, nset.serviceBehavior(s) | showPopupsFlag))
        nset.save()
        cfg.suppressedApps = []
        cfg.suppressedServices = []
    }
    Connections {
        target: root.cfg
        function onIslandNotificationsChanged() {
            if (root.cfg.islandNotifications) nset.knownApplications.forEach(e => root.adopt(e, ""))
            else root.releaseAll()
        }
    }

    // the island's own queue: only apps it took over, only what arrived since start,
    // never during Do Not Disturb (Plasma keeps those in the history)
    readonly property date startedAt: new Date()
    NotificationManager.Notifications {
        id: popups
        showNotifications: true
        showJobs: false
        showExpired: false
        showDismissed: false
        showAddedDuringInhibition: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        onCountChanged: Qt.callLater(root.pickCurrent)
        onRowsInserted: Qt.callLater(root.pickCurrent)
        onRowsRemoved: Qt.callLater(root.pickCurrent)
        onDataChanged: Qt.callLater(root.pickCurrent)
    }
    property var current: null          // persistent index of the notification on show
    function pickCurrent() {
        const apps = cfg.suppressedApps || [], services = cfg.suppressedServices || []
        let found = null
        if (cfg.islandNotifications && (apps.length || services.length)) {
            for (let i = 0; i < popups.count; ++i) {
                const idx = popups.index(i, 0)
                const created = popups.data(idx, NotificationManager.Notifications.CreatedRole)
                if (created && created < startedAt) continue
                const e = popups.data(idx, NotificationManager.Notifications.DesktopEntryRole) || ""
                const s = popups.data(idx, NotificationManager.Notifications.NotifyRcNameRole) || ""
                if ((e && apps.indexOf(e) >= 0) || (!e && s && services.indexOf(s) >= 0)) { found = popups.makePersistentModelIndex(idx); break }
            }
        }
        if (String(found) !== String(current)) current = found
    }
    readonly property bool inhibited: NotificationManager.Server.inhibited

    Island {
        id: island
        host: root
        model: popups
        current: root.current
        anchorItem: root.compactRepresentationItem
    }

    Component.onCompleted: {
        if (cfg.islandNotifications) nset.knownApplications.forEach(e => adopt(e, ""))
        pickCurrent()
    }

    // ---------------------------------------------------------------- the pill face
    compactRepresentation: MouseArea {
        id: face
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        // while the island is out, the clock steps back so the island reads as the same object
        opacity: island.showing ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing * 2
            PC3.Label {
                visible: root.cfg.showDate
                text: root.now.toLocaleDateString(Qt.locale(), "ddd d. MMM")
                opacity: 0.65
            }
            PC3.Label {
                text: root.now.toLocaleTimeString(Qt.locale(), "HH:mm")
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Rectangle {                         // unread: a small dot, gone once you look
                visible: root.unread > 0
                Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3
                color: Kirigami.Theme.highlightColor
            }
        }
    }

    fullRepresentation: FullPanel { host: root }
    onExpandedChanged: if (expanded) markRead()
}
