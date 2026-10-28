pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pomodoro-Zähler ohne eigene Oberfläche (die Leiste zeigt ihn, mono:
// Status.qml und PomodoroPanel.qml). Einstellungen in
// ~/.config/g5/pomodoro.json (Panel oder von Hand, wird beim Speichern neu
// gelesen), Zustand in ~/.local/state/g5/pomodoro.json – ein Neustart von
// Quickshell (z. B. `style`) lässt die laufende Runde weiterlaufen.
//
// Von außen: qs -p ~/.config/quickshell/mono ipc call pomodoro toggle
//   (auch skip, reset, add <min>, status)
Singleton {
    id: root

    // Phase: idle, focus, short (kurze Pause), long (lange Pause)
    readonly property string phase: st.phase
    readonly property bool running: st.running
    readonly property bool isBreak: phase === "short" || phase === "long"
    // Runden seit der letzten langen Pause und heute geschafft
    readonly property int round: st.round
    readonly property int doneToday: st.day === today() ? st.doneToday : 0
    // Restzeit in Sekunden und Länge der Phase (für den Fortschritt)
    property int left: 0
    readonly property int total: minutes(phase) * 60
    readonly property real progress: total > 0 ? 1 - left / total : 0
    readonly property var settings: cfg

    function minutes(p) {
        return p === "short" ? cfg.shortBreak : p === "long" ? cfg.longBreak : cfg.focus;
    }

    function today() {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    // mm:ss
    function clock(s) {
        const m = Math.floor(s / 60);
        const r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    function update() {
        if (st.running) {
            left = Math.max(0, Math.round((st.endsAt - Date.now()) / 1000));
            if (left === 0)
                finish();
        } else {
            left = st.phase === "idle" ? cfg.focus * 60 : st.left;
        }
    }

    // Phase p beginnen (läuft gleich oder wartet auf Klick)
    function enter(p, run) {
        const secs = minutes(p) * 60;
        st.phase = p;
        st.left = secs;
        st.endsAt = Date.now() + secs * 1000;
        st.running = run;
        quiet(p === "focus" && run);
        if (run)
            hook(p);
        update();
    }

    // Start, Pause, Weiter
    function toggle() {
        if (st.phase === "idle") {
            enter("focus", true);
        } else if (st.running) {
            st.left = left;
            st.running = false;
            quiet(false);
        } else {
            st.endsAt = Date.now() + st.left * 1000;
            st.running = true;
            quiet(st.phase === "focus");
            hook(st.phase);
        }
        update();
    }

    // Phase überspringen: zählt nicht als geschafft
    function skip() {
        if (st.phase === "idle")
            return;
        next(false);
    }

    function reset() {
        st.phase = "idle";
        st.running = false;
        st.round = 0;
        quiet(false);
        update();
    }

    // Restzeit um n Minuten ändern (Mausrad), nie unter eine Minute
    function add(n) {
        if (st.phase === "idle") {
            cfg.focus = Math.max(1, Math.min(180, cfg.focus + n));
        } else if (st.running) {
            st.endsAt = Math.max(Date.now() + 60000, st.endsAt + n * 60000);
        } else {
            st.left = Math.max(60, st.left + n * 60);
        }
        update();
    }

    function finish() {
        const was = st.phase;
        quiet(false);
        // Lange vorbei (Rechner aus, Quickshell neu): still weiterzählen,
        // die nächste Phase wartet auf einen Klick
        const stale = Date.now() - st.endsAt > 10 * 60000;
        next(true, stale);
        if (stale)
            return;
        if (was === "focus")
            say(st.phase === "long" ? "Lange Pause" : "Pause", minutes(st.phase) + " min durchatmen", cfg.soundFocusEnd);
        else
            say("Fokus", minutes("focus") + " min, los geht’s", cfg.soundBreakEnd);
    }

    // Nach Phase: Fokus → kurze/lange Pause, Pause → Fokus
    function next(counted, hold) {
        if (st.phase === "focus") {
            if (counted) {
                if (st.day !== today()) {
                    st.day = today();
                    st.doneToday = 0;
                }
                st.doneToday += 1;
                st.round += 1;
            }
            const long = st.round > 0 && st.round % cfg.longEvery === 0;
            enter(long ? "long" : "short", cfg.autoBreak && !hold);
        } else {
            if (st.phase === "long")
                st.round = 0;
            enter("focus", cfg.autoFocus && !hold);
        }
    }

    // Nicht stören (mako) während des Fokus
    function quiet(on) {
        if (cfg.dnd)
            Quickshell.execDetached(["makoctl", "mode", on ? "-a" : "-r", "do-not-disturb"]);
    }

    // Eigener Befehl beim Start einer Phase (cmdFocus, cmdBreak), über sh
    function hook(p) {
        const cmd = p === "focus" ? cfg.cmdFocus : cfg.cmdBreak;
        if (cmd)
            Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // Nachricht etwas später: makoctl (quiet) soll „nicht stören“ erst
    // aufheben, sonst bliebe sie unsichtbar
    function say(title, body, sound) {
        if (cfg.sound && sound)
            Quickshell.execDetached(["paplay", sound]);
        if (cfg.notify) {
            sayLater.args = ["notify-send", "-a", "Pomodoro", "-i", "alarm-timer", title, body];
            sayLater.restart();
        }
    }

    Timer {
        id: sayLater

        property var args: []

        interval: 300
        onTriggered: Quickshell.execDetached(args)
    }

    Timer {
        interval: 1000
        running: root.running
        repeat: true
        triggeredOnStart: true
        onTriggered: root.update()
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/g5/pomodoro.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: cfg

            // Minuten
            property int focus: 25
            property int shortBreak: 5
            property int longBreak: 15
            // lange Pause nach so vielen Fokus-Runden
            property int longEvery: 4
            // Tagesziel (Punkte im Panel)
            property int goal: 8
            // nächste Phase von selbst starten
            property bool autoBreak: true
            property bool autoFocus: false
            property bool notify: true
            property bool sound: true
            property string soundFocusEnd: "/usr/share/sounds/freedesktop/stereo/complete.oga"
            property string soundBreakEnd: "/usr/share/sounds/freedesktop/stereo/bell.oga"
            // mako im Fokus auf „do-not-disturb“
            property bool dnd: false
            // ohne laufende Runde nur das Symbol zeigen (sonst ganz weg)
            property bool showIdle: true
            // Befehle beim Start einer Phase, z. B. "playerctl play"
            property string cmdFocus: ""
            property string cmdBreak: ""
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/g5/pomodoro.json"
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: st

            property string phase: "idle"
            property bool running: false
            // Ende in ms (läuft) bzw. Rest in s (angehalten)
            property real endsAt: 0
            property int left: 0
            property int round: 0
            property int doneToday: 0
            property string day: ""
        }
    }

    // Einstellungen geändert: angehaltene/leere Anzeige mitziehen
    Connections {
        target: cfg
        function onFocusChanged() {
            root.update();
        }
    }

    Component.onCompleted: update()

    IpcHandler {
        target: "pomodoro"

        function toggle(): void {
            root.toggle();
        }
        function skip(): void {
            root.skip();
        }
        function reset(): void {
            root.reset();
        }
        function add(min: int): void {
            root.add(min);
        }
        function status(): string {
            return root.phase + (root.running || root.phase === "idle" ? "" : " (paused)") + " " + root.clock(root.left);
        }
    }
}
