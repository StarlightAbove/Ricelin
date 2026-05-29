// rishot — pure annotation store + undo/redo command stack. No Qt imports.
// Annotation: {type,points:[{x,y}...],color,width,filled,text,font}. points in GLOBAL coords.
// Ops are coarse (one per user action) so undo/redo is per-action.

function create() {
    return {
        items: [],      // committed annotations, render order = array order
        undoStack: [],  // ops available to undo
        redoStack: [],  // ops available to redo

        // Append an annotation as a single undoable op. Clears the redo stack.
        add: function (ann) {
            this.items.push(ann);
            this.undoStack.push({ kind: "add", ann: ann });
            this.redoStack = [];
            return ann;
        },

        // Reverse the last op; push it onto the redo stack.
        undo: function () {
            if (this.undoStack.length === 0) return false;
            var op = this.undoStack.pop();
            if (op.kind === "add") this.items.pop();
            this.redoStack.push(op);
            return true;
        },

        // Re-apply the last undone op.
        redo: function () {
            if (this.redoStack.length === 0) return false;
            var op = this.redoStack.pop();
            if (op.kind === "add") this.items.push(op.ann);
            this.undoStack.push(op);
            return true;
        },

        canUndo: function () { return this.undoStack.length > 0; },
        canRedo: function () { return this.redoStack.length > 0; }
    };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { create: create };
}
