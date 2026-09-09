import Quickshell
import Quickshell.Wayland
import QtQuick

// Même motif que ControlCenter.qml, et volontairement le même : une surface
// PLEIN ÉCRAN transparente dont la bulle n'est qu'un enfant. C'est ce qui donne
// la fermeture au clic extérieur sans avoir à surveiller un « dehors ». Un
// PopupWindow ancré sous l'horloge aurait été un second motif de fenêtre dans
// la config pour le même besoin.
//
// Conséquence assumée, identique à celle du centre de contrôle : le calendrier
// ouvert capte tous les clics de l'écran, et celui qui le referme n'atteint pas
// l'application dessous.
//
// Ce fichier est le SEUL à savoir où le calendrier s'affiche. Calendar.qml
// n'a pas d'anchors et ne se dimensionne pas : il expose ses tailles
// implicites, la bulle les lit.
PanelWindow {
    id: root

    signal dismissed()

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-calendar"

    // Rien à taper dans une grille de dates : le calendrier ne doit jamais
    // apparaître dans le chemin du clavier, contrairement au centre de contrôle
    // qui l'arme en OnDemand pour le champ de mot de passe du Wi-Fi.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }

    // Le calendrier flotte, il ne décale rien.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // Zone de rejet : tout l'écran, sous la bulle. Elle comprend la barre, donc
    // l'horloge : c'est par elle que le second clic sur l'horloge referme.
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Rectangle {
        // Centré horizontalement parce que l'horloge l'est : elle est posée en
        // `anchors.centerIn` d'une barre qui occupe toute la largeur de
        // l'écran, le centre de l'écran EST le centre de l'horloge. Aucun
        // calcul de position d'un module vers un autre.
        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + 8
        anchors.horizontalCenter: parent.horizontalCenter

        // La bulle prend la taille que le calendrier annonce. Pas de largeur en
        // dur ici : changer la taille des cases dans Calendar.qml redimensionne
        // la bulle sans que ce fichier soit touché.
        implicitWidth: calendar.implicitWidth
        implicitHeight: calendar.implicitHeight

        // Fond, rayon et filet repris de ControlCenter.qml : deux bulles qui
        // sortent de la même barre n'ont pas à avoir deux silhouettes.
        color: Theme.bg
        radius: 14
        border.width: 1
        border.color: Theme.muted

        // Absorbe les clics tombés dans la bulle. Sans elle ils traverseraient
        // jusqu'à la zone de rejet et refermeraient le calendrier — y compris
        // les clics de navigation entre les mois.
        MouseArea { anchors.fill: parent }

        Calendar {
            id: calendar

            anchors.fill: parent
        }
    }
}
