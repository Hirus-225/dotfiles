import Quickshell
import QtQuick

// Tiroir de tray, dans la barre. Un chevron toujours visible ; le reste des
// items n'existe que déplié.
//
// Ce module ne connaît pas sa place dans la barre : aucun `anchors` ici, il
// n'expose qu'une taille implicite. C'est Bar.qml qui l'ancre, comme pour
// Connectivity et Battery.
//
// Il ne connaît pas non plus le service : il lit Services.trayItems et
// Services.trayAttention, jamais Quickshell.Services.SystemTray. Le seul
// import Quickshell de ce fichier sert à QsWindow (pour ouvrir le menu) et à
// Quickshell.hasThemeIcon (pour détecter une icône absente) — deux fonctions
// du cœur, pas un service.
//
// --- Si le tiroir est vide, ce n'est probablement pas ce fichier -----------
// Un tiroir vide veut d'abord dire que personne ne s'est enregistré auprès du
// watcher, pas que l'affichage est cassé. La question se tranche sur le bus,
// pas dans le QML :
//
//     busctl --user get-property org.kde.StatusNotifierWatcher \
//       /StatusNotifierWatcher org.kde.StatusNotifierWatcher \
//       RegisteredStatusNotifierItems
//
// Liste vide : le problème est l'ordre de lancement des applets, pas ici.
// Liste pleine et pastille vide : alors c'est ce fichier. Ce qui a été mesuré
// au moment de l'écrire est détaillé dans la section tray de Services.qml —
// blueman s'est enregistré à chaud, sans redémarrage, contre toute attente.
//
// --- Pas d'animation de largeur, et c'est un choix -------------------------
// La spec l'autorise ; voici pourquoi il est pris. Le contenu du tiroir est
// détruit au repli (Loader.active, voir plus bas) : il n'y a plus rien à
// faire glisser une fois le repli commencé. Animer la largeur de la pastille
// pendant que son contenu disparaît d'un coup donnerait un mouvement qui ment
// sur ce qui se passe — pire que pas de mouvement. Et le rattraper
// proprement supposerait de garder le contenu vivant le temps de l'animation,
// donc exactement ce que la règle interdit. `clip: true`, qui masquerait le
// débordement, est banni pour cette carte.
//
// Reste ce qui ne coûte rien et ne ment pas : la rotation du chevron, une
// transformation sur un seul nœud de texte, aucun relayout.
Item {
    id: root

    property bool expanded: false

    // Le module ne sait pas ouvrir de fenêtre, il demande. Même découpage que
    // Clock et Connectivity, qui émettent `clicked` sans jamais nommer la
    // surface qui s'ouvre : c'est Bar.qml qui décide, et c'est Bar.qml qui
    // tient toutes les fenêtres de la config.
    //
    // anchorX est le centre de la cellule cliquée en coordonnées de la barre.
    // C'est une MESURE, pas un placement : le module dit où il est, pas où le
    // menu doit se poser.
    signal menuRequested(var trayItem, real anchorX)

    readonly property var items: Services.trayItems

    // Les items en alerte sortent du tiroir : ils restent affichés replié.
    // Un tiroir qui avale les alertes est une machine à les rater.
    readonly property var alerts:
        root.items.filter(i => i.status === Services.trayAttention)

    // Cible de clic, pas taille de dessin. 26 px parce que la machine se
    // pilote au pavé tactile : viser 22 px à la main y est un exercice.
    readonly property int cellSize: 26
    readonly property int iconSize: 22

    // Hauteur de la pastille, alignée sur celle de Connectivity : les deux
    // sont côte à côte dans la barre, deux hauteurs différentes se verraient.
    // Les cellules, elles, débordent de 2 px en haut et en bas — c'est la
    // marge de clic, elle n'est jamais peinte (voir `slot` plus bas).
    readonly property int pillHeight: 22

    implicitWidth: row.implicitWidth + 8
    implicitHeight: root.pillHeight

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: height / 2
        color: Theme.muted
    }

    // spacing: 0 volontairement. Chaque cellule fait 26 px pour une icône de
    // 22 : elle porte déjà 2 px de gouttière de chaque côté, donc 4 px entre
    // deux icônes voisines, ce qui suffit au pavé tactile. Un spacing en plus
    // s'ajouterait aussi autour du Loader replié — un Row compte l'espacement
    // d'un enfant de largeur nulle — et la pastille grandirait sans que rien
    // n'apparaisse.
    Row {
        id: row

        anchors.centerIn: parent
        spacing: 0

        // Le contenu du tiroir n'existe pas replié : rien n'est construit,
        // aucune icône n'est chargée, aucune MouseArea n'écoute.
        //
        // Loader (QtQuick) et non LazyLoader (Quickshell), et c'est vérifié à
        // l'exécution, pas supposé : un LazyLoader { active: true } chargeant
        // un Rectangle dans un Row a bien construit l'objet — lazy.item non
        // nul — mais avec parent === null, row.children.length === 0 et
        // row.implicitWidth === 0. Rien n'entre dans l'arbre visuel.
        // LazyLoader dérive de Reloadable, pas d'Item : c'est l'outil des
        // fenêtres (ControlCenter, CalendarPopup dans Bar.qml), pas des
        // éléments de barre. Il charge aussi en différé — lazy.item était
        // encore nul au Component.onCompleted — ce qu'on ne veut pas d'un
        // tiroir qui répond à un clic.
        //
        // Loader.active a exactement la sémantique demandée : inactif, rien
        // n'existe.
        //
        // La largeur explicite ci-dessous n'est pas une coquetterie, c'est un
        // BUG DE QQuickLoader contourné, et il ne se voit qu'au deuxième clic.
        // Mesuré, en instrumentant la bascule aller-retour :
        //
        //     replié, jamais ouvert   item=null   implicitWidth=0    → 34 px
        //     ouvert                  item=Row    implicitWidth=26   → 60 px
        //     replié APRÈS ouverture  item=null   implicitWidth=26   → 60 px
        //
        // Le Loader décharge bien son item — item redevient null, le contenu
        // cesse d'exister, la règle est tenue — mais il GARDE la taille
        // implicite du dernier item chargé. Qt ne la remet jamais à zéro
        // (_q_updateSize sort tôt quand il n'y a plus d'item). La pastille
        // restait donc large de 60 px, vide, après le repli.
        //
        // Encore une valeur plausible et fausse : rien ne prévient, et les
        // deux états testés SÉPARÉMENT sont corrects — seul l'aller-retour
        // révèle le défaut. Un test qui ne fait pas le chemin du retour ne
        // prouve rien ici.
        //
        // On ne lit donc pas la taille implicite du Loader quand il est
        // inactif : le Row se sert de `width`, et c'est `width` qu'on force.
        // Pas de `visible: false` — ce n'est pas la visibilité qui est en
        // cause, c'est une mesure périmée.
        Loader {
            active: root.expanded

            width: root.expanded ? implicitWidth : 0

            sourceComponent: Row {
                spacing: 0

                Repeater {
                    model: root.items
                    delegate: trayCell
                }
            }
        }

        // Les alertes, hors tiroir. Modèle vide quand le tiroir est ouvert :
        // sinon l'item en alerte serait dessiné deux fois, ici et dans le
        // tiroir.
        Repeater {
            model: root.expanded ? [] : root.alerts
            delegate: trayCell
        }

        // Le chevron. Toujours là, y compris tiroir vide — atténué, pas
        // absent : un module qui disparaît quand il n'a rien à dire se
        // confond avec un module cassé.
        //
        // Il reste cliquable dans ce cas. La rotation est alors la seule
        // réponse visible, et c'est le but : elle prouve que le module est
        // vivant et que le tray est simplement vide.
        Item {
            implicitWidth: root.cellSize
            implicitHeight: root.cellSize

            StyledText {
                anchors.centerIn: parent

                // md-chevron_left. Codepoint VÉRIFIÉ au rendu, pas de
                // mémoire : F0140 est chevron_down, F0141 chevron_left,
                // F0142 chevron_right, F0143 chevron_up.
                //
                // Il pointe à gauche replié parce que le tiroir s'ouvre vers
                // la gauche — le module est ancré à droite dans la barre, sa
                // largeur croît donc de ce côté. Déplié, la rotation le
                // renvoie vers la droite : « repousse tout ça ».
                text: "\u{F0141}"
                style: Text.Normal      // sur un aplat, pas de contour

                // Trois niveaux, même langage que le tint() de Connectivity :
                // rien à montrer / replié / ouvert.
                color: root.items.length === 0
                       ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35)
                       : root.expanded ? Theme.accent : Theme.fg

                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                onClicked: root.expanded = !root.expanded
            }
        }
    }

    // Une seule définition de cellule, utilisée par les deux Repeater : celui
    // du tiroir et celui des alertes. Un item en alerte doit être dessiné et
    // se comporter à l'identique des deux côtés du repli.
    Component {
        id: trayCell

        Item {
            id: cell

            required property var modelData

            implicitWidth: root.cellSize
            implicitHeight: root.cellSize

            // Repli lisible plutôt que joli : la première lettre du nom de
            // l'item. Une icône absente ne doit pas laisser un trou anonyme
            // dans la pastille.
            readonly property string initial: {
                const s = (cell.modelData.title || cell.modelData.id || "").trim();
                return s ? s.charAt(0).toUpperCase() : "?";
            }

            // La surface peinte de la cellule. Elle fait la hauteur de la
            // pastille, PAS celle de la cellule : la cellule déborde de 2 px
            // en haut et en bas pour agrandir la cible de clic, et sans
            // `clip` un survol dessiné sur toute sa hauteur baverait hors de
            // la pastille, sur le fond de la barre.
            Rectangle {
                id: slot

                anchors.centerIn: parent
                width: parent.width
                height: root.pillHeight
                radius: 6

                // La seule affordance qui ne dépende PAS de l'icône. Elle
                // vaut aussi pour le trou assumé de TrayIcon.iconMissing() :
                // même parfaitement transparent, un item reste survolable,
                // donc trouvable au pavé tactile.
                color: Theme.accent
                opacity: zone.containsMouse ? 0.25 : 0

                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            TrayIcon {
                anchors.centerIn: parent

                size: root.iconSize
                source: cell.modelData.icon
                fallbackText: cell.initial
            }

            // Marqueur d'alerte. Ancré sur `slot` et non sur la cellule, pour
            // la même raison que la hauteur de `slot` : rester dans la
            // pastille.
            Rectangle {
                visible: cell.modelData.status === Services.trayAttention

                width: 6
                height: 6
                radius: 3
                color: Theme.alert

                anchors.right: slot.right
                anchors.top: slot.top
                anchors.rightMargin: 1
                anchors.topMargin: 1
            }

            // On n'appelle PAS modelData.display(). C'était la première
            // version, et le premier clic droit réel l'a démentie :
            //
            //     ERROR: Cannot display PlatformMenuEntry as quickshell was
            //            not started in QApplication mode.
            //
            // display() ouvre un menu de PLATEFORME, indisponible hors mode
            // QApplication — et qui, même disponible, serait peint par le
            // style de widgets de Qt, donc sourd à Theme et à pywal. Le menu
            // est rendu en QML : voir TrayMenu.qml.
            //
            // QsWindow.itemRect() sert encore, mais seulement à MESURER où se
            // trouve la cellule dans la barre. Vérifié : renvoie bien un
            // rectangle en coordonnées de fenêtre (1224,5 26x26).
            //
            // Renvoie false si rien n'a pu être demandé, pour que l'appelant
            // décide de la suite. hasMenu peut rester faux après l'apparition
            // de l'item : DBusMenu est distant, donc asynchrone, comme tous
            // les services au démarrage à froid.
            function openMenu(): bool {
                if (!cell.modelData.hasMenu) return false;

                const r = cell.QsWindow.itemRect(cell);
                root.menuRequested(cell.modelData, r.x + r.width / 2);
                return true;
            }

            MouseArea {
                id: zone

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                // Clic droit : le menu. Clic gauche : l'activation — sauf si
                // l'item déclare onlyMenu, auquel cas il n'a pas d'action
                // d'activation et le clic gauche doit ouvrir le menu lui aussi.
                //
                // Repli si le menu n'est pas (encore) là : on active. Un item
                // onlyMenu dont le DBusMenu n'a pas fini d'arriver rend ainsi
                // un clic inerte plutôt qu'un clic perdu.
                onClicked: event => {
                    const wantsMenu =
                        event.button === Qt.RightButton || cell.modelData.onlyMenu;

                    if (wantsMenu && cell.openMenu()) return;
                    if (event.button === Qt.LeftButton) cell.modelData.activate();
                }
            }
        }
    }
}
