import QtQuick
import "../theme.js" as Theme

Item {
    id: root

    property url studioUrl
    property bool started: false
    property bool loaded: false
    property bool failed: false
    property bool available: false
    property string failureText: "The field studio has not started yet."
    property real progress: 0
    property string pageTitle: ""

    signal pageLoaded()
    signal pageFailed(string message)

    function runJavaScript(script, callback) {
        if (loader.status === Loader.Ready && loader.item && loader.item.runJavaScript)
            loader.item.runJavaScript(script, callback);
    }

    function reload() {
        loaded = false;
        failed = false;
        failureText = "";
        progress = 0;
        if (loader.status === Loader.Ready && loader.item) loader.item.reload();
        stallTimer.restart();
    }

    function loadUrl(url) {
        studioUrl = url;
        reload();
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: root.started
        source: "StudioWebViewImpl.qml"

        onStatusChanged: {
            if (status === Loader.Error) {
                root.available = false;
                root.failed = true;
                root.failureText = "QtWebView is not available in this build. The native field desk is active.";
            } else if (status === Loader.Ready) {
                root.available = true;
            }
        }
        onLoaded: {
            item.studioUrl = Qt.binding(function () { return root.studioUrl; });
            stallTimer.restart();
        }
    }

    Connections {
        target: loader.item
        ignoreUnknownSignals: true

        function onPageLoaded() {
            root.loaded = true;
            root.failed = false;
            root.progress = 1;
            root.pageLoaded();
        }

        function onPageFailed(message) {
            root.loaded = false;
            root.failed = true;
            root.failureText = message.length > 0 ? message : "The field studio could not load.";
            root.pageFailed(root.failureText);
        }

        function onProgressChanged(value) {
            root.progress = value;
        }

        function onTitleChanged(title) {
            root.pageTitle = title;
        }
    }

    Timer {
        id: stallTimer
        interval: 14000
        running: root.started && !root.loaded && !root.failed
        repeat: false
        onTriggered: {
            if (root.loaded || root.failed) return;
            root.failed = true;
            root.failureText = "The studio did not finish loading. Use Reconnect, or run scripts/serve-map.sh and switch to the local server.";
            root.pageFailed(root.failureText);
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !loader.item || !root.loaded
        color: Theme.paperDeep

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.failed ? "Field studio unavailable" : "Opening the field studio"
                color: Theme.inkSoft
                font.family: Theme.displayFont
                font.pixelSize: 17
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 360
                text: root.failed
                      ? root.failureText
                      : "Loading produce plots, field work and farmer inventory."
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 9
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.failed
                width: 260
                height: 4
                radius: 2
                color: Theme.line

                Rectangle {
                    width: Math.max(8, parent.width * Math.max(0.04, root.progress))
                    height: parent.height
                    radius: 2
                    color: Theme.forestMid
                    Behavior on width { NumberAnimation { duration: 180 } }
                }
            }
        }
    }
}
