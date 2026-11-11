import QtQuick
import QtQuick.Effects
import Quickshell
import "../../../reusables"
import "../../../"

// ZerØLayer (ZeroLayer) · espectro tipo osciloscopio: barras cuadradas en bloques LED desde una línea central.
// Basado en las caras de visualizador de Serpantinum; módulo serpantinum de ZerØLayer (AGPL-3.0).
Item {
    id: root
    anchors.fill: parent

    property real minWidth: 120
    property real minHeight: 50
    property real maxWidth: 99999
    property real maxHeight: 99999
    property real minAspect: 0
    property real maxAspect: 99999

    property bool isVisVisible: visible
    property bool isSubscribed: false

    readonly property color ice: ThemeBackend.blue
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int ledOn: 4
    readonly property int ledOff: 2

    onIsVisVisibleChanged: updateSubscription()

    function updateSubscription() {
        if (isVisVisible && !isSubscribed) {
            isSubscribed = true;
            Cava.registerConsumer();
        } else if (!isVisVisible && isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    Component.onCompleted: updateSubscription()

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    // Línea base del osciloscopio
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 1
        color: root.ice
        opacity: 0.35
    }

    // Marcas de escala en el borde inferior
    Repeater {
        model: Math.floor(root.width / 48)
        Rectangle {
            x: index * 48
            y: root.height - height
            width: 1
            height: index % 4 === 0 ? 6 : 3
            color: root.ice
            opacity: 0.4
        }
    }

    Item {
        id: spectrum
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ledMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.0
        }

        Visualizer {
            anchors.fill: parent
            active: root.isSubscribed
            continuous: false
            alignment: "center"
            count: Math.max(32, Math.min(128, Math.round(parent.width / 9)))
            spacing: 3
            minLength: 2
            radiusRatio: 0
            edgeFade: true
            tintStrength: 0.55
            rise: 0.35
            fall: 0.12
            maxLength: height * 0.95
            color: root.ice
        }
    }

    // Máscara de franjas horizontales: corta las barras en bloques LED
    Item {
        id: ledMask
        anchors.fill: spectrum
        visible: false
        layer.enabled: true

        Column {
            spacing: root.ledOff
            Repeater {
                model: Math.ceil(ledMask.height / (root.ledOn + root.ledOff)) + 1
                Rectangle {
                    width: ledMask.width
                    height: root.ledOn
                    color: "white"
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        text: "SPECTRUM://AUDIO"
        font.family: root.mono
        font.pixelSize: 9
        font.letterSpacing: 2
        color: root.ice
        opacity: 0.55
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.isSubscribed && Cava.barLevels && Cava.barLevels.length > 0 ? "◢ LIVE" : "◢ IDLE"
        font.family: root.mono
        font.pixelSize: 9
        font.letterSpacing: 2
        color: root.ice
        opacity: 0.55
    }
}
