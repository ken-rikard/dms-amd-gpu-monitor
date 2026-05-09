import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

import "components" as Components
import "components/shared" as Shared
import "components/styles" as Styles

DesktopPluginComponent {
    id: root

    minWidth: 260
    minHeight: 180
    property real defaultWidth: 360
    property real defaultHeight: 430

    // --- settings (from pluginData) ---
    property int gpuIndex: pluginData.gpuIndex ?? 0
    property string displayStyle: pluginData.displayStyle ?? "default"
    property real bgOpacity: (pluginData.backgroundOpacity ?? 70) / 100
    property bool showProcessList: pluginData.showProcessList ?? true
    property int processListHeight: Math.max(80, Math.min(500,
        parseInt(pluginData.processListHeight ?? "200") || 200))

    readonly property string styleSource: {
        switch (displayStyle) {
            case "alt":    return "components/styles/AltStyle.qml";
            case "legacy": return "components/styles/LegacyStyle.qml";
            default:       return "components/styles/DefaultStyle.qml";
        }
    }

    // --- data model ---
    Components.GpuDataModel {
        id: gpuData
        gpuIndex: root.gpuIndex
    }

    // Expose at root scope so Loader-passed style components work
    // identically to how the bar widget's popout uses them.
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

    // --- UI ---
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, root.bgOpacity)
        clip: true

        // ── header bar ───────────────────────────────────────────────
        Rectangle {
            id: header
            width: parent.width
            height: headerRow.implicitHeight + Theme.spacingS * 2
            color: Theme.withAlpha(Theme.surfaceContainerHigh, root.bgOpacity)
            radius: Theme.cornerRadius

            // Square off the bottom corners
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Theme.cornerRadius
                color: parent.color
            }

            Row {
                id: headerRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.spacingM
                    rightMargin: Theme.spacingM
                }
                spacing: Theme.spacingS

                DankIcon {
                    name: "shadow"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.gpuName
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                    // leave room for the live pill on the right
                    width: parent.width
                          - Theme.iconSize - Theme.spacingS
                          - livePill.width - Theme.spacingS
                }

                // Live usage summary pill
                Rectangle {
                    id: livePill
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.fontSizeSmall + Theme.spacingXS * 2
                    width: livePillText.implicitWidth + Theme.spacingM * 2
                    radius: height / 2
                    color: Theme.withAlpha(Theme.primary, 0.15)

                    StyledText {
                        id: livePillText
                        anchors.centerIn: parent
                        text: `${root.gpuUsage.toFixed(0)}% · ${(root.vramUsed / 1024).toFixed(1)} GiB`
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                    }
                }
            }
        }

        // ── scrollable body ───────────────────────────────────────────
        Flickable {
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: Theme.spacingS
                margins: Theme.spacingS
            }
            contentWidth: width
            contentHeight: bodyColumn.implicitHeight
            clip: true
            // Only show scrollbar when content overflows
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: bodyColumn
                width: parent.width
                spacing: Theme.spacingS

                // ── style panel (gauges / stat cards / legacy bars) ──
                Loader {
                    id: styleLoader
                    width: parent.width
                    function loadStyle() {
                        setSource(root.styleSource, { "root": root });
                    }
                    Component.onCompleted: loadStyle()
                    Connections {
                        target: root
                        function onStyleSourceChanged() { styleLoader.loadStyle(); }
                    }
                }

                // ── process list (collapsible below 300 px width) ────
                Column {
                    visible: root.showProcessList
                             && root.widgetWidth >= 300
                             && root.processes.length > 0
                    width: parent.width
                    spacing: Theme.spacingXS

                    Row {
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "apps"
                            size: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: `GPU Processes (${root.processes.length})`
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankListView {
                        width: parent.width
                        height: Math.min(contentHeight, root.processListHeight)
                        model: root.processes
                        spacing: 2
                        clip: true

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 40
                            radius: Theme.cornerRadius
                            color: procMouse.containsMouse
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                   : "transparent"
                            border.color: procMouse.containsMouse
                                          ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                          : "transparent"
                            border.width: 1

                            MouseArea {
                                id: procMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: Theme.spacingS
                                    rightMargin: Theme.spacingS
                                }
                                spacing: Theme.spacingS

                                // Process name + PID
                                Item {
                                    width: parent.width
                                           - vramChip.width
                                           - gfxChip.width
                                           - Theme.spacingS * 2
                                    height: parent.height

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.parent.width
                                        }
                                        StyledText {
                                            text: `PID ${modelData.pid}`
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                // VRAM chip
                                Rectangle {
                                    id: vramChip
                                    width: vramChipText.implicitWidth + Theme.spacingS * 2
                                    height: 22
                                    radius: height / 2
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        id: vramChipText
                                        anchors.centerIn: parent
                                        text: `${modelData.vram} ${modelData.vramUnit}`
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }
                                }

                                // GFX chip
                                Rectangle {
                                    id: gfxChip
                                    width: gfxChipText.implicitWidth + Theme.spacingS * 2
                                    height: 22
                                    radius: height / 2
                                    color: modelData.gfx > 50
                                           ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.15)
                                           : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        id: gfxChipText
                                        anchors.centerIn: parent
                                        text: modelData.gfx > 0 ? `${modelData.gfx}%` : "-"
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.weight: Font.Bold
                                        color: modelData.gfx > 50 ? Theme.warning : Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
