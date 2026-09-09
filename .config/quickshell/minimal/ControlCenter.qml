import Quickshell
import Quickshell.Wayland
import QtQuick

// Le panneau est une surface PLEIN ÉCRAN transparente ; le rectangle visible
// n'en est qu'un enfant. C'est ce qui permet au clic extérieur de fonctionner :
// il n'y a pas de « dehors » à surveiller, tout l'écran appartient déjà au
// panneau, et la zone hors du rectangle est une simple MouseArea de rejet.
//
// Le prix de ce choix est que le panneau ouvert capte tous les clics de
// l'écran. C'est exactement le comportement de macOS : le clic qui referme le
// centre de contrôle n'atteint pas l'application en dessous.
PanelWindow {
    id: root

    signal dismissed()

    // Overlay : au-dessus de la barre (qui est en layer top) et de toutes les
    // fenêtres. Le namespace rend la surface identifiable dans `hyprctl layers`.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-controlcenter"

    // Le clavier n'est armé QUE pour le menu Wi-Fi, parce que c'est le seul
    // endroit de la config où l'on tape quelque chose.
    //
    // OnDemand et pas Exclusive : Exclusive prendrait le clavier dès
    // l'ouverture du panneau, donc à l'application dessous, sans que personne
    // l'ait demandé. OnDemand ne le donne qu'au clic — celui qui vise le champ
    // de mot de passe.
    //
    // None le reste du temps : un panneau de sliders et de bascules n'a aucune
    // raison d'apparaître dans le chemin du clavier.
    WlrLayershell.keyboardFocus: root.shown === "wifi" ? WlrKeyboardFocus.OnDemand
                                                       : WlrKeyboardFocus.None

    // Ancrée aux quatre bords pour couvrir l'écran.
    anchors { top: true; bottom: true; left: true; right: true }

    // Contrainte explicite : le panneau flotte, il ne décale rien. Vérifié —
    // la zone réservée du moniteur reste à [0, 35, 0, 0] (les 35 px de la
    // barre) panneau ouvert comme fermé.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // Prise et restitution du compteur de Services. Les deux sont pilotées par
    // le cycle de vie de l'objet, lui-même piloté par le LazyLoader : il
    // n'existe aucun chemin où le panneau vit sans avoir acquis, ni où il est
    // détruit sans avoir rendu.
    Component.onCompleted: Services.acquire()
    Component.onDestruction: Services.release()

    // --- Menu déplié --------------------------------------------------------
    // `expanded` est l'INTENTION (ce sur quoi on a cliqué), `shown` est la
    // réalité (ce qui a encore un sens à afficher). Même découpage que
    // toggleState / shown / face dans Toggle.qml, et pour la même raison :
    // sans lui, couper le Bluetooth pendant que son menu est ouvert laisserait
    // une liste d'appareils inconnectables sous un chevron retourné.
    //
    // Un seul menu à la fois, par construction : c'est une chaîne, pas deux
    // booléens. Deux menus ouverts, ce serait deux listes empilées dans une
    // bulle de 340 px — et, quand le Wi-Fi arrivera, un scan que rien
    // n'obligerait à s'arrêter en ouvrant l'autre.
    property string expanded: ""

    readonly property string shown:
          root.expanded === "bt"   && Services.btAvailable   && Services.btEnabled   ? "bt"
        : root.expanded === "wifi" && Services.wifiAvailable && Services.wifiEnabled ? "wifi"
                                                                                     : ""

    function toggleMenu(name: string): void {
        root.expanded = (root.expanded === name) ? "" : name;
    }

    // Zone de rejet : tout l'écran, sous le rectangle.
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.barHeight + 8
        anchors.rightMargin: 12

        implicitWidth: 340
        // La hauteur suit le contenu : le panneau grandit quand un menu se
        // déplie, plutôt que d'être une boîte à moitié vide en attendant.
        implicitHeight: content.implicitHeight + 2 * content.anchors.margins

        // Le contenu apparaît d'un coup, c'est la BOÎTE qui s'ouvre. Sans
        // clip, la liste déborderait sous le bord arrondi pendant les 140 ms
        // de l'animation.
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        color: Theme.bg
        radius: 14
        border.width: 1
        border.color: Theme.muted

        // Absorbe les clics qui tombent dans le panneau. Sans elle ils
        // traverseraient jusqu'à la zone de rejet et le refermeraient.
        MouseArea { anchors.fill: parent }

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16

            spacing: 12

            // `active` est le point de garde unique de chaque service, celui
            // que Services.qml a rendu possible : à la toute première ouverture
            // après un démarrage, audio et brightnessReady sont encore vides
            // pendant ~27 ms. Le slider s'affiche éteint puis s'allume, sans
            // rien lever.
            Slider {
                width: parent.width

                active: Services.audio !== null
                value: Services.audio?.volume ?? 0
                icon: Services.audio?.muted ? "\u{F0581}" : "\u{F057E}"

                iconClickable: true

                onMoved: v => Services.setVolume(v)
                onIconClicked: Services.toggleMute()
            }

            Slider {
                width: parent.width

                active: Services.brightnessReady
                value: Services.brightness
                icon: "\u{F00DF}"

                onMoved: v => Services.setBrightness(v)
            }

            // Les trois traductions ci-dessous ont volontairement la même
            // forme, alors que les trois sources n'ont pas la même nature.
            // C'est Services.qml qui absorbe l'asymétrie ; ici on ne fait que
            // choisir parmi quatre états. La seule différence visible est que
            // le Wi-Fi n'a pas de cas Busy : NetworkManager n'expose aucun état
            // transitoire, et sa correction dure ~15 ms — moins d'une frame.
            Row {
                id: toggles

                width: parent.width
                spacing: 10

                readonly property real cell: (width - 2 * spacing) / 3

                Toggle {
                    width: toggles.cell

                    icon: "\u{F1EB}"
                    toggleState: !Services.wifiAvailable ? Toggle.State.Unavailable
                               : Services.wifiEnabled    ? Toggle.State.On
                                                         : Toggle.State.Off

                    expandable: true
                    expanded: root.shown === "wifi"

                    onToggled: Services.setWifi(!Services.wifiEnabled)
                    onExpandRequested: root.toggleMenu("wifi")
                }

                Toggle {
                    width: toggles.cell

                    icon: "\u{F293}"
                    toggleState: !Services.btAvailable ? Toggle.State.Unavailable
                               : Services.btBusy       ? Toggle.State.Busy
                               : Services.btEnabled    ? Toggle.State.On
                                                       : Toggle.State.Off

                    expandable: true
                    expanded: root.shown === "bt"

                    onToggled: Services.setBluetooth(!Services.btEnabled)
                    onExpandRequested: root.toggleMenu("bt")
                }

                Toggle {
                    width: toggles.cell

                    icon: "\u{F1F6}"
                    toggleState: Services.dndBusy          ? Toggle.State.Busy
                               : !Services.swayncAvailable ? Toggle.State.Unavailable
                               : Services.dndEnabled       ? Toggle.State.On
                                                           : Toggle.State.Off

                    onToggled: Services.setDnd(!Services.dndEnabled)
                }
            }

            // Le menu est un ENFANT du panneau, pas une fenêtre à part. C'est
            // ce qui donne sa garantie de cycle de vie : détruire le panneau
            // détruit le menu, sans qu'aucun code n'ait à s'en souvenir.
            // Mesuré (sonde de cycle de vie) — panneau fermé menu ouvert, les
            // deux Component.onDestruction se déclenchent, le parent d'abord.
            //
            // `visible: active` n'est pas cosmétique : une Column exclut de sa
            // hauteur les enfants invisibles, mais compte l'espacement d'un
            // enfant visible de hauteur nulle. Sans ça, le panneau garderait
            // 12 px de vide sous les toggles, menu fermé.
            Loader {
                width: parent.width

                active: root.shown === "bt"
                visible: active

                sourceComponent: Component { BluetoothMenu {} }
            }

            // Deux Loaders et pas un seul dont on changerait le
            // sourceComponent : passer d'un menu à l'autre doit DÉTRUIRE le
            // premier, pas le remplacer en douceur. C'est cette destruction qui
            // rend le bail de scan du Wi-Fi. Un Loader partagé laisserait à
            // Quickshell le choix de l'ordre entre la construction du nouveau
            // et la destruction de l'ancien.
            Loader {
                width: parent.width

                active: root.shown === "wifi"
                visible: active

                sourceComponent: Component { WifiMenu {} }
            }
        }
    }
}
