/*
 * Live window previews for one app in the ring (like Plasma's task manager tooltips).
 * Opens outward from the ring/dock next to the hovered slot, with its own
 * calm fade-and-grow (no KWin slide), and glides along when the slot changes.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire

PlasmaCore.Dialog {
    id: popup

    property var tasksModel
    property int appRow: -1                // row of the app in tasksModel
    property bool isGroup: false
    property string appName: ""
    property var appIcon
    property color accent: "#8fb0c2"
    property real angle: 0                 // direction of the slot from the orb (radians)
    property Item anchorItem: null         // the slot we open next to
    readonly property bool hovered: hover.hovered
    property bool appear: false            // drives the open animation

    // unit vector pointing away from the orb / dock
    readonly property real dx: Math.abs(Math.cos(angle)) > 0.7 ? Math.sign(Math.cos(angle)) : 0
    readonly property real dy: dx === 0 ? (Math.sin(angle) < 0 ? -1 : 1) : 0

    function place() {
        if (!anchorItem || !anchorItem.Window.window) return
        const g = anchorItem.mapToGlobal(anchorItem.width / 2, anchorItem.height / 2)
        const gap = 14
        let px = g.x - width / 2, py = g.y - height / 2
        if (dy < 0) py = g.y - anchorItem.height / 2 - gap - height
        if (dy > 0) py = g.y + anchorItem.height / 2 + gap
        if (dx < 0) px = g.x - anchorItem.width / 2 - gap - width
        if (dx > 0) px = g.x + anchorItem.width / 2 + gap
        // keep it on the monitor the slot is on
        const sc = Qt.application.screens.find(s => g.x >= s.virtualX && g.x < s.virtualX + s.width && g.y >= s.virtualY && g.y < s.virtualY + s.height)
        if (sc) {
            px = Math.max(sc.virtualX + 8, Math.min(px, sc.virtualX + sc.width - width - 8))
            py = Math.max(sc.virtualY + 8, Math.min(py, sc.virtualY + sc.height - height - 8))
        }
        x = Math.round(px); y = Math.round(py)
    }
    function open() {
        const wasOpen = visible
        place()
        if (!wasOpen) { appear = false; visible = true; Qt.callLater(() => { place(); appear = true }) }
    }
    function close() { appear = false; visible = false }
    onWidthChanged: if (visible) place()
    onHeightChanged: if (visible) place()
    // gliding between slots instead of popping
    Behavior on x { enabled: popup.appear; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: popup.appear; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    signal activated()                     // a window was chosen: caller closes the ring

    type: PlasmaCore.Dialog.Tooltip
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: false
    // Floating + our own position: no KWin slide-in, we animate ourselves
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground

    readonly property int thumbW: Kirigami.Units.gridUnit * 12
    readonly property int thumbH: Math.round(thumbW * 0.62)

    // Plasma dialogs size themselves from mainItem's width/height, not its implicit size
    mainItem: Item {
        readonly property int padding: Kirigami.Units.largeSpacing
        width: column.implicitWidth + padding * 2
        height: column.implicitHeight + padding * 2
        HoverHandler { id: hover }

        // everything below animates as one piece: fade in, grow from the slot side, settle
        Item {
            id: body
            anchors.fill: parent
            opacity: popup.appear ? 1 : 0
            scale: popup.appear ? 1 : 0.94
            transformOrigin: popup.dy < 0 ? Item.Bottom : popup.dy > 0 ? Item.Top : popup.dx < 0 ? Item.Right : Item.Left
            transform: Translate {
                x: popup.appear ? 0 : -popup.dx * 8
                y: popup.appear ? 0 : -popup.dy * 8
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            // glass
            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.gridUnit * 0.9
                color: Qt.rgba(0.05, 0.06, 0.08, 0.93)
                border.width: 1
                border.color: Qt.rgba(popup.accent.r, popup.accent.g, popup.accent.b, 0.35)
            }

    ColumnLayout {
        id: column
        x: parent.parent.padding; y: parent.parent.padding
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon { source: popup.appIcon; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
            PC3.Label { text: popup.appName; font.weight: Font.DemiBold; Layout.fillWidth: true; Layout.minimumWidth: popup.thumbW - Kirigami.Units.iconSizes.small; elide: Text.ElideRight }
        }

        Row {
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                // a group lists its windows as children; a single window is the row itself
                model: DelegateModel {
                    model: popup.tasksModel
                    rootIndex: popup.isGroup && popup.appRow >= 0 ? popup.tasksModel.makeModelIndex(popup.appRow) : undefined
                    delegate: Thumb {
                        required property int index
                        required property var model
                        visible: popup.isGroup || index === popup.appRow
                        width: visible ? popup.thumbW : 0
                        // cards fan in one after another
                        opacity: popup.appear ? 1 : 0
                        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: popup.appear ? 60 + (popup.isGroup ? index : 0) * 40 : 0 } NumberAnimation { duration: 200 } } }
                        title: model.display || ""
                        winId: model.WinIdList && model.WinIdList.length ? String(model.WinIdList[0]) : ""
                        minimized: model.IsMinimized === true
                        active: model.IsActive === true
                        accent: popup.accent
                        thumbHeight: popup.thumbH
                        onChosen: {
                            popup.tasksModel.requestActivate(popup.isGroup ? popup.tasksModel.makeModelIndex(popup.appRow, index) : popup.tasksModel.makeModelIndex(index))
                            popup.activated()
                        }
                        onCloseRequested: popup.tasksModel.requestClose(popup.isGroup ? popup.tasksModel.makeModelIndex(popup.appRow, index) : popup.tasksModel.makeModelIndex(index))
                    }
                }
            }
        }
    }
        }
    }

    component Thumb: Item {
        id: thumb
        property string title
        property string winId
        property bool minimized
        property bool active
        property color accent
        property int thumbHeight: 120
        signal chosen()
        signal closeRequested()

        height: thumbHeight + titleLabel.implicitHeight + Kirigami.Units.smallSpacing

        Rectangle {
            id: frame
            width: parent.width; height: thumb.thumbHeight
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(0, 0, 0, 0.35)
            border.width: thumbHover.hovered || thumb.active ? 2 : 1
            border.color: thumbHover.hovered ? thumb.accent : thumb.active ? Qt.rgba(thumb.accent.r, thumb.accent.g, thumb.accent.b, 0.6) : Qt.rgba(1, 1, 1, 0.12)
            clip: true

            PipeWire.PipeWireSourceItem {
                id: live
                anchors.fill: parent
                anchors.margins: 3
                nodeId: request.nodeId
                visible: request.nodeId > 0 && !thumb.minimized
                enabled: visible
                opacity: thumbHover.hovered ? 1 : 0.92
                TaskManager.ScreencastingRequest { id: request; uuid: thumb.winId }
            }
            // fallback while the stream starts, or for minimised windows
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.large; height: width
                source: popup.appIcon
                visible: !live.visible
                opacity: 0.6
            }
            PC3.Label {
                anchors { right: parent.right; bottom: parent.bottom; margins: Kirigami.Units.smallSpacing }
                visible: thumb.minimized
                text: i18n("minimized")
                font: Kirigami.Theme.smallFont
                opacity: 0.8
            }
            PC3.ToolButton {
                anchors { right: parent.right; top: parent.top; margins: 2 }
                visible: thumbHover.hovered
                icon.name: "window-close"
                display: PC3.AbstractButton.IconOnly
                text: i18n("Close window")
                onClicked: thumb.closeRequested()
            }
            HoverHandler { id: thumbHover }
            TapHandler { onTapped: thumb.chosen() }
        }
        PC3.Label {
            id: titleLabel
            anchors.top: frame.bottom
            anchors.topMargin: Kirigami.Units.smallSpacing / 2
            width: parent.width
            text: thumb.title
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
            opacity: 0.85
        }
    }
}
