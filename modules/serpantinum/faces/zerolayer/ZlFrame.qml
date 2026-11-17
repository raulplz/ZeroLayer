import QtQuick
import QtQuick.Layouts
import "../../../reusables"

// ZerØLayer (ZeroLayer) · marco común de los widgets ZerØ: panel translúcido,
// cabecera «> ALGO://ZERØ», insignia a la derecha y línea divisoria.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Rectangle {
    id: frame
    required property var theme
    property string title: ""
    property string badge: ""
    property color badgeColor: Qt.alpha(theme.acento, 0.7)
    property int pad: 12
    default property alias content: body.data
    property alias headerExtra: extra.data

    anchors.fill: parent
    color: Qt.alpha(theme.fondo, 0.62)
    radius: 4
    border.width: 1
    border.color: Qt.alpha(theme.acento, 0.35)

    WallpaperBlur {
        z: -1
        anchors.fill: parent
        radius: parent.radius
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: frame.pad
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "> " + frame.title
                font.family: frame.theme.mono
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
                color: frame.theme.acento
            }
            Item { Layout.fillWidth: true }
            Row {
                id: extra
                spacing: 6
            }
            Text {
                visible: frame.badge !== ""
                text: frame.badge
                font.family: frame.theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1
                color: frame.badgeColor
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(frame.theme.acento, 0.3)
        }

        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
