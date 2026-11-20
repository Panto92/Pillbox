/*
 * Pillbox Launcher – full-screen app overview opened from the orb.
 * Uses Plasma's own application models (the ones Kickoff uses), so it lists
 * exactly the apps the system menu knows, with categories and search.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

PlasmaCore.Dialog {
    id: launcher

    property var appletInterface          // the PlasmoidItem (needed by Plasma's app models)
    property var tasksModel               // the orb's model: used for pinning
    property rect area: Qt.rect(0, 0, 1920, 1080)   // the monitor to cover
    property color accent: "#8fb0c2"
    property bool open: false
    signal closeRequested()

    type: PlasmaCore.Dialog.PopupMenu
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: true
    title: "Pillbox Launcher"
    visible: open
    x: area.x
    y: area.y

    onVisibleChanged: {
        if (visible) {
            if (!rootModel.populated) { rootModel.refresh(); rootModel.populated = true }
            search.text = ""
            categories.currentIndex = 0
            requestActivate()
            search.forceActiveFocus()
        } else if (open) {
            closeRequested()                       // focus moved elsewhere
        }
    }

    // ------------------------------------------------------------------ data
    // (a Dialog only takes visual children, so the models live in properties)
    property Kicker.RootModel rootModel: Kicker.RootModel {
        property bool populated: false
        autoPopulate: false
        appletInterface: launcher.appletInterface
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: false
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        appNameFormat: 0
    }
    property Kicker.RunnerModel runnerModel: Kicker.RunnerModel {
        appletInterface: launcher.appletInterface
        runners: ["krunner_services", "krunner_systemsettings"]
        mergeResults: true
        query: search.text
    }
    readonly property bool searching: search.text.length > 0
    readonly property var appsSource: searching ? (runnerModel.count > 0 ? runnerModel.modelForRow(0) : null)
                                                : rootModel.modelForRow(Math.max(0, categories.currentIndex))

    function launcherUrl(m) {
        let id = m.favoriteId ? String(m.favoriteId) : ""
        if (!id && m.url) id = String(m.url)
        if (id && id.indexOf(":") < 0) id = "applications:" + id
        return id
    }
    function isPinned(url) {
        return url !== "" && tasksModel && tasksModel.launcherList.indexOf(url) >= 0
    }
    function launch(row) {
        if (appsSource) appsSource.trigger(row, "", null)
        closeRequested()
    }

    // ------------------------------------------------------------------ UI
    mainItem: Rectangle {
        id: backdrop
        width: launcher.area.width
        height: launcher.area.height
        color: Qt.rgba(0.035, 0.045, 0.06, 0.86)
        focus: true

        Keys.onEscapePressed: launcher.closeRequested()

        // click on empty space closes
        MouseArea { anchors.fill: parent; onClicked: launcher.closeRequested() }

        ColumnLayout {
            id: content
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.08)
            width: Math.min(parent.width - Kirigami.Units.gridUnit * 6, Kirigami.Units.gridUnit * 70)
            height: parent.height - y - Kirigami.Units.gridUnit * 3
            spacing: Kirigami.Units.gridUnit
            opacity: launcher.open ? 1 : 0
            scale: launcher.open ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            // search
            PC3.TextField {
                id: search
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(content.width, Kirigami.Units.gridUnit * 30)
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.35
                placeholderText: i18n("Search applications…")
                leftPadding: Kirigami.Units.gridUnit * 2.2
                Kirigami.Icon {
                    source: "search"
                    anchors.verticalCenter: parent.verticalCenter
                    x: Kirigami.Units.gridUnit * 0.7
                    width: Kirigami.Units.iconSizes.smallMedium; height: width
                    opacity: 0.6
                }
                Keys.onEscapePressed: text.length ? text = "" : launcher.closeRequested()
                Keys.onDownPressed: { grid.forceActiveFocus(); if (grid.currentIndex < 0) grid.currentIndex = 0 }
                Keys.onReturnPressed: if (grid.count > 0) launcher.launch(Math.max(0, grid.currentIndex))
                Keys.onEnterPressed: if (grid.count > 0) launcher.launch(Math.max(0, grid.currentIndex))
                onTextChanged: grid.currentIndex = 0
            }

            // categories
            ListView {
                id: categories
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.9
                visible: !launcher.searching
                orientation: ListView.Horizontal
                spacing: Kirigami.Units.smallSpacing
                clip: true
                model: rootModel
                delegate: QQC2.AbstractButton {
                    required property int index
                    required property var model
                    height: categories.height
                    leftPadding: Kirigami.Units.gridUnit * 0.8; rightPadding: leftPadding
                    contentItem: PC3.Label {
                        text: model.display
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: categories.currentIndex === index ? "#0d1013" : Kirigami.Theme.textColor
                    }
                    background: Rectangle {
                        radius: height / 2
                        color: categories.currentIndex === index ? launcher.accent
                             : parent.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                    }
                    onClicked: { categories.currentIndex = index; search.forceActiveFocus() }
                }
            }

            // apps
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: launcher.appsSource
                readonly property int columns: Math.max(4, Math.floor(width / (Kirigami.Units.gridUnit * 8)))
                cellWidth: Math.floor(width / columns)
                cellHeight: Kirigami.Units.gridUnit * 7.2
                keyNavigationEnabled: true
                highlightFollowsCurrentItem: false
                Keys.onReturnPressed: if (currentIndex >= 0) launcher.launch(currentIndex)
                Keys.onEnterPressed: if (currentIndex >= 0) launcher.launch(currentIndex)
                Keys.onUpPressed: event => { if (currentIndex < columns) search.forceActiveFocus(); else event.accepted = false }
                Keys.onPressed: event => {
                    // typing anywhere goes to the search field
                    if (event.text.length && event.text.trim().length && !(event.modifiers & Qt.ControlModifier)) {
                        search.forceActiveFocus(); search.text += event.text; event.accepted = true
                    }
                }

                delegate: Item {
                    id: tile
                    required property int index
                    required property var model
                    width: grid.cellWidth; height: grid.cellHeight
                    readonly property bool lit: hover.hovered || (grid.activeFocus && grid.currentIndex === index)
                                                || (launcher.searching && index === 0 && !grid.activeFocus)
                    readonly property string pinUrl: launcher.launcherUrl(model)

                    Kirigami.ImageColors { id: colors; source: tile.model.decoration }
                    onLitChanged: if (lit) colors.update()
                    readonly property color glow: {
                        const c = colors.dominant
                        return (c.a === 0 || c.hslSaturation < 0.2) ? launcher.accent
                             : Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55), Math.min(Math.max(c.hslLightness, 0.55), 0.7), 1)
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        radius: Kirigami.Units.gridUnit * 0.8
                        color: tile.lit ? Qt.rgba(tile.glow.r, tile.glow.g, tile.glow.b, 0.16) : "transparent"
                        border.width: tile.lit ? 1.5 : 0
                        border.color: Qt.rgba(tile.glow.r, tile.glow.g, tile.glow.b, 0.7)
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: Kirigami.Units.iconSizes.large * 1.15; implicitHeight: implicitWidth
                            source: tile.model.decoration
                            scale: tile.lit ? 1.1 : 1
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        }
                        PC3.Label {
                            Layout.fillWidth: true
                            text: tile.model.display
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                    // pinned to the orb
                    Rectangle {
                        visible: launcher.isPinned(tile.pinUrl)
                        anchors { top: parent.top; right: parent.right; margins: Kirigami.Units.gridUnit * 0.6 }
                        width: 8; height: 8; radius: 4
                        color: tile.glow
                    }

                    HoverHandler { id: hover; onHoveredChanged: if (hovered) grid.currentIndex = tile.index }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                tileMenu.url = tile.pinUrl
                                tileMenu.visualParent = tile
                                tileMenu.open(mouse.x, mouse.y)
                            } else {
                                launcher.launch(tile.index)
                            }
                        }
                    }
                }

                PC3.Label {
                    anchors.centerIn: parent
                    visible: launcher.searching && grid.count === 0 && !runnerModel.querying
                    text: i18n("No matching applications")
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                }
            }
        }
    }

    property PlasmaExtras.Menu tileMenu: PlasmaExtras.Menu {
        property string url: ""
        PlasmaExtras.MenuItem {
            text: launcher.isPinned(tileMenu.url) ? i18n("Unpin from orb") : i18n("Pin to orb")
            icon: launcher.isPinned(tileMenu.url) ? "window-unpin" : "window-pin"
            enabled: tileMenu.url !== ""
            onClicked: {
                if (launcher.isPinned(tileMenu.url)) launcher.tasksModel.requestRemoveLauncher(tileMenu.url)
                else launcher.tasksModel.requestAddLauncher(tileMenu.url)
            }
        }
    }
}
