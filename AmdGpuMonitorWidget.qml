import QtQuick
import Quickshell
import Quickshell.Io

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

import "components" as Components

PluginComponent {
    id: root

    property string variantId: ""
    property var variantData: null

    property bool minimumWidth: variantData?.minimumWidth ?? pluginData.minimumWidth ?? true
    property int gpuIndex: Math.max(0, parseInt(variantData?.gpuIndex ?? "0") || 0)
    property string popoutStyle: variantData?.popoutStyle ?? pluginData.popoutStyle ?? "default"
    property int processListHeight: Math.max(100, Math.min(750, parseInt(variantData?.processListHeight ?? pluginData.processListHeight ?? "250") || 250))

    readonly property string popoutStyleSource: {
        switch (popoutStyle) {
            case "alt":
                return "components/styles/AltStyle.qml";
            case "legacy":
                return "components/styles/LegacyStyle.qml";
            default:
                return "components/styles/DefaultStyle.qml";
        }
    }

    // Shared data model — all GPU polling lives here
    Components.GpuDataModel {
        id: gpuData
        gpuIndex: root.gpuIndex
    }

    // Expose model properties at root level so existing style components
    // continue to work unchanged (they reference `root.*`).
    readonly property real gpuUsage: gpuData.gpuUsage
    readonly property real vramUsed: gpuData.vramUsed
    readonly property real vramTotal: gpuData.vramTotal
    readonly property real vramPercent: gpuData.vramPercent
    readonly property int temperature: gpuData.temperature
    readonly property int powerUsage: gpuData.powerUsage
    readonly property string gpuName: gpuData.gpuName
    readonly property var processes: gpuData.processes
    readonly property real gfxUsage: gpuData.gfxUsage
    readonly property real memUsage: gpuData.memUsage
    readonly property real mediaUsage: gpuData.mediaUsage

    function formatVram() { return gpuData.formatVram(); }
    function getUsageColor(percent) { return gpuData.getUsageColor(percent); }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "shadow"
                size: root.iconSize
                color: Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: root.minimumWidth ? Math.max(textBaseline.width, currentTextMetrics.width) : currentTextMetrics.width
                implicitHeight: currentTextMetrics.height
                width: implicitWidth
                height: implicitHeight

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                StyledTextMetrics {
                    id: textBaseline
                    font.pixelSize: Theme.fontSizeSmall
                    text: "88% | 8.8GiB"
                }

                StyledTextMetrics {
                    id: currentTextMetrics
                    font.pixelSize: Theme.fontSizeSmall
                    text: `${root.gpuUsage.toFixed(0)}% | ${(root.vramUsed / 1024).toFixed(1)}GiB`
                }

                StyledText {
                    id: gpuText
                    text: currentTextMetrics.text
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor
                    anchors.fill: parent
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideNone
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 1

            DankIcon {
                name: "shadow"
                size: root.iconSize
                color: Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: `${root.gpuUsage.toFixed(0)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: root.gpuName
            showCloseButton: true

            Loader {
                id: popoutLoader
                width: parent.width
                function loadStyle() {
                    setSource(root.popoutStyleSource, { "root": root });
                }

                Component.onCompleted: loadStyle()
                Connections {
                    target: root
                    function onPopoutStyleSourceChanged() {
                        popoutLoader.loadStyle();
                    }
                }
            }
        }
    }
}
