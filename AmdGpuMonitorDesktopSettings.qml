import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "amdGpuMonitorDesktop"

    StyledText {
        width: parent.width
        text: "AMD GPU Monitor — Desktop Widget"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Freely positionable desktop widget. Right-click + drag to move; drag the bottom-right corner to resize."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StringSetting {
        settingKey: "gpuIndex"
        label: "GPU Index"
        description: "Zero-based index of the AMD GPU to monitor (0 = first GPU)"
        placeholder: "0"
        defaultValue: "0"
    }

    SelectionSetting {
        settingKey: "displayStyle"
        label: "Display Style"
        description: "Visual style for the widget body"
        options: [
            { label: "Default (circular gauges)", value: "default" },
            { label: "Alternative (stat cards)",  value: "alt" },
            { label: "Legacy (progress bars)",    value: "legacy" }
        ]
        defaultValue: "default"
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: "Background Opacity"
        description: "Transparency of the widget background"
        defaultValue: 70
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "showProcessList"
        label: "Show Process List"
        description: "Show active GPU processes below the main stats (hidden when widget width < 300 px)"
        defaultValue: true
    }

    StringSetting {
        settingKey: "processListHeight"
        label: "Process List Max Height (px)"
        description: "Maximum height of the scrollable process list"
        placeholder: "200"
        defaultValue: "200"
    }
}
