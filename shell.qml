import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    property bool open: false

    // shared overlay content, hosted by whichever window type the platform gets
    Component {
        id: content

        Item {
            focus: root.open

            // on X11 the window must explicitly take keyboard focus when it
            // opens, or Esc / homerow keys never reach the Keys handler
            Connections {
                target: root
                function onOpenChanged() {
                    if (root.open) forceActiveFocus()
                }
            }

            // keyboard grab target: Esc closes, homerow keys launch
            Keys.onPressed: event => {
                // Ctrl/Alt down while hovering → arm dwell launch
                if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt) {
                    wheel.setDwellModifier(true)
                    event.accepted = false // still allow other bindings
                    return
                }
                if (event.key === Qt.Key_Escape) {
                    root.open = false
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

            // dim + click-outside-to-close
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.35)
                }
            }

            Wheel {
                id: wheel
                anchors.centerIn: parent
                active: root.open
                apps: appsFile.config.apps ?? []
                hoverDelay: appsFile.config.hoverDelay ?? 250
                idleTimeout: appsFile.config.idleTimeout ?? 5000

                onActiveChanged: if (!active) reset()
                onLaunched: root.open = false
                onClosed: root.open = false
            }
        }
    }

    // Wayland: layer-shell panel (overlay, exclusive keyboard focus)
    Component {
        id: waylandWindow

        PanelWindow {
            visible: root.open
            color: "transparent"

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            // layer-shell only exists on Wayland; on X11 the attached object is null
            Component.onCompleted: if (this.WlrLayershell != null) {
                this.WlrLayershell.layer = WlrLayer.Overlay
                this.WlrLayershell.namespace = "wheel-hover-launcher"
                this.WlrLayershell.exclusiveZone = -1
                this.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
            }

            Loader {
                anchors.fill: parent
                sourceComponent: content
            }
        }
    }

    // X11: PanelWindow maps as _NET_WM_WINDOW_TYPE_DOCK, which i3 never
    // manages (no struts, fullscreen dock) — use a normal fullscreen window.
    // i3 fullscreens it via: for_window [title="^quickshell$"] fullscreen enable
    Component {
        id: x11Window

        FloatingWindow {
            visible: root.open
            fullscreen: true
            color: "transparent"

            Loader {
                anchors.fill: parent
                sourceComponent: content
            }
        }
    }

    Loader {
        sourceComponent: Qt.platform.pluginName === "wayland"
                         ? waylandWindow : x11Window
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
        onPressed: root.open = !root.open
    }

    // X11/i3 toggle path (no global-shortcut protocol there):
    //   bindsym $mod+X exec quickshell -p <config path> ipc call wheel-hover-launcher toggle
    IpcHandler {
        target: "wheel-hover-launcher"

        function toggle() {
            root.open = !root.open
        }
    }
}
