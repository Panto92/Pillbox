/*
 * Settings page for Pillbox Atmosphere (System Settings → Wallpaper).
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page
    property string cfg_Scene
    property alias cfg_FollowTime: follow.checked
    property alias cfg_FixedHour: hour.value
    property string cfg_Reactivity
    property string cfg_Motion
    property alias cfg_PauseWhenCovered: pause.checked

    component Choice: QQC2.ComboBox {
        property string key
        textRole: "text"; valueRole: "value"
        currentIndex: Math.max(0, indexOfValue(page["cfg_" + key]))
        onActivated: page["cfg_" + key] = currentValue
    }

    Choice {
        Kirigami.FormData.label: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Atmosphere:")
        key: "Scene"
        model: [
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Flow – soft clouds of colour"), value: "flow" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Horizon – flat hills, one clear sun"), value: "horizon" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Fogline – misty lake under mountains"), value: "fogline" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Dune – desert, layered dunes"), value: "dune" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Aurora – polar night, a lone hut"), value: "aurora" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Tide – open sea"), value: "tide" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Neon – a city at night"), value: "neon" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Frost – frozen lake at sunrise"), value: "frost" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Market – Christmas market in the snow"), value: "market" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Alpine – mountain village under stars"), value: "alpine" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Polar – northern lights over the river"), value: "polar" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Orbit – a planet in space"), value: "orbit" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Contour – topographic lines"), value: "contour" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Grid – a field of dots"), value: "grid" }
        ]
    }
    QQC2.CheckBox {
        id: follow
        Kirigami.FormData.label: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Time of day:")
        text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Follow the clock")
    }
    QQC2.Slider {
        id: hour
        visible: !follow.checked
        from: 0; to: 23.75; stepSize: 0.25
        Kirigami.FormData.label: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Fixed time:")
        QQC2.ToolTip.text: Math.floor(value) + ":" + String(Math.round((value % 1) * 60)).padStart(2, "0")
        QQC2.ToolTip.visible: pressed || hovered
    }
    Choice {
        Kirigami.FormData.label: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Reacts to your computer:")
        key: "Reactivity"
        model: [
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Off"), value: "off" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Subtle"), value: "subtle" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Strong"), value: "strong" }
        ]
    }
    Choice {
        Kirigami.FormData.label: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Motion:")
        key: "Motion"
        model: [
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Calm"), value: "calm" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Normal"), value: "normal" },
            { text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Lively"), value: "lively" }
        ]
    }
    QQC2.CheckBox {
        id: pause
        Kirigami.FormData.label: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Battery & power:")
        text: i18nd("plasma_wallpaper_org.pillbox.atmosphere", "Pause while a maximised or fullscreen window covers the screen")
    }
}
