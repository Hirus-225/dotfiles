import Quickshell.Bluetooth
import QtQuick

// Menu Bluetooth : les appareils CONNUS, et rien d'autre.
//
// Aucune découverte. C'est la décision qui rend ce module gratuit : la liste
// ne coûte rien, donc il n'y a rien à éteindre à la fermeture, donc pas de
// compteur — contrairement au menu Wi-Fi, qui devra en porter un.
//
// MESURÉ, adaptateur allumé et `discovering` jamais mis à vrai :
//   adapter.devices.length = 2 dès t+810 ms (le temps que BlueZ réponde),
//   avec pour chaque appareil name, icon, paired, bonded, trusted, connected,
//   state, batteryAvailable et battery déjà peuplés.
// BlueZ garde ses appareils connus comme objets D-Bus persistants ; la
// découverte ne sert qu'à faire APPARAÎTRE des inconnus. Comme on n'apparie
// pas ici, elle n'a aucun usage.
//
// L'appairage reste à blueman, volontairement : il demande un agent D-Bus
// (code PIN, confirmation de passkey, autorisation de service), c'est-à-dire
// une machine à états et des boîtes modales qui n'ont pas leur place dans une
// bulle de barre.
MenuList {
    id: root

    // Traduction icône BlueZ → glyphe. Les noms viennent de la spécification
    // freedesktop d'icônes, c'est BlueZ qui les pose d'après la classe de
    // l'appareil. Vérifié sur cette machine : "audio-headset" pour le casque,
    // "input-gaming" pour la manette.
    //
    // Tous les points de code ci-dessous ont été vérifiés présents dans
    // JetBrainsMonoNerdFont-Regular.ttf (fc-query %{charset}) : un glyphe
    // manquant s'afficherait en tofu sans rien lever.
    function glyph(icon: string): string {
        switch (icon) {
        case "audio-headset":
        case "audio-headphones":    return "\u{F02CB}";
        case "audio-card":
        case "audio-speakers":
        case "multimedia-player":   return "\u{F04C3}";
        case "input-gaming":        return "\u{F02B4}";
        case "input-keyboard":      return "\u{F030C}";
        case "input-mouse":
        case "input-tablet":        return "\u{F037D}";
        case "phone":               return "\u{F011C}";
        case "computer":            return "\u{F0322}";
        default:                    return "\u{F293}";   // le glyphe Bluetooth
        }
    }

    // Une seule ligne de détail, quatre cas exclusifs. Les deux transitions
    // sont natives — BluetoothDeviceState les expose — on ne les déduit pas
    // d'un délai.
    function detail(d): string {
        if (d.state === BluetoothDeviceState.Connecting)    return "connexion…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "déconnexion…";
        if (d.connected)
            return d.batteryAvailable
                ? "connecté · " + Math.round(d.battery * 100) + " %"
                : "connecté";
        // Un appareil peut être connu sans être apparié : mesuré, la manette
        // DualSense est trusted=true, paired=false, bonded=false. Le taire
        // ferait passer pour apparié un appareil qui ne l'est pas.
        return d.paired ? "" : "non apparié";
    }

    // Le seul cas où le menu n'a rien à montrer. Il reste ouvrable :
    // « aucun appareil connu » est une réponse, une liste vide n'en est pas
    // une.
    StyledText {
        width: parent.width
        height: root.rowHeight
        visible: Services.btDevices.length === 0

        text: "  aucun appareil connu — appairer avec blueman"
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Theme.fontSize - 2
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
        style: Text.Normal
    }

    Repeater {
        model: Services.btDevices

        MenuRow {
            required property var modelData

            width: parent.width
            height: root.rowHeight

            icon: root.glyph(modelData.icon)
            label: modelData.name
            detail: root.detail(modelData)
            on: modelData.connected

            busy: modelData.state === BluetoothDeviceState.Connecting
               || modelData.state === BluetoothDeviceState.Disconnecting

            // Coche seulement : la ligne dit déjà « connecté ». Un second
            // signal coloré n'ajouterait rien.
            trailing: modelData.connected ? "\u{F012C}" : ""

            onActivated: Services.btToggleDevice(modelData)
        }
    }
}
