# Pillbox

A calm, modern desktop for **KDE Plasma 6**. Instead of a dock, a glowing
**Orb** floats wherever you want it: click it for a ring of your apps, drag it
anywhere, minimise windows into it. On top: three floating "pills" with your
system stats, the clock and the tray.

> **Status:** 0.7 – Orb and three dock forms, ten living wallpapers, a settings centre. Feedback welcome.

## Why

Most "rices" with this look are built for Hyprland and need a dozen moving
parts. Pillbox gets there with **plain Plasma**:

- no compiled code – only QML, SVG and Plasma's layout scripts
- the global theme **only references things that ship with Plasma or with
  Pillbox** – no missing icons or cursors after you apply it
- missing style images fall back to Breeze, so Plasma updates don't break it
- installs into your home directory, **no sudo**, keeps a backup, and
  `./uninstall.sh` brings your old desktop back

## The Orb

| | |
|---|---|
| **Click** | ring of your pinned and running apps |
| **Drag** | put it anywhere, on any monitor (right-click → *Lock position*) |
| **Hover an app in the ring** | live previews of its windows |
| **Click a running app** | bring it to the front – or, if it already is, minimise it into the Orb |
| **App with several windows** | shows all its windows side by side |
| **Middle click** | window overview |
| **All applications** | full-screen launcher with search and categories |
| **Satellites** | your open windows orbit the ball; minimised windows fly into it |

## Forms

Don't want a floating ball? Pick another **form** – same apps, same behaviour:

| Form | |
|---|---|
| **Orb** | the floating ball described above |
| **Ember** | a thin seam of glowing dots that unfolds into a dock on hover |
| **Shelf** | icons standing on a glass ledge; the hovered one lifts, tilts towards you and reflects |
| **Liquid** | a dock of liquid glass: a drop swells out under the pointer, lifts the icon and flows along |

Docks can sit at the **bottom, left or right**, on the main monitor, on **all
monitors** or on one you choose, and can rest **always visible**, **small until
the pointer comes** or **hidden behind a thin line**.

## Living wallpapers

**Pillbox Atmosphere** follows the time of day – blue hour, noon, evening glow,
stars – and quietly shows what your computer is doing, without a single number:

| | | CPU load | GPU load | Unread |
|---|---|---|---|---|
| **Flow** | soft clouds of colour | drift faster | warmer tones | a soft ring of light |
| **Horizon** | flat layered hills, one clear sun | haze drifts through | the sun grows warmer | a flock of birds |
| **Fogline** | misty lake under mountains | denser fog | the ridges glow | rings on the water |
| **Dune** | layered desert dunes | sand blows over the crests | heat shimmer | a shooting star |
| **Aurora** | Norwegian fjord in polar night | the aurora dances brighter | the hut's window lights up | snowfall |
| **Tide** | open sea | waves grow | the sea glows | rain over the water |
| **Neon** | a city at night | more windows light up | the signs glow | rain on a wet street |
| **Orbit** | a ringed planet | the belt turns faster | the atmosphere glows | a comet |
| **Contour** | topographic lines | lines move more | valleys glow warm | a wave runs through |
| **Grid** | a calm field of dots | a wave of light | the centre glows | a ping |

Every scene has its own options (colours, fog, sea, rain …), a **Try it** button that
plays its reactions for eight seconds, and a time-of-day slider: follow the clock or
hold the wallpaper at, say, 14:30.

Built to cost next to nothing (measured on a 3440×1440 + 1080×1920 setup,
share of *one* CPU core above a plain image wallpaper):

| | Plasma | KWin |
|---|---|---|
| Fogline | +0.1 % | +1.7 % |
| Horizon | +0.1 % | +2.6 % |
| Flow | +1.5 % | +4.5 % |
| any scene, with a maximised or fullscreen window | 0 | 0 |

