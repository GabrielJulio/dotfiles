import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import org.kde.kwin as KWin
import org.kde.kwin.private.effects
import org.kde.milou as Milou

KWin.SceneEffect {
    id: effect
    visible: false
    property bool contentShown: false
    property bool heapOrganized: false

    function openAnimated() {
        closeTimer.stop()
        heapOrganized = false
        contentShown = false
        visible = true
        Qt.callLater(function() {
            contentShown = true
            heapOrganized = true
        })
    }

    function closeAnimated() {
        if (!visible)
            return
        heapOrganized = false
        contentShown = false
        closeTimer.restart()
    }

    function toggleAnimated() {
        if (visible)
            closeAnimated()
        else
            openAnimated()
    }

    Timer {
        id: closeTimer
        interval: 260
        repeat: false
        onTriggered: effect.visible = false
    }
    readonly property string debugVersion: "windowheap-v2"

    KWin.WindowModel {
        id: windows
    }

    KWin.VirtualDesktopModel {
        id: desktopModel
    }   

    delegate: FocusScope {
        id: root
        focus: true


        property QtObject targetScreen: KWin.SceneView.screen

        End4Colors {
            id: colors
        }

	Item {
            anchors.fill: parent

            KWin.DesktopBackground {
                id: desktopBackground

                anchors.fill: parent
                activity: KWin.Workspace.currentActivity
                desktop: KWin.Workspace.currentDesktop
                outputName: root.targetScreen.name

                visible: false
            }

            FastBlur {
                anchors.fill: parent
                source: desktopBackground

                radius: 48
            }
        }

        Rectangle {
            anchors.fill: parent

            color: colors.background
            opacity: effect.contentShown ? 0.42 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }

        KWin.WindowFilterModel {
            id: filteredWindows
            windowModel: windows
            activity: KWin.Workspace.currentActivity
            desktop: KWin.Workspace.currentDesktop
            screenName: root.targetScreen.name
            filter: searchInput.text
            minimizedWindows: true

            windowType: ~KWin.WindowFilterModel.Dock
                      & ~KWin.WindowFilterModel.Desktop
                      & ~KWin.WindowFilterModel.Notification
                      & ~KWin.WindowFilterModel.CriticalNotification
        }

        Rectangle {
            id: searchBox

            opacity: effect.contentShown ? 1 : 0
            scale: effect.contentShown ? 1 : 0.96

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }


            width: Math.min(560, parent.width * 0.42)
            height: 56

            anchors.top: parent.top
            anchors.topMargin: 44
            anchors.horizontalCenter: parent.horizontalCenter

            radius: 20
            color: colors.surfaceHigh
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? colors.primary : colors.outline

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter

                visible: searchInput.text.length === 0

                text: "Search apps"
                color: colors.textMuted

                font.family: "Google Sans Flex"
                font.pixelSize: 17
            }

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22

                verticalAlignment: TextInput.AlignVCenter
                focus: true

                color: colors.text
                selectionColor: colors.primary

                font.family: "Google Sans Flex"
		font.pixelSize: 17
	        Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        appResults.runCurrentIndex(event)
                        event.accepted = true
                    } else if (searchInput.text.length > 0) {
                        appResults.navigationKeyHandler(event)
                    }
                }
            }
        }

        Milou.ResultsView {
            id: appResults

            opacity: effect.contentShown ? 1 : 0
            scale: effect.contentShown ? 1 : 0.96

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }


            anchors.top: searchBox.bottom
            anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: workspaceBar.top
            anchors.bottomMargin: 20

            width: Math.min(720, parent.width * 0.58)

            visible: searchInput.text.length > 0
            enabled: visible
            clip: true

            queryString: searchInput.text
            queryField: searchInput
            singleRunner: "services"
            limit: 10

            onActivated: {
                searchInput.text = ""
                effect.closeAnimated()
            }
        }

	WindowHeap {
            id: heap

            opacity: effect.contentShown ? 1 : 0
            scale: effect.contentShown ? 1 : 0.97

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            visible: searchInput.text.length === 0

            anchors.top: searchBox.bottom
            anchors.topMargin: 32
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.right: parent.right
            anchors.rightMargin: 64
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 110

            organized: effect.heapOrganized
            animationDuration: 220
            animationEnabled: true
            padding: 24

            model: KWin.WindowFilterModel {
                activity: KWin.Workspace.currentActivity
                desktop: KWin.Workspace.currentDesktop
                screenName: root.targetScreen.name
                windowModel: windows
                filter: ""
                minimizedWindows: true

                windowType: ~KWin.WindowFilterModel.Dock
                          & ~KWin.WindowFilterModel.Desktop
                          & ~KWin.WindowFilterModel.Notification
                          & ~KWin.WindowFilterModel.CriticalNotification
            }
	    delegate: WindowHeapDelegate {
                windowHeap: heap
                layout: heap.layout

                readonly property string end4Class:
                    String(window.resourceClass || "").toLowerCase()

                readonly property string end4Name:
                    String(window.resourceName || "").toLowerCase()

                readonly property bool end4Ignored:
                    end4Class === "quickshell"
                    || end4Name === "quickshell"
                    || end4Class === "xwaylandvideobridge"
                    || end4Name === "xwaylandvideobridge"

                shouldLayout: !activeHidden && !end4Ignored
                visible: !end4Ignored
            }   

            onActivated: effect.closeAnimated()
        }

        Rectangle {
            id: workspaceBar

            opacity: effect.contentShown ? 1 : 0
            scale: effect.contentShown ? 1 : 0.96

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }


            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28

            width: workspaceRow.width + 28
            height: 42
            radius: 21

            color: colors.surfaceHigh
            border.width: 1
            border.color: colors.outline

            Row {
                id: workspaceRow

                anchors.centerIn: parent
                spacing: 10

                Repeater {
                    model: desktopModel

                    delegate: Rectangle {
                        required property QtObject desktop
                        required property int index

                        readonly property bool current:
                            KWin.SceneView.currentDesktop === desktop

                        width: current ? 28 : 10
                        height: 10
                        radius: 5

                        color: current ? colors.primary : colors.textMuted
                        opacity: current ? 1.0 : 0.55

                        Behavior on width {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }

                        TapHandler {
                            onTapped: KWin.SceneView.currentDesktop = desktop
                        }
                    }
                }
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                searchInput.text = "";
                effect.closeAnimated();
                event.accepted = true;
            }
        }
    }

    KWin.ShortcutHandler {
        name: "Toggle end-4 Overview"
        text: "Toggle end-4 Overview"
        sequence: "Meta+Shift+O"

        onActivated: {
            effect.toggleAnimated();
        }
    }
}
