/*
    Sistema LFA — Monitor de sistema ligero y nativo para LFA AI OS (Plasma 6).
    Muestra CPU, Memoria, Disco y Temperatura con barras horizontales en la paleta LFA Dorado.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    property int cpuPct: 0
    property int ramPct: 0
    property int diskPct: 0
    property int tempC: 0
    property string ramDetail: ""
    property string diskDetail: ""

    readonly property string probeCmd: "python3 -c \"import os,shutil,time; " +
        "r=lambda: (lambda p:(sum(p)-p[3]-p[4],sum(p)))(list(map(int,open('/proc/stat').readline().split()[1:8]))); " +
        "a1,t1=r(); time.sleep(0.15); a2,t2=r(); cpu=min(100,max(0,round(100*(a2-a1)/max(1,t2-t1)))); " +
        "mi={l.split(':')[0]:int(l.split(':')[1].split()[0]) for l in open('/proc/meminfo') if ':' in l}; " +
        "mt=mi['MemTotal']; mu=mt-mi.get('MemAvailable',mi['MemFree']); ram=min(100,max(0,round(100*mu/max(1,mt)))); " +
        "du=shutil.disk_usage('/'); disk=min(100,max(0,round(100*du.used/max(1,du.total)))); " +
        "ts=[int(open(f'/sys/class/thermal/thermal_zone{i}/temp').read().strip())//1000 for i in range(12) if os.path.exists(f'/sys/class/thermal/thermal_zone{i}/temp')]; " +
        "ts=[v for v in ts if 15<v<115]; temp=max(ts) if ts else 0; " +
        "print(f'{cpu}|{ram}|{disk}|{temp}|{mu/1048576:.1f}/{mt/1048576:.0f} GB|{du.used/1073741824:.0f}/{du.total/1073741824:.0f} GB')\""

    P5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var out = (data["stdout"] || "").trim()
            if (out.length > 0) {
                var parts = out.split("|")
                if (parts.length >= 6) {
                    root.cpuPct = parseInt(parts[0]) || 0
                    root.ramPct = parseInt(parts[1]) || 0
                    root.diskPct = parseInt(parts[2]) || 0
                    root.tempC = parseInt(parts[3]) || 0
                    root.ramDetail = parts[4]
                    root.diskDetail = parts[5]
                }
            }
            disconnectSource(sourceName)
        }
    }

    function refreshStats() {
        execSource.connectSource(probeCmd)
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStats()
    }

    component MetricBar: ColumnLayout {
        id: barItem
        property string label: ""
        property string valueText: ""
        property real ratio: 0
        property color barColor: "#d1b57b"

        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: barItem.label
                color: "#e6eaee"
                font.weight: Font.Medium
                font.pointSize: 9.5
                Layout.fillWidth: true
            }
            PC3.Label {
                text: barItem.valueText
                color: "#c8d0d8"
                font.pointSize: 9
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            implicitHeight: 8
            radius: 4
            color: "#2a333c"

            Rectangle {
                width: Math.max(4, parent.width * Math.min(1, Math.max(0, barItem.ratio)))
                height: parent.height
                radius: 4
                color: barItem.barColor

                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 13
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: "Sistema"
                color: "#d1b57b"
            }
            PC3.Label {
                visible: root.tempC > 0
                text: root.tempC + " °C"
                color: "#ecd6a0"
                font.weight: Font.DemiBold
                font.pointSize: 9.5
            }
        }

        MetricBar {
            label: "CPU"
            valueText: root.cpuPct + "%"
            ratio: root.cpuPct / 100.0
            barColor: "#d1b57b"
        }

        MetricBar {
            label: "Memoria"
            valueText: root.ramDetail ? (root.ramPct + "% · " + root.ramDetail) : (root.ramPct + "%")
            ratio: root.ramPct / 100.0
            barColor: "#d68c64"
        }

        MetricBar {
            label: "Disco"
            valueText: root.diskDetail ? (root.diskPct + "% · " + root.diskDetail) : (root.diskPct + "%")
            ratio: root.diskPct / 100.0
            barColor: "#a0aa64"
        }

        MetricBar {
            visible: root.tempC > 0
            label: "Temperatura"
            valueText: root.tempC + " °C"
            ratio: Math.min(1.0, root.tempC / 100.0)
            barColor: "#ecd6a0"
        }

        Item { Layout.fillHeight: true }
    }
}
