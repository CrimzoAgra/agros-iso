/* AgrOS's slideshow while it installs: its logo and name, as in its README */
import QtQuick 2.15;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Slide {
        anchors.fill: parent

        Image {
            source: "slide1.png"
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
        }
    }

    function onActivate() { }
    function onLeave() { }
}
