pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root

    required property var screen

    readonly property var monitor: WM.monitorFor(root.screen)
    readonly property var workspaceEntries: WM.workspaces.filter(
        workspace => workspace.output === (root.screen?.name ?? "")
    )
    readonly property real previewScale: Config.options.overview.scale
    readonly property real workspaceWidth: Math.max(
        220,
        (root.screen?.width ?? 1920) * root.previewScale
    )
    readonly property real workspaceHeight: Math.max(
        124,
        (root.screen?.height ?? 1080) * root.previewScale
    )
    readonly property int gridColumns: Math.max(
        1,
        Math.min(
            Number(Config.options.overview.columns),
            root.workspaceEntries.length
        )
    )
    readonly property real cardSpacing: 8
    readonly property real padding: 12

    property string draggingWindowId: ""
    property string draggingFromWorkspaceId: ""
    property string draggingTargetWorkspaceId: ""
    property real dragX: 0
    property real dragY: 0

    implicitWidth: overviewBackground.implicitWidth
    implicitHeight: overviewBackground.implicitHeight

    function windowsForWorkspace(workspaceId) {
        return WM.windowList.filter(
            window =>
                window.workspaceId === workspaceId
                && window.output === (root.screen?.name ?? "")
                && !window.minimized
        );
    }

    function comparableAppId(value) {
        return String(value ?? "")
            .toLowerCase()
            .replace(/\.desktop$/, "");
    }

    function toplevelForWindow(window) {
        if (!window)
            return null;

        const toplevels = ToplevelManager.toplevels.values;
        const titleMatch = toplevels.find(
            toplevel =>
                (toplevel.title ?? "") !== ""
                && toplevel.title === window.title
        );

        if (titleMatch)
            return titleMatch;

        const appId = root.comparableAppId(window.appId);
        const appMatches = toplevels.filter(
            toplevel => root.comparableAppId(toplevel.appId) === appId
        );

        return appMatches.length === 1 ? appMatches[0] : null;
    }

    function windowById(windowId) {
        return WM.windowList.find(
            window => window.id === windowId
        ) ?? null;
    }

    function finishWindowDrag() {
        const windowId = root.draggingWindowId;
        const fromWorkspaceId = root.draggingFromWorkspaceId;
        const targetWorkspaceId = root.draggingTargetWorkspaceId;

        root.draggingWindowId = "";
        root.draggingFromWorkspaceId = "";
        root.draggingTargetWorkspaceId = "";

        if (
            windowId !== ""
            && targetWorkspaceId !== ""
            && targetWorkspaceId !== fromWorkspaceId
        ) {
            WM.moveWindowToWorkspace(windowId, targetWorkspaceId);
        }
    }

    Rectangle {
        id: overviewBackground

        implicitWidth: workspaceGrid.implicitWidth + root.padding * 2
        implicitHeight: workspaceGrid.implicitHeight + root.padding * 2
        radius: Appearance.rounding.large + root.padding
        color: Appearance.colors.colBackgroundSurfaceContainer

        Grid {
            id: workspaceGrid

            anchors.centerIn: parent
            columns: root.gridColumns
            spacing: root.cardSpacing

            Repeater {
                model: root.workspaceEntries

                delegate: Rectangle {
                    id: workspaceCard

                    required property var modelData
                    readonly property var workspaceData: modelData
                    readonly property var windows: root.windowsForWorkspace(
                        workspaceCard.workspaceData.id
                    )

                    implicitWidth: root.workspaceWidth
                    implicitHeight: root.workspaceHeight
                    radius: Appearance.rounding.large
                    color: root.draggingTargetWorkspaceId === workspaceData.id
                        ? Appearance.colors.colLayer1Hover
                        : Appearance.colors.colSurfaceContainerLow
                    border.width: workspaceData.is_active
                        || root.draggingTargetWorkspaceId === workspaceData.id
                        ? 2
                        : 1
                    border.color: root.draggingTargetWorkspaceId === workspaceData.id
                        ? Appearance.colors.colSecondary
                        : workspaceData.is_active
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colOutlineVariant
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Config.options.background.wallpaperPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        opacity: 0.38
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: workspaceCard.workspaceData.idx
                        font.pixelSize: root.workspaceHeight * 0.34
                        font.weight: Font.DemiBold
                        color: ColorUtils.transparentize(
                            Appearance.colors.colOnLayer1,
                            workspaceCard.windows.length > 0 ? 0.92 : 0.58
                        )
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: workspaceCard.windows.length === 0

                        onClicked: {
                            WM.switchWorkspace(workspaceCard.workspaceData.id);
                            GlobalStates.overviewOpen = false;
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["kwin-window"]

                        onEntered: {
                            root.draggingTargetWorkspaceId = workspaceCard.workspaceData.id;
                        }

                        onExited: {
                            if (root.draggingTargetWorkspaceId === workspaceCard.workspaceData.id)
                                root.draggingTargetWorkspaceId = "";
                        }
                    }

                    Repeater {
                        model: workspaceCard.windows

                        delegate: Item {
                            id: windowPreview

                            required property var modelData
                            readonly property var windowData: modelData
                            readonly property var toplevelData: root.toplevelForWindow(
                                windowPreview.windowData
                            )
                            readonly property real localX: Math.max(
                                0,
                                windowData.x - (root.screen?.x ?? 0)
                            )
                            readonly property real localY: Math.max(
                                0,
                                windowData.y - (root.screen?.y ?? 0)
                            )

                            x: localX * root.previewScale
                            y: localY * root.previewScale
                            width: Math.max(
                                48,
                                Math.min(
                                    windowData.width * root.previewScale,
                                    root.workspaceWidth - x
                                )
                            )
                            height: Math.max(
                                34,
                                Math.min(
                                    windowData.height * root.previewScale,
                                    root.workspaceHeight - y
                                )
                            )
                            z: windowData.focused ? 2 : 1

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer1
                                border.width: windowPreview.windowData.focused ? 2 : 1
                                border.color: windowPreview.windowData.focused
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colOutlineVariant
                                clip: true

                                ScreencopyView {
                                    anchors.fill: parent
                                    visible: windowPreview.toplevelData !== null
                                    captureSource: GlobalStates.overviewOpen
                                        ? windowPreview.toplevelData
                                        : null
                                    live: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: previewMouseArea.containsMouse
                                        ? ColorUtils.transparentize(
                                            Appearance.colors.colLayer2Hover,
                                            0.72
                                        )
                                        : "transparent"
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    visible: windowPreview.toplevelData === null
                                    source: Quickshell.iconPath(
                                        AppSearch.guessIcon(windowPreview.windowData.class),
                                        "image-missing"
                                    )
                                    implicitSize: Math.min(
                                        48,
                                        Math.min(parent.width, parent.height) * 0.44
                                    )
                                }

                                StyledText {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                        margins: 5
                                    }
                                    text: windowPreview.windowData.title
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                    style: Text.Outline
                                    styleColor: Appearance.colors.colScrim
                                }
                            }

                            MouseArea {
                                id: previewMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                property bool dragStarted: false
                                property real pressRootX: 0
                                property real pressRootY: 0

                                onPressed: mouse => {
                                    dragStarted = false;

                                    if (mouse.button !== Qt.LeftButton)
                                        return;

                                    const point = mapToItem(root, mouse.x, mouse.y);
                                    pressRootX = point.x;
                                    pressRootY = point.y;
                                    root.dragX = point.x;
                                    root.dragY = point.y;
                                }

                                onPositionChanged: mouse => {
                                    if ((previewMouseArea.pressedButtons & Qt.LeftButton) === 0)
                                        return;

                                    const point = mapToItem(root, mouse.x, mouse.y);
                                    const deltaX = point.x - pressRootX;
                                    const deltaY = point.y - pressRootY;

                                    if (
                                        !dragStarted
                                        && Math.sqrt(deltaX * deltaX + deltaY * deltaY) >= 10
                                    ) {
                                        dragStarted = true;
                                        root.draggingWindowId = windowPreview.windowData.id;
                                        root.draggingFromWorkspaceId = windowPreview.windowData.workspaceId;
                                    }

                                    if (dragStarted) {
                                        root.dragX = point.x;
                                        root.dragY = point.y;
                                    }
                                }

                                onReleased: {
                                    if (dragStarted)
                                        root.finishWindowDrag();
                                }

                                onCanceled: {
                                    if (dragStarted)
                                        root.finishWindowDrag();
                                }

                                onClicked: event => {
                                    if (dragStarted)
                                        return;

                                    if (event.button === Qt.MiddleButton) {
                                        WM.closeWindow(windowPreview.windowData.id);
                                    } else {
                                        WM.focusWindow(windowPreview.windowData.id);
                                        GlobalStates.overviewOpen = false;
                                    }

                                    event.accepted = true;
                                }

                                StyledToolTip {
                                    extraVisibleCondition: false
                                    alternativeVisibleCondition: parent.containsMouse
                                    text: `${windowPreview.windowData.title}\n[${windowPreview.windowData.class}]`
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: dragGhost

        readonly property var windowData: root.windowById(root.draggingWindowId)

        visible: root.draggingWindowId !== ""
        x: root.dragX - width / 2
        y: root.dragY - height / 2
        width: Math.min(220, root.workspaceWidth * 0.7)
        height: 64
        z: 1000
        radius: Appearance.rounding.normal
        color: Appearance.colors.colSurfaceContainerHigh
        border.width: 2
        border.color: Appearance.colors.colSecondary
        opacity: 0.92

        Drag.active: visible
        Drag.source: dragGhost
        Drag.keys: ["kwin-window"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        RowLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 8

            IconImage {
                source: Quickshell.iconPath(
                    AppSearch.guessIcon(dragGhost.windowData?.class),
                    "image-missing"
                )
                implicitSize: 36
            }

            StyledText {
                Layout.fillWidth: true
                text: dragGhost.windowData?.title ?? ""
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer1
            }
        }
    }
}
