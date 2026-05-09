import QtQuick
import Quickshell
import Quickshell.Io

// Shared data model for AMD GPU monitoring.
// Used by both the bar widget (AmdGpuMonitorWidget.qml) and the
// desktop widget (AmdGpuMonitorDesktopWidget.qml).
QtObject {
    id: root

    // --- inputs ---
    property int gpuIndex: 0
    property int updateInterval: 4000

    // --- outputs (read-only by consumers) ---
    property real gpuUsage: 0.0
    property real vramUsed: 0.0
    property real vramTotal: 0.0
    property real vramPercent: 0.0
    property int temperature: 0
    property int powerUsage: 0
    property string gpuName: "AMD GPU"
    property var processes: []

    property real gfxUsage: 0.0
    property real memUsage: 0.0
    property real mediaUsage: 0.0

    property string temperatureSysfsPath: ""

    // --- internal ---
    property var _timer: Timer {
        interval: root.updateInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: _statsProcess.running = true
    }

    property var _fallbackTempProcess: Process {
        id: _fallbackTempProcess
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const rawValue = text.trim();
                const milliCelsius = parseInt(rawValue);
                if (!isNaN(milliCelsius) && milliCelsius > 0) {
                    root.temperature = Math.round(milliCelsius / 1000);
                }
            }
        }
    }

    property var _statsProcess: Process {
        id: _statsProcess
        command: ["amdgpu_top", "-J", "-n", "1"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                const data = JSON.parse(output);
                const devices = Array.isArray(data.devices) ? data.devices : [];
                const selectedGpu = devices[root.gpuIndex] || devices[0];

                if (!selectedGpu) {
                    root.gpuName = "AMD GPU";
                    root.gfxUsage = 0.0;
                    root.memUsage = 0.0;
                    root.mediaUsage = 0.0;
                    root.gpuUsage = 0.0;
                    root.vramUsed = 0.0;
                    root.vramTotal = 0.0;
                    root.vramPercent = 0.0;
                    root.temperature = 0;
                    root.powerUsage = 0;
                    root.temperatureSysfsPath = "";
                    root.processes = [];
                    return;
                }

                root.gpuName = selectedGpu["Info"]?.["DeviceName"] || `AMD GPU ${root.gpuIndex}`;

                root.gfxUsage = parseFloat(selectedGpu.gpu_activity?.["GFX"]?.value) || 0.0;
                root.memUsage = parseFloat(selectedGpu.gpu_activity?.["Memory"]?.value) || 0.0;
                root.mediaUsage = parseFloat(selectedGpu.gpu_activity?.["MediaEngine"]?.value) || 0.0;
                root.gpuUsage = Math.max(root.gfxUsage, root.memUsage, root.mediaUsage);

                root.vramUsed = parseFloat(selectedGpu["VRAM"]?.["Total VRAM Usage"]?.value) || 0.0;
                root.vramTotal = parseFloat(selectedGpu["VRAM"]?.["Total VRAM"]?.value) || 0.0;
                root.vramPercent = root.vramTotal > 0
                    ? (root.vramUsed / root.vramTotal * 100) : 0.0;

                const extractedTemperature = root.extractTemperature(selectedGpu);
                if (extractedTemperature > 0) {
                    root.temperature = extractedTemperature;
                    root.temperatureSysfsPath = "";
                } else if (!root.refreshTemperatureFromSysfs(selectedGpu)) {
                    root.temperature = 0;
                }

                root.powerUsage = parseInt(selectedGpu.Sensors?.["Average Power"]?.value) || 0;

                if (selectedGpu.fdinfo) {
                    const processList = [];

                    Object.keys(selectedGpu.fdinfo).forEach(pid => {
                        const procInfo = selectedGpu.fdinfo[pid];
                        const usage = procInfo.usage?.usage;
                        if (!usage) return;

                        const vram = usage.VRAM?.value || 0;
                        const gfx = usage.GFX?.value || 0;
                        const cpu = usage.CPU?.value || 0;

                        if (vram > 0 || gfx > 0) {
                            processList.push({
                                name: procInfo.name || "Unknown",
                                pid: parseInt(pid),
                                vram: vram,
                                vramUnit: usage.VRAM?.unit || "MiB",
                                gfx: gfx,
                                cpu: cpu,
                                gtt: usage.GTT?.value || 0,
                                compute: usage.Compute?.value || 0
                            });
                        }
                    });

                    processList.sort((a, b) => b.vram - a.vram);
                    root.processes = processList;
                } else {
                    root.processes = [];
                }
            }
        }
    }

    // --- helper functions ---

    function formatVram() {
        if (root.vramTotal < 1024) {
            return `${root.vramUsed.toFixed(0)}/${root.vramTotal.toFixed(0)} MiB`;
        }
        const usedGiB = (root.vramUsed / 1024).toFixed(1);
        const totalGiB = (root.vramTotal / 1024).toFixed(1);
        return `${usedGiB}/${totalGiB} GiB`;
    }

    function extractTemperature(selectedGpu) {
        const edgeTemp = parseInt(selectedGpu?.gpu_metrics?.temperature_edge);
        if (!isNaN(edgeTemp) && edgeTemp > 0)
            return edgeTemp;

        const sensorsEdgeTemp = parseInt(selectedGpu?.Sensors?.["Edge Temperature"]?.value);
        if (!isNaN(sensorsEdgeTemp) && sensorsEdgeTemp > 0)
            return sensorsEdgeTemp;

        const gfxTemp = parseInt(selectedGpu?.gpu_metrics?.temperature_gfx);
        if (!isNaN(gfxTemp) && gfxTemp > 0)
            return Math.round(gfxTemp / 100);

        return 0;
    }

    function normalizeSysfsPath(path) {
        if (typeof path !== "string")
            return "";
        const normalizedPath = path.trim().replace(/\/+$/, "");
        return normalizedPath.startsWith("/sys/") ? normalizedPath : "";
    }

    function normalizePciAddress(address) {
        if (typeof address !== "string")
            return "";
        const normalizedAddress = address.trim();
        return /^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$/.test(normalizedAddress)
            ? normalizedAddress
            : "";
    }

    function getTemperatureSysfsPath(selectedGpu) {
        const infoDevicePath = selectedGpu?.Info?.DevicePath;
        const nestedDevicePath = selectedGpu?.DevicePath;
        const legacyDevicePath = selectedGpu?.device_path;
        const directPath = root.normalizeSysfsPath(
            (typeof infoDevicePath === "string" ? infoDevicePath : infoDevicePath?.sysfs_path)
            || (typeof nestedDevicePath === "string" ? nestedDevicePath : nestedDevicePath?.sysfs_path)
            || (typeof legacyDevicePath === "string" ? legacyDevicePath : legacyDevicePath?.sysfs_path)
            || selectedGpu?.sysfs_path
        );
        if (directPath)
            return directPath;

        const pciAddress = root.normalizePciAddress(
            infoDevicePath?.pci
            || selectedGpu?.PCI
            || selectedGpu?.pci
        );
        if (pciAddress)
            return `/sys/bus/pci/devices/${pciAddress}`;

        return "";
    }

    function refreshTemperatureFromSysfs(selectedGpu) {
        if (_fallbackTempProcess.running)
            return true;

        const sysfsPath = root.getTemperatureSysfsPath(selectedGpu);
        root.temperatureSysfsPath = sysfsPath;
        if (!sysfsPath)
            return false;

        _fallbackTempProcess.command = [
            "find",
            `${sysfsPath}/hwmon`,
            "-mindepth", "2",
            "-maxdepth", "2",
            "-type", "f",
            "-name", "temp1_input",
            "-exec", "cat", "{}", ";",
            "-quit"
        ];
        _fallbackTempProcess.running = true;
        return true;
    }

    function getUsageColor(percent) {
        if (percent > 90) return Theme.error;
        if (percent > 70) return "#ffa500";
        return Theme.primary;
    }
}
