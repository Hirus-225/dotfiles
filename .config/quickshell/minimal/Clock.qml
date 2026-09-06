import Quickshell
import QtQuick

StyledText {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: clock.date.toLocaleString(Qt.locale("fr_FR"), "dddd d MMMM  HH:mm")
}
