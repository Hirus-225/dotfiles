import QtQuick

// Bulle d'état des radios, dans la barre. Point d'entrée du centre de contrôle.
//
// Ce module TOURNE EN PERMANENCE, panneau fermé. Il ne fait donc que lire :
// aucune écriture, aucun scan, aucune découverte. Les deux propriétés
// coûteuses (scannerEnabled, discovering) restent pilotées par le compteur
// de Services, que ce module n'incrémente jamais — seul le panneau le fait,
// via acquire().
//
// Sa seule conséquence est que le singleton Services est désormais référencé
// dès le démarrage du shell, et non plus à la première ouverture du panneau.
// Les connexions D-Bus vers NetworkManager et BlueZ sont donc ouvertes en
// continu. Coût mesuré de ce choix : voir l'en-tête de Services.qml.
Rectangle {
    id: root

    signal clicked()

    implicitWidth: icons.implicitWidth + 18
    implicitHeight: 22

    radius: height / 2
    color: Theme.muted

    // Trois niveaux, pas deux : « indisponible » (pas de radio, rfkill,
    // démon absent) ne doit pas se confondre avec « éteint ».
    function tint(available: bool, on: bool): color {
        if (!available) return Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22);
        if (!on) return Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45);
        return Theme.accent;
    }

    Row {
        id: icons

        anchors.centerIn: parent
        spacing: 10

        StyledText {
            text: "\u{F1EB}"
            color: root.tint(Services.wifiAvailable, Services.wifiEnabled)
            style: Text.Normal      // sur un aplat, pas de contour

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        StyledText {
            text: "\u{F293}"
            color: root.tint(Services.btAvailable, Services.btEnabled)
            style: Text.Normal

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
    }
}
