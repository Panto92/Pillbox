// Time-of-day palette shared by all scenes.  SPDX-License-Identifier: MIT
.pragma library

var KEYS = [
    [0, [5, 8, 14], [18, 24, 34], 0.22, 1], [5.5, [16, 20, 32], [52, 56, 72], 0.35, 0.6],
    [7, [58, 66, 90], [200, 150, 128], 0.72, 0.1], [10, [86, 118, 142], [178, 196, 206], 1, 0],
    [17, [80, 104, 126], [170, 178, 186], 0.95, 0], [19.6, [56, 50, 76], [214, 132, 98], 0.62, 0.15],
    [21.5, [11, 14, 24], [32, 36, 52], 0.28, 0.85], [24, [5, 8, 14], [18, 24, 34], 0.22, 1]
]
function lerp(a, b, t) { return a + (b - a) * t }
function mix(a, b, t) { return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)] }
function col(c, a) { return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, a === undefined ? 1 : a) }

// {top, bot, light, star} for an hour 0..24, tinted towards `tint` by k
function sky(h, tint, k) {
    h = ((h % 24) + 24) % 24
    for (var i = 0; i < KEYS.length - 1; i++) {
        var a = KEYS[i], b = KEYS[i + 1]
        if (h >= a[0] && h <= b[0]) {
            var f = (h - a[0]) / (b[0] - a[0]), e = f * f * (3 - 2 * f)
            return { top: mix(mix(a[1], b[1], e), tint, k), bot: mix(mix(a[2], b[2], e), tint, k * 1.2),
                     light: lerp(a[3], b[3], e), star: lerp(a[4], b[4], e) }
        }
    }
    return { top: KEYS[0][1], bot: KEYS[0][2], light: KEYS[0][3], star: KEYS[0][4] }
}
// sun position as fractions of the scene (x 0..1, y 0..1), up = above the horizon
function sun(h, horizon) {
    var day = Math.max(0, Math.min(1, (h - 6) / 14))
    return { x: 0.12 + 0.76 * day, y: horizon - 0.5 * Math.sin(Math.PI * day) + 0.05, up: h > 6 && h < 20 }
}
// stable pseudo-random 0..1 for (index, salt) – same layout on every start
function rnd(i, s) { var v = Math.sin(i * 12.9898 + s * 78.233) * 43758.5453; return v - Math.floor(v) }
