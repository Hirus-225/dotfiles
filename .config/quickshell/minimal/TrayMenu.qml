import Quickshell
import Quickshell.Wayland
import QtQuick

// Le menu contextuel d'un item de tray.
//
// --- Pourquoi ce fichier existe au lieu d'un appel à display() -------------
// SystemTrayItem expose display(fenêtre, x, y), qui ouvre le menu NATIF. C'est
// ce que faisait la première version, et c'était faux. Mesuré au premier clic
// droit réel :
//
//     ERROR: Cannot display PlatformMenuEntry as quickshell was not started
//            in QApplication mode.
//     ERROR: To use platform menus, add `//@ pragma UseQApplication` …
//
// Le correctif proposé par le message — passer le shell en QApplication —
// n'est pas le bon ici, pour une raison qui n'a rien à voir avec le coût de
// QtWidgets sur cette machine : un menu de plateforme est peint par le style
// de widgets de Qt. Il ne connaît pas Theme, donc il ne suit pas pywal. La
// première règle de cette config serait contournée par le seul élément qui
// n'aurait pas eu à la respecter.
//
// On rend donc le menu nous-mêmes. QsMenuOpener donne les entrées de DBusMenu
// sous forme de modèle ; le reste est du QML ordinaire, avec Theme et
// StyledText comme partout ailleurs.
//
// --- Motif de fenêtre -------------------------------------------------------
// Repris tel quel de CalendarPopup.qml et ControlCenter.qml : une surface
// PLEIN ÉCRAN transparente dont la bulle n'est qu'un enfant. C'est ce qui donne
// la fermeture au clic extérieur sans surveiller un « dehors ». Un troisième
// motif de fenêtre pour le même besoin n'aurait rien apporté.
PanelWindow {
    id: root

    // SystemTrayItem. Nullable : la fenêtre peut naître avant que l'appelant
    // ait posé l'item, et l'item peut disparaître pendant que le menu est
    // ouvert (une application qui se ferme).
    property var trayItem: null

    // Centre de la cellule cliquée, en coordonnées de la barre. Une MESURE,
    // pas un placement : c'est ce fichier, et lui seul, qui décide où la bulle
    // se pose à partir d'elle.
    property real anchorX: 0

    signal dismissed()

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-traymenu"

    // Rien à taper dans un menu contextuel, comme dans le calendrier.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // --- Navigation par pile, pas par imbrication -------------------------
    // Un sous-menu REMPLACE la liste au lieu de s'indenter dessous. Ce n'est
    // pas un choix esthétique : QML refuse qu'un composant s'instancie
    // récursivement, et une ligne de menu qui contient des lignes de menu est
    // exactement ça (voir l'en-tête de TrayMenuEntry.qml). La pile contourne
    // l'interdit sans le contourner de travers — profondeur arbitraire, aucun
    // cycle de type, et une largeur de 320 px qui reste lisible là où trois
    // niveaux d'indentation ne tiendraient pas.
    //
    // La pile contient des QsMenuHandle. Vide = on est au premier niveau.
    property var stack: []

    readonly property var currentMenu:
        root.stack.length > 0 ? root.stack[root.stack.length - 1]
                              : (root.trayItem ? root.trayItem.menu : null)

    function descend(handle: var): void {
        // Concat plutôt que push : muter un tableau en place ne notifie pas la
        // liaison, et `currentMenu` ne se réévaluerait pas.
        root.stack = root.stack.concat([handle]);
    }

    function ascend(): void {
        root.stack = root.stack.slice(0, -1);
    }

    QsMenuOpener {
        id: opener

        // Un DBusMenuHandle EST un QsMenuHandle — vérifié à l'exécution, le
        // menu d'un item se lit « qs::menu::QsMenuHandle(0x…) ». Les qmltypes
        // laissaient planer un doute sur la parenté des deux types ; le
        // runtime tranche. Un QsMenuEntry en est un aussi, ce qui permet de
        // rouvrir l'opener sur une entrée de sous-menu telle quelle.
        menu: root.currentMenu
    }

    // --- Nettoyage des séparateurs ---------------------------------------
    // Pas de la cosmétique : DBusMenu envoie pour de vrai des séparateurs en
    // tête et des séparateurs consécutifs. Mesuré sur le menu de blueman, 17
    // entrées, dont deux filets qui se suivent et un filet en première
    // position. Rendus tels quels, ils donnent un menu qui commence par une
    // barre et contient des doubles barres.
    readonly property var entries: {
        const src = opener.children ? opener.children.values : [];
        const out = [];

        for (const e of src) {
            if (e.isSeparator) {
                if (out.length === 0) continue;                  // jamais en tête
                if (out[out.length - 1].isSeparator) continue;   // jamais deux
            }
            out.push(e);
        }

        while (out.length > 0 && out[out.length - 1].isSeparator) out.pop();

        return out;
    }

    // Zone de rejet : tout l'écran, sous la bulle. Elle comprend la barre,
    // donc le tiroir : le clic qui referme le menu ne rouvre rien.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.dismissed()
    }

    Rectangle {
        id: bubble

        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + 8

        // Centrée sur la cellule cliquée, puis rabattue dans l'écran. Le
        // tiroir vit à droite de la barre : sans la borne, un menu large
        // sortirait par le bord droit.
        x: Math.max(8, Math.min(root.anchorX - width / 2, root.width - width - 8))

        // Largeur fixe et libellés élidés. L'alternative — se dimensionner sur
        // le plus long libellé — laisserait une application décider de la
        // largeur d'une fenêtre de la barre, et le menu de blueman contient
        // « Profils audio et d'entrée sur DualSense Wireless Controller ».
        implicitWidth: 320
        implicitHeight: list.implicitHeight

        // Fond, rayon et filet repris de CalendarPopup.qml : trois bulles qui
        // sortent de la même barre n'ont pas à avoir trois silhouettes.
        color: Theme.bg
        radius: 14
        border.width: 1
        border.color: Theme.muted

        // Absorbe les clics tombés dans la bulle. Sans elle, ils
        // traverseraient jusqu'à la zone de rejet et refermeraient le menu
        // avant que la ligne visée ait reçu quoi que ce soit.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        // MenuList porte exactement ce qui manque ici : l'empilement, le
        // plafond de hauteur et le défilement au-delà. spacing: 0 parce qu'un
        // menu contextuel est contigu, contrairement aux listes de réseaux.
        MenuList {
            id: list

            width: parent.width
            rows: 12
            rowHeight: 30
            spacing: 0

            // Ligne de retour, présente seulement en sous-menu. Elle n'est
            // pas une TrayMenuEntry : elle ne vient pas de DBusMenu et ne
            // déclenche rien chez l'application.
            Item {
                width: list.width
                height: root.stack.length > 0 ? list.rowHeight : 0
                visible: root.stack.length > 0

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    radius: 6

                    color: backHover.hovered
                           ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)
                           : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        // md-chevron_left, le même glyphe que le chevron de la
                        // barre, vérifié au rendu.
                        text: "\u{F0141}"
                        color: Theme.accent
                        style: Text.Normal
                    }
                }

                HoverHandler { id: backHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.ascend()
                }
            }

            Repeater {
                model: root.entries

                TrayMenuEntry {
                    required property var modelData

                    width: list.width
                    entry: modelData
                    rowHeight: list.rowHeight

                    onActivated: root.dismissed()
                    onSubmenuRequested: handle => root.descend(handle)
                }
            }

            // DBusMenu est distant : la disposition arrive après l'ouverture.
            // Sans cette ligne, le menu naît comme une bulle plate de 2 px, ce
            // qui se lit comme un bug plutôt que comme une attente.
            StyledText {
                width: list.width
                height: root.entries.length === 0 ? list.rowHeight : 0
                visible: root.entries.length === 0

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                text: "…"
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                style: Text.Normal
            }
        }
    }
}
