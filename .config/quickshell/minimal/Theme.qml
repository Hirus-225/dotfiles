pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property color bg: "#1e1e2e"
    property color fg: "#cdd6f4"
    property color accent: "#89b4fa"
    property color muted: "#45475a"
    property color alert: "#f38ba8"

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            const wal = JSON.parse(text())
            root.bg = wal.special.background
            root.fg = wal.special.foreground
            root.accent = wal.colors.color4
            root.muted = wal.colors.color8
            root.alert = wal.colors.color1
        }
    }
}
