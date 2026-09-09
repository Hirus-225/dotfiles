import Quickshell
import QtQuick

// Une ligne du menu contextuel d'un item de tray.
//
// Elle ne se contient PAS elle-même. La première version dépliait les
// sous-menus sous la ligne, en s'instanciant récursivement, et le moteur l'a
// refusé net :
//
//     @TrayMenuEntry.qml: TrayMenuEntry is instantiated recursively
//
// QML détecte le cycle au chargement du type, même quand l'instanciation est
// différée par un Loader — seul un Loader par URL (`source: "…"`) le
// contournerait, au prix de propriétés posées à la main après chargement.
// TrayMenu.qml navigue donc par PILE : ouvrir un sous-menu remplace la liste
// au lieu de l'indenter. Profondeur arbitraire, aucun cycle de type, et un
// menu de 320 px de large qui reste lisible — une indentation à trois niveaux
// n'y aurait pas tenu.
//
// Pourquoi pas MenuRow.qml, qui existe déjà : MenuRow porte la sémantique des
// menus Wi-Fi et Bluetooth — `on` (connecté / associé), `detail` (seconde
// ligne), `busy` (transition en vol de plusieurs secondes). Aucune de ces trois
// notions n'existe dans DBusMenu, qui a en revanche trois notions que MenuRow
// n'a pas : séparateur, case à cocher / bouton radio, et sous-menu. Ce n'est
// pas le même objet, et lui faire porter les deux jeux de propriétés le
// rendrait illisible pour les deux.
//
// Ce qui EST réutilisé : StyledText, Theme, TrayIcon, et MenuList pour
// l'empilement et le plafond de hauteur — voir TrayMenu.qml.
Item {
    id: root

    // QsMenuEntry. Nullable : DBusMenu est distant, donc asynchrone.
    property var entry: null

    property int rowHeight: 30

    // L'entrée a été déclenchée : la fenêtre se referme.
    signal activated()

    // L'entrée a des enfants : la fenêtre descend dedans.
    signal submenuRequested(var handle)

    readonly property bool separator: root.entry ? root.entry.isSeparator : false
    readonly property bool hasChildren: root.entry ? root.entry.hasChildren : false
    readonly property bool enabled: root.entry ? root.entry.enabled : false

    // Qt.Checked vaut 2, Qt.PartiallyChecked 1. On ne distingue pas les deux :
    // DBusMenu autorise le tiers état, mais une coche à demi cochée dans un
    // menu de barre n'apprend rien de plus que « ce n'est pas décoché ».
    readonly property bool checked:
        root.entry !== null
        && root.entry.buttonType !== QsMenuButtonType.None
        && root.entry.checkState !== Qt.Unchecked

    implicitHeight: root.separator ? 9 : root.rowHeight

    // --- Le séparateur -------------------------------------------------------
    // Un filet, pas une ligne de menu : il ne survole pas, ne clique pas, et ne
    // fait pas la hauteur d'une entrée.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        visible: root.separator
        height: 1
        color: Theme.fg
        opacity: 0.15
    }

    // --- L'entrée ------------------------------------------------------------
    Rectangle {
        id: body

        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        visible: !root.separator
        radius: 6

        // Même règle que MenuRow : le fond ne marque QUE le survol. L'état
        // coché se lit sur la marque de droite.
        color: hover.hovered && root.enabled
               ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)
               : "transparent"

        // Une entrée désactivée reste lisible, mais visiblement inerte.
        // DBusMenu en envoie pour de vrai — mesuré sur blueman :
        // « Reconnecte à… » arrive avec enabled = false.
        opacity: root.enabled ? 1 : 0.4

        Behavior on color { ColorAnimation { duration: 100 } }

        TrayIcon {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            size: 16
            source: root.entry ? root.entry.icon : ""

            // Pas de repli visible ici : le libellé porte déjà le sens, une
            // lettre de plus en tête de ligne ne ferait que du bruit. Voir
            // TrayIcon.fallbackText.
            fallbackText: ""
        }

        StyledText {
            anchors.left: glyph.right
            anchors.leftMargin: 8
            anchors.right: mark.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            // Les libellés de tray sont écrits par l'application, pas par
            // nous : « Profils audio et d'entrée sur DualSense Wireless
            // Controller » est un cas réel, mesuré. On élide plutôt que de
            // laisser une application dicter la largeur d'une fenêtre de la
            // barre.
            text: root.entry ? root.entry.text : ""
            elide: Text.ElideRight
            style: Text.Normal
        }

        // La marque de droite porte les deux cas, qui s'excluent : un
        // sous-menu (chevron) ou un état coché.
        StyledText {
            id: mark

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            // md-chevron_right et md-check, même famille que les points de
            // code vérifiés au rendu pour le chevron de la barre.
            text: root.hasChildren ? "\u{F0142}"
                : root.checked     ? "\u{F012C}"
                                   : ""

            color: root.checked ? Theme.accent
                                : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
            style: Text.Normal
        }
    }

    HoverHandler {
        id: hover
        enabled: root.enabled && !root.separator
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled && !root.separator
        cursorShape: Qt.PointingHandCursor

        // Une entrée à enfants n'a rien à déclencher : elle fait descendre.
        // Les autres déclenchent et referment.
        //
        // NON VÉRIFIÉ SUR CETTE MACHINE : le menu de blueman, seul client du
        // tray ici, annonce hasChildren = false sur ses 17 entrées. Cette
        // branche n'a donc jamais été empruntée. Elle ne peut pas casser ce
        // qui marche — sans sous-menu, elle n'est pas atteinte.
        onClicked: {
            if (root.hasChildren) {
                root.submenuRequested(root.entry);
                return;
            }
            root.entry.triggered();
            root.activated();
        }
    }
}
