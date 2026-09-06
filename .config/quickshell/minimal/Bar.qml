import Quickshell
import QtQuick

PanelWindow {
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 32
    color: Theme.bg

    Workspaces {
        id: workspaces

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
    }

    ActiveWindow {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: workspaces.right
        anchors.right: clock.left
        anchors.leftMargin: 16
        anchors.rightMargin: 16
    }

    Clock {
        id: clock

        anchors.centerIn: parent
    }

    Battery {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 12
    }
}
