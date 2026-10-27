import QtQuick
import "../theme.js" as Theme

Canvas {
    id: icon

    property string name: "grid"
    property color color: Theme.ink
    property real strokeWidth: 1.5

    implicitWidth: 18
    implicitHeight: 18
    width: 18
    height: 18

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width;
        var h = height;
        var s = Math.min(w, h);
        var cx = w / 2;
        var cy = h / 2;
        ctx.strokeStyle = color;
        ctx.fillStyle = color;
        ctx.lineWidth = strokeWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        function line(x1, y1, x2, y2) {
            ctx.beginPath();
            ctx.moveTo(x1, y1);
            ctx.lineTo(x2, y2);
            ctx.stroke();
        }
        function rect(x, y, rw, rh, r) {
            var rad = (r === undefined) ? 1.5 : r;
            ctx.beginPath();
            ctx.moveTo(x + rad, y);
            ctx.lineTo(x + rw - rad, y);
            ctx.quadraticCurveTo(x + rw, y, x + rw, y + rad);
            ctx.lineTo(x + rw, y + rh - rad);
            ctx.quadraticCurveTo(x + rw, y + rh, x + rw - rad, y + rh);
            ctx.lineTo(x + rad, y + rh);
            ctx.quadraticCurveTo(x, y + rh, x, y + rh - rad);
            ctx.lineTo(x, y + rad);
            ctx.quadraticCurveTo(x, y, x + rad, y);
            ctx.stroke();
        }
        function circle(x, y, r) {
            ctx.beginPath();
            ctx.arc(x, y, r, 0, Math.PI * 2);
            ctx.stroke();
        }
        function dot(x, y, r) {
            ctx.beginPath();
            ctx.arc(x, y, r, 0, Math.PI * 2);
            ctx.fill();
        }

        if (name === "grid") {
            var p = s * 0.16;
            var g = s * 0.13;
            var cell = (s - p * 2 - g) / 2;
            rect(p, p, cell, cell, 2);
            rect(p + cell + g, p, cell, cell, 2);
            rect(p, p + cell + g, cell, cell, 2);
            rect(p + cell + g, p + cell + g, cell, cell, 2);
        } else if (name === "market") {
            var bw = s * 0.52;
            var bh = s * 0.34;
            var bx = cx - bw / 2;
            var by = s * 0.42;
            ctx.beginPath();
            ctx.moveTo(bx, by);
            ctx.lineTo(bx + s * 0.06, s * 0.2);
            ctx.lineTo(bx + bw - s * 0.06, s * 0.2);
            ctx.lineTo(bx + bw, by);
            ctx.stroke();
            rect(bx, by, bw, bh, 3);
            line(cx, by + s * 0.05, cx, by + bh - s * 0.05);
            ctx.beginPath();
            ctx.arc(cx - s * 0.16, s * 0.2, s * 0.08, Math.PI, 0);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx + s * 0.16, s * 0.2, s * 0.08, Math.PI, 0);
            ctx.stroke();
        } else if (name === "projects") {
            rect(s * 0.16, s * 0.16, s * 0.68, s * 0.68, 3);
            line(s * 0.16, s * 0.38, s * 0.84, s * 0.38);
            line(s * 0.16, s * 0.6, s * 0.84, s * 0.6);
            dot(s * 0.3, s * 0.27, 1.3);
            dot(s * 0.3, s * 0.49, 1.3);
        } else if (name === "challenges") {
            ctx.beginPath();
            ctx.moveTo(s * 0.56, s * 0.12);
            ctx.lineTo(s * 0.3, s * 0.52);
            ctx.lineTo(s * 0.48, s * 0.52);
            ctx.lineTo(s * 0.42, s * 0.86);
            ctx.lineTo(s * 0.7, s * 0.44);
            ctx.lineTo(s * 0.51, s * 0.44);
            ctx.closePath();
            ctx.stroke();
        } else if (name === "wallet") {
            rect(s * 0.14, s * 0.26, s * 0.72, s * 0.52, 3.5);
            line(s * 0.14, s * 0.4, s * 0.86, s * 0.4);
            dot(s * 0.68, s * 0.62, 1.8);
            line(s * 0.32, s * 0.26, s * 0.62, s * 0.15);
        } else if (name === "room") {
            ctx.beginPath();
            ctx.moveTo(s * 0.16, s * 0.22);
            ctx.lineTo(s * 0.84, s * 0.22);
            ctx.quadraticCurveTo(s * 0.9, s * 0.22, s * 0.9, s * 0.3);
            ctx.lineTo(s * 0.9, s * 0.62);
            ctx.quadraticCurveTo(s * 0.9, s * 0.7, s * 0.82, s * 0.7);
            ctx.lineTo(s * 0.42, s * 0.7);
            ctx.lineTo(s * 0.26, s * 0.84);
            ctx.lineTo(s * 0.26, s * 0.7);
            ctx.lineTo(s * 0.18, s * 0.7);
            ctx.quadraticCurveTo(s * 0.1, s * 0.7, s * 0.1, s * 0.62);
            ctx.lineTo(s * 0.1, s * 0.3);
            ctx.quadraticCurveTo(s * 0.1, s * 0.22, s * 0.16, s * 0.22);
            ctx.stroke();
            dot(s * 0.38, s * 0.46, 1.2);
            dot(s * 0.5, s * 0.46, 1.2);
            dot(s * 0.62, s * 0.46, 1.2);
        } else if (name === "map") {
            ctx.beginPath();
            ctx.moveTo(s * 0.12, s * 0.28);
            ctx.lineTo(s * 0.38, s * 0.18);
            ctx.lineTo(s * 0.62, s * 0.28);
            ctx.lineTo(s * 0.88, s * 0.18);
            ctx.lineTo(s * 0.88, s * 0.74);
            ctx.lineTo(s * 0.62, s * 0.84);
            ctx.lineTo(s * 0.38, s * 0.74);
            ctx.lineTo(s * 0.12, s * 0.84);
            ctx.closePath();
            ctx.stroke();
            line(s * 0.38, s * 0.18, s * 0.38, s * 0.74);
            line(s * 0.62, s * 0.28, s * 0.62, s * 0.84);
            dot(s * 0.5, s * 0.5, 1.7);
        } else if (name === "kitchen") {
            ctx.beginPath();
            ctx.moveTo(s * 0.16, s * 0.44);
            ctx.lineTo(s * 0.84, s * 0.44);
            ctx.lineTo(s * 0.78, s * 0.8);
            ctx.quadraticCurveTo(s * 0.76, s * 0.86, s * 0.68, s * 0.86);
            ctx.lineTo(s * 0.32, s * 0.86);
            ctx.quadraticCurveTo(s * 0.24, s * 0.86, s * 0.22, s * 0.8);
            ctx.closePath();
            ctx.stroke();
            line(s * 0.12, s * 0.44, s * 0.88, s * 0.44);
            line(s * 0.18, s * 0.38, s * 0.82, s * 0.38);
            line(s * 0.5, s * 0.38, s * 0.5, s * 0.31);
            dot(s * 0.5, s * 0.28, 1.4);
            line(s * 0.12, s * 0.55, s * 0.2, s * 0.55);
            line(s * 0.8, s * 0.55, s * 0.88, s * 0.55);
            ctx.beginPath();
            ctx.moveTo(s * 0.36, s * 0.22);
            ctx.quadraticCurveTo(s * 0.32, s * 0.16, s * 0.38, s * 0.12);
            ctx.moveTo(s * 0.56, s * 0.22);
            ctx.quadraticCurveTo(s * 0.6, s * 0.16, s * 0.54, s * 0.12);
            ctx.stroke();
        } else if (name === "landscape") {
            ctx.beginPath();
            ctx.moveTo(s * 0.1, s * 0.74);
            ctx.quadraticCurveTo(s * 0.28, s * 0.5, s * 0.42, s * 0.62);
            ctx.quadraticCurveTo(s * 0.58, s * 0.76, s * 0.7, s * 0.48);
            ctx.quadraticCurveTo(s * 0.78, s * 0.34, s * 0.9, s * 0.4);
            ctx.stroke();
            circle(s * 0.7, s * 0.28, s * 0.1);
            line(s * 0.1, s * 0.84, s * 0.9, s * 0.84);
        } else if (name === "shield") {
            ctx.beginPath();
            ctx.moveTo(cx, s * 0.12);
            ctx.lineTo(s * 0.82, s * 0.26);
            ctx.lineTo(s * 0.78, s * 0.58);
            ctx.quadraticCurveTo(s * 0.72, s * 0.78, cx, s * 0.88);
            ctx.quadraticCurveTo(s * 0.28, s * 0.78, s * 0.22, s * 0.58);
            ctx.lineTo(s * 0.18, s * 0.26);
            ctx.closePath();
            ctx.stroke();
        } else if (name === "check") {
            ctx.beginPath();
            ctx.moveTo(s * 0.2, s * 0.52);
            ctx.lineTo(s * 0.42, s * 0.72);
            ctx.lineTo(s * 0.8, s * 0.3);
            ctx.stroke();
        } else if (name === "clock") {
            circle(cx, cy, s * 0.34);
            line(cx, cy - s * 0.2, cx, cy);
            line(cx, cy, cx + s * 0.16, cy + s * 0.1);
        } else if (name === "arrow") {
            line(s * 0.2, cy, s * 0.78, cy);
            line(s * 0.58, cy - s * 0.16, s * 0.78, cy);
            line(s * 0.58, cy + s * 0.16, s * 0.78, cy);
        } else if (name === "close") {
            line(s * 0.26, s * 0.26, s * 0.74, s * 0.74);
            line(s * 0.74, s * 0.26, s * 0.26, s * 0.74);
        } else if (name === "leaf") {
            ctx.beginPath();
            ctx.moveTo(s * 0.2, s * 0.8);
            ctx.quadraticCurveTo(s * 0.2, s * 0.26, s * 0.82, s * 0.18);
            ctx.quadraticCurveTo(s * 0.8, s * 0.68, s * 0.2, s * 0.8);
            ctx.stroke();
            line(s * 0.26, s * 0.74, s * 0.64, s * 0.36);
        } else if (name === "plus") {
            line(cx, s * 0.2, cx, s * 0.8);
            line(s * 0.2, cy, s * 0.8, cy);
        } else if (name === "key") {
            circle(s * 0.3, s * 0.34, s * 0.16);
            line(s * 0.4, s * 0.46, s * 0.82, s * 0.82);
            line(s * 0.66, s * 0.68, s * 0.56, s * 0.78);
            line(s * 0.76, s * 0.78, s * 0.66, s * 0.88);
        } else if (name === "external") {
            line(s * 0.22, s * 0.78, s * 0.78, s * 0.22);
            line(s * 0.4, s * 0.22, s * 0.78, s * 0.22);
            line(s * 0.78, s * 0.22, s * 0.78, s * 0.6);
        } else if (name === "info") {
            circle(cx, cy, s * 0.38);
            line(cx, s * 0.44, cx, s * 0.68);
            dot(cx, s * 0.32, 1.2);
        }
    }
}
