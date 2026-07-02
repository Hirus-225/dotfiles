# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal Hyprland (Wayland compositor) configuration for an Arch Linux MacBook. Not a software project — these are runtime config files read by `hyprland.conf` and the Hypr ecosystem daemons (`hypridle`, `hyprlock`). Comments throughout are in French; match that language when editing existing comments.

## Applying / testing changes

There is no build or test step. Changes take effect when Hyprland reloads its config:

- `hyprctl reload` — reload Hyprland after editing `hyprland.conf` or any `modules/*.conf`.
- `hyprlock` — preview the lock screen (`hyprlock.conf`).
- `hyprctl reload && pkill hypridle && hypridle &` — apply `hypridle.conf` changes.
- Permission changes (`modules/permissions.conf`) require a full Hyprland **restart**, not a reload — they are not applied on the fly.

Validate config syntax by watching `hyprctl reload` output, or `journalctl --user -xe -t Hyprland` for errors.

## Architecture

`hyprland.conf` is the entrypoint. It does nothing but `source` files in a fixed order (modules/*.conf), so **order matters** — colors must be sourced before the modules that consume them. The current order is: monitors → my_programs → autostart → variables → permissions → pywal colors → apparence → animations → input → keybindings → media-controls → workspaces.

Each module owns one concern:
- `my_programs.conf` — `$terminal`, `$fileManager`, `$menu` aliases used by keybindings.
- `raccourcis-clavier.conf` — keybindings. `$mainMod = SUPER`. Defines workspace nav, screenshots (grim/slurp), scratchpad (`SUPER+S` special workspace), lid-close lock.
- `media-controls.conf` — volume/brightness/media keys, all routed through **SwayOSD** (`swayosd-client`) for on-screen feedback. Keyboard backlight uses the Apple-specific `apple::kbd_backlight` LED path.
- `workspaces.conf` — window rules (floating apps, sizes, special-workspace assignment) AND resize keybinds. Uses the **V2 window-rule syntax** (`windowrule = match:class X, float true`); some rules also use the block form (`windowrule { ... }`). Keep new rules consistent with V2.
- `input.conf` — `us`/`mac` keyboard layout by default, with a per-device override (`casue-usb-kb` → French azerty). Natural scroll + 3-finger horizontal workspace gesture.
- `apparence.conf` — look & feel (gaps, blur, shadows, rounding) plus `layerrule` blur for waybar/swaync/gtklock.

## Dynamic theming (the one non-obvious system)

Colors are **not hardcoded** — they come from Pywal, generated from the current wallpaper:

1. `wal -i <wallpaper>` (run at autostart) writes `~/.cache/wal/colors`.
2. `scripts/refresh_colors.sh` reads two colors from that file and writes `~/.cache/wal/colors-hyprland.conf` defining `$color1`/`$color2`.
3. `hyprland.conf` and `hyprlock.conf` `source` that cache file. Variables like `$color1`, `$color2`, `$color4`, `$foreground` reference Pywal output — they are defined outside this repo.
4. `refresh_colors.sh` then live-reloads every themed component: waybar (`SIGUSR2`), swaync, swayosd-server (killed/relaunched), and `hyprctl reload`.

When changing wallpaper/colors, run `scripts/refresh_colors.sh` rather than reloading Hyprland directly, so all UI components pick up the new palette. Editing a `$colorN` value by hand will be overwritten on the next Pywal run.

## External dependencies referenced here

Configs assume these are installed and on PATH: `waybar`, `rofi`, `kitty`, `nautilus`, `swaync`/`swaync-client`, `swayosd-server`/`swayosd-client`, `swayosd-libinput-backend`, `wal` (pywal), `waypaper`, `awww`/`awww-daemon` (wallpaper daemon), `cliphist` + `wl-clipboard`, `grim`/`slurp`, `playerctl`, `brightnessctl`, `hypridle`, `hyprlock`, `hyprpm`, `bitwarden-desktop`, `rclone` (mounts gdrive at autostart). Sibling configs live in `~/.config/waybar` and `~/.config/rofi`.
