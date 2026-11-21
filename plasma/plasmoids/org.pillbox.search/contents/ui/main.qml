/*
 * Pillbox Search – a magnifier in the bar. A click, or Meta+Space, frosts the whole screen
 * and puts one large glass search field in the middle; results come from the same search
 * services as KRunner (apps, files, settings, calculator, windows …).
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false          // the shortcut opens the overlay, not an (empty) popup
    toolTipMainText: i18n("Search")
    toolTipSubText: i18n("Apps, files, settings and more – Meta+Space")

    SearchOverlay { id: overlay; screenRect: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 1920, 1080) }
    function toggle() { if (overlay.visible) overlay.hideNow(); else overlay.showNow() }

    // Meta+Space, once – after that the user's own choice in the widget settings wins
    Component.onCompleted: {
        if (!Plasmoid.configuration.shortcutSet) {
            if (!Plasmoid.globalShortcut || String(Plasmoid.globalShortcut) === "") Plasmoid.globalShortcut = "Meta+Space"
            Plasmoid.configuration.shortcutSet = true
        }
    }
    Connections { target: Plasmoid; function onActivated() { root.expanded = false; root.toggle() } }

    compactRepresentation: MouseArea {
        id: btn
        Layout.minimumWidth: height
        Layout.preferredWidth: height
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: root.toggle()
        Rectangle {
            anchors.centerIn: parent
            width: parent.height * 0.78; height: width; radius: width / 2
            color: Kirigami.Theme.textColor
            opacity: btn.containsMouse ? 0.1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            source: "search-symbolic"
            width: Math.round(parent.height * 0.45); height: width
            isMask: true
            color: Kirigami.Theme.textColor
        }
    }
    fullRepresentation: Item {}
}
