import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Scope {
    id: root

    required property string name
    property string description: name
    required property int key

    signal pressed()

    readonly property bool enabled: WM.compositor === "kwin"
    readonly property string actionIdArgument: "['end4_pc', '"
        + root.name + "', 'end4-pC', '" + root.description + "']"
    readonly property string keyArgument: "[" + root.key + "]"

    function initialize() {
        if (root.enabled && !registerProcess.running)
            registerProcess.running = true;
    }

    Component.onCompleted: root.initialize()
    onEnabledChanged: root.initialize()

    Process {
        id: registerProcess
        command: [
            "/usr/bin/gdbus",
            "call",
            "--session",
            "--dest", "org.kde.kglobalaccel",
            "--object-path", "/kglobalaccel",
            "--method", "org.kde.KGlobalAccel.doRegister",
            root.actionIdArgument
        ]

        stderr: SplitParser {
            onRead: line => console.warn("[KWinGlobalShortcut] register:", line)
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.enabled)
                return;

            if (exitCode === 0)
                assignProcess.running = true;
            else
                retryTimer.restart();
        }
    }

    Process {
        id: assignProcess
        command: [
            "/usr/bin/gdbus",
            "call",
            "--session",
            "--dest", "org.kde.kglobalaccel",
            "--object-path", "/kglobalaccel",
            "--method", "org.kde.KGlobalAccel.setShortcut",
            root.actionIdArgument,
            root.keyArgument,
            "2"
        ]

        stdout: StdioCollector {
            id: assignmentOutput
        }

        stderr: SplitParser {
            onRead: line => console.warn("[KWinGlobalShortcut] assign:", line)
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.enabled)
                return;

            if (exitCode === 0 && assignmentOutput.text.includes(String(root.key)))
                monitorProcess.running = true;
            else
                retryTimer.restart();
        }
    }

    Process {
        id: monitorProcess
        command: [
            "/usr/bin/gdbus",
            "monitor",
            "--session",
            "--dest", "org.kde.kglobalaccel",
            "--object-path", "/component/end4_pc"
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                if (line.includes("globalShortcutPressed")
                        && line.includes("'" + root.name + "'"))
                    root.pressed();
            }
        }

        stderr: SplitParser {
            onRead: line => console.warn("[KWinGlobalShortcut] monitor:", line)
        }

        onExited: {
            if (root.enabled)
                retryTimer.restart();
        }
    }

    Timer {
        id: retryTimer
        interval: 1000
        repeat: false
        onTriggered: root.initialize()
    }
}
