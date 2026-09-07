import QtQuick

// Conteneur des menus dépliés : un fond, une hauteur plafonnée, un défilement.
// Il ne connaît ni service ni contenu — on lui donne des lignes, il les
// empile. Les deux menus (Bluetooth, Wi-Fi) ont exactement ce besoin.
//
// La hauteur plafonnée est la raison d'être du module. Sans elle, une liste de
// réseaux dans un quartier dense (11 SSID mesurés ici en 5 s de scan) ferait
// descendre la bulle jusqu'en bas de l'écran, et le panneau cesserait d'être
// une bulle.
Item {
    id: root

    default property alias content: col.data

    property int rows: 4
    property int rowHeight: 38
    property int spacing: 2

    readonly property int maxHeight: root.rows * root.rowHeight
                                     + (root.rows - 1) * root.spacing

    implicitHeight: Math.min(col.implicitHeight, root.maxHeight)

    // Le fond distingue la liste des toggles au-dessus. Il est tiré de Theme.fg
    // et non d'une couleur fixe : la teinte doit suivre pywal comme le reste.
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.06)
    }

    Flickable {
        id: list

        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true

        // Sans ça la liste rebondit au-delà de ses bornes, ce qui, dans une
        // boîte de 158 px collée aux toggles, se lit comme un décrochage.
        boundsBehavior: Flickable.StopAtBounds

        // Le défilement ne s'active que s'il y a matière : une liste de deux
        // lignes ne doit pas glisser sous le curseur.
        interactive: contentHeight > height

        Column {
            id: col

            width: list.width
            spacing: root.spacing
        }
    }
}
