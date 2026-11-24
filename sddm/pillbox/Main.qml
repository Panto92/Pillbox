/*
 * Pillbox login screen (SDDM). A living atmosphere behind a large clock and one
 * glass card. The scenes are the same as the Pillbox wallpaper; the installer copies
 * them into scenes/ next to this file.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kirigami.primitives as KirigamiPrimitives

Item {
    id: root
    width: 1920
    height: 1080

    readonly property color accent: config.accent || "#8fb0c2"

    // English by default, German when the system speaks German (SDDM themes have no catalogue of their own)
    readonly property bool german: Qt.locale().name.indexOf("de") === 0
    function tr(en, de) { return german ? de : en }
    readonly property color ink: "#0b0e12"
    readonly property color frost: "#e9eef2"
    readonly property color paper: "#cdd5db"
    readonly property color mist: "#8a96a0"

    // ---- preview (sddm-greeter --test-mode): always a way out
    readonly property bool preview: Qt.application.arguments.indexOf("--test-mode") >= 0
    focus: true
    Keys.onEscapePressed: if (preview) Qt.quit()
    Timer { interval: 120000; running: root.preview; onTriggered: Qt.quit() }

    // ---- time
    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }
    readonly property real hour: now.getHours() + now.getMinutes() / 60

    // ---- the scene's environment (what the wallpaper's main.qml provides)
    QtObject {
        id: env
        property real hour: root.hour
        property real time: 0
        property real cpu: 0
        property real gpu: 0
        property real motion: 1
        property bool running: true
        property var cfg: ({ Scene: root.sceneName })
        signal newNotification()
    }
    Timer { interval: 83; repeat: true; running: true; onTriggered: env.time += interval / 1000 * 0.6 }

    readonly property string sceneName: {
        const c = String(config.scene || "auto")
        if (c === "painted") return "aurora"          // the photo lives in the user's home – not readable here
        if (c !== "auto") return c
        const h = hour
        return h < 6.5 || h >= 20.5 ? "aurora" : h < 10 ? "fogline" : h < 17 ? "horizon" : "dune"
    }
    readonly property var sceneFiles: ({ flow: "FlowScene.qml", horizon: "HorizonScene.qml", fogline: "FoglineScene.qml",
                                         dune: "DuneScene.qml", aurora: "AuroraScene.qml", tide: "TideScene.qml",
                                         neon: "NeonScene.qml", yule: "YuleScene.qml", orbit: "OrbitScene.qml",
                                         frost: "PaintedScene.qml", market: "PaintedScene.qml", alpine: "PaintedScene.qml", polar: "PaintedScene.qml", contour: "ContourScene.qml", grid: "GridScene.qml" })

    // one background per screen; the card sits on the primary one
    Repeater {
        model: screenModel
        delegate: Item {
            required property rect geometry
            x: geometry.x; y: geometry.y; width: geometry.width; height: geometry.height
            Rectangle { anchors.fill: parent; color: "#070a10" }
            Loader {
                anchors.fill: parent
                source: "scenes/" + (root.sceneFiles[root.sceneName] || "AuroraScene.qml")
                onLoaded: item.env = env
            }
            // a soft veil so the card and clock always read well
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.02, 0.03, 0.05, 0.35) }
                    GradientStop { position: 0.5; color: Qt.rgba(0.02, 0.03, 0.05, 0.1) }
                    GradientStop { position: 1; color: Qt.rgba(0.02, 0.03, 0.05, 0.55) }
                }
            }
        }
    }

    readonly property rect main: {
        const n = screenModel.rowCount ? screenModel.rowCount() : 0
        const p = typeof screenModel.primary === "number" ? screenModel.primary : 0
        const g = n > 0 ? screenModel.data(screenModel.index(Math.max(0, Math.min(n - 1, p)), 0), Qt.UserRole + 2) : undefined
        return g && g.width ? g : Qt.rect(0, 0, root.width, root.height)
    }

    // ---------------------------------------------------------------- clock
    Item {
        x: root.main.x; y: root.main.y; width: root.main.width; height: root.main.height

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.12
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.now.toLocaleTimeString(Qt.locale(), "HH:mm")
                color: root.frost
                font.pixelSize: Math.round(parent.parent.height * 0.12)
                font.weight: Font.Light
                font.letterSpacing: -2
                font.features: { "tnum": 1 }
                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.15)
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.now.toLocaleDateString(Qt.locale(), "dddd, d. MMMM")
                color: root.paper
                font.pixelSize: Math.round(parent.parent.height * 0.022)
                font.weight: Font.Medium
            }
        }

        // ------------------------------------------------------------ the card
        Rectangle {
            id: card
            readonly property int pad: 28
            width: Math.min(420, parent.width - 48)
            height: cardCol.implicitHeight + pad * 2
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.5
            radius: 28
            color: Qt.rgba(0.06, 0.075, 0.1, 0.62)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            // shake on a wrong password
            transform: Translate { id: shakeT }
            SequentialAnimation {
                id: shake
                loops: 1
                NumberAnimation { target: shakeT; property: "x"; to: -14; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: 12; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: 5; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
            }

            ColumnLayout {
                id: cardCol
                x: card.pad; y: card.pad
                width: card.width - card.pad * 2
                spacing: 14

                // more than one user: pick one
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    visible: userList.count > 1
                    spacing: 8
                    Repeater {
                        id: userList
                        model: userModel
                        delegate: Rectangle {
                            required property int index
                            required property string name
                            required property string realName
                            width: chipText.implicitWidth + 24; height: 28; radius: 14
                            color: index === login.userIndex ? root.accent : Qt.rgba(1, 1, 1, 0.08)
                            Text { id: chipText; anchors.centerIn: parent; text: realName || name; color: index === login.userIndex ? root.ink : root.paper; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { login.userIndex = index; password.forceActiveFocus() } }
                        }
                    }
                }

                // avatar
                Item {
                    id: login
                    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
                    function role(r) { return userModel.data(userModel.index(userIndex, 0), r) }
                    readonly property string userName: role(Qt.UserRole + 1) || userModel.lastUser || ""
                    readonly property string realName: role(Qt.UserRole + 2) || userName
                    // the picture from Plasma's user settings (AccountsService) first – it is what the
                    // desktop shows – then whatever SDDM offers (often an old ~/.face.icon)
                    readonly property var faces: {
                        const list = []
                        if (userName) list.push("file:///var/lib/AccountsService/icons/" + userName)
                        const r = role(Qt.UserRole + 4) || ""
                        if (r) list.push(r.indexOf("file:") === 0 ? r : "file://" + r)
                        return list
                    }
                    property int faceIndex: 0
                    onUserNameChanged: faceIndex = 0
                    readonly property string iconPath: faceIndex < faces.length ? faces[faceIndex] : ""
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 92; implicitHeight: 92
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 2
                        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                        clip: true
                        KirigamiPrimitives.ShadowedImage {
                            id: face
                            anchors.fill: parent; anchors.margins: 3
                            radius: width / 2
                            source: login.iconPath
                            onStatusChanged: if (status === Image.Error) login.faceIndex++
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            color: "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            text: login.realName.length ? login.realName.charAt(0).toUpperCase() : "?"
                            color: root.frost
                            font.pixelSize: 38; font.weight: Font.DemiBold
                        }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: login.realName
                    color: root.frost
                    font.pixelSize: 22; font.weight: Font.DemiBold
                }

                // password pill with the arrow inside
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 48
                    radius: 24
                    color: Qt.rgba(1, 1, 1, password.activeFocus ? 0.12 : 0.08)
                    border.width: 1
                    border.color: password.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8) : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    QQC2.TextField {
                        id: password
                        anchors { left: parent.left; right: go.left; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 6 }
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        placeholderText: root.tr("Password", "Passwort")
                        placeholderTextColor: root.mist
                        color: root.frost
                        font.pixelSize: 15
                        background: null
                        focus: true
                        enabled: !root.busy
                        Keys.onReturnPressed: root.doLogin()
                        Keys.onEnterPressed: root.doLogin()
                        Component.onCompleted: forceActiveFocus()
                    }
                    Rectangle {
                        id: go
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
                        width: 36; height: 36; radius: 18
                        color: password.text.length ? root.accent : Qt.rgba(1, 1, 1, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: root.busy ? "…" : "→"
                            color: password.text.length ? root.ink : root.paper
                            font.pixelSize: 18; font.weight: Font.DemiBold
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
                    }
                }
                Text {
                    id: message
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: text.length ? 18 : 0
                    visible: text.length > 0
                    text: root.failed ? root.tr("Wrong password. Please try again.", "Falsches Passwort. Versuch es noch einmal.")
                        : keyboard.capsLock ? root.tr("Caps Lock is on", "Feststelltaste ist an")
                        : ""
                    color: root.failed ? "#ffb1a6" : root.paper
                    font.pixelSize: 13
                }
            }
        }

        // ------------------------------------------------------------ bottom bar
        RowLayout {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 28 }
            spacing: 10

            // session
            Rectangle {
                implicitWidth: sessionText.implicitWidth + 40; implicitHeight: 36; radius: 18
                color: Qt.rgba(0.06, 0.075, 0.1, 0.55)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                Text {
                    id: sessionText
                    anchors.centerIn: parent
                    text: root.sessionName + "  ▾"
                    color: root.paper; font.pixelSize: 13
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sessionMenu.popup() }
                QQC2.Menu {
                    id: sessionMenu
                    Repeater {
                        model: sessionModel
                        delegate: QQC2.MenuItem {
                            required property int index
                            required property string name
                            text: name
                            onTriggered: root.sessionIndex = index
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            PowerPill { label: root.tr("Sleep", "Standby"); icon: "system-suspend"; shown: sddm.canSuspend; onActivated: sddm.suspend() }
            PowerPill { label: root.tr("Restart", "Neustart"); icon: "system-reboot"; shown: sddm.canReboot; onActivated: sddm.reboot() }
            PowerPill { label: root.tr("Shut down", "Ausschalten"); icon: "system-shutdown"; shown: sddm.canPowerOff; onActivated: sddm.powerOff() }
        }
    }

    // the way out of the preview, top right on every screen
    Repeater {
        model: root.preview ? screenModel : 0
        delegate: Rectangle {
            required property rect geometry
            x: geometry.x + geometry.width - width - 24; y: geometry.y + 24
            width: quitRow.implicitWidth + 32; height: 40; radius: 20
            color: quitMouse.containsMouse ? root.accent : Qt.rgba(0.06, 0.075, 0.1, 0.75)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.15)
            Row {
                id: quitRow
                anchors.centerIn: parent
                spacing: 8
                Text { text: root.tr("Close preview", "Vorschau beenden"); color: quitMouse.containsMouse ? root.ink : root.frost; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text { text: "✕"; color: quitMouse.containsMouse ? root.ink : root.frost; font.pixelSize: 14 }
            }
            MouseArea { id: quitMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
        }
    }
    Text {
        visible: root.preview
        x: root.main.x + 24; y: root.main.y + 32
        text: root.tr("Preview · Esc closes", "Vorschau · Esc schließt")
        color: root.paper; opacity: 0.7; font.pixelSize: 13
    }

    component PowerPill: Rectangle {
        id: pp
        property string label
        property string icon
        property bool shown: true
        signal activated()
        enabled: shown
        opacity: shown ? 1 : 0.45
        implicitWidth: ppRow.implicitWidth + 28; implicitHeight: 36; radius: 18
        color: ppMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.06, 0.075, 0.1, 0.55)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: ppRow
            anchors.centerIn: parent
            spacing: 8
            Kirigami.Icon { source: pp.icon; width: 16; height: 16; color: root.paper; isMask: true; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pp.label; color: root.paper; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: ppMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pp.activated() }
    }

    // ---------------------------------------------------------------- login
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property string sessionName: {
        const v = sessionModel.data(sessionModel.index(sessionIndex, 0), Qt.UserRole + 4)
        return v ? String(v) : "Plasma"
    }
    property bool busy: false
    property bool failed: false
    function doLogin() {
        if (busy || !password.text.length) return
        busy = true; failed = false
        sddm.login(login.userName, password.text, sessionIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; root.failed = true
            password.text = ""
            shake.restart()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() { root.busy = false }
    }
}
