import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    PanelWindow {
        id: window
        property bool open: false

        visible: open
        color: "transparent"

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        // layer-shell: fullscreen overlay, grabs keyboard so Esc always works
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wheel-hover-launcher"
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // keyboard grab target: Esc closes, homerow keys launch
        Item {
            anchors.fill: parent
            focus: window.open
            Keys.onPressed: event => {
                // Ctrl/Alt down while hovering → arm dwell launch
                if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt) {
                    wheel.setDwellModifier(true)
                    event.accepted = false // still allow other bindings
                    return
                }
                if (event.key === Qt.Key_Escape) {
                    window.open = false
                    event.accepted = true
                    return
                }
                wheel.activity()   // any key press counts as usage
                if (wheel.handleKey(event.text))
                    event.accepted = true
            }
            // releasing Ctrl/Alt cancels any pending dwell auto-launch
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt) {
                    const held = !!(event.modifiers & (Qt.ControlModifier
                                                       | Qt.AltModifier))
                    wheel.setDwellModifier(held)
                }
            }
        }

        onOpenChanged: if (!open) wheel.reset()

        // dim + click-outside-to-close
        MouseArea {
            anchors.fill: parent
            onClicked: window.open = false

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)
            }
        }

        Wheel {
            id: wheel
            anchors.centerIn: parent
            active: window.open
            apps: appsFile.config.apps ?? []
            hoverDelay: appsFile.config.hoverDelay ?? 250
            idleTimeout: appsFile.config.idleTimeout ?? 5000

            onLaunched: window.open = false
            onClosed: window.open = false
        }
    }

    FileView {
        id: appsFile
        property var config: ({ apps: [], hoverDelay: 250 })

        function parse() {
            try {
                config = JSON.parse(text())
            } catch (e) {
                console.warn("wheel-hover-launcher: bad apps.json:", e)
                config = { apps: [], hoverDelay: 250 }
            }
        }

        path: Quickshell.env("HOME") + "/.config/wheel-hover-launcher/apps.json"
        blockLoading: true   // config is ready by the time windows load
        watchChanges: true   // live-reload when you edit apps.json
        onLoaded: parse()
        onFileChanged: reload()
    }

    // registered via hyprland_global_shortcuts_v1; bound in hyprland.lua:
    //   hl.bind(mainMod .. " + X", hl.dsp.global("quickshell:wheel-hover-launcher"))
    GlobalShortcut {
        name: "wheel-hover-launcher"
        description: "Toggle the wheel app launcher"
        onPressed: window.open = !window.open
    }
}
