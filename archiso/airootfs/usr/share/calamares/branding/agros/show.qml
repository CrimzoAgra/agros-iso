/* AgrOS's slideshow while it installs: its logo and name on a card with rounded corners, the leaves drawing themselves
   and going again as it works (LoadingLogo.qml) */
import QtQuick 2.15;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Slide {
        anchors.fill: parent

        // (the page's own colour round the card: its corners show it)
        Rectangle {
            anchors.fill: parent
            color: "#121318"
        }

        LoadingLogo {
            anchors.fill: parent
        }
    }

    function onActivate() { }
    function onLeave() { }
}
