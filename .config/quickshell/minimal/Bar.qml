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

    implicitHeight: 35
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
        anchors.rightMargin: 20
    }

    Clock {
        id: clock

        anchors.centerIn: parent
    }

    Volume {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: battery.left
        anchors.rightMargin: 12
    }

    Battery {
        id: battery

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 12
    }
}
