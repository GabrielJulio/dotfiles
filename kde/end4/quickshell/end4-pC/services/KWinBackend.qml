pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // WM.qml backend interface
    property var windowList: []
    property var workspaces: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var focusedMonitor: null

    // Functions on dynamically-created backends cannot reliably resolve
    // sibling ids with ComponentBehavior: Bound. Expose the processes and
    // debounce timer through root properties instead.
    property alias actionProcess: actionProc
    property alias windowsProcess: getWindows
    property alias desktopsProcess: getDesktops
    property alias currentDesktopProcess: getCurrent
    property alias focusedOutputProcess: getFocusedOutput
    property alias windowRefreshDebounceTimer: windowRefreshDebounce

    // KWin state
    property var desktopDefs: []
    property string currentDesktopUuid: ""
    property string focusedOutputName: ""

    function normalizedMonitors() {
        let result = [];

        for (let i = 0; i < Quickshell.screens.length; ++i) {
            const screen = Quickshell.screens[i];

            result.push({
                name: screen.name,
                make: "",
                model: screen.model ?? "",
                logical: {
                    x: screen.x,
                    y: screen.y,
                    width: screen.width,
                    height: screen.height,
                    scale: screen.devicePixelRatio
                }
            });
        }

        return result;
    }

    function rebuildWorkspaces() {
        root.monitors = root.normalizedMonitors();

        // KWin virtual desktops are global rather than per-output.
        // pC expects Niri-style per-output workspace entries, so expose
        // each KWin virtual desktop on every monitor.
        const outputs = root.monitors.length > 0
            ? root.monitors
            : [{ name: "" }];

        let result = [];

        for (const desktop of root.desktopDefs) {
            for (const monitor of outputs) {
                result.push({
                    id: desktop.uuid,
                    uuid: desktop.uuid,
                    idx: desktop.idx,
                    index: desktop.index,
                    name: desktop.name,
                    output: monitor.name,

                    is_active:
                        desktop.uuid === root.currentDesktopUuid,

                    is_focused:
                        desktop.uuid === root.currentDesktopUuid
                        && (
                            root.focusedOutputName === ""
                            || monitor.name === root.focusedOutputName
                        )
                });
            }
        }

        root.workspaces = result;

        let byId = {};

        for (const ws of result) {
            // Support both KWin UUID and pC's numerical workspace index.
            byId[ws.id] = ws;
            byId[ws.idx] = ws;
        }

        root.workspaceById = byId;

        root.activeWorkspace =
            result.find(ws =>
                ws.id === root.currentDesktopUuid
                && ws.output === root.focusedOutputName
            )
            ?? result.find(ws =>
                ws.id === root.currentDesktopUuid
            )
            ?? null;

        root.focusedMonitor =
            root.monitors.find(m =>
                m.name === root.focusedOutputName
            )
            ?? root.monitors[0]
            ?? null;
    }

    function refresh() {
        root.monitors = root.normalizedMonitors();

        if (!root.desktopsProcess.running)
            root.desktopsProcess.running = true;

        if (!root.currentDesktopProcess.running)
            root.currentDesktopProcess.running = true;

        if (!root.focusedOutputProcess.running)
            root.focusedOutputProcess.running = true;

        if (!root.windowsProcess.running)
            root.windowsProcess.running = true;
    }

    function outputForWindow(window) {
        const cx = (window.x ?? 0) + (window.width ?? 0) / 2;
        const cy = (window.y ?? 0) + (window.height ?? 0) / 2;

        const monitor = root.monitors.find(m =>
            cx >= m.logical.x
            && cx < m.logical.x + m.logical.width
            && cy >= m.logical.y
            && cy < m.logical.y + m.logical.height
        );

        return monitor?.name
            ?? root.focusedOutputName
            ?? root.monitors[0]?.name
            ?? "";
    }

    function normalizeWindow(window) {
        const output = root.outputForWindow(window);

        // Keep this explicit for Qt 6.8 / Quickshell 0.3.1, whose QML
        // JavaScript engine does not support object spread syntax.
        return {
            id: String(window.id ?? ""),
            address: String(window.address ?? window.id ?? ""),
            title: window.title ?? "",
            appId: window.appId ?? "",
            appName: window.appName ?? window.appId ?? "",
            class: window.class ?? window.appId ?? "",
            desktopFile: window.desktopFile ?? "",
            resourceClass: window.resourceClass ?? "",
            resourceName: window.resourceName ?? "",
            pid: Number(window.pid ?? 0),
            workspaceId: window.workspaceId ?? "",
            workspaceNumber: Number(window.workspaceNumber ?? 0),
            workspaceUuid: window.workspaceUuid ?? window.workspaceId ?? "",
            workspaceIds: window.workspaceIds ?? [],
            focused: window.focused ?? false,
            isFocused: window.isFocused ?? window.focused ?? false,
            fullscreen: window.fullscreen ?? false,
            minimized: window.minimized ?? false,
            skipTaskbar: window.skipTaskbar ?? false,
            x: Number(window.x ?? 0),
            y: Number(window.y ?? 0),
            width: Number(window.width ?? 0),
            height: Number(window.height ?? 0),
            output: output
        };
    }

    function refreshWindows() {
        if (!root.windowsProcess.running)
            root.windowsProcess.running = true;
    }

    function kdotoolWindowId(id) {
        const value = String(id ?? "");

        if (value.startsWith("{") && value.endsWith("}"))
            return value;

        return "{" + value + "}";
    }

    function switchWorkspaceRelative(direction) {
        const method =
            direction === "next"
                ? "org.kde.KWin.nextDesktop"
                : "org.kde.KWin.previousDesktop";

        root.actionProcess.exec([
            "qdbus6",
            "org.kde.KWin",
            "/KWin",
            method
        ]);
    }

    function switchWorkspace(id) {
        let number = Number(id);

        // Also accept KWin UUIDs.
        if (!Number.isFinite(number)) {
            const desktop =
                root.desktopDefs.find(
                    d => d.uuid === String(id)
                );

            number = desktop?.idx ?? NaN;
        }

        if (!Number.isFinite(number))
            return;

        root.actionProcess.exec([
            "qdbus6",
            "org.kde.KWin",
            "/KWin",
            "org.kde.KWin.setCurrentDesktop",
            String(number)
        ]);
    }

    // KWin window IDs are internal UUIDs handled by kdotool.
    function focusWindow(id) {
        root.actionProcess.exec([
            "kdotool",
            "windowactivate",
            root.kdotoolWindowId(id)
        ]);

        root.windowRefreshDebounceTimer.restart();
    }

    function closeWindow(id) {
        root.actionProcess.exec([
            "kdotool",
            "windowclose",
            root.kdotoolWindowId(id)
        ]);

        root.windowRefreshDebounceTimer.restart();
    }

    function moveWindowToWorkspace(id, wsId) {
        let number = Number(wsId);

        if (!Number.isFinite(number)) {
            const desktop = root.desktopDefs.find(
                d => d.uuid === String(wsId)
            );

            number = desktop?.idx ?? NaN;
        }

        if (!Number.isFinite(number))
            return;

        root.actionProcess.exec([
            "kdotool",
            "set_desktop_for_window",
            root.kdotoolWindowId(id),
            String(number)
        ]);

        root.windowRefreshDebounceTimer.restart();
    }

    function monitorFor(screen) {
        if (!screen)
            return null;

        return root.monitors.find(
            monitor => monitor.name === screen.name
        ) ?? null;
    }

    function activeWorkspaceForMonitor(monitorName) {
        return root.workspaces.find(
            ws =>
                ws.output === monitorName
                && ws.is_active
        ) ?? null;
    }

    function biggestWindowForWorkspace(wsId) {
        const windows =
            root.windowList.filter(
                window => window.workspaceId === wsId
            );

        if (windows.length === 0)
            return null;

        return windows.reduce(
            (a, b) =>
                ((a.width ?? 0) * (a.height ?? 0))
                >=
                ((b.width ?? 0) * (b.height ?? 0))
                    ? a
                    : b
        );
    }

    function fullscreenOnMonitor(monitorName) {
        return root.windowList.some(
            window =>
                window.output === monitorName
                && window.fullscreen
        );
    }

    function monitorGeometry(screen) {
        if (!screen)
            return {
                x: 0,
                y: 0,
                scale: 1
            };

        const monitor = root.monitorFor(screen);

        if (!monitor)
            return {
                x: screen.x ?? 0,
                y: screen.y ?? 0,
                scale: screen.devicePixelRatio ?? 1
            };

        return {
            x: monitor.logical.x,
            y: monitor.logical.y,
            scale: monitor.logical.scale
        };
    }

    Process {
        id: actionProc
    }

    Process {
        id: getWindows

        command: [
            "python3",
            Quickshell.env("HOME")
                + "/.config/quickshell/end4-pC/scripts/kwin/windows-json.py"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = text.trim();
                    const raw = payload.length > 0
                        ? JSON.parse(payload)
                        : [];

                    root.windowList = raw.map(
                        window => root.normalizeWindow(window)
                    );
                } catch (error) {
                    console.warn(
                        "[KWinBackend] windows parse error:",
                        error
                    );
                }
            }
        }
    }

    Process {
        id: getDesktops

        command: [
            "busctl",
            "--user",
            "--json=short",
            "get-property",
            "org.kde.KWin",
            "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager",
            "desktops"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload =
                        JSON.parse(text.trim());

                    const rows =
                        payload.data ?? [];

                    root.desktopDefs =
                        rows.map(row => ({
                            index: Number(row[0]),
                            idx: Number(row[0]) + 1,
                            uuid: String(row[1]),
                            name: String(row[2])
                        }));

                    root.rebuildWorkspaces();
                } catch (error) {
                    console.log(
                        "[KWinBackend] desktop parse error:",
                        error
                    );
                }
            }
        }
    }

    Process {
        id: getCurrent

        command: [
            "busctl",
            "--user",
            "--json=short",
            "get-property",
            "org.kde.KWin",
            "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager",
            "current"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload =
                        JSON.parse(text.trim());

                    root.currentDesktopUuid =
                        String(payload.data ?? "");

                    root.rebuildWorkspaces();
                } catch (error) {
                    console.log(
                        "[KWinBackend] current desktop parse error:",
                        error
                    );
                }
            }
        }
    }

    Process {
        id: getFocusedOutput

        command: [
            "qdbus6",
            "org.kde.KWin",
            "/KWin",
            "org.kde.KWin.activeOutputName"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.focusedOutputName =
                    text.trim();

                root.rebuildWorkspaces();
            }
        }
    }

    // Refresh immediately whenever KWin announces a virtual desktop change.
    Process {
        id: desktopMonitor

        running: true

        command: [
            "busctl",
            "--user",
            "--match=type='signal',path='/VirtualDesktopManager'",
            "monitor",
            "org.kde.KWin"
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                if (line.trim().length > 0)
                    refreshDebounce.restart();
            }
        }

        onExited: monitorRestart.restart()
    }

    Timer {
        id: refreshDebounce
        interval: 60
        repeat: false
        onTriggered: root.refresh()
    }

    // KWin does not expose a convenient all-window event stream. Polling keeps
    // the pC models current when windows are opened, closed, focused, or moved.
    Timer {
        id: windowRefreshTimer
        interval: 1200
        repeat: true
        running: true

        onTriggered: {
            root.refreshWindows();

            if (!root.focusedOutputProcess.running)
                root.focusedOutputProcess.running = true;
        }
    }

    Timer {
        id: windowRefreshDebounce
        interval: 120
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: monitorRestart
        interval: 1000
        repeat: false

        onTriggered: {
            if (!desktopMonitor.running)
                desktopMonitor.running = true;
        }
    }

    Component.onCompleted: {
        console.warn("[KWinBackend] initialized");
        root.refresh();
    }
}
