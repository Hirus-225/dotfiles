import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 40
            color: "transparent"

            Text {
                anchors.centerIn: parent
                color: "#cdd6f4"
                text: "Hello Quickshell"
            }
        }
    }
}
