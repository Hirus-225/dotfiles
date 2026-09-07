import QtQuick

// Slider générique sur 0..1. Il ne connaît aucun service : il reçoit une
// valeur, il demande un changement. C'est l'appelant qui sait ce que ça veut
// dire.
//
// Pas de valeur locale, pas de « pendant le glissement c'est moi l'autorité » :
// `value` est lié directement au service. Mesuré — sur un glissement simulé de
// 40 frames à 16 ms, PipeWire comme sysfs renvoient la valeur écrite sans
// jamais accuser plus d'une frame de retard (0 frame en écart sur 40). La
// machinerie habituelle pour masquer la latence n'a rien à masquer ici.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property real step: 0.05        // un cran de molette
    property bool active: true      // false = service indisponible

    signal moved(real v)

    // Zone d'icône optionnelle. Le disque de tête devient un bouton distinct
    // du glissement — c'est ce qui manquait : l'icône affichait l'état de
    // sourdine sans qu'aucun clic n'y soit branché, et un clic dessus tombait
    // sur la zone de glissement, qui posait la valeur ~0,036 ET démutait.
    //
    // Laissée à false, la zone est désactivée et les clics retombent sur le
    // glissement : le slider de luminosité garde donc son clic sur toute sa
    // largeur.
    property bool iconClickable: false

    signal iconClicked()

    implicitHeight: 34
    implicitWidth: 200

    function clamp(v: real): real { return Math.max(0, Math.min(1, v)); }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Theme.muted
        opacity: root.active ? 1 : 0.35

        Rectangle {
            // Jamais plus étroit que sa propre hauteur : à zéro le remplissage
            // reste un disque sous l'icône, qui garde donc toujours le même
            // fond. Sans ça l'icône passerait du fond accent au fond muted en
            // cours de course.
            width: Math.max(parent.height, parent.width * root.clamp(root.value))
            height: parent.height
            radius: parent.radius
            color: Theme.accent

            Behavior on width {
                enabled: !drag.pressed   // pendant le glissement, aucune inertie
                NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
            }
        }

        // Frontière visible de la zone d'icône.
        //
        // Sans elle, la zone cliquable était invisible : dès que le
        // remplissage dépasse le disque de tête, l'icône se fond dedans et
        // rien n'indique où finit le bouton et où commence le slider. Mesuré
        // sur l'écran : couper le son marchait jusqu'à x=1138 et posait le
        // volume à 12 % dès x=1141. Trois pixels séparaient les deux, sans le
        // moindre repère — je demandais de viser une cible qu'on ne voit pas.
        //
        // Le trait est exactement à root.height, donc l'affordance et la zone
        // de clic coïncident au pixel.
        Rectangle {
            visible: root.iconClickable

            x: root.height
            width: 1
            height: parent.height * 0.42
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.bg
            opacity: 0.35
        }

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter

            text: root.icon
            color: Theme.bg
            font.pixelSize: Theme.fontSize + 1
            style: Text.Normal      // pas de contour : l'icône est sur un aplat
        }
    }

    // Cumul de molette. Les événements du pavé tactile arrivent par salves plus
    // fines qu'une frame ; on les additionne et on n'écrit qu'une fois par
    // frame. `value` n'est donc lu qu'une fois par salve, après que le service
    // s'est posé (mesuré : 2 à 3 ms, moins d'une frame).
    //
    // Contrairement au Volume.qml de la barre, l'application est
    // proportionnelle et non quantifiée au cran : sur un slider un pavé tactile
    // doit glisser, pas sauter. Une molette de souris envoie exactement 120 par
    // cran, donc un cran = un `step` — les deux entrées restent justes.
    property real pending: 0

    function applyWheel(delta: real): void {
        if (!root.active) return;
        root.pending += delta;
        if (!flush.running) flush.start();
    }

    Timer {
        id: flush

        interval: 16

        onTriggered: {
            const d = root.pending / 120 * root.step;
            root.pending = 0;
            if (d !== 0) root.moved(root.clamp(root.value + d));
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        function pick(x: real): void { root.moved(root.clamp(x / width)); }

        onPressed: event => pick(event.x)
        onPositionChanged: event => { if (pressed) pick(event.x); }
        onWheel: event => root.applyWheel(event.angleDelta.y)
    }

    // Déclarée APRÈS la zone de glissement : à position égale, c'est le
    // dernier déclaré qui reçoit l'événement. Désactivée, une MouseArea est
    // transparente aux événements, donc rien à isoler quand iconClickable
    // est faux.
    //
    // Elle couvre exactement le disque de tête, soit la largeur d'une hauteur.
    // On y perd le clic-pour-poser sur les ~11 % de gauche du slider de
    // volume — une zone où poser une valeur au clic était de toute façon
    // imprécise, et où le glissement reste possible en partant d'ailleurs.
    MouseArea {
        width: root.height
        height: root.height

        enabled: root.active && root.iconClickable
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: root.iconClicked()
    }
}
