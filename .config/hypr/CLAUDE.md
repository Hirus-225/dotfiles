# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal Hyprland (Wayland compositor) configuration for an Arch Linux MacBook. Not a software project — these are runtime config files read by `hyprland.lua` and the Hypr ecosystem daemons (`hypridle`, `hyprlock`). Comments throughout are in French; match that language when editing existing comments.

**Config language:** since Hyprland 0.55 the compositor config is **Lua**, not hyprlang. The entrypoint is `hyprland.lua`; Hyprland picks it over `hyprland.conf` at startup (the choice is made once, at launch). The legacy `.conf` files are still on disk but **inert** — they are the revert path, not the live config. Timestamped snapshots of the pre-migration tree live in `backups/`.

`hyprlock` and `hypridle` are separate programs and have **not** migrated: `hyprlock.conf` and `hypridle.conf` are still hyprlang.

## Applying / testing changes

There is no build or test step.

- `Hyprland --verify-config` — **validate without restarting**. Parses the config and prints `config ok` or the errors. Use this after every edit; it is the only safe check while a session is running.
- `hyprctl reload` — apply changes to `hyprland.lua` or any `modules/*.lua`. Re-executes the whole Lua config.
- `hyprlock` — preview the lock screen (`hyprlock.conf`).
- `hyprctl reload && pkill hypridle && hypridle &` — apply `hypridle.conf` changes.
- Permission changes (`modules/permissions.lua`) require a full Hyprland **restart**, not a reload — they are not applied on the fly.

Errors also land in `journalctl --user -xe -t Hyprland` and `hyprctl configerrors`.

## Architecture

`hyprland.lua` is the entrypoint. It does nothing but `require` the modules in a fixed order, so **order matters** — colors must load before the modules that consume them. Order: monitors → my_programs → autostart → variables → permissions → colors → apparence → animations → input → raccourcis-clavier → media-controls → workspaces.

`require` is rooted at the config directory (`package.path` starts with `~/.config/hypr/?.lua`), so submodules are addressed with a dot: `require("modules.colors")`.

Each module owns one concern:
- `my_programs.lua` — **returns a table** (`terminal`, `fileManager`, `menu`) that `raccourcis-clavier.lua` requires. Replaces the old `$terminal`/`$menu` hyprlang variables.
- `colors.lua` — **returns the Pywal palette table** (see below).
- `raccourcis-clavier.lua` — keybindings via `hl.bind("SUPER + K", hl.dsp....)`. `mainMod = "SUPER"`. Workspace nav is generated in a `for i = 1, 10` loop. Screenshots (grim/slurp), scratchpad (`SUPER+S`), lid-close lock.
- `media-controls.lua` — volume/brightness/media keys through **SwayOSD** (`swayosd-client`). Old bind suffixes map to option tables: `bindel` → `{ locked = true, repeating = true }`, `bindl` → `{ locked = true }`, `binde` → `{ repeating = true }`, `bindm` → `{ mouse = true }`.
- `workspaces.lua` — window rules (floating apps, sizes, special-workspace assignment) AND resize keybinds. Repetitive float+center+size rules are generated from a table literal.
- `input.lua` — `us`/`mac` layout by default, per-device override (`casue-usb-kb` → French azerty) via `hl.device`. Natural scroll + 3-finger workspace gesture via `hl.gesture`.
- `apparence.lua` — look & feel (gaps, blur, shadows, rounding) plus `hl.layer_rule` blur for waybar/swaync/rofi/gtklock.
- `animations.lua` — `hl.curve` (beziers) + `hl.animation` (leaves), plus dwindle/master/misc.
- `autostart.lua` — the old `exec-once` list, now `hl.on("hyprland.start", ...)` + `hl.exec_cmd`. That event fires only at startup, not on `hyprctl reload`, which preserves exec-once semantics. `hl.exec_cmd` runs its argument through a shell, so `&&`, `&` and `$(...)` work.

### Lua API reference

The authoritative, version-matched API reference is installed locally — prefer it over the wiki:
- `/usr/share/hypr/stubs/hl.meta.lua` — full LuaLS type stubs: every `hl.*` function, every dispatcher under `hl.dsp.*`, every config key, every event name.
- `/usr/share/hypr/hyprland.lua` — the shipped default config, i.e. worked examples of every construct.

`hl.dsp.*` builders are lazy: they validate their arguments at `hl.bind()` time, not when called. A bad dispatcher arg surfaces as a Lua error naming the expected shape.

## Dynamic theming (the one non-obvious system)

Colors are **not hardcoded** — they come from Pywal, generated from the current wallpaper:

1. `wal -i <wallpaper>` (run at autostart) writes `~/.cache/wal/colors`.
2. `scripts/refresh_colors.sh` reads that palette and writes it **twice**, atomically:
   - `~/.cache/wal/colors-hyprland.lua` — a Lua table, loaded by `modules/colors.lua`.
   - `~/.cache/wal/colors-hyprland.conf` — hyprlang, still `source`d by `hyprlock.conf`.
3. `modules/colors.lua` loads the Lua table and returns it with a **fallback palette behind a metatable**, so a missing or half-written cache file can never break the config. Consume it with `local colors = require("modules.colors")` then `colors.color1`.
4. `refresh_colors.sh` then live-reloads every themed component: waybar (`SIGUSR2`), swaync, swayosd-server (killed/relaunched), and `hyprctl reload`.

When changing wallpaper/colors, run `scripts/refresh_colors.sh` rather than reloading Hyprland directly, so all UI components pick up the new palette. Both generated cache files are overwritten on the next Pywal run — never edit them by hand, and never edit the fallback table in `colors.lua` as a way to change colors.

## External dependencies referenced here

Configs assume these are installed and on PATH: `waybar`, `rofi`, `kitty`, `nautilus`, `swaync`/`swaync-client`, `swayosd-server`/`swayosd-client`, `swayosd-libinput-backend`, `wal` (pywal), `waypaper`, `awww`/`awww-daemon` (wallpaper daemon), `cliphist` + `wl-clipboard`, `grim`/`slurp`, `playerctl`, `brightnessctl`, `hypridle`, `hyprlock`, `hyprpm`, `proton-pass`, `rclone` (mounts gdrive at autostart). Sibling configs live in `~/.config/waybar` and `~/.config/rofi`.
