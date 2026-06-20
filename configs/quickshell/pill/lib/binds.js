function readMod(luaText) {
    var m = luaText.match(/^\s*local\s+mod\s*=\s*"([^"]*)"/m);
    return m ? m[1] : "SUPER";
}

function isMouseCombo(combo) {
    return /mouse:|mouse_up|mouse_down/.test(combo);
}

function optsHasMouse(opts) {
    return /\bmouse\s*=\s*true\b/.test(opts);
}

function splitArgs(inner) {
    var args = [];
    var depth = 0;
    var inStr = false;
    var start = 0;
    for (var i = 0; i < inner.length; i++) {
        var c = inner[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
        if (c === '(' || c === '{' || c === '[') depth++;
        else if (c === ')' || c === '}' || c === ']') depth--;
        else if (c === ',' && depth === 0) {
            args.push(inner.slice(start, i));
            start = i + 1;
        }
    }
    args.push(inner.slice(start));
    return args.map(function (a) { return a.trim(); });
}

function resolveCombo(firstArg, modValue) {
    var modMatch = firstArg.match(/^mod\s*\.\.\s*"([^"]*)"$/);
    if (modMatch) {
        return { combo: modValue + modMatch[1], comboForm: "mod" };
    }
    var litMatch = firstArg.match(/^"([^"]*)"$/);
    if (litMatch) {
        return { combo: litMatch[1], comboForm: "literal" };
    }
    return { combo: firstArg, comboForm: "literal" };
}

function deriveLabel(action) {
    var exec = action.match(/exec_cmd\(\s*"([^"]*)"\s*\)/);
    if (exec) {
        var cmd = exec[1];
        var script = cmd.match(/\/scripts\/([^\/]+)\.sh\b/);
        if (script) return script[1];
        return cmd.split(/\s+/)[0];
    }
    var execEnv = action.match(/exec_cmd\(\s*os\.getenv\([^)]*\)\s*\.\.\s*"([^"]*)"/);
    if (execEnv) {
        var path = execEnv[1];
        var s = path.match(/\/scripts\/([^\/]+)\.sh\b/);
        if (s) return s[1];
        return path;
    }

    if (/window\.kill\b/.test(action)) return "kill window";
    if (/window\.close\b/.test(action)) return "close window";
    if (/window\.fullscreen\b/.test(action)) return "fullscreen";
    if (/window\.float\b/.test(action)) return "float";
    if (/window\.move\b/.test(action)) return "move to workspace";
    if (/window\.drag\b/.test(action)) return "drag window";
    if (/window\.resize\b/.test(action)) return "resize window";

    var ws = action.match(/focus\(\s*{\s*workspace\s*=\s*"r([+-]\d+)"/);
    if (ws) return "workspace " + ws[1];

    return action.replace(/^hl\.dsp\./, "").replace(/\(\)$/, "");
}

function parseLine(raw, lineIndex, modValue) {
    var open = raw.indexOf("hl.bind(");
    if (open === -1) return null;

    var depth = 0;
    var inStr = false;
    var startInner = open + "hl.bind(".length;
    var endInner = -1;
    for (var i = startInner - 1; i < raw.length; i++) {
        var c = raw[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
        if (c === '(') depth++;
        else if (c === ')') {
            depth--;
            if (depth === 0) { endInner = i; break; }
        }
    }
    if (endInner === -1) return null;

    var inner = raw.slice(startInner, endInner);
    var args = splitArgs(inner);
    if (args.length < 2) return null;

    var resolved = resolveCombo(args[0], modValue);
    var action = args[1];
    var opts = args.length >= 3 ? args.slice(2).join(", ") : "";

    if (isMouseCombo(resolved.combo) || optsHasMouse(opts)) return null;

    return {
        combo: resolved.combo,
        label: deriveLabel(action),
        action: action,
        opts: opts,
        lineIndex: lineIndex,
        raw: raw,
        comboForm: resolved.comboForm
    };
}

function parse(luaText) {
    var modValue = readMod(luaText);
    var lines = luaText.split("\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var entry = parseLine(lines[i], i, modValue);
        if (entry) out.push(entry);
    }
    return out;
}

function rebind(luaText, lineIndex, newCombo) {
    var modValue = readMod(luaText);
    var lines = luaText.split("\n");
    if (lineIndex < 0 || lineIndex >= lines.length) {
        return { text: luaText, ok: false, error: "invalid lineIndex" };
    }

    var raw = lines[lineIndex];
    var open = raw.indexOf("hl.bind(");
    if (open === -1) {
        return { text: luaText, ok: false, error: "no hl.bind on line" };
    }

    var startInner = open + "hl.bind(".length;
    var firstEnd = -1;
    var depth = 0;
    var inStr = false;
    for (var i = startInner; i < raw.length; i++) {
        var c = raw[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
        if (c === '(' || c === '{' || c === '[') depth++;
        else if (c === ')' || c === '}' || c === ']') depth--;
        else if (c === ',' && depth === 0) { firstEnd = i; break; }
    }
    if (firstEnd === -1) {
        return { text: luaText, ok: false, error: "could not isolate first arg" };
    }

    var firstRaw = raw.slice(startInner, firstEnd);
    var leading = firstRaw.match(/^\s*/)[0];
    var trailing = firstRaw.match(/\s*$/)[0];

    var modPrefix = modValue + " + ";
    var firstArg;
    if (newCombo.indexOf(modPrefix) === 0) {
        firstArg = 'mod .. " + ' + newCombo.slice(modPrefix.length) + '"';
    } else {
        firstArg = '"' + newCombo + '"';
    }

    var newFirstRaw = leading + firstArg + trailing;
    var newLine = raw.slice(0, startInner) + newFirstRaw + raw.slice(firstEnd);
    lines[lineIndex] = newLine;

    return { text: lines.join("\n"), ok: true, error: "" };
}

function inUse(luaText, newCombo, exceptLineIndex) {
    var entries = parse(luaText);
    for (var i = 0; i < entries.length; i++) {
        if (entries[i].lineIndex === exceptLineIndex) continue;
        if (entries[i].combo === newCombo) return true;
    }
    return false;
}

var Binds = {
    parse: parse,
    rebind: rebind,
    inUse: inUse,
    readMod: readMod,
    deriveLabel: deriveLabel
};

if (typeof module !== "undefined" && module.exports) {
    module.exports = Binds;
}
