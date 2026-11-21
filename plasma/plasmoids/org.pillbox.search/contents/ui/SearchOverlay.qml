/*
 * The frosted search: one window over the whole screen. Plasma draws its translucent glass
 * behind it and KWin blurs what lies underneath; in the middle sit a large search field
 * and the results. Up/Down choose, Enter opens, Esc or a click beside it closes.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

PlasmaCore.Dialog {
    id: overlay
    type: PlasmaCore.Dialog.Normal
    location: PlasmaCore.Types.Floating
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    backgroundHints: PlasmaCore.Dialog.StandardBackground
    hideOnWindowDeactivate: true
    visible: false

    property rect area: Qt.rect(0, 0, 1920, 1080)
    property rect screenRect: Qt.rect(0, 0, 1920, 1080)   // the screen of the bar the magnifier sits in
    function showNow() {
        area = screenRect
        x = area.x + Kirigami.Units.gridUnit * 0.5; y = area.y + Kirigami.Units.gridUnit * 0.5
        field.text = ""
        visible = true
        requestActivate()
        field.forceActiveFocus()
        card.shown = true
    }
    function hideNow() { card.shown = false; visible = false }
    onVisibleChanged: if (!visible) card.shown = false

    mainItem: FocusScope {
        id: scope
        // the frame of the glass adds a little on each side; keep the window inside the screen
        width: overlay.area.width - Kirigami.Units.gridUnit * 2
        height: overlay.area.height - Kirigami.Units.gridUnit * 2
        Layout.minimumWidth: width; Layout.preferredWidth: width; Layout.maximumWidth: width
        Layout.minimumHeight: height; Layout.preferredHeight: height; Layout.maximumHeight: height
        focus: true
        Keys.onEscapePressed: overlay.hideNow()

        // a click beside the card closes
        MouseArea { anchors.fill: parent; onClicked: overlay.hideNow() }

        Item {
            id: card
            property bool shown: false
            width: Math.min(parent.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 40)
            height: col.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.22
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Kirigami.Units.largeSpacing

                // ---- the field
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.gridUnit * 3.4
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.09)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                    MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.gridUnit * 1.2
                        anchors.rightMargin: Kirigami.Units.gridUnit * 1.2
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon { source: "search-symbolic"; isMask: true; color: Kirigami.Theme.textColor; opacity: 0.7
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth }
                        QQC2.TextField {
                            id: field
                            Layout.fillWidth: true
                            background: null
                            font.pixelSize: Kirigami.Units.gridUnit * 1.3
                            color: "#e9eef2"
                            placeholderText: i18n("Search apps, files, settings…")
                            placeholderTextColor: Qt.rgba(0.91, 0.93, 0.95, 0.45)
                            focus: true
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onReturnPressed: list.runCurrent()
                            Keys.onEnterPressed: list.runCurrent()
                            Keys.onEscapePressed: overlay.hideNow()
                        }
                        PC3.ToolButton {
                            visible: field.text.length > 0
                            icon.name: "edit-clear"
                            onClicked: { field.text = ""; field.forceActiveFocus() }
                        }
                    }
                }

                // ---- the results
                Rectangle {
                    Layout.fillWidth: true
                    visible: field.text.length > 0
                    implicitHeight: Math.min(list.contentHeight, Kirigami.Units.gridUnit * 24) + Kirigami.Units.largeSpacing * 2
                    radius: Kirigami.Units.gridUnit * 1.2
                    color: Qt.rgba(0.06, 0.075, 0.1, 0.55)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                    ListView {
                        id: list
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 120
                        model: Milou.ResultsModel {
                            id: results
                            queryString: field.text
                            limit: 12
                            onModelReset: list.currentIndex = 0
                            onRowsInserted: if (list.currentIndex < 0) list.currentIndex = 0
                        }
                        function runCurrent() {
                            if (count === 0) return
                            if (results.run(results.index(Math.max(0, currentIndex), 0))) overlay.hideNow()
                        }
                        section.property: "category"
                        section.criteria: ViewSection.FullString
                        section.delegate: PC3.Label {
                            required property string section
                            width: ListView.view.width
                            leftPadding: Kirigami.Units.largeSpacing
                            topPadding: Kirigami.Units.smallSpacing * 2
                            bottomPadding: Kirigami.Units.smallSpacing
                            text: section
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.letterSpacing: 1.1
                            font.capitalization: Font.AllUppercase
                            opacity: 0.5
                        }
                        highlight: Rectangle {
                            radius: Kirigami.Units.gridUnit * 0.8
                            color: Qt.rgba(1, 1, 1, 0.1)
                        }
                        delegate: MouseArea {
                            id: row
                            required property int index
                            required property var model
                            width: ListView.view.width
                            height: Kirigami.Units.gridUnit * 2.6
                            hoverEnabled: true
                            onEntered: list.currentIndex = index
                            onClicked: { list.currentIndex = index; list.runCurrent() }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Kirigami.Units.largeSpacing
                                anchors.rightMargin: Kirigami.Units.largeSpacing
                                spacing: Kirigami.Units.largeSpacing
                                Kirigami.Icon { source: row.model.decoration; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                                PC3.Label { text: row.model.display; color: "#e9eef2"; elide: Text.ElideRight; Layout.maximumWidth: parent.width * 0.6; font.weight: list.currentIndex === row.index ? Font.DemiBold : Font.Normal }
                                PC3.Label { text: row.model.subtext || ""; opacity: 0.55; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                    }
                }
                PC3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    visible: field.text.length === 0
                    text: i18n("↑ ↓ choose · Enter opens · Esc closes")
                    opacity: 0.5
                }
            }
        }
    }
}
