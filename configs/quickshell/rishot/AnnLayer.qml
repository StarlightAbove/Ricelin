// rishot — annotation layer for one output (file is AnnLayer to avoid clashing with QtQuick's
// built-in `Canvas` type; the spec calls this unit "Canvas"). Renders committed annotations
// (model.items) plus the in-progress draft on top of the frozen capture, in this screen's LOCAL
// coords. Real QML items (Rectangle for rect); export grabs this together with the frozen frame.
import QtQuick

Item {
    id: canvas

    required property int sx        // this screen's global x origin
    required property int sy        // this screen's global y origin
    property var model: null        // AnnotationModel instance ({items,...})
    property var draft: null        // in-progress annotation (same shape as a model item) | null
    property int revision: 0        // bump to force a re-read of model.items

    // Flatten committed items + draft into a render list of LOCAL rects for rect-type annotations.
    function rects() {
        var out = [];
        var src = model ? model.items.slice() : [];
        if (draft) src.push(draft);
        for (var i = 0; i < src.length; i++) {
            var a = src[i];
            if (a.type !== "rect" || !a.points || a.points.length < 2) continue;
            var p0 = a.points[0], p1 = a.points[1];
            out.push({
                x: Math.min(p0.x, p1.x) - sx,
                y: Math.min(p0.y, p1.y) - sy,
                w: Math.abs(p1.x - p0.x),
                h: Math.abs(p1.y - p0.y),
                color: a.color,
                width: a.width,
                filled: a.filled === true
            });
        }
        return out;
    }

    Repeater {
        model: { canvas.revision; return canvas.rects(); }
        Rectangle {
            required property var modelData
            x: modelData.x; y: modelData.y
            width: modelData.w; height: modelData.h
            color: modelData.filled ? modelData.color : "transparent"
            border.color: modelData.color
            border.width: modelData.width
            antialiasing: true
        }
    }
}
