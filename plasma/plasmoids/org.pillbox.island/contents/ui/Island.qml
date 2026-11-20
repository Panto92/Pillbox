/*
 * The island: a glass shape that grows out of the clock pill, shows one notification
 * and shrinks back into the pill. The window has its final size from the start; only
 * the glass shape inside animates, so the compositor never has to resize a window.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

PlasmaCore.Dialog {
    id: island

    property var host
    property var model
    property var current                 // QPersistentModelIndex or null
    property Item anchorItem

    readonly property bool hasNote: !!current && current.valid
    readonly property bool showing: hasNote && !host.expanded && !host.inhibited
    property bool open: false             // the shape is out (stays true while collapsing)
    property bool hovered: false

    // the notification on show
    function role(r) { return hasNote ? model.data(current, r) : undefined }
    readonly property string appName: role(NotificationManager.Notifications.ApplicationNameRole) || ""
    readonly property string appIcon: role(NotificationManager.Notifications.ApplicationIconNameRole) || role(NotificationManager.Notifications.IconNameRole) || "preferences-desktop-notification-bell"
    readonly property var image: role(NotificationManager.Notifications.ImageRole)
    readonly property string summary: role(NotificationManager.Notifications.SummaryRole) || ""
    readonly property string body: role(NotificationManager.Notifications.BodyRole) || ""
    readonly property var actionNames: role(NotificationManager.Notifications.ActionNamesRole) || []
    readonly property var actionLabels: role(NotificationManager.Notifications.ActionLabelsRole) || []
    readonly property bool hasDefault: role(NotificationManager.Notifications.HasDefaultActionRole) === true
    readonly property bool canReply: role(NotificationManager.Notifications.HasReplyActionRole) === true
    readonly property bool critical: role(NotificationManager.Notifications.UrgencyRole) === NotificationManager.Notifications.CriticalUrgency
    readonly property bool expandedView: actionNames.length > 0 || canReply

    // geometry: centred under the pill's top edge
    readonly property int islandW: Kirigami.Units.gridUnit * 25
    readonly property int islandH: Math.ceil(content.implicitHeight + Kirigami.Units.largeSpacing * 2)
    property point pillPos: Qt.point(0, 0)
    property size pillSize: Qt.size(160, 32)
    function measurePill() {
        const a = anchorItem || (host ? host.compactRepresentationItem : null)
        if (!a) return
        const g = a.mapToGlobal(0, 0)
        const w = a.Window.window
        // the pill is the panel window itself; fall back to the widget's own rectangle
        if (w && w.width > 0) { pillPos = Qt.point(w.x, w.y); pillSize = Qt.size(w.width, w.height) }
        else { pillPos = Qt.point(g.x, g.y); pillSize = Qt.size(a.width, a.height) }
    }

    type: PlasmaCore.Dialog.Notification
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false
    visible: open
    x: Math.round(pillPos.x + pillSize.width / 2 - islandW / 2)
    y: Math.round(pillPos.y)

    onShowingChanged: {
        if (showing) { measurePill(); open = true; growTimer.restart(); restartTimer() }
        else { shape.grown = false; closeTimer.restart() }
    }
    onCurrentChanged: if (showing) restartTimer()

    // ---- timing: hover holds it, critical notes stay until dismissed
    function restartTimer() { if (!critical) lifeTimer.restart(); else lifeTimer.stop() }
    property Timer lifeTimer: Timer {
        interval: Math.max(4000, nsettings.popupTimeout || 6000)
        onTriggered: if (island.hovered) restart(); else island.model.expire(island.current)
    }
    // grow one frame after the window appeared, so the growth itself is visible
    property Timer growTimer: Timer { interval: 30; onTriggered: shape.grown = true }
    property Timer closeTimer: Timer {
        interval: 380
        onTriggered: if (!island.showing) island.open = false
    }
    property NotificationManager.Settings nsettings: NotificationManager.Settings {}

    mainItem: Item {
        width: island.islandW
        height: island.islandH
        HoverHandler { onHoveredChanged: island.hovered = hovered }

        // the glass shape: starts as the pill, grows into the island
        Rectangle {
            id: shape
            property bool grown: false
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: grown ? parent.width : Math.min(parent.width, island.pillSize.width)
            height: grown ? parent.height : Math.min(parent.height, island.pillSize.height)
            radius: grown ? Kirigami.Units.gridUnit * 1.3 : height / 2
            color: Qt.rgba(0.063, 0.078, 0.102, 0.94)
            border.width: 1
            border.color: island.critical ? Qt.rgba(1, 0.54, 0.48, 0.55) : Qt.rgba(1, 1, 1, 0.09)
            Behavior on width { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }
            Behavior on height { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }
            Behavior on radius { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
            clip: true

            // a click anywhere on the island (outside buttons) opens the app
            MouseArea {
                anchors.fill: parent
                enabled: island.hasDefault
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: island.model.invokeDefaultAction(island.current, NotificationManager.Notifications.Close)
            }

            ColumnLayout {
                id: content
                x: Kirigami.Units.largeSpacing * 1.4
                y: Kirigami.Units.largeSpacing
                width: island.islandW - Kirigami.Units.largeSpacing * 2.8
                spacing: Kirigami.Units.smallSpacing * 2
                opacity: shape.grown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: shape.grown ? 260 : 120 } }

                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Layout.fillWidth: true
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        Layout.alignment: Qt.AlignTop
                        source: island.image && island.image.width ? island.image : island.appIcon
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            Layout.fillWidth: true
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: island.appName && island.summary ? island.appName + " · " + island.summary : (island.summary || island.appName)
                                font.weight: Font.DemiBold
                                color: "#e9eef2"
                                elide: Text.ElideRight
                            }
                            QQC2.ToolButton {
                                icon.name: "window-close"
                                display: QQC2.AbstractButton.IconOnly
                                text: i18n("Close")
                                implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth
                                onClicked: island.model.close(island.current)
                            }
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: island.body
                            textFormat: Text.StyledText
                            color: "#cdd5db"
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
                // reply field
                RowLayout {
                    visible: island.canReply
                    Layout.fillWidth: true
                    QQC2.TextField {
                        id: replyField
                        Layout.fillWidth: true
                        placeholderText: i18n("Reply…")
                        onPressed: island.requestActivate()
                        onAccepted: if (text.length) { island.model.reply(island.current, text, NotificationManager.Notifications.Close); text = "" }
                    }
                }
                // actions
                Flow {
                    visible: island.actionNames.length > 0
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: island.actionNames.length
                        QQC2.Button {
                            required property int index
                            text: island.actionLabels[index] || island.actionNames[index]
                            onClicked: island.model.invokeAction(island.current, island.actionNames[index], NotificationManager.Notifications.Close)
                        }
                    }
                }
            }
        }
    }
}
