pragma Singleton

import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick

// Point d'accès unique aux services système, et seul endroit de la config qui
// connaisse leur forme brute.
//
// Deux raisons d'exister, aucune n'est cosmétique :
//
// 1. Les singletons de service s'initialisent à la PREMIÈRE référence, et
//    l'initialisation est asynchrone. Mesuré : au tick de la première
//    référence tout vaut null / [] / false, et tout se peuple 27 ms plus
//    tard. Un module qui lit Bluetooth.defaultAdapter.name à l'instanciation
//    lève donc un TypeError à chaque premier affichage. La protection est ici
//    et nulle part ailleurs : chaque service se réduit à UNE propriété
//    nullable, et les modules n'ont plus qu'un seul point de garde.
//
// 2. Les propriétés coûteuses (scan Wi-Fi, découverte Bluetooth) doivent
//    suivre la visibilité du panneau. Les lier ici plutôt que dans chaque
//    module garantit qu'aucun module futur ne puisse les allumer sans les
//    éteindre.
//
// Ce singleton était réservé au panneau. Il ne l'est plus : Connectivity.qml,
// dans la barre, lit wifiAvailable/wifiEnabled/btAvailable/btEnabled pour
// afficher l'état des radios en permanence. Les connexions D-Bus vers
// NetworkManager et BlueZ sont donc ouvertes dès le démarrage du shell, et non
// plus à la première ouverture du panneau.
//
// Ça ne change rien à ce qui coûte. Une connexion D-Bus au repos est passive —
// elle ne réveille le processus que lorsqu'un démon émet un signal. Il ne
// reste qu'UNE propriété coûteuse, le scan Wi-Fi, et elle n'est plus asservie
// à `watchers` mais à un second compteur, `scanners` : ouvrir le panneau ne
// lance plus rien, seul l'ouverture du menu Wi-Fi le fait. La découverte
// Bluetooth, elle, a disparu — voir plus bas.
//
// COÛT MESURÉ. Deux instances de la config lancées simultanément, l'une avec
// la bulle, l'autre sans, échantillonnées toutes les 20 s :
//
//     Δt= 20 s   CPU sans + 40 ms   CPU avec + 50 ms   écart +10 ms
//     Δt= 41 s   CPU sans + 90 ms   CPU avec +100 ms   écart +10 ms
//     Δt= 61 s   CPU sans +130 ms   CPU avec +140 ms   écart +10 ms
//     Δt= 82 s   CPU sans +180 ms   CPU avec +190 ms   écart +10 ms
//
// L'écart est CONSTANT : c'est un coût unique au démarrage (l'ouverture des
// deux connexions), après quoi les deux pentes sont identiques. La
// consommation continue est nulle à la résolution de la mesure — le tick
// noyau vaut 10 ms. RSS : 235 à 239 Mo des deux côtés, l'écart changeant de
// signe d'un relevé à l'autre, donc dans le bruit.
//
// Ce qui coûte reste le scan, jamais la connexion. Mesuré : scannerEnabled
// déclenche un balayage toutes les ~12 s tant qu'il est vrai, et zéro dès
// qu'il repasse à faux.
Singleton {
    id: root

    // Nombre de panneaux actuellement instanciés. Un compteur, pas un booléen :
    // il y a une instance de panneau par écran, deux peuvent coexister, et la
    // fermeture de la première ne doit pas éteindre le scan de la seconde.
    property int watchers: 0
    readonly property bool active: watchers > 0

    // La lecture DND se déclenche au passage de 0 à 1 : à l'ouverture du
    // panneau, jamais avant. Panneau fermé, aucun processus n'est lancé.
    function acquire(): void {
        root.watchers++;
        if (root.watchers === 1) root.refreshDnd();
    }
    // GARANTIE 2 — le filet. La destruction du panneau remet le compteur de
    // scans à zéro, et elle arrive EN PREMIER (mesuré). Même si le
    // Component.onDestruction du menu ne se déclenchait pas du tout, le scan
    // s'arrêterait ici.
    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1);
        if (root.watchers === 0) root.scanners = 0;
    }

    // --- Le second compteur -------------------------------------------------
    // `watchers` compte les panneaux ouverts ; `scanners` compte les MENUS
    // Wi-Fi ouverts. Le scan suit le second, pas le premier.
    //
    // Il est indispensable qu'il soit indépendant : un panneau ouvert sur les
    // sliders n'a aucune raison de balayer les ondes, et c'était pourtant le
    // cas — le seul poste de consommation qui restait.
    //
    // MESURÉ sur une sonde reproduisant la forme exacte du panneau
    // (LazyLoader → PanelWindow → Loader → objet feuille), pour les quatre
    // sorties : fermer le menu seul, fermer le panneau menu encore ouvert,
    // Qt.quit, et rechargement à chaud. Résultat qui commande tout le reste :
    // à la destruction du panneau, **le parent est détruit AVANT l'enfant**.
    // Il existe donc un instant où watchers vaut 0 et scanners vaut encore 1.
    // Un compteur nu s'y ferait piéger ; d'où trois garanties, pas une.
    property int scanners: 0

    // GARANTIE 1 — la porte. Même si `scanners` fuyait, panneau fermé le scan
    // est éteint : le menu Wi-Fi ne peut pas survivre au panneau qui le
    // contient, donc un `scanners` non nul sans panneau est forcément une
    // fuite, et cette conjonction la neutralise.
    readonly property bool scanning: root.watchers > 0 && root.scanners > 0

    function scanAcquire(): void { root.scanners++ }

    // GARANTIE 3 — le plancher. Les trois ordres de destruction possibles
    // convergent vers 0 sans jamais passer sous zéro, donc sans qu'une
    // libération en trop puisse rendre le compteur négatif et le rendre
    // insensible à l'acquisition suivante.
    function scanRelease(): void { root.scanners = Math.max(0, root.scanners - 1) }

    // --- Accès protégés -----------------------------------------------------
    // Tout est readonly et nullable. Les modules écrivent sur les propriétés
    // de l'objet rendu, jamais sur ces propriétés-ci : une affectation
    // détruirait la liaison et figerait l'accès.

    // PwNodeAudio n'est peuplé que si le node est suivi par un PwObjectTracker.
    // Volume.qml en a déjà un, mais la barre ne doit rien devoir au panneau ni
    // l'inverse : le panneau porte le sien.
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNodeAudio audio: sink?.audio ?? null

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    function toggleMute(): void {
        if (!root.audio) return;
        root.audio.muted = !root.audio.muted;
    }

    function setVolume(v: real): void {
        if (!root.audio) return;
        root.audio.volume = Math.max(0, Math.min(1, v));
        root.audio.muted = false;   // après l'écriture : pas de blip au volume précédent
    }

    // --- Wi-Fi ---------------------------------------------------------
    // La propriété est optimiste, contrairement au Bluetooth. Mesuré sous
    // rfkill : l'écriture pose la valeur demandée localement (relecture
    // synchrone = true), NetworkManager corrige à t+15 ms, puis exécute
    // réellement à t+19 ms. Elle reste une source d'état réel parce qu'elle se
    // corrige seule, sans qu'on le lui demande — mais elle peut afficher l'état
    // souhaité pendant au plus une frame. Décision assumée : 15 ms sur un cas
    // rare ne valent pas 20 ms de temps mort sur chaque bascule légitime.
    //
    // wifiHardwareEnabled ne suit QUE le blocage matériel : mesuré, il est
    // resté true pendant tout un blocage logiciel rfkill. C'est donc bien la
    // propriété à interroger pour l'indisponibilité matérielle.
    //
    // NON TESTÉ : NetworkManager arrêté. Pas de sudo non interactif sur cette
    // machine pour l'arrêter. Le chemin est structurellement identique aux deux
    // autres sources absentes (adaptateur Bluetooth nul, swaync éteint) :
    // `wifi` retombe à null par la boucle de recherche ci-dessus, donc
    // wifiAvailable devient faux, donc Unavailable. Vérifié par construction,
    // pas par mesure.
    readonly property bool wifiAvailable: root.wifi !== null && Networking.wifiHardwareEnabled
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function setWifi(v: bool): void { Networking.wifiEnabled = v; }

    // Les réseaux visibles. MESURÉ : scanner ÉTEINT, ce modèle contient déjà
    // exactement les réseaux connus (total=2, known=2, stable à 811, 2010 et
    // 5010 ms), signalStrength et connected peuplés. Le menu s'affiche donc
    // plein dès l'ouverture ; le scan ne fait qu'AJOUTER les inconnus, et à
    // son extinction le modèle retombe aux connus en 2 ms.
    //
    // Le tri est connecté / connu / nom, et surtout PAS par puissance. La
    // puissance bouge à chaque balayage : trier dessus ferait sauter les
    // lignes sous le curseur pendant qu'on vise. Elle est affichée, elle
    // n'ordonne pas.
    readonly property var wifiNetworks: {
        if (!root.wifi) return [];
        const out = [];
        for (const n of root.wifi.networks.values) out.push(n);
        out.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return out;
    }

    // Un mot de passe PSK est-il attendu ? La liste est volontairement
    // restrictive : le binaire de Quickshell refuse connectWithPsk sur les
    // autres types (chaîne trouvée dans /usr/bin/quickshell : « has the wrong
    // security type for a PSK. ») et se contente d'une ligne de log. Mieux
    // vaut ne pas proposer le champ que proposer un champ sans effet.
    function wifiNeedsPsk(n): bool {
        return n.security === WifiSecurityType.WpaPsk
            || n.security === WifiSecurityType.Wpa2Psk
            || n.security === WifiSecurityType.Sae;
    }

    // Ouvert : rien à saisir. Owe est du chiffrement opportuniste, sans
    // secret côté client — il se connecte comme un réseau ouvert.
    function wifiIsOpen(n): bool {
        return n.security === WifiSecurityType.Open
            || n.security === WifiSecurityType.Owe;
    }

    // Tout le reste — EAP d'entreprise, WEP, LEAP, inconnu — demande des
    // réglages que cette bulle n'a pas à porter (certificats, identité,
    // méthode de phase 2). On l'affiche, on ne prétend pas savoir le faire.
    function wifiSupported(n): bool {
        return n.known || root.wifiIsOpen(n) || root.wifiNeedsPsk(n);
    }

    // Le seul point d'entrée de connexion, et le seul endroit où un mot de
    // passe est manipulé. Il ne le stocke pas, ne le journalise pas et ne le
    // renvoie pas : il le passe à connectWithPsk et l'oublie.
    //
    // Un réseau CONNU se reconnecte par connect() même s'il est protégé :
    // NetworkManager a déjà le secret, redemander le mot de passe serait
    // demander à l'utilisateur ce que le système sait déjà.
    function wifiActivate(n, psk: string): void {
        if (!n) return;
        if (n.known || psk === "") n.connect();
        else n.connectWithPsk(psk);
    }

    // --- Bluetooth -------------------------------------------------------
    // Miroir strict, à l'inverse du Wi-Fi. Mesuré sous rfkill : écrire
    // enabled = true ne déplace pas la propriété, pas même en relecture
    // synchrone dans le tick de l'écriture. Une écriture qui échoue ne produit
    // donc aucun mouvement, il n'y a rien à « faire revenir ».
    //
    // L'état transitoire est natif et réel : Enabling / Disabling durent 154 à
    // 241 ms (mesuré), largement au-dessus du seuil d'attente du Toggle.
    //
    // Blocked couvre le blocage rfkill. L'énumération ne distingue pas logiciel
    // et matériel, ce qui est sans conséquence ici : dans les deux cas
    // l'écriture est vaine, donc indisponible.
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    readonly property bool btAvailable:
        root.adapter !== null && root.adapter.state !== BluetoothAdapterState.Blocked
    readonly property bool btBusy:
        root.adapter !== null
        && (root.adapter.state === BluetoothAdapterState.Enabling
            || root.adapter.state === BluetoothAdapterState.Disabling)
    readonly property bool btEnabled: root.adapter?.enabled ?? false

    function setBluetooth(v: bool): void {
        if (root.adapter) root.adapter.enabled = v;
    }

    // Les appareils CONNUS, sans aucune découverte. Mesuré, `discovering`
    // jamais mis à vrai : adapter.devices contient déjà les deux appareils de
    // cette machine à t+810 ms, avec name / icon / paired / bonded / trusted /
    // connected / state / battery peuplés. BlueZ garde ses appareils connus
    // comme objets D-Bus persistants — la découverte ne sert qu'à faire
    // apparaître des INCONNUS, ce qu'on ne fait pas ici.
    //
    // Le filtre est `paired || bonded || trusted`, et pas `paired` seul :
    // mesuré, la manette DualSense est trusted=true, paired=false,
    // bonded=false. Filtrer sur l'appairage la ferait disparaître d'une liste
    // qui s'appelle « appareils connus ».
    //
    // Le tri met les connectés en tête. La liaison se réévalue quand l'un
    // d'eux change d'état : `connected` et `name` sont lus pendant
    // l'évaluation, donc suivis comme dépendances.
    readonly property var btDevices: {
        if (!root.adapter) return [];
        const out = [];
        for (const d of root.adapter.devices.values)
            if (d.paired || d.bonded || d.trusted) out.push(d);
        out.sort((a, b) => a.connected !== b.connected
                           ? (a.connected ? -1 : 1)
                           : a.name.localeCompare(b.name));
        return out;
    }

    // Une seule porte pour les deux sens. Rien pendant une transition : même
    // raison que le Toggle, un clic empilé sur une commande en vol produirait
    // deux demandes contraires. La ligne est déjà désactivée pendant l'attente,
    // cette garde couvre le cas où elle serait reconstruite entre-temps.
    function btToggleDevice(d): void {
        if (!d) return;
        if (d.state === BluetoothDeviceState.Connecting
            || d.state === BluetoothDeviceState.Disconnecting) return;
        if (d.connected) d.disconnect(); else d.connect();
    }

    readonly property WifiDevice wifi: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi) return d;
        return null;
    }

    readonly property UPowerDevice battery: UPower.displayDevice

    // --- Luminosité ---------------------------------------------------------
    // Aucun module natif. On écrit directement dans sysfs : le fichier
    // appartient au groupe `video` dont tu fais partie, donc ni brightnessctl
    // ni Process, donc aucun fork par cran de molette.
    //
    // atomicWrites: false est obligatoire — l'écriture atomique passe par un
    // fichier temporaire puis rename(), impossible sur sysfs.
    //
    // watchChanges: true capte les changements venus d'ailleurs (tes touches
    // Fn). Mesuré : inotify se déclenche bien sur cet attribut sysfs, et une
    // liaison sur text() se réévalue (2777 → 2657 après un brightnessctl
    // extérieur).
    //
    // Seul chemin de la config qui dépende du matériel. Mesuré sur cette
    // machine : intel_backlight est le seul périphérique de /sys/class/backlight.
    readonly property string backlight: "intel_backlight"

    readonly property int brightnessMax: parseInt(blMax.text()) || 0
    readonly property int brightnessRaw: parseInt(blCur.text()) || 0
    readonly property bool brightnessReady: brightnessMax > 0
    readonly property real brightness: brightnessReady ? brightnessRaw / brightnessMax : 0

    // Plancher à 1 %. Écrire 0 éteint complètement le rétroéclairage, et il ne
    // reste alors rien à l'écran pour revenir en arrière.
    function setBrightness(v: real): void {
        if (!root.brightnessReady) return;
        const floor = Math.max(1, Math.round(root.brightnessMax * 0.01));
        const raw = Math.round(Math.max(0, Math.min(1, v)) * root.brightnessMax);
        blCur.setText(String(Math.max(floor, raw)));
    }

    FileView {
        id: blMax
        path: "/sys/class/backlight/" + root.backlight + "/max_brightness"
    }

    FileView {
        id: blCur
        path: "/sys/class/backlight/" + root.backlight + "/brightness"
        atomicWrites: false
        watchChanges: true
        onFileChanged: reload()
    }

    // --- Ne pas déranger (swaync) ----------------------------------------
    // La seule source qui ne notifie rien : ni propriété, ni signal
    // exploitable. On ne connaît l'état que parce qu'on vient de le demander.
    //
    // swaync expose bien un signal Subscribe, mais l'écouter demanderait un
    // `busctl monitor` permanent, ce qui violerait « rien ne tourne panneau
    // fermé ». On relit donc à chaque ouverture (voir acquire()).
    //
    // Toute interaction passe par une porte NameHasOwner, et ce n'est pas de la
    // prudence gratuite. Mesuré, swaync arrêté :
    //   swaync-client -D  → rc=0, 2041 ms, affiche "false"   ment en silence
    //   busctl GetDnd     → rc=1, 1721 ms, mais ACTIVE swaync par D-Bus
    //   NameHasOwner      → rc=0,   23 ms, honnête, n'active rien
    // Le code de retour de swaync-client est inutilisable : il vaut 0 même
    // quand le démon est mort, et la sortie "false" est indiscernable d'une
    // vraie réponse. La porte est la seule détection fiable.
    //
    // Elle est refaite à CHAQUE appel, pas seulement à l'ouverture : swaync
    // peut mourir entre l'ouverture du panneau et le clic.
    property bool dndAvailable: false
    property bool dndEnabled: false
    property bool dndBusy: false

    readonly property string dndGate:
        "busctl --user call org.freedesktop.DBus /org/freedesktop/DBus"
        + " org.freedesktop.DBus NameHasOwner s org.erikreider.swaync.cc"

    // -dn / -df posent une valeur explicite et impriment l'état résultant :
    // la confirmation est la sortie de la commande elle-même, pas une seconde
    // lecture. On n'utilise pas -d (bascule aveugle) : on veut demander un état
    // précis pour pouvoir comparer.
    function dndRun(action: string): void {
        if (root.dndBusy) return;   // une commande est déjà en vol
        root.dndBusy = true;
        dndProc.command = ["sh", "-c",
            'case "$(' + root.dndGate + ')" in *true*) ' + action + ' ;; *) echo absent ;; esac'];
        dndProc.running = true;
        dndWatchdog.restart();
    }

    function refreshDnd(): void { root.dndRun("swaync-client -D"); }
    function setDnd(v: bool): void { root.dndRun(v ? "swaync-client -dn" : "swaync-client -df"); }

    Process {
        id: dndProc

        stdout: StdioCollector {
            onStreamFinished: {
                dndWatchdog.stop();
                const out = text.trim();
                // Seules deux sorties sont une réponse. "absent", une chaîne
                // vide ou n'importe quoi d'autre signifie qu'on ne sait pas —
                // et ne pas savoir n'est pas « éteint ».
                root.dndAvailable = (out === "true" || out === "false");
                if (root.dndAvailable) root.dndEnabled = (out === "true");
                root.dndBusy = false;
            }
        }
    }

    // Filet : si le bus de session se coince, la commande ne rend jamais la
    // main et dndBusy resterait vrai pour toujours, laissant le toggle en
    // attente perpétuelle. 3 s = 45 fois le pire cas mesuré (66,8 ms).
    Timer {
        id: dndWatchdog

        interval: 3000

        onTriggered: {
            dndProc.running = false;
            root.dndAvailable = false;
            root.dndBusy = false;
        }
    }

    // --- État coûteux, asservi à la visibilité ------------------------------
    // Liaisons déclaratives, pas d'appels impératifs : il n'existe pas de
    // chemin de code qui allume sans éteindre. `when` protège la fenêtre de
    // 27 ms où la cible est encore nulle ; dès qu'elle apparaît, la liaison
    // s'applique avec la valeur courante de `scanning`.
    //
    // Fermeture normale  : `scanning` repasse à false, la liaison écrit false.
    // Arrêt brutal (kill -9) : le démon nettoie tout seul. Mesuré —
    //   BlueZ révoque la découverte 200 à 400 ms après la déconnexion du
    //   client D-Bus (Discovering: yes → no) ;
    //   NetworkManager n'a aucun état persistant à fuir, scannerEnabled ne
    //   fait qu'émettre des demandes de scan (LastScan se fige à l'instant
    //   du kill et ne bouge plus).

    Binding {
        target: root.wifi
        property: "scannerEnabled"
        value: root.scanning
        when: root.wifi !== null
    }

    // Il n'y a PAS de liaison sur `discovering`, et c'est délibéré. Le menu
    // Bluetooth ne liste que les appareils connus, que BlueZ expose déjà sans
    // découverte (mesuré : 2 appareils à t+810 ms, discovering=false). Une
    // découverte allumée à l'ouverture du panneau serait donc du balayage
    // radio pur, sans rien à afficher de plus.
    //
    // On ne force pas non plus `discovering` à false : blueman peut être en
    // train d'apparier pendant que le panneau est ouvert, et lui couper sa
    // découverte sous les pieds serait pire que de ne rien faire.
}
