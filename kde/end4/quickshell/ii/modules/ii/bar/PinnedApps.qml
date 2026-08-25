import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    Layout.fillHeight: true
    implicitWidth: appsRow.implicitWidth

    RowLayout {
        id: appsRow
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: ScriptModel {
                values: TaskbarApps.apps.filter(app => app.pinned)
            }

            delegate: RippleButton {
                id: button

                required property var modelData

                property var desktopEntry: DesktopEntries.heuristicLookup(modelData.appId)
                property int lastFocused: -1

                Layout.fillHeight: true
                implicitWidth: 38
                buttonRadius: Appearance.rounding.normal

                onClicked: {
                    if (modelData.toplevels.length === 0) {
                        desktopEntry?.execute();
                        return;
                    }

                    lastFocused = (lastFocused + 1) % modelData.toplevels.length;
                    modelData.toplevels[lastFocused].activate();
                }

                middleClickAction: () => {
                    desktopEntry?.execute();
                }

                altAction: () => {
                    TaskbarApps.togglePin(modelData.appId);
                }

                contentItem: IconImage {
                    anchors.centerIn: parent
                    source: Quickshell.iconPath(
                        AppSearch.guessIcon(button.modelData.appId),
                        "image-missing"
                    )
                    implicitSize: 26
                }
            }
        }
    }
}
