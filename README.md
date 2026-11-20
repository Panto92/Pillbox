# Pillbox

A calm, modern desktop for **KDE Plasma 6** – floating "pill" panels, a muted
grey-blue palette and a compact system readout.

> **Status:** 0.1 – early, but usable. Feedback welcome.

## Why

Most "rices" with this look are built for Hyprland and need a dozen moving
parts. Pillbox gets close to that look with **plain Plasma**:

- no compiled code – only QML, SVG and Plasma's layout scripts
- the global theme **only references things that ship with Plasma or with
  Pillbox** – no missing icons or cursors after you apply it
- missing style images fall back to Breeze, so Plasma updates don't break it
- installs into your home directory, **no sudo**, with a backup and an uninstaller

## What's inside

| Component | Description |
|---|---|
| Global theme `Pillbox` | Colors, Plasma style, Breeze Dark icons, Breeze cursor |
| Layout | Top: three floating pills – stats · clock · media/tray/power. Bottom: floating dock |
| Widget `Pillbox Stats` | `CPU 12%  GPU 4%  RAM 31%  45°C` – uses Plasma's own system sensors (works with NVIDIA, AMD, Intel) |
| Color scheme + Plasma style | Muted grey-blue, dark |
| Konsole profile | Matching colors, comfortable margins |
| fastfetch config | Optional, compact and muted |

## Install

```bash
git clone https://github.com/Panto92/Pillbox.git pillbox
cd pillbox
./install.sh            # install only – nothing on your desktop changes yet
./install.sh --apply    # + apply colors/style/icons, keep your panels
./install.sh --layout   # + replace your panels with the Pillbox layout
```

Every option that changes your desktop first backs up your settings to
`~/.local/share/pillbox/backups/`.

Requirements: KDE Plasma 6.0 or newer.

## Uninstall

```bash
./uninstall.sh
```

## Credits

The look is inspired by [43PR's Hyprland dotfiles](https://github.com/43PR/dotfiles)
(MIT). Pillbox is an independent re-implementation for KDE Plasma and contains
no code from that project.

## License

[MIT](LICENSE)
