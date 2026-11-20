/*
 * The panel behind a click on the clock: the month on the left, notifications on the
 * right, Do Not Disturb underneath.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

Item {
    id: panel
    property var host

    Layout.preferredWidth: Kirigami.Units.gridUnit * 38
    Layout.preferredHeight: Kirigami.Units.gridUnit * 22
    Layout.minimumWidth: Kirigami.Units.gridUnit * 30
    Layout.minimumHeight: Kirigami.Units.gridUnit * 18

    NotificationManager.Settings { id: nset; live: true }
    NotificationManager.Notifications {
        id: history
        showNotifications: true
        showJobs: false
        showExpired: true
        showDismissed: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        limit: 40
    }
    readonly property bool dnd: NotificationManager.Server.inhibited

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing * 2

        // ---- the month
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading {
                level: 2
                text: panel.host.now.toLocaleDateString(Qt.locale(), "dddd")
            }
            PC3.Label {
                text: panel.host.now.toLocaleDateString(Qt.locale(), "d. MMMM yyyy")
                opacity: 0.7
            }
            PlasmaCalendar.MonthView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                today: panel.host.now
                showWeekNumbers: false
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ---- notifications
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Heading { level: 2; text: i18n("Notifications"); Layout.fillWidth: true }
                PC3.ToolButton {
                    visible: history.count > 0
                    text: i18n("Clear all")
                    icon.name: "edit-clear-history"
                    onClicked: history.clear(NotificationManager.Notifications.ClearExpired | NotificationManager.Notifications.ClearNonExpired)
                }
            }
            PlasmaComponents_ScrollList {}
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: panel.dnd ? "notifications-disabled" : "notifications"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
                PC3.Label { text: i18n("Do not disturb"); Layout.fillWidth: true }
                PC3.Switch {
                    checked: panel.dnd
                    onToggled: {
                        if (checked) {
                            const d = new Date(); d.setFullYear(d.getFullYear() + 1)
                            nset.notificationsInhibitedUntil = d
                        } else {
                            nset.notificationsInhibitedUntil = new Date(NaN)
                            nset.revokeApplicationInhibitions()
                        }
                        nset.save()
                    }
                }
            }
        }
    }

    component PlasmaComponents_ScrollList: PC3.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ListView {
            id: list
            model: history
            spacing: Kirigami.Units.smallSpacing
            clip: true
            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                visible: list.count === 0
                iconName: "checkmark"
                text: i18n("Nothing new")
            }
            delegate: Rectangle {
                id: note
                required property var model
                required property int index
                width: ListView.view.width
                implicitHeight: noteRow.implicitHeight + Kirigami.Units.largeSpacing * 1.5
                radius: Kirigami.Units.gridUnit * 0.6
                color: noteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                MouseArea {
                    id: noteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: note.model.hasDefaultAction === true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: history.invokeDefaultAction(history.index(note.index, 0), NotificationManager.Notifications.Close)
                }
                RowLayout {
                    id: noteRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing * 0.75
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.alignment: Qt.AlignTop
                        source: note.model.applicationIconName || note.model.iconName || "preferences-desktop-notification-bell"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            Layout.fillWidth: true
                            PC3.Label {
                                Layout.fillWidth: true
                                text: note.model.summary || note.model.applicationName || ""
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            PC3.Label {
                                text: note.model.created.toLocaleTimeString(Qt.locale(), "HH:mm")
                                opacity: 0.55
                                font: Kirigami.Theme.smallFont
                            }
                        }
                        PC3.Label {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: note.model.body || ""
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            opacity: 0.8
                        }
                    }
                    PC3.ToolButton {
                        Layout.alignment: Qt.AlignTop
                        icon.name: "window-close"
                        display: QQC2.AbstractButton.IconOnly
                        text: i18n("Remove")
                        onClicked: history.close(history.index(note.index, 0))
                    }
                }
            }
        }
    }
}
