import Quickshell
import Quickshell.Hyprland
import QtQuick

// Config Hyprland en Lua : dispatch("workspace N") échoue au parsing.
// activate() passe par l'API typée et ignore le format de config.
// Ne pas se fier a Hyprland.usingLua, qui renvoie false a tort.

Row {
    spacing: 6

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            required property var modelData

            width: modelData.focused ? 26 : 10
            height: 10
            radius: 5
            color: modelData.focused ? Theme.accent : Theme.muted

            Behavior on width {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.activate()
            }
        }
    }
}
