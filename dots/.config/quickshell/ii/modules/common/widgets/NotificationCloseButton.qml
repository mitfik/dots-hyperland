import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton { // Dismiss button for a notification (or notification group)
    id: root
    property real iconSize: Appearance?.font.pixelSize.normal ?? 16
    property real diameter: root.iconSize + 4 * 2

    implicitWidth: diameter
    implicitHeight: diameter
    Layout.alignment: Qt.AlignVCenter
    Layout.fillHeight: false

    buttonRadius: Appearance.rounding.full
    colBackground: "transparent"
    colBackgroundHover: Appearance?.colors.colLayer2Hover ?? "#E5DFED"
    colRipple: Appearance?.colors.colLayer2Active ?? "#D6CEE2"

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: "close"
        iconSize: root.iconSize
        color: Appearance.colors.colSubtext
    }
}
