import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// PwNodeAudio n'est peuplé que si le node est suivi par un PwObjectTracker.
// Sans tracker, mesuré : volume reste à 0 et volumes à [] indéfiniment.
// defaultAudioSink vaut null au démarrage (avant Pipewire.ready) et chaque
// fois qu'aucune sortie n'existe : tout accès passe par audio, jamais direct.

StyledText {
    id: root

    // Liaisons en lecture seule. Rien ici n'est jamais affecté impérativement :
    // une affectation détruirait la liaison et figerait l'affichage.
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNodeAudio audio: sink?.audio ?? null
    readonly property int pct: audio ? Math.round(audio.volume * 100) : 0

    property int step: 5

    // Accumulateur de molette : état local, dérivé de rien, cible d'aucune
    // liaison. C'est le seul endroit du fichier où l'affectation impérative
    // est légitime.
    property int wheelAcc: 0

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    text: !audio ? "n/d" : audio.muted ? "muet" : pct + "%"
    color: !audio || audio.muted ? Theme.muted : Theme.fg

    // L'écriture ne vise que la propriété du service. Le backend n'écrête que
    // par le bas (‑0.3 → 0) : la borne à 100 % est la nôtre.
    function setPct(value: int) {
        if (!audio) return;
        audio.volume = Math.max(0, Math.min(100, value)) / 100;
    }

    // Le pavé tactile émet des deltas continus très fins : on accumule jusqu'au
    // cran (120). L'application est différée d'une frame — mesuré : après une
    // écriture, PipeWire renvoie l'ancienne valeur pendant ~2 ms avant que la
    // nouvelle se pose (50 → 55 → 50 → 55). Deux écritures espacées de moins de
    // ~3 ms liraient donc la même base et un cran serait perdu. Rien n'est
    // dupliqué ici : wheelAcc est de l'état d'entrée, pas une copie du volume,
    // et pct n'est lu qu'une fois par salve, une fois stabilisé.
    Timer {
        id: wheelFlush

        interval: 16

        onTriggered: {
            const notches = Math.trunc(root.wheelAcc / 120);
            if (notches === 0 || !root.audio) return;
            root.wheelAcc -= notches * 120;

            root.setPct(root.pct + notches * root.step);
            root.audio.muted = false; // après l'écriture : pas de blip au volume précédent
        }
    }

    function applyWheel(delta: int) {
        wheelAcc += delta;
        if (!wheelFlush.running) wheelFlush.start();
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: if (root.audio) root.audio.muted = !root.audio.muted
        onWheel: event => root.applyWheel(event.angleDelta.y)
    }
}
