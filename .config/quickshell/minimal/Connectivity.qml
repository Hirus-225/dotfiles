import QtQuick

// Bulle d'état, dans la barre. Quatre icônes — cloche, Wi-Fi, Bluetooth, son —
// et le point d'entrée du centre de contrôle.
//
// La cloche est la SEULE zone de la bulle qui n'ouvre pas le centre de
// contrôle : elle ouvre le centre de notifications de swaync. Elle est donc
// traitée comme le chevron du Toggle — une seconde MouseArea déclarée après la
// première, et un trait posé exactement sur sa frontière pour que l'affordance
// et la cible coïncident au pixel.
//
// Ce module TOURNE EN PERMANENCE, panneau fermé. Il ne fait donc que lire :
// aucun scan, aucune découverte. Les propriétés coûteuses restent pilotées par
// les compteurs de Services, que ce module n'incrémente jamais — seuls le
// panneau et le menu Wi-Fi le font.
//
// Sa seule conséquence est que le singleton Services est référencé dès le
// démarrage du shell. Les connexions D-Bus vers NetworkManager et BlueZ sont
// donc ouvertes en continu, et le PwObjectTracker de Services est instancié en
// continu lui aussi. Coût mesuré : voir l'en-tête de Services.qml.
//
// Depuis que Volume.qml a quitté la barre, c'est ce tracker-là, et lui seul,
// qui peuple PwNodeAudio. Sans PwObjectTracker, mesuré : volume reste à 0 et
// volumes à [] indéfiniment. La garde `audioAvailable` couvre la fenêtre de
// démarrage où defaultAudioSink est encore nul.
Rectangle {
    id: root

    signal clicked()

    implicitWidth: icons.implicitWidth + 18
    implicitHeight: 22

    radius: height / 2
    color: Theme.muted

    // Trois niveaux, pas deux : « indisponible » (pas de radio, rfkill,
    // démon absent) ne doit pas se confondre avec « éteint ».
    function tint(available: bool, on: bool): color {
        if (!available) return Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22);
        if (!on) return Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45);
        return Theme.accent;
    }

    // --- Ce que tint() veut dire pour un volume -------------------------------
    // Pour une radio, `on` veut dire « le sous-système est allumé ». Un volume
    // n'a pas d'interrupteur équivalent : PipeWire est allumé ou absent, il
    // n'est jamais « éteint ».
    //
    // On garde donc les trois niveaux en leur donnant le sens le plus proche,
    // qui est aussi le seul vérifiable à l'oreille :
    //   indisponible (0,22) — aucune sortie audio ; même sens que « pas de
    //                         carte Wi-Fi ». C'est la seule des trois valeurs
    //                         qui garde exactement son sens d'origine.
    //   éteint       (0,45) — muet OU volume à zéro. Les deux s'entendent
    //                         pareil, donc ils s'affichent pareil : prétendre
    //                         qu'un son sort alors que rien ne sort serait le
    //                         seul vrai contresens.
    //   allumé     (accent) — quelque chose sort.
    readonly property bool audioAvailable: Services.audio !== null
    readonly property bool audioOn:
        root.audioAvailable && !Services.audio.muted && Services.audio.volume > 0

    readonly property int pct: Services.audio ? Math.round(Services.audio.volume * 100) : 0

    // Le niveau approximatif, en plus de la teinte. Le glyphe muet est le même
    // que celui du slider du panneau (md-volume_off) : la même situation ne
    // doit pas avoir deux icônes selon la surface qui l'affiche.
    readonly property string volumeGlyph:
          !root.audioAvailable           ? "\u{F0581}"   // md-volume_off
        : Services.audio.muted           ? "\u{F0581}"
        : root.pct === 0                 ? "\u{F0581}"
        : root.pct <= 33                 ? "\u{F057F}"   // md-volume_low
        : root.pct <= 66                 ? "\u{F0580}"   // md-volume_medium
                                         : "\u{F057E}"  // md-volume_high

    // --- Ce que tint() veut dire pour une cloche ----------------------------
    // Même exercice que pour le volume : les trois niveaux gardent le sens le
    // plus proche de leur sens d'origine.
    //   indisponible (0,22) — swaync n'est pas là. On ne sait rien, et ne pas
    //                         savoir n'est pas « zéro notification » : le
    //                         nombre disparaît en même temps que la teinte.
    //   éteint       (0,45) — DND actif. Le glyphe barré le dit déjà ; la
    //                         teinte évite d'avoir à distinguer deux dessins
    //                         de cloche du coin de l'œil.
    //   allumé     (accent) — les notifications passent.
    readonly property bool notifOn: Services.swayncAvailable && !Services.dndEnabled

    readonly property string bellGlyph:
        Services.dndEnabled ? "\u{F009B}"   // md-bell_off
                            : "\u{F009A}"  // md-bell

    // Au-delà de 99 le nombre exact n'apprend plus rien et coûterait une
    // quatrième colonne.
    readonly property string badge:
        Services.notifCount > 99 ? "99+" : String(Services.notifCount)

    Row {
        id: icons

        anchors.centerIn: parent
        spacing: 10

        // La cloche et son nombre forment UN objet : c'est ce groupe, et lui
        // seul, qui ouvre swaync. Même largeur figée que le volume, et pour la
        // même raison — la bulle est ancrée à droite, deux dessins de cloche
        // de chasse différente feraient sauter son bord gauche à chaque
        // bascule du DND.
        Row {
            id: bellGroup

            spacing: 4

            StyledText {
                width: root.bellWidth
                horizontalAlignment: Text.AlignHCenter

                text: root.bellGlyph
                color: root.tint(Services.swayncAvailable, root.notifOn)
                style: Text.Normal

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Le nombre n'a pas de largeur figée, lui : il apparaît et
            // disparaît avec les notifications, et son passage de 9 à 10 est
            // un vrai changement d'état. Ce n'est pas le même cas que le
            // glyphe de volume, qui changeait de chasse sans rien dire de neuf.
            StyledText {
                visible: Services.swayncAvailable && Services.notifCount > 0

                text: root.badge
                color: root.tint(Services.swayncAvailable, root.notifOn)
                style: Text.Normal

                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // La frontière. Construction du Toggle reprise telle quelle : le trait
        // est exactement sur le bord de la zone de clic de la cloche.
        Rectangle {
            id: bellEdge

            width: 1
            height: root.height * 0.55
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.fg
            opacity: 0.25
        }

        StyledText {
            text: "\u{F1EB}"
            color: root.tint(Services.wifiAvailable, Services.wifiEnabled)
            style: Text.Normal      // sur un aplat, pas de contour

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        StyledText {
            text: "\u{F293}"
            color: root.tint(Services.btAvailable, Services.btEnabled)
            style: Text.Normal

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Largeur figée, contrairement aux deux autres icônes qui ne changent
        // jamais de glyphe. Les quatre glyphes de volume n'ont pas le même
        // chasse — mesuré : 2 px d'écart entre md-volume_off et
        // md-volume_medium. La bulle étant ancrée à droite, son bord gauche
        // sauterait de 2 px à chaque passage d'un niveau à l'autre et à chaque
        // sourdine. Elle est calculée, pas écrite en dur : Theme.fontSize peut
        // changer.
        StyledText {
            width: root.volumeWidth
            horizontalAlignment: Text.AlignHCenter

            text: root.volumeGlyph
            color: root.tint(root.audioAvailable, root.audioOn)
            style: Text.Normal

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    readonly property real volumeWidth:
        Math.max(mOff.width, mLow.width, mMed.width, mHigh.width)

    readonly property real bellWidth: Math.max(mBell.width, mBellOff.width)

    // Mesure hors scène : ces quatre objets ne peignent rien et ne se
    // réévaluent qu'au changement de police.
    TextMetrics { id: mOff;  font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; text: "\u{F0581}" }
    TextMetrics { id: mLow;  font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; text: "\u{F057F}" }
    TextMetrics { id: mMed;  font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; text: "\u{F0580}" }
    TextMetrics { id: mHigh; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; text: "\u{F057E}" }
    TextMetrics { id: mBell;    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; text: "\u{F009A}" }
    TextMetrics { id: mBellOff; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; text: "\u{F009B}" }

    // --- Molette : l'accumulateur de Volume.qml, déplacé tel quel -------------
    // Le pavé tactile émet des deltas continus très fins : on accumule jusqu'au
    // cran (120). L'application est différée d'une frame — mesuré : après une
    // écriture, PipeWire renvoie l'ancienne valeur pendant ~2 ms avant que la
    // nouvelle se pose (50 → 55 → 50 → 55). Deux écritures espacées de moins de
    // ~3 ms liraient donc la même base et un cran serait perdu. `pct` n'est lu
    // qu'une fois par salve, une fois stabilisé.
    //
    // Le reste de la salve est conservé entre deux chasses : c'est ce qui rend
    // le geste continu sur un pavé tactile plutôt que quantifié par tranches
    // perdues.
    //
    // Seule différence avec l'original : sans sortie audio, l'accumulateur est
    // remis à zéro au lieu d'être laissé à grossir. Dans Volume.qml il gonflait
    // indéfiniment, et le premier cran après le branchement d'un casque aurait
    // appliqué toute la salve d'un coup — écrêtée à 100 %.
    property int wheelAcc: 0
    property int step: 5

    Timer {
        id: wheelFlush

        interval: 16

        onTriggered: {
            if (!Services.audio) { root.wheelAcc = 0; return; }

            const notches = Math.trunc(root.wheelAcc / 120);
            if (notches === 0) return;
            root.wheelAcc -= notches * 120;

            // setVolume écrête à [0, 1] et lève la sourdine APRÈS l'écriture,
            // donc sans blip au volume précédent. C'est exactement ce que
            // faisaient les deux dernières lignes de Volume.qml.
            Services.setVolume((root.pct + notches * root.step) / 100);
        }
    }

    function applyWheel(delta: int): void {
        root.wheelAcc += delta;
        if (!wheelFlush.running) wheelFlush.start();
    }

    // Une seule zone pour toute la bulle : le clic ouvre le panneau où qu'il
    // tombe, la molette règle le volume où qu'elle tourne. Aucune des trois
    // icônes n'a de zone propre — la bulle est un objet, pas trois boutons
    // collés.
    //
    // Le clic sur l'icône de son n'active donc PAS la sourdine, contrairement
    // à ce que faisait Volume.qml. La bascule de sourdine vit maintenant sur
    // le disque de tête du slider, dans le panneau, qui est à un clic d'ici.
    MouseArea {
        id: zoneAll
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: root.clicked()
        onWheel: event => root.applyWheel(event.angleDelta.y)
    }

    // Déclarée APRÈS la zone générale, comme la bande du chevron dans
    // Toggle.qml : à position égale c'est la dernière déclarée qui reçoit
    // l'événement.
    //
    // Sa largeur n'est pas écrite en dur et n'est pas mesurée à la souris :
    // elle est LA position du trait, exprimée dans le repère de la bulle.
    // `icons` est centré, donc son x bouge avec la largeur du contenu — le
    // nombre qui apparaît décale tout — et `bellEdge.x` bouge avec lui. Les
    // deux sont des propriétés, donc la liaison se réévalue : la cible suit le
    // trait sans qu'on ait à y penser.
    //
    // Elle reste activée même swaync absent, exactement comme la bande d'un
    // chevron grisé : désactivée, une MouseArea est transparente aux
    // événements, le clic tomberait sur la zone générale dessous et viser une
    // cloche éteinte ouvrirait le centre de contrôle. Elle absorbe donc le
    // clic et ne fait rien.
    //
    // La molette y est répétée : sans ça, le geste de volume mourrait sur la
    // largeur de la cloche. La bulle reste un seul objet pour la molette,
    // elle n'est coupée en deux que pour le clic.
    //
    // VÉRIFIÉ AU PIXEL, par root.childAt(x, height/2) — c'est pour ça que les
    // deux zones portent un id. Sans nombre affiché, bulle large de 105 px :
    //   x=0 … 30  → zoneBell        x=31 … 104 → zoneAll
    // Avec « 12 » affiché, la bulle passe à 124 px et la frontière suit toute
    // seule, sans qu'aucune constante ne bouge :
    //   x=0 … 50  → zoneBell        x=51 … 123 → zoneAll
    // Le trait est dessiné en x=31 (puis 51) : la première colonne qui
    // n'appartient plus à la cloche est exactement celle du trait.
    MouseArea {
        id: zoneBell
        x: 0
        y: 0
        width: icons.x + bellEdge.x
        height: root.height

        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: {
            if (Services.swayncAvailable) Services.toggleNotificationCenter();
        }
        onWheel: event => root.applyWheel(event.angleDelta.y)
    }
}
