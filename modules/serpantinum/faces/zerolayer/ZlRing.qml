import QtQuick

// ZerØLayer (ZeroLayer) · anillo de progreso con marcas, estilo ZerØ.
// Parte de ZerØLayer, módulo serpantinum (AGPL-3.0, como Serpantinum).
Canvas {
    id: ring
    property real value: 0          // 0..1
    property color trackColor: "#1c2a3a"
    property color fillColor: "#4da3ff"
    property real lineWidth: 5
    property int ticks: 24

    onValueChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        let ctx = getContext("2d");
        ctx.reset();
        let cx = width / 2, cy = height / 2;
        let r = Math.min(width, height) / 2 - lineWidth / 2 - 4;
        let v = Math.max(0, Math.min(1, value));
        let start = -Math.PI / 2;
        ctx.lineCap = "butt";
        ctx.lineWidth = lineWidth;
        ctx.strokeStyle = trackColor;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.stroke();
        if (v > 0) {
            ctx.strokeStyle = fillColor;
            ctx.beginPath();
            ctx.arc(cx, cy, r, start, start + v * 2 * Math.PI);
            ctx.stroke();
        }
        // Marcas exteriores, más vivas en la parte completada.
        for (let i = 0; i < ticks; i++) {
            let a = start + i / ticks * 2 * Math.PI;
            let on = i / ticks < v;
            ctx.strokeStyle = on ? fillColor : trackColor;
            ctx.globalAlpha = on ? 0.9 : 0.6;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(cx + Math.cos(a) * (r + lineWidth / 2 + 1), cy + Math.sin(a) * (r + lineWidth / 2 + 1));
            ctx.lineTo(cx + Math.cos(a) * (r + lineWidth / 2 + 4), cy + Math.sin(a) * (r + lineWidth / 2 + 4));
            ctx.stroke();
        }
        ctx.globalAlpha = 1;
    }
}
