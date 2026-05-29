import QtQuick
import QtQuick.Shapes

Item {
    id: canvas

    required property int sx
    required property int sy
    property var model: null
    property var draft: null
    property int revision: 0

    function items() {
        var src = model ? model.items.slice() : [];
        if (draft) src.push(draft);
        return src;
    }

    function lp(a, i) {
        return Qt.point(a.points[i].x - sx, a.points[i].y - sy);
    }

    function polyPath(a) {
        var out = [];
        for (var i = 0; i < a.points.length; i++)
            out.push(Qt.point(a.points[i].x - sx, a.points[i].y - sy));
        return out;
    }

    function strokeColorOf(a) {
        if (a.type !== "marker") return a.color;
        var c = Qt.color(a.color);
        return Qt.rgba(c.r, c.g, c.b, 0.35);
    }

    function strokeWidthOf(a) {
        return a.type === "marker" ? a.width * 2.5 : a.width;
    }

    function ellipseGeom(a) {
        var p0 = lp(a, 0), p1 = lp(a, 1);
        return {
            cx: (p0.x + p1.x) / 2,
            cy: (p0.y + p1.y) / 2,
            rx: Math.abs(p1.x - p0.x) / 2,
            ry: Math.abs(p1.y - p0.y) / 2
        };
    }

    function arrowHead(a) {
        var p0 = lp(a, 0), p1 = lp(a, 1);
        var ang = Math.atan2(p1.y - p0.y, p1.x - p0.x);
        var len = Math.max(a.width * 3.2, 12);
        var spread = 0.42;
        return [
            p1,
            Qt.point(p1.x - len * Math.cos(ang - spread), p1.y - len * Math.sin(ang - spread)),
            Qt.point(p1.x - len * Math.cos(ang + spread), p1.y - len * Math.sin(ang + spread)),
            p1
        ];
    }

    Repeater {
        model: { canvas.revision; return canvas.items(); }

        Item {
            id: cell
            required property var modelData
            readonly property var a: modelData
            readonly property bool valid: a !== undefined && a !== null && a.points !== undefined && a.points.length >= 2
            readonly property string kind: valid ? a.type : ""
            anchors.fill: parent
            visible: valid

            Rectangle {
                visible: cell.valid && cell.kind === "rect"
                x: cell.valid ? Math.min(cell.a.points[0].x, cell.a.points[1].x) - canvas.sx : 0
                y: cell.valid ? Math.min(cell.a.points[0].y, cell.a.points[1].y) - canvas.sy : 0
                width: cell.valid ? Math.abs(cell.a.points[1].x - cell.a.points[0].x) : 0
                height: cell.valid ? Math.abs(cell.a.points[1].y - cell.a.points[0].y) : 0
                color: (cell.valid && cell.a.filled === true) ? cell.a.color : "transparent"
                border.color: cell.valid ? cell.a.color : "transparent"
                border.width: cell.valid ? cell.a.width : 0
                antialiasing: true
            }

            Shape {
                id: shp
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                visible: cell.valid && cell.kind !== "rect"

                readonly property bool isLine: cell.kind === "line" || cell.kind === "arrow"
                readonly property bool isPoly: cell.kind === "pen" || cell.kind === "marker"
                readonly property bool isEllipse: cell.kind === "ellipse"
                readonly property var eg: (isEllipse && cell.valid) ? canvas.ellipseGeom(cell.a) : null

                ShapePath {
                    strokeColor: cell.valid ? canvas.strokeColorOf(cell.a) : "transparent"
                    strokeWidth: cell.valid ? canvas.strokeWidthOf(cell.a) : 0
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: {
                        if (!cell.valid) return 0;
                        if (shp.eg) return shp.eg.cx - shp.eg.rx;
                        return canvas.lp(cell.a, 0).x;
                    }
                    startY: {
                        if (!cell.valid) return 0;
                        if (shp.eg) return shp.eg.cy;
                        return canvas.lp(cell.a, 0).y;
                    }

                    PathPolyline {
                        path: {
                            if (!cell.valid) return [];
                            if (shp.isPoly) return canvas.polyPath(cell.a);
                            if (shp.isLine) return [canvas.lp(cell.a, 0), canvas.lp(cell.a, 1)];
                            return [];
                        }
                    }

                    PathArc {
                        x: shp.eg ? shp.eg.cx + shp.eg.rx : 0
                        y: shp.eg ? shp.eg.cy : 0
                        radiusX: shp.eg ? shp.eg.rx : 0
                        radiusY: shp.eg ? shp.eg.ry : 0
                    }
                    PathArc {
                        x: shp.eg ? shp.eg.cx - shp.eg.rx : 0
                        y: shp.eg ? shp.eg.cy : 0
                        radiusX: shp.eg ? shp.eg.rx : 0
                        radiusY: shp.eg ? shp.eg.ry : 0
                    }
                }

                ShapePath {
                    id: head
                    readonly property var pts: (cell.valid && cell.kind === "arrow") ? canvas.arrowHead(cell.a) : null
                    strokeColor: cell.valid ? cell.a.color : "transparent"
                    strokeWidth: 1
                    fillColor: cell.valid ? cell.a.color : "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: pts ? pts[0].x : 0
                    startY: pts ? pts[0].y : 0
                    PathPolyline { path: head.pts ? head.pts : [] }
                }
            }
        }
    }
}
