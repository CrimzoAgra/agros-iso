/* AgrOS's installer steps along the bottom, in the shell's style: the logo and a pill per step, the current one
   filled with the primary colour (branding.desc's style colours), Rubik. The logo and pills kept clear of the
   window's rounded corners (Hyprland rounds windows by 15 px). A step's pill clicked goes there, as Back and Next do
   (through them, a page at a time, so each page's checks still apply): back to any step before, forward only as far
   as the furthest step reached (filled in already; the ones after it greyed), never into the install itself (only its
   own button starts it).
   From CachyOS's calamares-sidebar.qml (Adriaan de Groot, Anke Boersma: GPL-3.0-or-later). */

import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick 2.3
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.15

Rectangle {
    id: sideBar
    color: Branding.styleString(Branding.SidebarBackground)
    height: 52
    width: parent.width

    // The furthest step reached: forward clicks go no further
    property int furthest: 0
    // Where a click is going (-1: nowhere): a step a tick, until there or a page won't let it go on
    property int target: -1

    function canGo(i) {
        const cur = ViewManager.currentStepIndex;
        return i < cur ? ViewManager.backEnabled : i > cur && i <= furthest && ViewManager.nextEnabled;
    }

    Connections {
        target: ViewManager
        function onCurrentStepChanged() {
            sideBar.furthest = Math.max(sideBar.furthest, ViewManager.currentStepIndex);
        }
    }

    Timer {
        id: walk
        interval: 60
        repeat: true
        onTriggered: {
            const cur = ViewManager.currentStepIndex;
            if (sideBar.target < cur && ViewManager.backEnabled)
                ViewManager.back();
            else if (sideBar.target > cur && sideBar.target <= sideBar.furthest && ViewManager.nextEnabled)
                ViewManager.next();
            else {
                stop(); // there, or a page that won't go on (its check failed): stays on it
                sideBar.target = -1;
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        spacing: 4

        Image {
            id: logo
            Layout.rightMargin: 14
            Layout.alignment: Qt.AlignVCenter
            width: 28
            height: width
            source: "file:/" + Branding.imagePath(Branding.ProductLogo)
            sourceSize.width: width
            sourceSize.height: height
        }

        Repeater {
            model: ViewManager
            Rectangle {
                id: pill
                readonly property bool current: index == ViewManager.currentStepIndex
                readonly property bool clickable: sideBar.target < 0 && sideBar.canGo(index)
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 34
                radius: height / 2
                color: Branding.styleString(current ? Branding.SidebarBackgroundCurrent : Branding.SidebarBackground)

                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    color: Branding.styleString(current ? Branding.SidebarTextCurrent : Branding.SidebarText)
                    text: display
                    font.family: "Rubik"
                    font.weight: current ? Font.Medium : Font.Normal
                    font.pixelSize: 13
                    // (greyed until the step is first reached)
                    opacity: index > sideBar.furthest ? 0.4 : 1

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                // (under the mouse, a step it can go to: a faint fill)
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Branding.styleString(Branding.SidebarText)
                    opacity: pillMouse.containsMouse && pill.clickable ? 0.08 : 0
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: pill.clickable || containsMouse
                    cursorShape: pill.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (pill.clickable) {
                        sideBar.target = index;
                        walk.start();
                    }
                }
            }
        }
    }
}
