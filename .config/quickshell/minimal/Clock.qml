import Quickshell
import QtQuick

// L'horloge ne connaît pas le calendrier : elle émet un clic, et c'est Bar.qml
// qui décide de ce que ce clic ouvre. Même découpage que Connectivity.qml, qui
// émet `clicked` sans jamais nommer ControlCenter.
StyledText {
    id: root

    signal clicked()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: clock.date.toLocaleString(Qt.locale("fr_FR"), "dddd d MMMM  HH:mm")

    // La cible déborde le texte en hauteur pour occuper toute la barre : viser
    // 35 px est plus facile que viser la boîte du texte, et la zone reste
    // strictement dans la largeur de l'horloge.
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -(Theme.barHeight - parent.height) / 2
        anchors.bottomMargin: -(Theme.barHeight - parent.height) / 2

        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: root.clicked()
    }
}
