# Pillbox Orb – behaviour spec (v0.2)

The Orb replaces the dock. It is a small glowing ball that floats above all
windows and can live anywhere on any monitor.

## The ball

| Input | Result |
|---|---|
| Hover | Normal pointer. The ball brightens, satellites slow down and move out a little. |
| Left click | Opens the **ring** around the ball. Clicking the ball again closes it. |
| Left press + drag | Moves the ball (grab cursor while held). Not possible when locked. |
| Middle click | Toggles the KWin **Overview** (all windows). |
| Right click | Menu: *Lock position*, *All applications*, *Overview*, *Remove orb help* |
| Drop an app on the ball | Pins it to the ring (from the app launcher, Dolphin or a `.desktop` file). |

The ball always lands fully on one monitor (never in the gap between two).
Its position and the lock survive restarts.

## Satellites (open windows)

Every window on the current desktop/activity orbits the ball as a small dot.

| Window state | Satellite |
|---|---|
| Normal | accent-coloured dot |
| Active | larger, brighter |
| Minimised | hollow white ring |
| Demands attention | amber, pulsing (and the ball pulses too) |
| Opened | dot grows in from the centre |
| Closed | dot disappears |

Satellites are decoration only (click-through), so they never block clicks on
windows behind them. Windows are handled in the ring.

**Minimising** any window – with its own button, a shortcut or from the ring –
flies it **into the ball**: the Orb registers itself as the minimise target, so
KWin's built-in *Magic Lamp* / *Squash* animation ends at the ball.

## The ring

Opens around the ball, clamped to the monitor. It shows every app that is
**pinned** or **running**, pinned ones first, in a fixed order so each app keeps
its direction ("muscle memory").

| Input on an app | Pinned, not running | Running, 1 window | Running, several windows |
|---|---|---|---|
| Hover | name in the centre | name + "1 window" | name + "N windows" |
| Left click | launch | activate; if already active: minimise into the orb | show **all its windows** (KWin *Present Windows* for that app) |
| Middle click | launch | new window | new window |
| Right click | menu: *Unpin* | menu: *New window, Pin/Unpin, Close* | menu: *New window, Show all windows, Pin/Unpin, Close all* |

Below each running app: one dot per window (max 3).
A dashed **+** slot opens the app launcher; drag an app from there onto the ball.

The centre (hub) shows the hovered app; without hover it is a button for
**All applications**. The ring closes after any action, on a second click on
the ball, on `Esc` or when focus moves elsewhere.

## Keyboard

The Orb's widget shortcut (default suggestion `Meta+Space`) opens the ring.
`Meta+W` stays the Overview, `Meta+F7` shows all windows of the current app.

## For new users

`./install.sh --layout` adds the Orb and removes the bottom dock. The app
launcher moves into the left top pill, so there is always a visible menu
button, and the Orb can open it too.
