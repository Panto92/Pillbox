/*
 * The panel behind a click on the clock. Dashboard: a large clock, the month, the
 * weather and notifications. Classic: the month and notifications.
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

    readonly property bool dash: (panel.host.cfg.panelStyle || "dashboard") === "dashboard"
    Layout.preferredWidth: Kirigami.Units.gridUnit * (dash ? 50 : 38)
    Layout.preferredHeight: Kirigami.Units.gridUnit * (dash ? 26 : 22)
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
    readonly property color accent: Kirigami.Theme.highlightColor

    // seconds tick only while the panel is open
    property date tick: new Date()
    Timer { interval: 1000; repeat: true; triggeredOnStart: true; running: panel.dash && panel.host.expanded; onTriggered: panel.tick = new Date() }

    // ---------------------------------------------------------------- weather (Open-Meteo, no key;
    // nothing is sent anywhere until the user enters a place)
    property var wx: null
    property double wxAt: 0
    property string wxError: ""
    readonly property bool hasPlace: (panel.host.cfg.weatherPlace || "") !== ""
    function wxIcon(code, day) {
        const n = day === false ? "-night" : ""
        if (code === 0) return "weather-clear" + n
        if (code <= 2) return "weather-few-clouds" + n
        if (code === 3) return "weather-overcast"
        if (code <= 48) return "weather-fog"
        if (code <= 57) return "weather-showers-scattered" + n
        if (code <= 67 || (code >= 80 && code <= 82)) return "weather-showers" + n
        if (code <= 77 || code === 85 || code === 86) return "weather-snow" + n
        return "weather-storm" + n
    }
    function wxText(code) {
        if (code === 0) return i18n("Clear")
        if (code <= 2) return i18n("Partly cloudy")
        if (code === 3) return i18n("Overcast")
        if (code <= 48) return i18n("Fog")
        if (code <= 57) return i18n("Drizzle")
        if (code <= 67 || (code >= 80 && code <= 82)) return i18n("Rain")
        if (code <= 77 || code === 85 || code === 86) return i18n("Snow")
        return i18n("Thunderstorm")
    }
    function get(url, done) {
        const x = new XMLHttpRequest()
        x.onreadystatechange = () => { if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status === 200) { try { done(JSON.parse(x.responseText)) } catch (e) { panel.wxError = i18n("Weather unavailable") } }
            else panel.wxError = i18n("Weather unavailable") }
        x.open("GET", url); x.send()
    }
    function loadWeather(force) {
        if (!hasPlace || (!force && wx && Date.now() - wxAt < 30 * 60000)) return
        const c = panel.host.cfg
        get("https://api.open-meteo.com/v1/forecast?latitude=" + c.weatherLat + "&longitude=" + c.weatherLon +
            "&current=temperature_2m,apparent_temperature,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=5",
            j => { panel.wx = j; panel.wxAt = Date.now(); panel.wxError = "" })
    }
    function setPlace(name) {
        if (!name.trim()) return
        get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=" + Qt.locale().name.slice(0, 2) + "&name=" + encodeURIComponent(name.trim()), j => {
            if (!j.results || !j.results.length) { panel.wxError = i18n("Place not found"); return }
            const r = j.results[0], c = panel.host.cfg
            c.weatherLat = r.latitude; c.weatherLon = r.longitude; c.weatherPlace = r.name
            panel.wx = null; panel.wxError = ""; panel.loadWeather(true)
        })
    }
    Connections { target: panel.host; function onExpandedChanged() { if (panel.host.expanded && panel.dash) panel.loadWeather(false) } }
    Component.onCompleted: if (dash) loadWeather(false)

    // ---------------------------------------------------------------- classic: month | notifications
    RowLayout {
        visible: !panel.dash
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing * 2
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading { level: 2; text: panel.host.now.toLocaleDateString(Qt.locale(), "dddd") }
            PC3.Label { text: panel.host.now.toLocaleDateString(Qt.locale(), "d. MMMM yyyy"); opacity: 0.7 }
            PlasmaCalendar.MonthView { Layout.fillWidth: true; Layout.fillHeight: true; today: panel.host.now; showWeekNumbers: false }
        }
        Kirigami.Separator { Layout.fillHeight: true }
        NotesColumn {}
    }

    // ---------------------------------------------------------------- dashboard: clock + month | weather + notifications
    RowLayout {
        visible: panel.dash
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing * 2
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillHeight: true
            spacing: 0
            Row {
                PC3.Label {
                    text: panel.tick.toLocaleTimeString(Qt.locale(), "HH:mm")
                    font.pixelSize: Kirigami.Units.gridUnit * 4.2; font.weight: Font.Bold; font.letterSpacing: -2
                    font.features: { "tnum": 1 }
                }
                PC3.Label {
                    anchors.baseline: parent.children[0].baseline
                    leftPadding: Kirigami.Units.smallSpacing
                    text: panel.tick.toLocaleTimeString(Qt.locale(), "ss")
                    font.pixelSize: Kirigami.Units.gridUnit * 1.7; font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: panel.accent
                }
            }
            PC3.Label {
                text: panel.host.now.toLocaleDateString(Qt.locale(), "dddd, d. MMMM")
                opacity: 0.65
                Layout.bottomMargin: Kirigami.Units.largeSpacing
            }
            PlasmaCalendar.MonthView { Layout.fillWidth: true; Layout.fillHeight: true; today: panel.host.now; showWeekNumbers: false }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing
            // the weather card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: wxBody.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.gridUnit * 0.9
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.16) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.04) }
                }
                ColumnLayout {
                    id: wxBody
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.largeSpacing }
                    spacing: Kirigami.Units.smallSpacing
                    // no place yet: ask for one
                    ColumnLayout {
                        visible: !panel.hasPlace
                        Layout.fillWidth: true
                        PC3.Label { text: i18n("Weather"); font.weight: Font.DemiBold }
                        PC3.Label { Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65; font: Kirigami.Theme.smallFont
                            text: i18n("Enter your town to see the weather. It is looked up at open-meteo.com; nothing else is sent.") }
                        RowLayout {
                            PC3.TextField { id: placeField; Layout.fillWidth: true; placeholderText: i18n("Town, e.g. Hamburg"); onAccepted: panel.setPlace(text) }
                            PC3.Button { icon.name: "checkmark"; onClicked: panel.setPlace(placeField.text) }
                        }
                        PC3.Label { visible: panel.wxError !== ""; text: panel.wxError; color: Kirigami.Theme.negativeTextColor; font: Kirigami.Theme.smallFont }
                    }
                    RowLayout {
                        visible: panel.hasPlace
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon { source: panel.wx ? panel.wxIcon(panel.wx.current.weather_code, panel.wx.current.is_day === 1) : "weather-none-available"
                            implicitWidth: Kirigami.Units.iconSizes.huge; implicitHeight: implicitWidth }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            PC3.Label { text: panel.wx ? Math.round(panel.wx.current.temperature_2m) + "°" : "–"; font.pixelSize: Kirigami.Units.gridUnit * 2.6; font.weight: Font.Bold }
                            PC3.Label { Layout.fillWidth: true; elide: Text.ElideRight; opacity: 0.7
                                text: panel.wx ? i18n("%1 · feels like %2°", panel.wxText(panel.wx.current.weather_code), Math.round(panel.wx.current.apparent_temperature)) : (panel.wxError || i18n("Loading…")) }
                        }
                        PC3.ToolButton {
                            Layout.alignment: Qt.AlignTop
                            text: panel.host.cfg.weatherPlace; icon.name: "mark-location"
                            PC3.ToolTip.text: i18n("Change place"); PC3.ToolTip.visible: hovered
                            onClicked: panel.host.cfg.weatherPlace = ""
                        }
                    }
                    Row {
                        id: days
                        visible: panel.hasPlace && !!panel.wx
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        Repeater {
                            id: dayRep
                            model: panel.wx ? panel.wx.daily.time.length : 0
                            ColumnLayout {
                                required property int index
                                width: days.width / Math.max(1, dayRep.count)
                                spacing: 2
                                PC3.Label { Layout.alignment: Qt.AlignHCenter; opacity: 0.6; font: Kirigami.Theme.smallFont
                                    text: index === 0 ? i18n("Today") : new Date(panel.wx.daily.time[index] + "T12:00").toLocaleDateString(Qt.locale(), "ddd") }
                                Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; source: panel.wxIcon(panel.wx.daily.weather_code[index], true)
                                    implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth }
                                PC3.Label { Layout.alignment: Qt.AlignHCenter; font.weight: Font.DemiBold
                                    text: Math.round(panel.wx.daily.temperature_2m_max[index]) + "°" }
                                PC3.Label { Layout.alignment: Qt.AlignHCenter; opacity: 0.5; font: Kirigami.Theme.smallFont
                                    text: Math.round(panel.wx.daily.temperature_2m_min[index]) + "°" }
                            }
                        }
                    }
                }
            }
            NotesColumn {}
        }
    }

    // notifications with "clear all" and Do Not Disturb
    component NotesColumn: ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading { level: panel.dash ? 4 : 2; text: i18n("Notifications"); Layout.fillWidth: true }
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
