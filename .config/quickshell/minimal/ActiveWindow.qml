import Quickshell.Wayland
import QtQuick

StyledText {
    text: ToplevelManager.activeToplevel?.title || "Bureau"

    elide: Text.ElideRight
    horizontalAlignment: Text.AlignLeft
}
