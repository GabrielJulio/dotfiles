pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property QsMenuHandle trayItemMenuHandle
    required property var anchorWindow
    required property var anchorCoordinateSpace
    required property Item anchorItem
    property string trayItemId: ""
    property real popupBackgroundMargin: 0
    property int openProbeCount: 0
    property int lastProbedMenuHeight: -1

    signal menuClosed
    signal menuOpened(qsWindow: var) // Correct type is QsWindow, but QML does not like that

    visible: false
    color: "transparent"
    screen: root.anchorWindow?.screen
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!root.barVertical)
            return Config.options.bar.bottom ? "bottom" : "top";
        return Config.options.bar.bottom ? "right" : "left";
    }
    readonly property real barThickness: root.barVertical
        ? Appearance.sizes.verticalBarWidth
        : Appearance.sizes.barHeight

    anchors.left: root.barEdge !== "right"
    anchors.right: root.barEdge === "right"
    anchors.top: root.barEdge !== "bottom"
    anchors.bottom: root.barEdge === "bottom"

    readonly property real anchorOffsetX: {
        const base = root.anchorCoordinateSpace?.mapFromItem(
            root.anchorItem,
            (root.anchorItem.width - root.implicitWidth) / 2,
            0
        ).x ?? 0;
        const edgeMargin = Appearance.sizes.elevationMargin;
        const maxLeft = root.screen.width - root.implicitWidth - edgeMargin;
        return Math.max(edgeMargin, Math.min(base, maxLeft));
    }
    readonly property real anchorOffsetY: {
        const base = root.anchorCoordinateSpace?.mapFromItem(
            root.anchorItem,
            0,
            (root.anchorItem.height - root.implicitHeight) / 2
        ).y ?? 0;
        const edgeMargin = Appearance.sizes.elevationMargin;
        const maxTop = root.screen.height - root.implicitHeight - edgeMargin;
        return Math.max(edgeMargin, Math.min(base, maxTop));
    }

    margins.left: {
        if (root.barEdge === "right")
            return 0;
        if (root.barEdge === "left")
            return root.barThickness;
        return root.anchorOffsetX;
    }
    margins.top: {
        if (root.barEdge === "bottom")
            return 0;
        if (root.barEdge === "top")
            return root.barThickness;
        return root.anchorOffsetY;
    }
    margins.right: root.barEdge === "right" ? root.barThickness : 0
    margins.bottom: root.barEdge === "bottom" ? root.barThickness : 0

    mask: Region {
        item: popupBackground
    }

    WlrLayershell.namespace: "quickshell:tray-menu"
    WlrLayershell.layer: WlrLayer.Overlay

    property real padding: Appearance.sizes.elevationMargin
    readonly property real menuImplicitWidth: stackView.currentItem?.implicitWidth ?? 0
    readonly property real menuImplicitHeight: stackView.currentItem?.implicitHeight ?? 0

    // StackView.children includes internal items whose implicit size can track
    // the popup window itself. On KWin that creates a circular size binding and
    // stretches a one-row menu vertically. Size from the active submenu only.
    implicitHeight: Math.max(
        1,
        root.menuImplicitHeight
            + popupBackground.padding * 2
            + root.padding * 2
    )
    implicitWidth: Math.max(
        1,
        root.menuImplicitWidth
            + popupBackground.padding * 2
            + root.padding * 2
    )

    function open() {
        if (root.visible)
            return;

        root.openProbeCount = 0;
        root.lastProbedMenuHeight = -1;
        openTimer.restart();
    }

    function close() {
        openTimer.stop();
        root.visible = false;
        while (stackView.depth > 1)
            stackView.pop();
        root.menuClosed();
    }

    // QsMenuOpener receives native entries asynchronously. Wait for two equal
    // size samples so the panel is mapped at its final size. The bounded
    // fallback keeps genuinely empty menus fast.
    Timer {
        id: openTimer
        interval: 25
        repeat: false

        onTriggered: {
            const height = Math.round(root.menuImplicitHeight);
            const stable = height > 0 && height === root.lastProbedMenuHeight;

            root.openProbeCount += 1;

            if (stable || root.openProbeCount >= 8) {
                root.visible = true;
                root.menuOpened(root);
                return;
            }

            root.lastProbedMenuHeight = height;
            openTimer.restart();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.RightButton
        onPressed: event => {
            if ((event.button === Qt.BackButton || event.button === Qt.RightButton) && stackView.depth > 1)
                stackView.pop();
        }

        StyledRectangularShadow {
            target: popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            readonly property real padding: 4
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: Config.options.bar.vertical ? parent.verticalCenter : undefined
                top: Config.options.bar.vertical ? undefined : Config.options.bar.bottom ? undefined : parent.top
                bottom: Config.options.bar.vertical ? undefined : Config.options.bar.bottom ? parent.bottom : undefined
                margins: root.padding
            }

            color: Appearance.colors.colLayer0
            radius: Appearance.rounding.windowRounding
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: root.menuImplicitWidth + popupBackground.padding * 2
            implicitHeight: root.menuImplicitHeight + popupBackground.padding * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

            StackView {
                id: stackView
                anchors {
                    fill: parent
                    margins: popupBackground.padding
                }
                pushEnter: NoAnim {}
                pushExit: NoAnim {}
                popEnter: NoAnim {}
                popExit: NoAnim {}

                implicitWidth: root.menuImplicitWidth
                implicitHeight: root.menuImplicitHeight

                initialItem: SubMenu {
                    handle: root.trayItemMenuHandle
                }
            }
        }
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: ColumnLayout {
        id: submenu
        required property QsMenuHandle handle
        property bool isSubMenu: false
        property bool shown: false
        opacity: shown ? 1 : 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        QsMenuOpener {
            id: menuOpener
            menu: submenu.handle
        }

        spacing: 0

        Loader {
            Layout.fillWidth: true
            visible: submenu.isSubMenu
            active: visible
            sourceComponent: RippleButton {
                id: backButton
                buttonRadius: popupBackground.radius - popupBackground.padding
                horizontalPadding: 12
                implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                implicitHeight: 36

                downAction: () => stackView.pop()

                contentItem: RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        leftMargin: backButton.horizontalPadding
                        rightMargin: backButton.horizontalPadding
                    }
                    spacing: 8
                    MaterialSymbol {
                        iconSize: 20
                        text: "chevron_left"
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Back")
                    }
                }
            }
        }
        RippleButton {
            id: pinEntry
            buttonRadius: popupBackground.radius - popupBackground.padding
            horizontalPadding: 12
            implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
            implicitHeight: 36
            Layout.preferredHeight: 36
            Layout.minimumHeight: 36
            Layout.maximumHeight: 36
            Layout.topMargin: 0
            Layout.bottomMargin: 0
            Layout.fillWidth: true

            visible: root.trayItemId !== undefined && root.trayItemId.length > 0 && stackView.depth === 1
            releaseAction: () => TrayService.togglePin(root.trayItemId);

            contentItem: RowLayout {
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: pinEntry.horizontalPadding
                    rightMargin: pinEntry.horizontalPadding
                }
                spacing: 8

                MaterialSymbol {
                    iconSize: 18
                    text: "push_pin"
                }

                StyledText {
                    Layout.fillWidth: true
                    text: TrayService.isPinned(root.trayItemId) ? Translation.tr("Unpin") : Translation.tr("Pin")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colSubtext
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        Repeater {
            id: menuEntriesRepeater
            property bool iconColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].icon.length > 0)
                        return true;
                }
                return false;
            }
            property bool specialInteractionColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].buttonType !== QsMenuButtonType.None)
                        return true;
                }
                return false;
            }
            model: ScriptModel {
                values: menuOpener.children.values
            }
            delegate: SysTrayMenuEntry {
                required property QsMenuEntry modelData
                forceIconColumn: menuEntriesRepeater.iconColumnNeeded
                forceSpecialInteractionColumn: menuEntriesRepeater.specialInteractionColumnNeeded
                menuEntry: modelData

                buttonRadius: popupBackground.radius - popupBackground.padding

                onDismiss: root.close()
                onOpenSubmenu: handle => {
                    stackView.push(subMenuComponent.createObject(null, {
                        handle: handle,
                        isSubMenu: true
                    }));
                }
            }
        }
    }

    Component {
        id: subMenuComponent
        SubMenu {}
    }
}
