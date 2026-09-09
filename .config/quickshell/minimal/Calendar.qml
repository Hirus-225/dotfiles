import QtQuick
import QtQuick.Controls

// Grille du mois. Ce module ne sait NI où il est affiché, ni dans quoi : il
// n'a pas d'anchors, il expose implicitWidth / implicitHeight et c'est son
// parent qui le pose. CalendarPopup.qml est le seul fichier qui décide d'un
// placement.
//
// Vérifié sur cette machine (Qt 6.11.2, Quickshell 0.3.1) : MonthGrid et
// DayOfWeekRow sont bien exposés par QtQuick.Controls (déclarés en 6.3 dans
// Basic/qmldir), et s'importent sans incident dans le moteur de Quickshell.
//
// Aucun timer : le LazyLoader détruit et reconstruit ce module à chaque
// ouverture, donc `today` est relu à la construction. Un shell laissé ouvert
// pendant un passage de minuit rouvrira sur la bonne date sans rien surveiller
// entre-temps.
Item {
    id: root

    // La date du jour, figée à la construction — voir ci-dessus.
    readonly property date today: new Date()

    // Le mois AFFICHÉ, qui n'est plus celui du jour dès le premier clic de
    // navigation. 0-base : c'est la convention de MonthGrid.month ET celle de
    // Date.getMonth(), vérifiées identiques (month: 8 → « septembre »). Aucune
    // conversion ±1 à faire nulle part, et donc aucune à oublier quelque part.
    property int shownYear: root.today.getFullYear()
    property int shownMonth: root.today.getMonth()

    // Trackpad, pas souris de précision : les deux zones de navigation font
    // 30x30, au-dessus du plancher de 26.
    readonly property int cellWidth: 30
    readonly property int cellHeight: 26
    readonly property int navSize: 30
    readonly property int pad: 14

    implicitWidth: content.implicitWidth + 2 * root.pad
    implicitHeight: content.implicitHeight + 2 * root.pad

    // Le décalage passe par un objet Date et par son débordement, pas par une
    // arithmétique modulo écrite à la main : `new Date(2026, 12, 1)` vaut
    // janvier 2027 et `new Date(2026, -1, 1)` vaut décembre 2025 — les deux
    // vérifiés. Décembre +1 et janvier -1 ne sont donc pas des cas
    // particuliers, ils n'existent pas.
    function shift(delta: int): void {
        const d = new Date(root.shownYear, root.shownMonth + delta, 1);
        root.shownYear = d.getFullYear();
        root.shownMonth = d.getMonth();
    }

    Column {
        id: content

        anchors.centerIn: parent
        spacing: 6

        // --- En-tête : mois précédent / titre / mois suivant ----------------
        Item {
            // Largeur prise sur la grille, PAS sur la Column : la Column tire
            // sa largeur du plus large de ses enfants, dont cet en-tête. Un
            // `width: content.implicitWidth` ici serait une boucle de liaison.
            implicitWidth: grid.implicitWidth
            implicitHeight: root.navSize

            NavButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                glyph: "\u{F0141}"      // chevron-gauche
                onTriggered: root.shift(-1)
            }

            // `title` est fourni par MonthGrid et suit son locale : « décembre
            // 2026 » puis « janvier 2027 » après un +1 — la liaison a bien été
            // vue se réévaluer, ce n'est pas une valeur figée à la
            // construction. Seule la capitale initiale est ajoutée ici, le
            // français écrit les mois en minuscule.
            StyledText {
                anchors.centerIn: parent

                text: grid.title.charAt(0).toUpperCase() + grid.title.slice(1)
                font.pixelSize: Theme.fontSize
                style: Text.Normal
            }

            NavButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                glyph: "\u{F0142}"      // chevron-droit
                onTriggered: root.shift(1)
            }
        }

        // --- Ligne des jours de la semaine ----------------------------------
        // Le locale fait DEUX choses ici, et la seconde est invisible tant
        // qu'elle est juste : il donne les noms français, et il met lundi en
        // première colonne (firstDayOfWeek = 1, vérifié). Sans lui, la grille
        // resterait cohérente avec elle-même tout en étant décalée d'un jour.
        DayOfWeekRow {
            locale: Qt.locale("fr_FR")
            spacing: 0

            // Les deux paddings verticaux sont remis à plat un par un : le
            // style Basic les fixe à 6 dans son propre fichier, et un
            // `padding: 0` global ne les écrase pas.
            padding: 0
            topPadding: 0
            bottomPadding: 4

            // Le delegate par défaut de DayOfWeekRow est un Text nu qui prend
            // control.font et control.palette.text, donc la police et la
            // couleur du style Qt — pas celles de Theme. Il est remplacé pour
            // cette seule raison.
            delegate: StyledText {
                required property var model

                width: root.cellWidth
                height: 20

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                // Le modèle expose day / shortName / narrowName / longName —
                // vérifié. shortName rend « lun. », narrowName rend « L », donc
                // deux M et deux S indistinguables : le point de « lun. » coûte
                // moins cher que l'ambiguïté.
                text: model.shortName
                color: Theme.muted
                font.pixelSize: Theme.fontSize - 2
                style: Text.Normal
            }
        }

        // --- Grille du mois --------------------------------------------------
        MonthGrid {
            id: grid

            locale: Qt.locale("fr_FR")
            year: root.shownYear
            month: root.shownMonth

            spacing: 0
            padding: 0

            // Même motif que ci-dessus : le delegate d'origine est un Text du
            // style Qt. Il porte en plus `opacity: model.month === control.month
            // ? 1 : 0` — les jours des mois voisins y sont donc franchement
            // INVISIBLES, pas atténués. La grille garde alors des trous là où
            // la semaine déborde. Ils sont ici affichés à 0.3.
            delegate: Item {
                id: cell

                required property var model

                // Rôles vérifiés sur cette version : day, month (0-base), year,
                // today (bool), date, weekNumber.
                readonly property bool inMonth: cell.model.month === grid.month
                readonly property bool isToday: cell.model.today && cell.inMonth

                implicitWidth: root.cellWidth
                implicitHeight: root.cellHeight

                // La pastille est conditionnée à `inMonth` et pas au seul
                // `today` : quand la grille d'un mois voisin affiche par
                // débordement le jour courant, celui-ci est un jour atténué
                // comme les autres, pas un second « aujourd'hui ».
                Rectangle {
                    anchors.centerIn: parent

                    width: root.cellHeight
                    height: root.cellHeight
                    radius: width / 2

                    color: Theme.accent
                    visible: cell.isToday
                }

                StyledText {
                    anchors.centerIn: parent

                    text: cell.model.day
                    color: cell.isToday ? Theme.bg : Theme.fg
                    opacity: cell.inMonth ? 1 : 0.3
                    style: Text.Normal
                }
            }
        }
    }

    // Bouton de navigation. Déclaré en composant local et pas dans un fichier à
    // part : il n'a aucun sens hors de cet en-tête, et un .qml à plat dans
    // minimal/ est enregistré globalement par Quickshell — ce serait un
    // composant public pour un usage privé.
    component NavButton: Item {
        id: navRoot

        property string glyph
        signal triggered()

        implicitWidth: root.navSize
        implicitHeight: root.navSize

        StyledText {
            anchors.centerIn: parent

            text: navRoot.glyph
            color: Theme.fg

            // Un cran au-dessus de la taille du texte : à Theme.fontSize le
            // chevron se lit comme un caractère de la ligne, pas comme la cible
            // qu'il est. La zone cliquable ne bouge pas pour autant — elle fait
            // la taille du NavButton, pas celle du glyphe.
            font.pixelSize: Theme.fontSize + 3
            opacity: zone.containsMouse ? 1 : 0.55
            style: Text.Normal

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
            }
        }

        MouseArea {
            id: zone

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton

            onClicked: navRoot.triggered()
        }
    }
}
