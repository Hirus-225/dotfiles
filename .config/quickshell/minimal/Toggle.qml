import QtQuick

// Toggle générique. Comme Slider.qml, il ne connaît aucun service : il reçoit
// un état, il émet une demande. C'est l'appelant qui traduit son service vers
// ces valeurs.
//
// L'état n'est PAS un booléen, et c'est la décision centrale du module. Un
// booléen ne sait dire qu'« allumé » ou « éteint » : il est structurellement
// incapable d'exprimer « bloqué par rfkill », « en transition » ou « source
// absente ». Il forcerait donc l'appelant à afficher l'état demandé faute de
// pouvoir dire autre chose — exactement ce qu'on ne veut pas.
Item {
    id: root

    // `Invalid` occupe délibérément la valeur 0.
    //
    // Mesuré : une référence non résolue (Toggle.State.Of au lieu de
    // Toggle.State.Off) ne lève pas d'erreur en QML. Elle vaut `undefined`, et
    // l'affectation à une propriété `int` la rabat sur 0 en n'émettant qu'un
    // avertissement dans les logs — « Unable to assign [undefined] to int ».
    // Si `Off` occupait la place 0, une faute de frappe donnerait un toggle
    // silencieusement éteint, indiscernable d'un toggle légitimement éteint.
    // Avec `Invalid` en 0, elle donne un toggle visiblement cassé.
    enum State { Invalid, Off, On, Busy, Unavailable }

    // Nommée toggleState et non state : Item possède déjà une propriété `state`
    // (chaîne, machine à états QtQuick) que la redéclarer masquerait.
    property int toggleState: Toggle.State.Invalid
    property string icon: ""

    signal toggled()

    // --- Bande d'expansion optionnelle --------------------------------------
    // Une tuile de 96 px ne peut pas porter deux gestes ambigus. La bande est
    // donc une zone SÉPARÉE et visible, sur toute la hauteur du bord droit,
    // avec son propre trait de frontière — exactement la solution retenue pour
    // le disque de tête du Slider, et pour la même raison : une zone cliquable
    // invisible est une cible qu'on demande de deviner.
    //
    // Elle est présente dès que `expandable`, même quand le menu n'est pas
    // ouvrable. Si elle apparaissait et disparaissait avec l'état de la radio,
    // l'icône se décalerait de 12 px à chaque bascule.
    property bool expandable: false
    property bool expanded: false

    signal expandRequested()

    readonly property int stripWidth: 24

    // Pas de menu quand la radio est éteinte, bloquée ou en transition. Un
    // menu Bluetooth radio éteinte listerait des appareils qu'aucun clic ne
    // peut connecter ; un menu Wi-Fi allumerait un scan sans interface pour le
    // porter.
    readonly property bool canExpand:
        root.expandable && root.toggleState === Toggle.State.On

    implicitHeight: 44
    implicitWidth: 96

    // Seuil d'affichage de l'attente.
    //
    // 120 ms : au-dessus du pire cas mesuré du Process DND (66,8 ms sous une
    // charge de 16 boucles CPU sur 4 cœurs ; 7,8 ms au repos, 28,5 ms sous
    // charge modérée), et en dessous du seuil où l'œil lit un délai comme une
    // latence plutôt que comme une réponse immédiate (~100 à 150 ms).
    //
    // Conséquence, avec les latences mesurées de chaque source : une bascule
    // DND normale n'affiche jamais d'attente ; une transition Bluetooth (154 à
    // 241 ms mesurés entre Enabling et Enabled) l'affiche toujours ; un swaync
    // coincé finit par se voir au lieu de passer pour un clic ignoré.
    //
    // Ne pas baisser ce nombre sans remesurer la latence DND sous charge.
    readonly property int busyDelay: 120

    // Dernier état stable connu. C'est lui qu'on affiche pendant l'incertitude
    // courte : le toggle reste sur ce qu'il savait, il n'affiche jamais ce qui
    // a été demandé.
    property int settled: Toggle.State.Off
    property bool busyVisible: false

    readonly property int shown:
        (root.toggleState === Toggle.State.Busy && !root.busyVisible)
            ? root.settled
            : root.toggleState

    // Ce qui est PEINT. Pendant l'attente on garde les couleurs du dernier état
    // stable : la pulsation dit « je ne sais pas encore », la couleur continue
    // de dire ce qu'on savait. Sans cette distinction, un allumage Bluetooth
    // afficherait allumé (BlueZ accepte à t+0), puis éteint pendant la
    // transition, puis allumé — mesuré, 243 ms de fausse couleur.
    readonly property int face:
        root.shown === Toggle.State.Busy ? root.settled : root.shown

    readonly property bool interactive:
        root.toggleState === Toggle.State.On || root.toggleState === Toggle.State.Off

    function absorb(): void {
        if (root.toggleState === Toggle.State.Busy) {
            busyTimer.restart();
        } else {
            busyTimer.stop();
            root.busyVisible = false;
            root.settled = root.toggleState;
        }
    }

    onToggleStateChanged: root.absorb()
    Component.onCompleted: root.absorb()

    Timer {
        id: busyTimer
        interval: root.busyDelay
        onTriggered: root.busyVisible = true
    }

    Rectangle {
        id: body

        anchors.fill: parent
        radius: height / 2

        color: {
            if (root.face === Toggle.State.Invalid) return Theme.alert;
            return root.face === Toggle.State.On ? Theme.accent : Theme.muted;
        }

        // Atténué quand la source est absente ou bloquée : ni allumé, ni
        // éteint — indisponible.
        //
        // `pulse` n'est lu que pendant l'attente. L'animation s'arrête sur la
        // valeur courante, qui resterait sinon figée à mi-course une fois
        // l'attente terminée.
        opacity: root.face === Toggle.State.Unavailable ? 0.35
               : root.busyVisible                      ? pulse
                                                       : 1

        // Pulsation d'attente, sur une propriété séparée de l'opacité pour
        // cette raison. Elle part de 1 et descend : une attente qui s'achève
        // juste après le seuil ne produit donc qu'un écart d'opacité
        // imperceptible, pas un clignotement.
        property real pulse: 1

        SequentialAnimation on pulse {
            running: root.busyVisible
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 350; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0;  duration: 350; easing.type: Easing.InOutQuad }
        }

        Behavior on color {
            ColorAnimation { duration: 120; easing.type: Easing.OutQuad }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            // Centrée sur ce qui RESTE de la tuile, pas sur la tuile entière.
            anchors.horizontalCenterOffset: root.expandable ? -root.stripWidth / 2 : 0

            text: root.icon
            color: root.face === Toggle.State.On || root.face === Toggle.State.Invalid
                   ? Theme.bg
                   : Theme.fg
            font.pixelSize: Theme.fontSize + 3
            style: Text.Normal      // pas de contour : l'icône est sur un aplat
        }

        // Frontière de la bande. Même construction que celle du Slider : le
        // trait est exactement sur le bord de la zone de clic, donc
        // l'affordance et la cible coïncident au pixel.
        Rectangle {
            visible: root.expandable

            x: parent.width - root.stripWidth
            width: 1
            height: parent.height * 0.42
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.bg
            opacity: 0.35
        }

        StyledText {
            visible: root.expandable

            anchors.right: parent.right
            anchors.rightMargin: (root.stripWidth - width) / 2
            anchors.verticalCenter: parent.verticalCenter

            text: "\u{F0140}"      // chevron-bas
            color: root.face === Toggle.State.On || root.face === Toggle.State.Invalid
                   ? Theme.bg
                   : Theme.fg
            opacity: root.canExpand ? 1 : 0.35
            font.pixelSize: Theme.fontSize
            style: Text.Normal

            // Le chevron pivote au lieu de changer de glyphe : la rotation dit
            // que c'est le MÊME bouton qui s'inverse, un second glyphe dirait
            // qu'un autre bouton a pris sa place.
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }
        }
    }

    MouseArea {
        anchors.fill: parent

        // Ni pendant une transition, ni quand la source est absente : un clic
        // empilé sur une commande en vol produirait deux demandes contraires.
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor

        onClicked: root.toggled()
    }

    // Déclarée APRÈS la zone de bascule, comme la zone d'icône du Slider : à
    // position égale c'est le dernier déclaré qui reçoit l'événement. Non
    // `expandable`, elle est désactivée donc transparente aux événements, et
    // la tuile reste cliquable sur toute sa largeur.
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.stripWidth

        // Activée dès que la bande EXISTE, pas seulement quand le menu est
        // ouvrable. Désactivée, une MouseArea est transparente aux événements :
        // le clic tomberait alors sur la zone de bascule dessous, et viser un
        // chevron grisé allumerait la radio. Elle absorbe donc le clic et ne
        // fait rien — le chevron grisé dit déjà pourquoi.
        enabled: root.expandable
        cursorShape: root.canExpand ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: { if (root.canExpand) root.expandRequested(); }
    }
}
