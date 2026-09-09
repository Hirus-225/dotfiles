import Quickshell
import Quickshell.Widgets
import QtQuick

// Une icône de tray, avec son repli. Deux appelants : la cellule de la barre
// (Tray.qml) et la ligne de menu (TrayMenuEntry.qml). Les deux reçoivent des
// URL d'icône de la même source — le protocole SNI — donc le même piège.
//
// --- LE PIÈGE, MESURÉ ------------------------------------------------------
// Une icône de thème ABSENTE ne produit ni erreur, ni status Error. Mesuré sur
// « image://icon/ce-nom-nexiste-pas-xyz123 » :
//
//     status = 1 (Ready)   sourceSize = 22x22   paintedWidth = 22
//
// C'est-à-dire EXACTEMENT ce que rend une icône valide. Le fournisseur
// d'images renvoie un carré entièrement transparent avec un statut Ready. Ni
// Image.status, ni sourceSize, ni paintedWidth ne distinguent les deux cas :
// les trois affichent une valeur plausible et fausse. Quickshell écrit bien un
// WARN dans son journal, mais QML ne le voit pas.
//
// Le seul détecteur qui marche est la résolution du nom dans le thème.
Item {
    id: root

    property string source: ""

    // Ce qu'on montre quand il n'y a rien à montrer. La barre y met l'initiale
    // de l'item — un trou anonyme dans la pastille serait pire qu'une lettre.
    // Le menu y met une chaîne vide : le libellé porte déjà le sens, et une
    // lettre de plus en tête de ligne ne ferait que du bruit.
    property string fallbackText: ""

    property int size: 22

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property bool missing: root.iconMissing(root.source)

    function iconMissing(url: string): bool {
        if (!url) return true;

        const scheme = "image://icon/";

        // Pixmap livrée par l'applet lui-même (image://qsimage/…) : les pixels
        // arrivent par le bus, il n'y a aucun nom à résoudre et rien à
        // vérifier. On ne masque pas une image qu'on ne sait pas juger.
        if (url.indexOf(scheme) !== 0) return false;

        const rest = url.slice(scheme.length);

        // « ?path=… » : l'applet fournit son propre dossier de thème
        // (IconThemePath du protocole SNI). hasThemeIcon ne sait pas y
        // chercher — répondre « absente » masquerait une icône valide, ce qui
        // est le pire des deux échecs. On fait confiance.
        if (rest.indexOf("?") !== -1) return false;

        const name = decodeURIComponent(rest);

        // hasThemeIcon("") renvoie TRUE (vérifié). Le cas vide doit donc être
        // écarté AVANT l'appel, sinon une icône absente passerait pour
        // présente — encore une valeur plausible et fausse.
        return name === "" || !Quickshell.hasThemeIcon(name);
    }

    // La source est COUPÉE quand l'icône est absente, pas seulement masquée.
    // Un `visible: false` laisse la liaison de source en place : l'Image
    // demande quand même l'icône au fournisseur, qui échoue et écrit un WARN
    // par entrée. Mesuré à l'ouverture du menu de blueman, une ligne par icône
    // absente :
    //
    //     WARN: Could not load icon "help-about-symbolic" at size QSize(16, 16)
    //
    // Une requête qu'on sait vouée à l'échec n'a pas à être émise.
    IconImage {
        anchors.centerIn: parent
        implicitSize: root.size

        visible: !root.missing
        source: root.missing ? "" : root.source
    }

    StyledText {
        anchors.centerIn: parent

        visible: root.missing && root.fallbackText !== ""
        text: root.fallbackText
        style: Text.Normal
    }
}
