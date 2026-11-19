// The live USB's installer splash: shown while calamares-online.sh gets the installer ready (online, the clock, the
// package keys: a minute or two before its window opens), in place of a notification; closed by it once the
// installer's window is up. Its line of text: what calamares-online.sh writes in the status file
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

ShellRoot {
    FloatingWindow {
        id: win

        property string message: "Getting the installer ready…"

        title: "AgrOS Installer"
        implicitWidth: 560
        implicitHeight: 340
        // (a fixed size, which Hyprland floats by itself: named agros-install (QS_APP_ID, for its dock icon), Caelestia's
        // float rule for Quickshell's windows (class org.quickshell) no longer reaches it, and it was tiled over the
        // whole screen)
        minimumSize.width: implicitWidth
        minimumSize.height: implicitHeight
        maximumSize.width: implicitWidth
        maximumSize.height: implicitHeight
        color: "#14131b"

        FileView {
            // (no XDG_RUNTIME_DIR: nothing read, as calamares-online.sh opens no splash then; never a name in the shared /tmp)
            path: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/agros-installer-splash" : ""
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                const t = text().trim();
                if (t)
                    win.message = t;
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 28

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 300
                fillMode: Image.PreserveAspectFit
                mipmap: true
                source: "file:///usr/share/calamares/branding/agros/logo.png"
            }
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: win.implicitWidth - 64
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: "#e4e1f0"
                font.pixelSize: 16
                text: win.message
            }
        }
    }
}
