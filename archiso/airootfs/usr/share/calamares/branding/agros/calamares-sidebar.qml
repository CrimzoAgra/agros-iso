/* AgrOS's installer steps along the bottom, in the shell's style: the logo and a pill per step, the current one
   filled with the primary colour (branding.desc's style colours), Rubik. The logo and pills kept clear of the
   window's rounded corners (Hyprland rounds windows by 15 px).
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
                readonly property bool current: index == ViewManager.currentStepIndex
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
                }
            }
        }
    }
}
