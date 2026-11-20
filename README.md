# Pillbox

A calm, modern desktop for **KDE Plasma 6**. Instead of a dock, a glowing
**Orb** floats wherever you want it: click it for a ring of your apps, drag it
anywhere, minimise windows into it. On top: three floating "pills" with your
system stats, the clock and the tray.

> **Status:** 0.3 – the Orb works, incl. notifications. Feedback welcome.

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

Size, colour (or each app's own icon colour), effect (aura, pulse, calm, plain),
ring size and more: right-click the Orb → *Customize orb…*.
Full behaviour spec: [docs/orb.md](docs/orb.md).

## What's inside

| Component | Description |
|---|---|
| Widget `Pillbox Orb` | The dock replacement described above |
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
