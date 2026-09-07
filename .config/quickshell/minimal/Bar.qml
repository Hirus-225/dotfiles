import Quickshell
import QtQuick

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    // color: "transparent"
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
        anchors.right: connectivity.left
        anchors.rightMargin: 12
    }

    Connectivity {
        id: connectivity

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: battery.left
        anchors.rightMargin: 10

        onClicked: controlCenter.active = true
    }

    Battery {
        id: battery

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 12
    }

    // Ouvert par Connectivity, jamais par Battery : un pourcentage de batterie
    // n'est pas un point d'entrée sémantique vers des réglages de radio.
    //
    // Deuxième clic : il n'atteint jamais la bulle. Panneau ouvert, la surface
    // plein écran de ControlCenter est au-dessus de la barre et avale le clic,
    // qui referme par la zone de rejet. La bascule est donc une simple
    // ouverture — il n'y a pas de double basculement possible.
    //
    // Seule trace du centre de contrôle dans ce fichier : sa naissance et sa
    // mort. Tout le reste est dans ControlCenter.qml.
    //
    // active: false ne cache pas le panneau, il l'empêche d'exister. Tant
    // qu'il vaut false, aucun objet du panneau n'est construit : pas de
    // fenêtre, pas de liaisons, pas de timers, pas de surface Wayland, et
    // aucune référence au singleton Services — donc aucune connexion D-Bus
    // vers NetworkManager ni BlueZ.
    //
    // Une instance par barre, donc par écran, comme le reste de la config.
    LazyLoader {
        id: controlCenter

        active: false

        ControlCenter {
            screen: root.screen
            onDismissed: controlCenter.active = false
        }
    }
}
