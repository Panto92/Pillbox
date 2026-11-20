// Soft round glow centred on the parent's origin.  SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Shapes
import "palette.js" as P
Shape {
    id: g
    property real r: 100
    property var tone: [255, 255, 255]
    property real strength: 0.2
    x: -r; y: -r; width: r * 2; height: r * 2
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: g.r; centerY: g.r; centerRadius: g.r; focalX: g.r; focalY: g.r
            GradientStop { position: 0; color: P.col(g.tone, g.strength) }
            GradientStop { position: 1; color: P.col(g.tone, 0) }
        }
        PathAngleArc { centerX: g.r; centerY: g.r; radiusX: g.r; radiusY: g.r; startAngle: 0; sweepAngle: 360 }
    }
}
