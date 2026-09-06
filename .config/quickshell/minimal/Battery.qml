import Quickshell
import Quickshell.Services.UPower
import QtQuick

StyledText {
    property var bat: UPower.displayDevice
    property int pct: Math.round(bat.percentage * 100)

    color: pct <= 20 && bat.state !== UPowerDeviceState.Charging
           ? Theme.alert
           : Theme.fg

    text: (bat.state === UPowerDeviceState.Charging ? "+ " : "") + pct + "%"
}
