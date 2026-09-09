pragma Singleton

import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
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

    // Ne déclenche plus de lecture DND à l'ouverture : l'état de swaync est
    // tenu à jour en permanence par le moniteur, panneau ouvert ou fermé. Le
    // panneau ne fait plus qu'afficher ce qui est déjà là.
    function acquire(): void {
        root.watchers++;
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
    // Sans tracker, mesuré : volume reste à 0 et volumes à [] indéfiniment.
    //
    // Celui-ci est désormais le SEUL de la config. Volume.qml portait le sien
    // tant qu'il était dans la barre ; il n'y est plus, et la bulle comme le
    // slider du panneau lisent tous deux `audio` d'ici. Mesuré après le
    // retrait : Services.audio est peuplé à t+100 ms (pct=58, muted=false)
    // sans que Volume.qml soit instancié. Le supprimer couperait le son des
    // deux surfaces à la fois.
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

    // --- Tray (StatusNotifier) ----------------------------------------------
    // MESURÉ AVANT D'ÉCRIRE. Sur ce bus, org.kde.StatusNotifierWatcher n'avait
    // AUCUN propriétaire : Waybar ne tient pas de tray, et le seul nom voisin,
    // org.x.StatusNotifierWatcher, est un nom DIFFÉRENT — activable, sans
    // propriétaire, sans rapport pour D-Bus. Le nom était donc libre, et c'est
    // Quickshell qui le prend en référençant le singleton SystemTray.
    //
    // ET LE TIROIR N'EST PAS RESTÉ VIDE — la prémisse était fausse, mesuré.
    // On attendait un tiroir vide au premier lancement, en supposant qu'un
    // applet ne publie son item qu'à SON démarrage et que blueman, lancé avant
    // tout watcher, était perdu pour la session jusqu'à un redémarrage manuel.
    //
    // Ce n'est pas ce qui s'est passé. Dès que le nom a eu un propriétaire, un
    // item est apparu, sans que rien ne soit relancé :
    //
    //     RegisteredStatusNotifierItems -> [":1.154/org/blueman/sni"]
    //     :1.154 = blueman-tray, PID 1953, démarré à 10:19:57
    //     le shell qui prend le nom : PID 1735, démarré à 10:19:56
    //     les deux tournent depuis, sans redémarrage (etimes identiques)
    //
    // Deux corrections à retenir. D'abord ce n'est pas blueman-applet qui
    // publie l'item mais blueman-tray, un second processus qu'il lance —
    // regarder le seul blueman-applet sur le bus donnait donc une réponse
    // juste à une mauvaise question. Ensuite ce processus SURVEILLE
    // l'apparition du nom au lieu de tester une fois au démarrage : il
    // s'enregistre à chaud.
    //
    // Ça ne se généralise pas. Un applet qui, lui, ne teste qu'au démarrage
    // restera absent, et l'ordre de lancement redeviendra la seule explication
    // d'un tiroir vide. C'est la première chose à vérifier avant de déboguer
    // le QML : `busctl --user get-property org.kde.StatusNotifierWatcher \
    // /StatusNotifierWatcher org.kde.StatusNotifierWatcher \
    // RegisteredStatusNotifierItems` dit si le tiroir est vide parce que
    // personne ne s'est enregistré, ou parce que l'affichage est cassé.
    //
    // Le nom est pris dès la première référence à ce singleton, donc au
    // démarrage du shell puisque Connectivity.qml lit Services en permanence.
    // Ce n'est pas un coût : posséder un nom D-Bus est passif, au même titre
    // que les connexions NetworkManager et BlueZ décrites en tête de fichier.
    // C'est même l'inverse d'un coût — sans ce nom pris tôt, un applet lancé
    // avant le shell est définitivement perdu pour la session.
    //
    // VÉRIFIÉ à l'exécution : SystemTray.items est un UntypedObjectModel, pas
    // une liste. On expose .values, le tableau JS, parce que les deux
    // consommateurs du tiroir le filtrent (NeedsAttention) — et parce qu'ici
    // le tableau vide est le cas nominal, pas l'exception.
    readonly property var trayModel: SystemTray.items ?? null
    readonly property var trayItems: root.trayModel ? root.trayModel.values : []

    // L'énumération vit dans Quickshell.Services.SystemTray. L'exposer ici
    // évite à Tray.qml d'importer le module de service : la règle du projet
    // est qu'un module ne parle qu'à Services.
    //
    // VÉRIFIÉ à l'exécution : Passive = 0, Active = 1, NeedsAttention = 2.
    readonly property int trayAttention: Status.NeedsAttention

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

    // --- swaync : présence, compteur, « ne pas déranger » -------------------
    // UNE source pour les trois, et c'est le point de la section : swaync
    // n'expose pas un état DND d'un côté et un compteur de l'autre, il émet
    // les deux dans le même signal. Deux chemins de lecture pourraient
    // diverger ; il n'y en a qu'un.
    //
    // Ce que dit swaync 0.12.6, vérifié au dbus-monitor :
    //   SubscribeV2 (ubbb)   = (count, dnd, cc_open, inhibited)   signal
    //   GetSubscribeData     → (bbub) = (dnd, cc_open, count, inhibited)
    // `Subscribe (ubb)` existe encore à l'introspection mais n'est PLUS émis :
    // s'y abonner ne donnerait jamais rien. C'est SubscribeV2 ou rien.
    //
    // COÛT MESURÉ. Deux instances de la config côte à côte, l'une avec le
    // moniteur, l'autre sans, sur 6,5 min puis 5 min :
    //
    //   au repos            CPU du moniteur      0 ms en 6,5 min
    //                       réveils du moniteur  0,0 / min sur 5 min
    //                       écart de CPU A↔B     ±10 ms, soit ±1 tick noyau
    //                       RSS du moniteur      2,7 Mo
    //   sous rafale         250 notifications envoyées puis refermées,
    //                       500 événements SubscribeV2 en 8 s :
    //                       moniteur   30 ms de CPU, 1 réveil par événement
    //                       shell      100 ms de CPU au-delà du témoin
    //                       → 0,26 ms et ~2 réveils PAR notification
    //
    // L'alternative écartée était un sondage périodique par Process one-shot.
    // Mesurée aussi, forme gatée (porte + GetSubscribeData), par sondage :
    //   client (sh + 2 busctl)  9,6 réveils   8,85 ms CPU   10,5 ms de latence
    //   dbus-broker            18,9 réveils   0,80 ms
    //   swaync                 10,4 réveils   0,90 ms
    //   ------------------------------------------------------------------
    //   total                 ~39 réveils    ~10,6 ms CPU  + 3 processus
    //
    // Un sondage coûte donc autant que 40 notifications reçues, et il le coûte
    // même quand il ne se passe rien. À 30 s de cadence : 80 réveils/min et un
    // compteur périmé jusqu'à 30 s. Le moniteur : 0 réveil/min et l'affichage
    // suit le signal. Le coût du moniteur est proportionnel aux notifications,
    // celui du sondage au temps qui passe — c'est ce qui tranche.
    //
    // LA PORTE S'APPLIQUE AUSSI AU MONITEUR, et la commande évidente la viole.
    // Mesuré, swaync arrêté, en lançant chaque moniteur sur le nom mort :
    //   gdbus monitor --dest org.erikreider.swaync.cc   → DÉMARRE swaync
    //   dbus-monitor "…interface='…swaync.cc'…"         → ne démarre rien
    //   busctl --user monitor org.erikreider.swaync.cc  → ne démarre rien
    // org.erikreider.swaync.cc a un fichier d'activation D-Bus
    // (/usr/share/dbus-1/services/), donc tout ce qui RÉSOUT le nom réveille le
    // démon. `gdbus monitor --dest` pose une surveillance de nom avec
    // auto-démarrage ; filtrer sur `interface=` ne résout aucun nom, donc
    // n'active rien — et capte quand même les signaux si swaync arrive après
    // (vérifié : moniteur lancé démon éteint, puis start, puis notification →
    // l'événement passe). L'activation n'a lieu qu'AU LANCEMENT du moniteur :
    // un moniteur déjà en vol ne ressuscite pas le démon (vérifié, swaync
    // arrêté sous lui, toujours mort à t+10 s).
    //
    // MORT AVEC LE SHELL. `setpriv --pdeathsig TERM` pose PR_SET_PDEATHSIG sur
    // l'enfant avant d'exec. Trois chemins, tous vérifiés :
    //   arrêt normal (SIGTERM) → Quickshell tue l'enfant       moniteur MORT
    //   rechargement à chaud   → l'enfant est relancé, pas dupliqué (1 seul)
    //   kill -9 du shell       → le noyau signale l'enfant     moniteur MORT
    // Sans setpriv, mesuré : le kill -9 laisse un dbus-monitor réparenté à
    // PID 1, qui survit indéfiniment. Quickshell ne pose pas PDEATHSIG
    // lui-même, et ne le peut pas — SIGKILL n'est pas interceptable.
    property bool swayncAvailable: false
    property int notifCount: 0
    property bool dndEnabled: false
    property bool dndBusy: false

    // La porte. Inchangée, et toujours pour la même raison : le code de retour
    // de swaync-client vaut 0 même démon mort, et un `busctl call` réveillerait
    // swaync au lieu de constater son absence. Mesuré démon arrêté :
    //   swaync-client -D  → rc=0, 2041 ms, affiche "false"   ment en silence
    //   busctl GetDnd     → rc=1, 1721 ms, mais ACTIVE swaync
    //   NameHasOwner      → rc=0,   23 ms, honnête, n'active rien
    readonly property string swayncGate:
        "busctl --user call org.freedesktop.DBus /org/freedesktop/DBus"
        + " org.freedesktop.DBus NameHasOwner s org.erikreider.swaync.cc"

    readonly property string swayncRead:
        "busctl --user call org.erikreider.swaync.cc /org/erikreider/swaync/cc"
        + " org.erikreider.swaync.cc GetSubscribeData"

    function swayncCmd(action: string): var {
        return ["sh", "-c",
            'case "$(' + root.swayncGate + ')" in *true*) ' + action + ' ;; *) echo absent ;; esac'];
    }

    // --- Le moniteur --------------------------------------------------------
    // Deux règles dans le MÊME processus. La seconde n'est pas un luxe : sans
    // elle, entre la mort et le retour de swaync, le compteur afficherait sa
    // dernière valeur connue comme si elle était vraie.
    //
    // Attention au piège mesuré : `sender=` ET `arg0=` dans la même règle ne
    // délivrent RIEN en mode moniteur sur dbus-broker (0 NameOwnerChanged reçu,
    // vérifié). `interface=` + `arg0=` en délivre exactement 2, un par
    // transition. C'est la forme retenue.
    Process {
        id: swayncMon

        running: true
        command: ["setpriv", "--pdeathsig", "TERM",
                  "dbus-monitor", "--session",
                  "type='signal',interface='org.erikreider.swaync.cc',member='SubscribeV2'",
                  "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.erikreider.swaync.cc'"]

        stdout: SplitParser { onRead: line => root.swayncLine(line) }

        // La graine part quand le moniteur est lancé, pas avant : si elle
        // partait la première, un événement tombé entre sa réponse et
        // l'attachement des règles serait perdu sans que rien ne le rattrape.
        // Dans l'autre sens, un signal qui double la graine est détecté et la
        // graine est jetée (voir seedProc).
        onStarted: root.seedSwaync()

        // Le moniteur mort, plus rien ne nous contredit : on afficherait
        // indéfiniment le dernier état connu comme s'il était vrai. Même
        // règle que partout ailleurs ici — ne pas savoir n'est pas « zéro ».
        // 2 s de battement pour ne pas boucler à pleine vitesse si
        // dbus-monitor n'arrive pas à s'attacher au bus.
        onExited: {
            root.swayncAvailable = false;
            monRevive.restart();
        }
    }

    Timer {
        id: monRevive

        interval: 2000

        onTriggered: swayncMon.running = true
    }

    // dbus-monitor imprime un en-tête puis une ligne par argument. On ne
    // reconstruit donc pas un message, on compte des lignes : l'en-tête dit
    // combien en attendre, les suivantes sont les valeurs. Pas d'awk dans un
    // tuyau — ce serait deux processus de plus pour ce que six lignes de QML
    // font sans réveil supplémentaire.
    property int swayncPending: 0
    property string swayncKind: ""
    property var swayncArgs: []

    // Compteur d'événements reçus, uniquement pour départager une graine en vol
    // et un signal arrivé entre-temps (voir seedProc).
    property int swayncSeq: 0

    function swayncLine(line: string): void {
        if (root.swayncPending > 0) {
            // "   uint32 4" / "   boolean false" / "   string \":1.84\""
            const v = line.trim().split(" ").slice(1).join(" ");
            root.swayncArgs.push(v.replace(/^"|"$/g, ""));
            if (--root.swayncPending > 0) return;
            if (root.swayncKind === "sub") root.applySubscribe(root.swayncArgs);
            else root.applyNameOwner(root.swayncArgs);
            return;
        }
        if (line.indexOf("member=SubscribeV2") !== -1) {
            root.swayncKind = "sub"; root.swayncArgs = []; root.swayncPending = 4;
        } else if (line.indexOf("member=NameOwnerChanged") !== -1) {
            root.swayncKind = "noc"; root.swayncArgs = []; root.swayncPending = 3;
        }
    }

    // Recevoir un signal PROUVE la présence : aucune porte à rejouer ici.
    function applySubscribe(a: var): void {
        root.swayncAvailable = true;
        root.notifCount = parseInt(a[0]);
        root.dndEnabled = a[1] === "true";
        root.swayncSeq++;
    }

    // NameOwnerChanged(nom, ancien, nouveau). Nouveau vide = swaync est mort ;
    // on ne garde pas le dernier compteur connu, on déclare l'ignorance — la
    // cloche passe en Unavailable et le nombre disparaît. Nouveau non vide =
    // swaync est de retour, et on redemande l'état plutôt que d'attendre.
    //
    // En pratique swaync émet un SubscribeV2 ~20 ms après avoir pris le nom
    // (mesuré), donc la graine et le signal se croisent. C'est pour ça que la
    // graine est datée : elle ne s'applique que si aucun signal ne l'a doublée.
    function applyNameOwner(a: var): void {
        const arrived = a[2] !== "";
        root.swayncAvailable = arrived;
        if (!arrived) {
            root.notifCount = 0;
            root.dndEnabled = false;
        } else {
            root.seedSwaync();
        }
    }

    // --- La graine ----------------------------------------------------------
    // Le moniteur ne dit rien tant que rien ne bouge : au démarrage du shell,
    // swaync peut tourner depuis des heures avec quatre notifications en
    // attente et n'émettre aucun signal avant la prochaine. Un seul appel
    // one-shot, gaté, au démarrage et à chaque retour du démon.
    property int seedSeq: 0

    function seedSwaync(): void {
        if (seedProc.running) return;
        root.seedSeq = root.swayncSeq;
        seedProc.command = root.swayncCmd(root.swayncRead);
        seedProc.running = true;
    }

    Process {
        id: seedProc

        stdout: StdioCollector {
            onStreamFinished: {
                const m = /^\(bbub\) (true|false) (true|false) (\d+)/.exec(text.trim());
                // "absent", vide, ou n'importe quoi d'autre : on ne sait pas,
                // et ne pas savoir n'est pas « zéro notification ».
                if (!m) { root.swayncAvailable = false; return; }
                root.swayncAvailable = true;
                if (root.swayncSeq !== root.seedSeq) return;   // doublée par un signal
                root.dndEnabled = m[1] === "true";
                root.notifCount = parseInt(m[3]);
            }
        }
    }

    // --- Les deux seules actions --------------------------------------------
    // Elles écrivent une commande, elles ne lisent aucun état : la confirmation
    // arrive par le moniteur, comme n'importe quel changement venu d'ailleurs.
    // C'est ce qui garantit qu'un DND basculé depuis waybar, un raccourci
    // clavier ou swaync lui-même s'affiche exactement pareil qu'un DND basculé
    // depuis le panneau.
    //
    // La porte est rejouée à chaque appel bien que `swayncAvailable` soit tenu
    // à jour au signal près : entre le clic et le fork, swaync peut mourir, et
    // sans porte le `busctl` de swaync-client le ressusciterait.
    function setDnd(v: bool): void {
        if (root.dndBusy) return;   // une commande est déjà en vol
        root.dndBusy = true;
        dndProc.command = root.swayncCmd(v ? "swaync-client -dn" : "swaync-client -df");
        dndProc.running = true;
        dndWatchdog.restart();
    }

    // Ouvre le centre de notifications de swaync — PAS le centre de contrôle.
    function toggleNotificationCenter(): void {
        if (ccProc.running) return;
        ccProc.command = root.swayncCmd("swaync-client -t");
        ccProc.running = true;
    }

    Process {
        id: dndProc

        stdout: StdioCollector {
            onStreamFinished: {
                dndWatchdog.stop();
                if (text.trim() === "absent") root.swayncAvailable = false;
                root.dndBusy = false;
            }
        }
    }

    Process {
        id: ccProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "absent") root.swayncAvailable = false;
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
            root.swayncAvailable = false;
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
