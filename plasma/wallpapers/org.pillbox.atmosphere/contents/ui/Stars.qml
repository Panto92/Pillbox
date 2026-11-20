// Static star field (never animated).  SPDX-License-Identifier: MIT
import QtQuick
import "palette.js" as P
Item {
    id: st
    property int count: 80
    property real band: 0.6          // fraction of the height that has stars
    property real strength: 1
    anchors.fill: parent
    visible: strength > 0.02
    Repeater {
        model: st.count
        Rectangle {
            required property int index
            x: P.rnd(index, 1) * st.width
            y: P.rnd(index, 2) * st.height * st.band
            width: 1.5 + (index % 3) * 0.5; height: width; radius: width / 2
            color: "#e9eef2"
            opacity: st.strength * (0.3 + (index % 5) * 0.13)
        }
    }
}
