import Quickshell.Networking
import QtQuick

// Menu Wi-Fi : la liste des réseaux, et la saisie du mot de passe.
//
// C'est le SEUL module de la config qui coûte quelque chose tant qu'il est
// ouvert. Il porte donc le bail de scan, et le porte de la seule façon qui se
// tienne : par son cycle de vie. Il n'y a pas de fonction « arrêter le scan »
// à appeler, donc pas de chemin où l'on oublierait de l'appeler.
Column {
    id: root

    // --- Le bail ------------------------------------------------------------
    // Prise à la naissance, restitution à la mort. Le menu est un enfant du
    // panneau : détruire le panneau détruit le menu, et MESURÉ sur sonde, les
    // deux Component.onDestruction se déclenchent — le parent d'abord. Les
    // trois garanties qui rendent cet ordre inoffensif sont dans Services.qml.
    Component.onCompleted: Services.scanAcquire()
    Component.onDestruction: Services.scanRelease()

    spacing: 6

    // --- État de la tentative en cours ---------------------------------------
    // `pending` : le réseau dont le champ de mot de passe est ouvert.
    // `attemptOn` : le réseau qu'on a demandé à connecter.
    // Les deux sont distincts : un réseau connu se connecte sans champ, et le
    // champ reste ouvert pendant la tentative pour porter l'erreur.
    property var pending: null
    property var attemptOn: null
    property string failure: ""

    // Le champ vit ICI, hors du Repeater, et ce n'est pas un détail de mise en
    // page. Le modèle `wifiNetworks` est un tableau reconstruit à chaque
    // changement de `connected`, `known` ou de composition de la liste — donc
    // plusieurs fois par balayage. Un champ de saisie placé dans un délégué
    // serait détruit et recréé sous les doigts, perdant le focus et le texte
    // déjà tapé.
    readonly property bool prompting: root.pending !== null

    function ask(n): void {
        root.failure = "";
        root.attemptOn = null;
        root.pending = n;
        field.text = "";
        field.forceActiveFocus();
    }

    function cancel(): void {
        root.pending = null;
        root.attemptOn = null;
        root.failure = "";
        field.text = "";      // le secret ne survit pas à l'annulation
        startGuard.stop();
        stallGuard.stop();
    }

    function activate(n): void {
        if (!n || !Services.wifiSupported(n)) return;
        if (n.connected) { n.disconnect(); return; }
        if (n.known || Services.wifiIsOpen(n)) { root.attempt(n, ""); return; }
        root.ask(n);
    }

    function submit(): void {
        if (!root.pending) return;
        root.attempt(root.pending, field.text);
    }

    function attempt(n, psk: string): void {
        root.failure = "";
        root.attemptOn = n;
        Services.wifiActivate(n, psk);
        startGuard.restart();
    }

    // A-t-on une preuve que NetworkManager a PRIS la demande ?
    function started(n): bool {
        return n.connected
            || n.stateChanging
            || n.state === ConnectionState.Connecting;
    }

    function fail(msg: string): void {
        root.failure = msg;
        root.attemptOn = null;
        startGuard.stop();
        stallGuard.stop();
        field.text = "";   // on ne garde pas un secret refusé en mémoire
    }

    function succeed(): void {
        root.pending = null;
        root.attemptOn = null;
        root.failure = "";
        field.text = "";
        startGuard.stop();
        stallGuard.stop();
    }

    // --- Traduction des échecs ----------------------------------------------
    // ConnectionFailReason nomme cinq causes plus Unknown. On les nomme toutes
    // en clair : « échec » tout court renverrait l'utilisateur à deviner s'il
    // s'est trompé de mot de passe ou si le point d'accès a disparu.
    function reasonText(r): string {
        switch (r) {
        case ConnectionFailReason.NoSecrets:
            return "mot de passe refusé ou manquant";
        case ConnectionFailReason.WifiAuthTimeout:
            return "délai d'authentification dépassé — le plus souvent un mot de passe erroné";
        case ConnectionFailReason.WifiClientFailed:
            return "association refusée par le point d'accès";
        case ConnectionFailReason.WifiClientDisconnected:
            return "déconnecté par le point d'accès";
        case ConnectionFailReason.WifiNetworkLost:
            return "réseau perdu pendant la connexion";
        default:
            return "échec de connexion, raison non fournie";
        }
    }

    // --- Les deux canaux d'échec --------------------------------------------
    // 1. ASYNCHRONE ET NOMMÉ : Network.connectionFailed(reason). C'est celui
    //    qu'on attend, et il est branché juste en dessous.
    //
    // 2. SYNCHRONE ET MUET : connectWithPsk peut refuser sur place sans
    //    émettre aucun signal ni changer aucun état. Trouvé dans les chaînes
    //    de /usr/bin/quickshell :
    //      « Failed to connectWithPsk: The network disappeared. »
    //      « Failed to connectWithPsk: The settings disappeared. »
    //      « ... has the wrong security type for a PSK. »
    //      « Failed to write PSK:  »
    //    Ces refus partent dans les logs de Quickshell, pas dans un signal.
    //    Sans filet, le clic serait purement avalé : le champ resterait là,
    //    sans erreur, sans progression, sans rien. C'est exactement le retour
    //    silencieux qu'on refuse.
    //
    // D'où deux gardes. La première vérifie qu'une tentative a DÉMARRÉ ; la
    // seconde, qu'elle se TERMINE.
    Connections {
        target: root.attemptOn
        ignoreUnknownSignals: true

        function onConnectionFailed(reason): void {
            // La raison brute part dans les logs, jamais le mot de passe.
            console.log("WifiMenu: échec de connexion, raison = "
                        + ConnectionFailReason.toString(reason));
            root.fail(root.reasonText(reason));
        }

        function onConnectedChanged(): void {
            if (root.attemptOn && root.attemptOn.connected) root.succeed();
        }
    }

    // 1200 ms : un aller-retour D-Bus vers NetworkManager se compte en
    // dizaines de millisecondes, la marge est donc large. NON MESURÉ : le
    // vérifier demande de provoquer un vrai échec, ce qui coupe le Wi-Fi de la
    // session. À remesurer si un refus légitime passait pour un démarrage.
    Timer {
        id: startGuard

        interval: 1200

        onTriggered: {
            const n = root.attemptOn;
            if (!n) return;
            if (root.started(n)) { stallGuard.restart(); return; }
            root.fail("NetworkManager n'a pas pris la demande — voir « qs log »");
        }
    }

    // 45 s : au-delà de tous les délais d'authentification de NetworkManager.
    // Sans elle, une tentative qui n'aboutit ni ne rate laisserait le champ en
    // attente perpétuelle — le même piège que dndBusy dans Services.qml.
    Timer {
        id: stallGuard

        interval: 45000

        onTriggered: root.fail("aucune réponse après 45 s")
    }

    // --- La liste ------------------------------------------------------------
    MenuList {
        id: list

        width: parent.width
        rows: 5

        // Glyphe unique portant DEUX informations : le niveau de signal et la
        // présence d'un cadenas. La police a les deux familles complètes
        // (md-wifi_strength_1..4 et md-wifi_strength_1..4_lock), vérifié par
        // nom de glyphe dans JetBrainsMonoNerdFont-Regular.ttf — pas par
        // supposition sur les points de code.
        function strength(n): string {
            const s = n.signalStrength;
            const secured = !Services.wifiIsOpen(n);
            const level = s >= 0.75 ? 3 : s >= 0.5 ? 2 : s >= 0.25 ? 1 : 0;
            const base = secured ? 0xF0921 : 0xF091F;   // niveau 1, avec/sans cadenas
            return String.fromCodePoint(base + 3 * level);
        }

        function detail(n): string {
            if (n.state === ConnectionState.Connecting || n.stateChanging)
                return "connexion…";
            if (n.connected)                  return "connecté";
            if (!Services.wifiSupported(n))   return "type de sécurité non géré ici";
            if (n.known)                      return "connu";
            if (Services.wifiIsOpen(n))       return "ouvert";
            return "";
        }

        Repeater {
            model: Services.wifiNetworks

            MenuRow {
                required property var modelData

                width: parent.width
                height: list.rowHeight

                icon: list.strength(modelData)
                // Un SSID masqué arrive avec un nom vide : une ligne sans
                // libellé ressemblerait à un bug d'affichage.
                label: modelData.name !== "" ? modelData.name : "(réseau masqué)"
                detail: list.detail(modelData)
                on: modelData.connected

                busy: modelData.stateChanging
                   || modelData.state === ConnectionState.Connecting

                actionable: Services.wifiSupported(modelData)

                trailing: modelData.connected ? "\u{F012C}"
                        : modelData === root.pending ? "\u{F0341}"
                                                     : ""

                onActivated: root.activate(modelData)
            }
        }
    }

    // --- Saisie du mot de passe ----------------------------------------------
    Rectangle {
        width: parent.width
        height: 38
        visible: root.prompting

        radius: 8
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.06)
        border.width: 1
        border.color: field.activeFocus ? Theme.accent
                                        : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.15)

        Behavior on border.color { ColorAnimation { duration: 120 } }

        StyledText {
            id: lock

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            text: "\u{F0341}"           // md-lock_outline
            font.pixelSize: Theme.fontSize + 1
            color: Theme.accent
            style: Text.Normal
        }

        TextInput {
            id: field

            anchors.left: lock.right
            anchors.leftMargin: 10
            anchors.right: go.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            // Le mot de passe n'est jamais rendu en clair, jamais journalisé,
            // et n'est lu qu'une fois — au moment de submit(). Il est effacé à
            // l'annulation, à l'échec et au succès.
            echoMode: TextInput.Password
            passwordCharacter: "•"
            passwordMaskDelay: 0

            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Text.NativeRendering
            selectByMouse: true
            selectionColor: Theme.accent
            clip: true

            // Entrée valide, Échap annule. Les deux sont attendus d'un champ
            // de mot de passe ; sans eux il faudrait viser un bouton de 24 px.
            onAccepted: root.submit()
            Keys.onEscapePressed: root.cancel()

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === "" && !field.activeFocus

                text: root.pending ? "mot de passe · " + root.pending.name : ""
                elide: Text.ElideRight
                width: parent.width
                font.pixelSize: Theme.fontSize - 1
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                style: Text.Normal
            }
        }

        StyledText {
            id: go

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            text: root.attemptOn ? "\u{F0450}" : "\u{F012C}"   // refresh / check
            font.pixelSize: Theme.fontSize + 1
            color: field.text !== "" ? Theme.accent
                                     : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35)
            style: Text.Normal

            RotationAnimation on rotation {
                running: root.attemptOn !== null
                loops: Animation.Infinite
                from: 0; to: 360; duration: 1400
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                enabled: field.text !== "" && !root.attemptOn
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submit()
            }
        }
    }

    // --- Ligne de pied : l'erreur, ou l'état du scan --------------------------
    // Une seule ligne, deux rôles exclusifs. L'erreur prime : tant qu'elle est
    // là, on ne raconte pas ce que fait le scan.
    StyledText {
        width: parent.width
        height: 16

        text: root.failure !== ""            ? "\u{F16BC}  " + root.failure
            : Services.scanning              ? "recherche de réseaux…"
                                             : ""
        visible: text !== ""

        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Theme.fontSize - 3
        color: root.failure !== "" ? Theme.alert
                                   : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
        style: Text.Normal

        SequentialAnimation on opacity {
            running: root.failure === "" && Services.scanning
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutQuad }
        }
    }
}
