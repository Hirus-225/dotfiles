import Quickshell
import Quickshell.Io
import QtQuick

// Simple lanceur. Tout le menu — les cinq entrées, les confirmations, les
// actions — vit dans ~/.local/bin/powermenu.sh et dans son Rofi. Ce fichier
// n'en duplique rien : il fork un script, c'est tout. Pas d'état, pas de
// service, pas de LazyLoader, il n'y a rien à charger ni à tenir à jour.
//
// Le glyphe est celui de l'entrée « Éteindre » du script lui-même (U+F0425,
// md-power), et pas un dessin choisi ici : la barre et le menu qu'elle ouvre
// doivent nommer la même chose de la même façon. Couverture du point de code
// vérifiée dans JetBrainsMono Nerd Font.
//
// Comme l'horloge et la bulle de connectivité, ce module ne sait pas où il est
// posé : il n'expose qu'une taille implicite, les ancrages vivent dans Bar.qml.
StyledText {
    id: root

    text: "\u{F0425}"   // md-power

    // --- Pourquoi un chemin absolu, et jamais « powermenu.sh » ---------------
    // Mesuré sur le shell en cours d'exécution (/proc/<pid>/environ) : le PATH
    // hérité par Quickshell est exactement
    //
    //     /usr/local/bin:/usr/bin
    //
    // Il ne contient PAS ~/.local/bin — contrairement au PATH d'un terminal
    // interactif, qui l'ajoute via le profil. Un appel par le nom nu échouerait
    // donc, et il échouerait de la pire façon pour ce projet : en silence.
    // Process ne lève rien, aucune fenêtre ne s'ouvre, et rien n'explique
    // pourquoi. Vérifié : `command -v powermenu.sh` depuis un enfant du shell
    // répond « introuvable ».
    //
    // Les quatre binaires que le script appelle à son tour — rofi, hyprlock,
    // hyprctl, systemctl — sont eux tous dans /usr/bin, donc atteignables sans
    // rien ajouter à l'environnement. Le script a été lancé une fois sous
    // l'environnement exact du shell : Rofi s'ouvre, prompt « Système : ».
    //
    // HOME plutôt qu'un /home/... en dur, comme Theme.qml pour colors.json.
    //
    // En production depuis le 2026-09-09. Le câblage à blanc — un
    // `notify-send` à la place du script — a servi à valider que le clic part
    // bien, puisque les actions de ce menu ne sont pas testables : on ne clique
    // pas « Éteindre » pour vérifier qu'un bouton marche. Pour y revenir un
    // jour, remplacer la ligne `command:` ci-dessous par :
    //
    //     command: ["notify-send", "powermenu", "declenche"]
    Process {
        id: proc

        command: [Quickshell.env("HOME") + "/.local/bin/powermenu.sh"]

        // Le seul filet du module. Ce projet a pour habitude que les échecs ne
        // crient pas ; un script absent, non exécutable ou cassé sortirait ici
        // avec un code non nul sans que rien ne le dise. Trois lignes, aucun
        // état retenu, visible avec `qs -c minimal -vv`.
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("powermenu: " + text.trim())
        }

        onExited: (code, status) => {
            if (code !== 0) console.warn("powermenu: sortie en code " + code);
        }
    }

    // Cible de 26 px au minimum, pour le trackpad. Le glyphe fait ~13 px de
    // large : la zone déborde donc le texte des deux côtés, exactement comme
    // celle de l'horloge déborde en hauteur, et pour la même raison — viser un
    // carré est plus facile que viser une boîte de texte. Le débordement est
    // invisible à la mise en page : implicitWidth reste celle du glyphe, c'est
    // Bar.qml qui décide des marges autour.
    MouseArea {
        anchors.centerIn: parent
        width: Math.max(parent.implicitWidth, 26)
        height: Theme.barHeight

        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        // `running = true` et non une bascule : un second clic pendant que Rofi
        // est ouvert est un no-op MESURÉ — Process ignore l'affectation s'il
        // tourne déjà (même PID, aucun avertissement). C'est exactement le
        // comportement voulu : deux Rofi simultanés se disputeraient le clavier.
        onClicked: proc.running = true
    }
}
