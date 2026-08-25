import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Item {
    id: root
    required property PwNode node

    readonly property var appWindow: {
        const processId = Number(root.node?.properties["application.process.id"] ?? 0);
        if (!Number.isFinite(processId) || processId <= 0)
            return null;

        return WM.windowList.find(window => Number(window.pid) === processId) ?? null;
    }

    readonly property string appIconName: {
        const properties = root.node?.properties ?? ({});
        const candidates = [
            properties["application.icon-name"],
            properties["application.icon_name"],
            properties["pipewire.access.portal.app_id"],
            root.appWindow?.desktopFile,
            root.appWindow?.appId,
            root.appWindow?.class,
            properties["application.process.binary"],
            properties["application.name"],
            properties["node.name"]
        ];

        for (const candidate of candidates) {
            if (!candidate)
                continue;

            const icon = AppSearch.guessIcon(String(candidate));
            if (icon !== "image-missing"
                    && icon !== "application-x-executable"
                    && AppSearch.iconExists(icon))
                return icon;
        }

        return "application-x-executable";
    }

    PwObjectTracker {
        objects: [root.node]
    }

    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 6

        MouseArea {
            property real size: 36
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: size
            Layout.preferredHeight: size

            cursorShape: Qt.PointingHandCursor
            onClicked: root.node.audio.muted = !root.node.audio.muted

            hoverEnabled: true
            property bool hovered: containsMouse
            StyledToolTip {
                text: root.node?.audio.muted ? Translation.tr("Click to unmute") : Translation.tr("Click to mute")
            }

            IconImage {
                id: iconImg
                anchors.fill: parent
                asynchronous: true
                source: Quickshell.iconPath(root.appIconName, "application-x-executable")
                opacity: root.node?.audio.muted ? 0.4 : 1.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.node?.audio.muted ?? false
                text: root.node?.isSink ? "volume_off" : "mic_off"
                iconSize: 22
                color: Appearance.colors.colOnLayer1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -4

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                text: {
                    // application.name -> description -> name
                    const app = Audio.appNodeDisplayName(root.node);
                    const media = root.node.properties["media.name"];
                    return media != undefined ? `${app} • ${media}` : app;
                }
            }

            StyledSlider {
                id: slider
                value: root.node?.audio.volume ?? 0
                onMoved: root.node.audio.volume = value
                configuration: StyledSlider.Configuration.S
            }
        }
    }
}
