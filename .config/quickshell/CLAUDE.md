# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Quickshell (QML-based Wayland shell) configuration directory. Not a software project — there is
no build system, package manager, test suite, or linter. QML is interpreted at runtime; the only
validation is running the shell and reading its logs.

Runtime targets Hyprland on Arch (Quickshell 0.3.1, `/usr/bin/qs`).

## Running

This directory holds **two independent configs**, each a subdirectory with its own `shell.qml`.
There is no `shell.qml` at the root, so bare `qs` (the "default" config) will fail — always select one:

```sh
qs -c minimal          # the real bar
qs -c test             # smoke test: a transparent 40px panel saying "Hello Quickshell"
qs -p ~/.config/quickshell/minimal   # equivalent, by path
```

Quickshell hot-reloads on file save, so an already-running instance picks up edits without a restart.

```sh
qs -c minimal -vv      # -v internal INFO logs, -vv DEBUG; QML errors print here
qs list                # running instances
qs kill -c minimal
qs log                 # logs of a daemonized instance (qs -d)
```

## Architecture (`minimal/`)

**No `qmldir` file, by design.** Quickshell auto-registers every `.qml` in the config directory:
each file becomes a component named after the file, and a file with `pragma Singleton` becomes a
singleton. That is why components are used bare — `Bar {}`, `Theme.accent`, `StyledText {}` — with
no import statement. Adding a new component means dropping a `.qml` file in the directory; nothing
else needs updating.

**Per-monitor instantiation.** `shell.qml` → `ShellRoot` → `Variants { model: Quickshell.screens }`
→ one `Bar` per screen. `Variants` injects a `modelData` property into each instance; `Bar.qml`
declares `required property var modelData` and assigns it to `screen`. Any new top-level window
replicated across monitors follows this same shape.

**Theme.qml is the single source of truth for color and font.** It is a singleton that live-reloads
from pywal's `~/.cache/wal/colors.json` via `FileView { watchChanges: true }`, mapping
`special.background`/`special.foreground`/`colors.color4`/`color8`/`color1` onto
`bg`/`fg`/`accent`/`muted`/`alert`. The Catppuccin hex literals in the property declarations are
only fallbacks for before the file loads. Never hardcode a color or font in a component — add a
property to `Theme` so the pywal binding stays intact.

**StyledText.qml is the text base class.** `Clock` and `Battery` extend it rather than `Text`, which
is where they inherit `Theme.fg`, the font family/size, and `NativeRendering`. New text elements
should extend `StyledText` too.

**Bar layout** is anchor-based inside a single `PanelWindow` (32px, anchored top/left/right):
`Workspaces` left, `Clock` centered, `Battery` right.

## System dependencies the config assumes

- **Hyprland** — `Workspaces.qml` uses `Quickshell.Hyprland` (`Hyprland.workspaces`, `Hyprland.dispatch`).
- **UPower** — `Battery.qml` uses `Quickshell.Services.UPower.UPower.displayDevice`.
- **pywal** — `~/.cache/wal/colors.json`; without it the theme silently stays on the fallback palette.
- **JetBrainsMono Nerd Font** — hardcoded in `Theme.fontFamily`.
- The clock is formatted with an explicit `fr_FR` locale, independent of the system locale.
