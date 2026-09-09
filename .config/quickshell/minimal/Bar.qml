import Quickshell
import QtQuick

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Cible du menu de tray, posée par le tiroir juste avant l'ouverture.
    // C'est le seul état que ce fichier porte : les deux autres fenêtres
    // (centre de contrôle, calendrier) n'ont besoin de rien pour naître, un
    // menu contextuel a besoin de savoir DE QUOI il est le menu.
    property var trayMenuItem: null
    property real trayMenuX: 0

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

        onClicked: calendar.active = true
    }

    // Volume.qml n'est plus dans la barre : son pourcentage faisait doublon
    // avec le slider du panneau, et l'état du son est désormais une des trois
    // icônes de Connectivity. Le fichier reste sur le disque — Quickshell
    // enregistre tout .qml du dossier, donc le composant existe toujours et
    // reste réutilisable, il n'est simplement plus instancié.
    // Avant la bulle de connectivité, et ancré à droite comme elle : le tiroir
    // grandit donc vers la GAUCHE en s'ouvrant, sans jamais déplacer ni la
    // bulle ni la batterie. C'est aussi pourquoi son chevron pointe à gauche.
    //
    // Tray.qml ne sait rien de tout ça : il n'expose qu'une largeur implicite,
    // les ancrages vivent ici comme pour tous les autres modules.
    Tray {
        id: tray

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: connectivity.left
        anchors.rightMargin: 10

        // Le tiroir ne connaît pas TrayMenu, exactement comme l'horloge ne
        // connaît pas le calendrier. Il dit « cet item-là, à cette abscisse » ;
        // c'est ici qu'on décide que ça ouvre une fenêtre.
        //
        // Les deux valeurs sont mises de côté AVANT l'activation : le
        // LazyLoader construit la fenêtre au moment où `active` passe à vrai,
        // et elle lit ses propriétés dans la foulée. Les poser après
        // donnerait une bulle née sur un item nul.
        onMenuRequested: (trayItem, anchorX) => {
            root.trayMenuItem = trayItem;
            root.trayMenuX = anchorX;
            trayMenu.active = true;
        }
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

    // Ouvert par l'horloge, et fermé de la même façon que le centre de
    // contrôle : `active: true` et non `active: !active`, parce qu'un second
    // clic sur l'horloge n'atteint jamais l'horloge. Calendrier ouvert, la
    // surface plein écran de CalendarPopup est au-dessus de la barre et avale
    // le clic, qui referme par la zone de rejet — c'est le raisonnement du
    // commentaire ci-dessus, appliqué au même motif de fenêtre. Une bascule
    // écrite ici serait un basculement de plus, jamais exécuté.
    //
    // Une seule bulle à la fois n'est PAS garanti par ce fichier : les deux
    // LazyLoaders sont indépendants. C'est la géométrie qui s'en charge —
    // panneau ouvert, le clic sur l'horloge tombe sur sa zone de rejet et
    // referme le panneau au lieu d'ouvrir le calendrier.
    //
    // Comme le centre de contrôle : tant que `active` vaut false, rien du
    // calendrier n'existe — ni fenêtre, ni surface Wayland, ni MonthGrid, ni
    // les 42 delegates de sa grille. Une instance par écran.
    LazyLoader {
        id: calendar

        active: false

        CalendarPopup {
            screen: root.screen
            onDismissed: calendar.active = false
        }
    }

    // Troisième fenêtre, même motif que les deux précédentes : tant que
    // `active` vaut false, il n'y a ni fenêtre, ni surface Wayland, ni
    // QsMenuOpener — donc aucune connexion DBusMenu ouverte vers l'application
    // qui possède l'item. Un menu de tray fermé ne coûte rien à personne.
    //
    // Une instance par barre, donc par écran, comme le reste de la config.
    LazyLoader {
        id: trayMenu

        active: false

        TrayMenu {
            screen: root.screen
            trayItem: root.trayMenuItem
            anchorX: root.trayMenuX

            onDismissed: trayMenu.active = false
        }
    }
}
