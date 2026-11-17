import QtQuick
import Quickshell
import "KeyMap.js" as KeyMap

Item {
    id: root

    // ---- config (set by shell.qml) ----
    property var apps: []
    property int hoverDelay: 250  // ms of Ctrl/Alt hover before launch
    property bool active: false    // true while the wheel is shown
    property int idleTimeout: 5000 // ms without a key press before closing

    // positional homerow fallback (used only when apps.json has no `key`)
    property var defaultKeys: ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"]
    // custom `key` from apps.json wins; else defaultKeys[i] if unclaimed; else ""
    readonly property var resolvedKeys: KeyMap.resolveKeys(apps, defaultKeys)

    // ---- layout knobs ----
    property real outerRadius: 230
    property real innerRadius: 80
    property real iconSize: 44

    // ---- state ----
    property int highlightIndex: -1
    // true while Ctrl or Alt is down (dwell launch only with modifier held)
    property bool dwellModifierHeld: false

    // signals
    signal launched(var app)
    signal closed

    // ---- derived geometry ----
    readonly property int count: apps.length
    readonly property real slice: count > 0 ? (Math.PI * 2) / count : 0
    readonly property real cx: width / 2
    readonly property real cy: height / 2

    width: outerRadius * 2
    height: outerRadius * 2

    onAppsChanged: {
        highlightIndex = -1
        hoverTimer.stop()
        canvas.requestPaint()
    }
    onHighlightIndexChanged: canvas.requestPaint()

    // idle close: only opening and key presses count as activity
    onActiveChanged: {
        idleTimer.stop()
        if (active)
            idleTimer.restart()
    }
    function activity() {
        if (active)
            idleTimer.restart()
    }
    function keyForIndex(i) {
        return i < resolvedKeys.length ? resolvedKeys[i] : ""
    }

    // Start/stop dwell timer from current modifier + highlight state.
    // sectorChanged=true → debounce restart (new sector under cursor).
    // Releasing Ctrl/Alt stops the timer (cancel pending auto-launch).
    function syncDwell(sectorChanged) {
        if (!KeyMap.shouldDwell(dwellModifierHeld, highlightIndex)) {
            hoverTimer.stop()
            return
        }
        if (sectorChanged || !hoverTimer.running)
            hoverTimer.restart()
    }

    // Called from shell.qml when Ctrl/Alt press/release arrives on the
    // focus item (mouse may be stationary, so no positionChanged event).
    function setDwellModifier(held) {
        dwellModifierHeld = held
        syncDwell(false)
    }

    function handleKey(txt) {
        const t = String(txt).toLowerCase()
        if (t.length !== 1)
            return false
        const i = resolvedKeys.indexOf(t)
        if (i < 0 || i >= count)
            return false
        launch(i)
        return true
    }

    // ---- sector drawing ----
    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (root.count === 0)
                return

            // sector 0 is centered straight up (top); canvas angles are
            // clockwise (y axis points down), matching atan2(dy, dx)
            const start = -Math.PI / 2 - root.slice / 2

            for (let i = 0; i < root.count; i++) {
                const a0 = start + i * root.slice
                const a1 = a0 + root.slice
                const hot = i === root.highlightIndex

                ctx.beginPath()
                ctx.arc(root.cx, root.cy, root.outerRadius, a0, a1, false)
                ctx.arc(root.cx, root.cy, root.innerRadius, a1, a0, true)
                ctx.closePath()

                ctx.fillStyle = hot ? Qt.rgba(0.26, 0.52, 0.96, 0.95)
                                    : Qt.rgba(0.13, 0.14, 0.18, 0.88)
                ctx.fill()
                ctx.lineWidth = 2
                ctx.strokeStyle = hot ? Qt.rgba(0.4, 0.65, 1.0, 0.9)
                                      : Qt.rgba(1, 1, 1, 0.12)
                ctx.stroke()
            }
        }
    }

    // ---- icons + labels, placed with polar coordinates ----
    Repeater {
        model: root.apps

        Item {
            required property var modelData
            required property int index

            readonly property bool hot: index === root.highlightIndex
            readonly property real midAngle: root.count > 0
                ? -Math.PI / 2 + index * root.slice : 0
            readonly property real r: (root.innerRadius + root.outerRadius) / 2

            x: root.cx + r * Math.cos(midAngle)
            y: root.cy + r * Math.sin(midAngle)
            width: 1
            height: 1

            // pinned so children are centered on this polar point;
            // the icon is centered exactly, label + key hint hang below
            Item {
                anchors.centerIn: parent
                width: root.iconSize
                height: root.iconSize

                // visible box so children can anchor safely even when the
                // icon itself is hidden
                Item {
                    id: iconBox
                    width: root.iconSize
                    height: root.iconSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    // icon field: XDG theme name, or a file path
                    // (/abs, ~/rel, file:// URL)
                    readonly property string iconStr: modelData.icon || ""
                    readonly property bool isPath: iconStr.startsWith("/")
                        || iconStr.startsWith("~")
                        || iconStr.startsWith("file://")
                    readonly property bool themeHit: iconStr !== "" && !isPath
                        && Quickshell.hasThemeIcon(iconStr)
                    // a path icon that fails to load (typo, deleted file)
                    // degrades to the letter fallback
                    property bool pathBroken: false
                    onIconStrChanged: pathBroken = false
                    readonly property bool hasIcon: themeHit
                        || (isPath && !pathBroken)

                    Image {
                        id: icon
                        anchors.fill: parent
                        source: iconBox.themeHit
                            ? Quickshell.iconPath(iconBox.iconStr)
                            : iconBox.isPath
                                ? "file://" + (iconBox.iconStr.startsWith("file://")
                                    ? iconBox.iconStr.slice(7)
                                    : iconBox.iconStr.startsWith("~")
                                        ? Quickshell.env("HOME") + iconBox.iconStr.slice(1)
                                        : iconBox.iconStr)
                                : ""
                        onStatusChanged: if (status === Image.Error)
                            iconBox.pathBroken = true
                        sourceSize: Qt.size(width, height)
                        visible: iconBox.hasIcon
                    }
                    Text {
                        // fallback: first letter of the app name
                        anchors.centerIn: parent
                        visible: !iconBox.hasIcon
                        text: modelData.name ? modelData.name.charAt(0) : "?"
                        color: "white"
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    text: modelData.name
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: iconBox.bottom
                    anchors.topMargin: 2
                    color: hot ? "white" : Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                // homerow key hint
                Text {
                    visible: root.keyForIndex(index) !== ""
                    text: "[" + root.keyForIndex(index) + "]"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: iconBox.bottom
                    anchors.topMargin: 18
                    color: hot ? Qt.rgba(1, 1, 1, 0.9)
                               : Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 12
                    font.family: "monospace"
                }
            }
        }
    }

    // ---- center hub ----
    Item {
        anchors.centerIn: parent
        width: root.innerRadius * 2
        height: width

        Text {
            anchors.centerIn: parent
            text: "ESC"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 14
            font.letterSpacing: 2
        }
    }

    // ---- input: polar hit detection ----
    MouseArea {
        id: input
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: mouse => {
            const dx = mouseX - root.cx
            const dy = mouseY - root.cy
            const dist = Math.sqrt(dx * dx + dy * dy)
            let idx = -1

            if (root.count > 0 && dist >= root.innerRadius
                    && dist <= root.outerRadius) {
                let a = Math.atan2(dy, dx)              // canvas angle space
                let norm = a - (-Math.PI / 2 - root.slice / 2)
                if (norm < 0)
                    norm += Math.PI * 2
                idx = Math.floor(norm / root.slice) % root.count
            }

            // plain hover: highlight only; dwell needs Ctrl/Alt held
            root.dwellModifierHeld =
                !!(mouse.modifiers & (Qt.ControlModifier | Qt.AltModifier))

            if (idx !== root.highlightIndex) {
                root.highlightIndex = idx
                // debounce: restart only when the sector under cursor changes
                root.syncDwell(true)
            } else {
                // same sector: cancel if modifier released; start if just armed
                root.syncDwell(false)
            }
        }

        onExited: {
            root.highlightIndex = -1
            hoverTimer.stop()
        }

        onClicked: mouse => {
            // Ctrl/Alt + click = explicit launch
            if (root.highlightIndex !== -1
                    && (mouse.modifiers & Qt.ControlModifier
                        || mouse.modifiers & Qt.AltModifier)) {
                root.launch(root.highlightIndex)
            } else if (root.highlightIndex === -1) {
                // clicked dead zone / outside ring (but inside wheel bbox)
                root.closed()
            }
        }
    }

    // ---- hover auto-launch (debounced; only while Ctrl/Alt held) ----
    Timer {
        id: hoverTimer
        interval: root.hoverDelay
        // re-check: cancel if modifier was released as the timer fired
        onTriggered: if (KeyMap.shouldDwell(root.dwellModifierHeld,
                                             root.highlightIndex))
            root.launch(root.highlightIndex)
    }

    // ---- idle close ----
    Timer {
        id: idleTimer
        interval: root.idleTimeout
        onTriggered: root.closed()
    }

    function reset() {
        highlightIndex = -1
        dwellModifierHeld = false
        hoverTimer.stop()
        idleTimer.stop()
    }

    function launch(index) {
        if (index < 0 || index >= count)
            return
        const app = apps[index]
        if (!app || !app.exec)
            return
        hoverTimer.stop()
        highlightIndex = -1
        // setsid -f detaches: the app survives this shell exiting
        Quickshell.execDetached(["sh", "-c", "setsid -f " + app.exec])
        launched(app)
    }
}
