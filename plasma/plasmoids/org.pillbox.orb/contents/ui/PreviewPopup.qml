/*
 * Live window previews for one app in the ring (like Plasma's task manager tooltips).
 * Opens outward from the ring next to the hovered slot.
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
    readonly property bool hovered: hover.hovered

    signal activated()                     // a window was chosen: caller closes the ring

    type: PlasmaCore.Dialog.Tooltip
    flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: false
    // open away from the orb: a slot above the orb gets the preview above it, and so on
    location: Math.abs(Math.sin(angle)) > Math.abs(Math.cos(angle))
              ? (Math.sin(angle) < 0 ? PlasmaCore.Types.BottomEdge : PlasmaCore.Types.TopEdge)
              : (Math.cos(angle) < 0 ? PlasmaCore.Types.RightEdge : PlasmaCore.Types.LeftEdge)

    readonly property int thumbW: Kirigami.Units.gridUnit * 12
    readonly property int thumbH: Math.round(thumbW * 0.62)

    // Plasma dialogs size themselves from mainItem's width/height, not its implicit size
    mainItem: ColumnLayout {
        width: implicitWidth
        height: implicitHeight
        spacing: Kirigami.Units.smallSpacing
        HoverHandler { id: hover }

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