How: everything is built from GPU-drawn shapes and gradients; colours change once
a minute; all motion shares one slow clock (8 / 12 / 20 fps for calm / normal /
lively) because for a wallpaper the cost is how often the whole screen must be
redrawn; a maximised or fullscreen window pauses the scene entirely.

## Login screen

A calm SDDM login screen on a living atmosphere that follows the time of day
(Aurora at night, Fogline in the morning, Horizon by day, Dune in the evening):
a large clock, one glass card, session and power buttons as small pills. A wrong
password shakes the card; Caps Lock is pointed out.

Easiest: **Customize… → Login screen → Set up…** in the settings centre. It asks once
for your password (login screens are installed system-wide); after that you pick the
atmosphere there without a password, and the accent follows the orb. By hand:

```bash
sudo ./sddm/install-login.sh            # install and switch to it
sudo ./sddm/install-login.sh --remove   # back to your previous login screen
```

It only adds `/usr/share/sddm/themes/pillbox`, `/etc/sddm.conf.d/zz-pillbox.conf` and
`/var/lib/pillbox-login/theme.conf.user` (owned by you); no existing file is changed.
Systems with another login manager (GDM, LightDM …) are detected and left alone. Pick a fixed scene in `theme.conf` (`scene=aurora`, …).
While it is installed, it takes precedence over the login theme chosen in System Settings.

## Settings

Right-click the Orb or a dock → **Customize…** opens the Pillbox settings centre:
a glass window with a sidebar – Form, Color, Wallpaper, Top bar, Behavior, Alerts,
About. Every change applies **live**; the real orb, dock and wallpaper are the
preview. Only the options of the chosen form are shown.
Full behaviour spec: [docs/orb.md](docs/orb.md).

## What's inside

| Component | Description |
|---|---|
| Widget `Pillbox Orb` | The dock replacement described above |
| Wallpaper `Pillbox Atmosphere` | Flow, Horizon, Fogline – follow the clock, react to load, pause when covered |
| Widget `Pillbox Stats` | `CPU 12%  GPU 4%  RAM 31%  45°C` from Plasma's own sensors (NVIDIA, AMD, Intel) |
| Global theme `Pillbox` | Colours, Plasma style, Breeze Dark icons, Breeze cursor |
| Layout | Top: menu + stats · clock · media/tray/power pills. The Orb replaces the dock |
| Color scheme + Plasma style | Muted grey-blue, dark |
| Konsole profile, fastfetch config | Optional extras |

English and German are included; other languages are welcome as `po/orb/<lang>.po`.

## Install

```bash
git clone https://github.com/Panto92/Pillbox.git pillbox
cd pillbox
./install.sh            # install only – your desktop does not change
./install.sh --apply    # + Pillbox colours, style and icons; your panels and dock stay
./install.sh --layout   # + the full Pillbox layout: the Orb replaces your dock
```

Before anything on your desktop changes, your settings are backed up to
`~/.local/share/pillbox/`. The first backup is kept as your pre-Pillbox state.

Requirements: KDE Plasma 6.0 or newer (Wayland recommended).

## Uninstall

```bash
./uninstall.sh                # restores your pre-Pillbox panels, dock, theme and colours
./uninstall.sh --keep-layout  # keeps your current panels, only removes Pillbox
```

## Translations

Source strings are English. To add a language, copy `po/orb/de.po` to
`po/orb/<lang>.po`, translate it and build the catalogue:

```bash
python3 tools/po2mo.py po/orb/<lang>.po \
  plasma/plasmoids/org.pillbox.orb/contents/locale/<lang>/LC_MESSAGES/plasma_applet_org.pillbox.orb.mo
```

## Credits

The look is inspired by [43PR's Hyprland dotfiles](https://github.com/43PR/dotfiles)
(MIT). Pillbox is an independent implementation for KDE Plasma and contains
no code from that project. Concept sketches: `docs/lab/pillbox-lab.html`.

## License

[MIT](LICENSE)
