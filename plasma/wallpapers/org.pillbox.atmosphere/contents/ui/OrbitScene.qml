/*
 * Orbit – a planet rising from the bottom of the screen. CPU: the asteroid belt
 * turns faster. GPU: the planet's atmosphere glows. Unread: a comet passes.
 * The time of day turns its lit side.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 15
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property var sky: P.sky(hour, [40, 50, 90], 0.2)
    readonly property real r: height * 0.5
    readonly property real cx: width * 0.5
    readonly property real cy: height * 0.36 + r
    readonly property real lx: Math.sin((hour / 24) * Math.PI * 2 - Math.PI)       // light from left at night, right by day
    readonly property string kind: ((env && env.cfg && env.cfg.OrbitPlanet) || "blue")
    readonly property var surf: kind === "red" ? [[215, 130, 95], "#5a2a1e"] : kind === "gold" ? [[230, 195, 130], "#5c4626"] : [[125, 170, 220], "#25405f"]
    readonly property var air: P.mix(kind === "red" ? [255, 150, 120] : kind === "gold" ? [255, 220, 150] : [110, 170, 255], [255, 140, 80], gpu * 0.8)
    readonly property real tilt: -14 * Math.PI / 180

    Rectangle { anchors.fill: parent; color: P.col(P.mix([4, 6, 12], scene.sky.top, 0.18)) }
    Stars { count: 200; band: 1; strength: 0.9 }

    component Rock: Rectangle {
        required property int index
        readonly property real a: P.rnd(index, 1) * Math.PI * 2 + scene.t * (0.02 + P.rnd(index, 2) * 0.012)
        readonly property real ex: Math.cos(a) * scene.r * 1.75
        readonly property real ey: Math.sin(a) * scene.r * 0.26
        z: Math.sin(a) >= 0 ? 2 : 0           // in front of or behind the planet (z 1)
        x: scene.cx + ex * Math.cos(scene.tilt) - ey * Math.sin(scene.tilt)
        y: scene.cy + ex * Math.sin(scene.tilt) + ey * Math.cos(scene.tilt) + (P.rnd(index, 3) - 0.5) * scene.r * 0.06
        width: 1.5 + P.rnd(index, 4) * 3; height: width; radius: width / 2
        color: "#c8ccd6"; opacity: 0.45 + P.rnd(index, 5) * 0.4
    }
    // the belt itself: a faint static band, back half behind the planet, front half before it
    component BeltHalf: Shape {
        property bool front: false
        anchors.fill: parent
        z: front ? 2 : 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(0.8, 0.84, 0.9, 0.07)
            strokeWidth: scene.r * 0.06
            capStyle: ShapePath.FlatCap
            PathPolyline {
                path: {
                    const pts = []
                    for (let i = 0; i <= 90; ++i) {
                        const a = (front ? 0 : Math.PI) + i / 90 * Math.PI
                        const ex = Math.cos(a) * scene.r * 1.75, ey = Math.sin(a) * scene.r * 0.26
                        pts.push(Qt.point(scene.cx + ex * Math.cos(scene.tilt) - ey * Math.sin(scene.tilt), scene.cy + ex * Math.sin(scene.tilt) + ey * Math.cos(scene.tilt)))
                    }
                    return pts
                }
            }
        }
    }
    BeltHalf { front: false }
    BeltHalf { front: true }
    Repeater { model: 110; Rock {} }

    // atmosphere: a thin glowing rim
    Shape {
        id: rim
        readonly property real rr: scene.r * 1.1
        x: scene.cx - rr; y: scene.cy - rr; width: rr * 2; height: rr * 2
        z: 1
        opacity: 0.45 + scene.gpu * 0.55
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: rim.rr; centerY: rim.rr; centerRadius: rim.rr; focalX: rim.rr; focalY: rim.rr
                GradientStop { position: 0.86; color: P.col(scene.air, 0) }
                GradientStop { position: 0.905; color: P.col(scene.air, 0.55) }
                GradientStop { position: 1; color: P.col(scene.air, 0) }
            }
            PathAngleArc { centerX: rim.rr; centerY: rim.rr; radiusX: rim.rr; radiusY: rim.rr; startAngle: 0; sweepAngle: 360 }
        }
    }
    // the planet, lit from the side the clock points to
    Shape {
        id: planet
        x: scene.cx - scene.r; y: scene.cy - scene.r; width: scene.r * 2; height: scene.r * 2
        z: 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: scene.r + scene.lx * scene.r * 0.55; centerY: scene.r * 0.45
                focalX: centerX; focalY: centerY; centerRadius: scene.r * 1.35
                GradientStop { position: 0; color: P.col(P.mix(scene.surf[0], scene.air, 0.15)) }
                GradientStop { position: 0.45; color: scene.surf[1] }
                GradientStop { position: 1; color: "#060910" }
            }
            PathAngleArc { centerX: scene.r; centerY: scene.r; radiusX: scene.r; radiusY: scene.r; startAngle: 0; sweepAngle: 360 }
        }
    }

    Meteor { id: comet; z: 3; width: scene.width * 0.14; height: 3; duration: 2600; tone: "#d8ecff" }
    Connections {
        target: scene.env; ignoreUnknownSignals: true
        function onNewNotification() {
            const y = scene.height * (0.08 + Math.random() * 0.2)
            comet.fire(scene.width * 0.05, y, scene.width * 0.85, y + scene.height * 0.12)
        }
    }
}
