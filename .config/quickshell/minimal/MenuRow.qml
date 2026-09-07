import QtQuick

// Ligne de liste générique, pour les menus dépliés sous les toggles. Comme
// Slider.qml et Toggle.qml, elle ne connaît aucun service : elle reçoit un
// libellé et un état, elle émet une demande.
//
// Une seule ligne pour les deux menus (appareils Bluetooth, réseaux Wi-Fi).
// Les deux sources n'ont rien en commun — un appareil apparié n'est pas un
// point d'accès — mais leur RENDU est le même : une icône, un nom, une ligne
// de détail, un état à droite. C'est l'appelant qui traduit.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string detail: ""      // vide = ligne secondaire non affichée
    property string trailing: ""    // glyphe de droite, vide = rien

    // « actif » au sens de la source : connecté pour un appareil, associé pour
    // un réseau. Ce n'est pas une sélection d'interface.
    property bool on: false

    // Attente affichée SANS seuil, contrairement à Toggle.qml. Le seuil de
    // 120 ms y protège des bascules quasi instantanées (DND : 7,8 ms au
    // repos) ; ici la connexion BlueZ met plusieurs secondes à établir ses
    // profils. Il n'y a donc rien à masquer, et masquer les 120 premières
    // millisecondes ne ferait que retarder le seul retour visuel du clic.
    // NON MESURÉ sur cette machine : je n'ai pas coupé le casque en cours de
    // session pour chronométrer. L'ordre de grandeur suffit à la décision.
    property bool busy: false

    property bool actionable: true

    signal activated()

    implicitHeight: 38
    implicitWidth: 240

    Rectangle {
        id: body

        anchors.fill: parent
        radius: 8

        // Le fond ne marque que le survol. L'état « connecté » se lit sur
        // l'icône et sur la ligne de détail, jamais sur le fond : un fond
        // teinté par ligne transformerait la liste en damier dès que deux
        // appareils sont connectés.
        color: hover.hovered && root.actionable
               ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)
               : "transparent"

        opacity: root.actionable ? pulse : 0.4

        // Même construction que Toggle.qml : la pulsation part de 1 et
        // descend, une attente courte ne produit donc pas de clignotement.
        property real pulse: 1

        SequentialAnimation on pulse {
            running: root.busy
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 350; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0;  duration: 350; easing.type: Easing.InOutQuad }
        }

        Behavior on color { ColorAnimation { duration: 100 } }

        StyledText {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            text: root.icon
            color: root.on ? Theme.accent : Theme.fg
            font.pixelSize: Theme.fontSize + 3
            style: Text.Normal

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Column {
            anchors.left: glyph.right
            anchors.leftMargin: 10
            anchors.right: mark.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            spacing: 1

            StyledText {
                width: parent.width

                text: root.label
                elide: Text.ElideRight
                style: Text.Normal
            }

            StyledText {
                width: parent.width
                visible: root.detail !== ""

                text: root.detail
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSize - 3
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                style: Text.Normal
            }
        }

        StyledText {
            id: mark

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            text: root.trailing
            color: root.on ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
            font.pixelSize: Theme.fontSize
            style: Text.Normal
        }
    }

    HoverHandler { id: hover; enabled: root.actionable }

    MouseArea {
        anchors.fill: parent

        // Comme le Toggle : rien pendant une transition. Un second clic sur une
        // connexion en vol produirait la demande contraire.
        enabled: root.actionable && !root.busy
        cursorShape: Qt.PointingHandCursor

        onClicked: root.activated()
    }
}
