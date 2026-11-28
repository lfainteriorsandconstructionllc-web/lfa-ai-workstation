// LFA AI OS 1.0 — Diseño completo del escritorio Plasma 6
// Replica exactamente el escritorio LFA: fondo dinámico LFA Living Landscapes,
// widgets de Clima, Monitor de Sistema ("Sistema") y Noticias LFA a la derecha,
// y dock flotante de cristal abajo con lanzador a pantalla completa (todas las apps en una vista),
// LFA AI Assistant anclado y macOS Dock con zoom.

var desktopsArray = desktopsForActivity(currentActivity())
for (var j = 0; j < desktopsArray.length; j++) {
    var d = desktopsArray[j]
    d.wallpaperPlugin = "org.lfa.weatherlandscape"
    d.currentConfigGroup = ["Wallpaper", "org.lfa.weatherlandscape", "General"]
    d.writeConfig("sceneMode", "auto")
    d.writeConfig("dailyRotation", true)

    // Agregar los 3 widgets en la columna derecha sólo en la pantalla principal (j === 0)
    if (j === 0) {
        var geo = screenGeometry(d.screen)
        var sw = (geo && geo.width > 0) ? geo.width : 1920
        var sh = (geo && geo.height > 0) ? geo.height : 1080
        var colW = Math.min(480, Math.round(sw * 0.25))
        var colX = sw - colW - 16

        // 1. Widget de Clima (arriba a la derecha)
        var weather = d.addWidget("org.kde.plasma.weather", colX, 0, colW, Math.round(sh * 0.35))
        if (weather) {
            weather.currentConfigGroup = ["WeatherStation"]
            weather.writeConfig("provider", "bbcukmet")
            weather.writeConfig("placeDisplayName", "New York, US")
            weather.writeConfig("placeInfo", "New York, United States, US|5128581")
        }

        // 2. Monitor de Sistema "Sistema" con colores LFA dorado/cobre/oliva (centro derecha)
        var sysmon = d.addWidget("org.kde.plasma.systemmonitor", colX, Math.round(sh * 0.37), colW, Math.round(sh * 0.28))
        if (sysmon) {
            sysmon.currentConfigGroup = ["Appearance"]
            sysmon.writeConfig("chartFace", "org.kde.ksysguard.horizontalbars")
            sysmon.writeConfig("showTitle", true)
            sysmon.writeConfig("title", "Sistema")

            sysmon.currentConfigGroup = ["Sensors"]
            sysmon.writeConfig("highPrioritySensorIds", '["cpu/all/usage","memory/physical/usedPercent","gpu/all/usage","disk/all/usedPercent"]')
            sysmon.writeConfig("lowPrioritySensorIds", '["cpu/all/averageTemperature"]')

            sysmon.currentConfigGroup = ["SensorColors"]
            sysmon.writeConfig("cpu/all/usage", "209,181,123")
            sysmon.writeConfig("memory/physical/usedPercent", "214,140,100")
            sysmon.writeConfig("gpu/all/usage", "150,158,166")
            sysmon.writeConfig("disk/all/usedPercent", "160,170,100")
            sysmon.writeConfig("memory/swap/usedPercent", "236,214,160")
        }

        // 3. Widget de Noticias LFA (abajo a la derecha)
        if (knownWidgetTypes.indexOf("org.lfa.noticias") >= 0) {
            d.addWidget("org.lfa.noticias", colX, Math.round(sh * 0.67), colW, Math.round(sh * 0.25))
        }
    }
}

// Dock flotante de cristal abajo, centrado, del tamaño de su contenido
var panel = new Panel
panel.location = "bottom"
panel.height = 70
panel.floating = true
panel.alignment = "center"
panel.lengthMode = "fit"
panel.hiding = "dodgewindows"
panel.opacity = "translucent"

// Lanzador a pantalla completa con TODAS las apps en una sola vista (Linexin Launcher)
var launcher
if (knownWidgetTypes.indexOf("org.linexin.launcher") >= 0) {
    launcher = panel.addWidget("org.linexin.launcher")
    launcher.currentConfigGroup = ["General"]
    launcher.writeConfig("defaultCategory", -2)
    launcher.writeConfig("showAllAppsInDashboard", true)
    launcher.writeConfig("showActiveApps", false)
    launcher.writeConfig("useCustomBackgroundColor", true)
    launcher.writeConfig("backgroundColor", "#1e242a")
    launcher.writeConfig("backgroundOpacity", 75)
    launcher.writeConfig("useCustomButtonImage", true)
    launcher.writeConfig("customButtonImage", "file:///usr/share/icons/LFA/apps/512/lfa-boton.png")
} else {
    var fallbackId = knownWidgetTypes.indexOf("org.kde.plasma.kickerdash") >= 0
        ? "org.kde.plasma.kickerdash"
        : "org.kde.plasma.kickoff"
    launcher = panel.addWidget(fallbackId)
    launcher.currentConfigGroup = ["General"]
}
if (launcher) {
    launcher.writeConfig("icon", "lfa-boton")
    launcher.writeConfig("showRecentApps", false)
    launcher.writeConfig("showRecentDocs", false)
    launcher.globalShortcut = "Alt+F1"
}

// Dock de aplicaciones con zoom estilo macOS (o icontasks como respaldo)
var hasMacDock = knownWidgetTypes.indexOf("com.github.mattanis.macosdock") >= 0
var tasks = panel.addWidget(hasMacDock ? "com.github.mattanis.macosdock" : "org.kde.plasma.icontasks")
if (tasks) {
    tasks.currentConfigGroup = ["General"]
    var launchers = ["preferred://filemanager", "preferred://browser"]
    var extra = [
        "lfa-ai-assistant.desktop",
        "lfa-ai-setup.desktop",
        "org.kde.konsole.desktop",
        "org.kde.kate.desktop",
        "org.kde.discover.desktop",
        "systemsettings.desktop"
    ]
    for (var i = 0; i < extra.length; i++) {
        if (applicationExists(extra[i])) {
            launchers.push("applications:" + extra[i])
        }
    }
    tasks.writeConfig("launchers", launchers)
    if (hasMacDock) {
        tasks.writeConfig("containerBackgroundType", 1)
        tasks.writeConfig("elevation", 0)
        tasks.writeConfig("hoverElevation", 0)
        tasks.writeConfig("iconSize", 56)
        tasks.writeConfig("iconSpacing", 4)
        tasks.writeConfig("zoomAnimationType", 0)
        tasks.writeConfig("zoomBlastRadius", 2)
        tasks.writeConfig("zoomEnabled", true)
        tasks.writeConfig("zoomMultiplier", 1.3)
    }
    tasks.writeConfig("maxStripes", "1")
    tasks.writeConfig("indicateAudioStreams", "true")
}

// Zona derecha del dock: separador, bandeja del sistema, reloj y papelera
panel.addWidget("org.kde.plasma.marginsseparator")
panel.addWidget("org.kde.plasma.systemtray")
var clock = panel.addWidget("org.kde.plasma.digitalclock")
if (clock) {
    clock.currentConfigGroup = ["Appearance"]
    clock.writeConfig("autoFontAndSize", false)
    clock.writeConfig("fontSize", 11)
}
panel.addWidget("org.kde.plasma.trash")
