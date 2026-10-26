import QtQuick
import QtWebView

Item {
    id: root

    property url studioUrl

    signal pageLoaded()
    signal pageFailed(string message)
    signal progressChanged(real value)
    signal titleChanged(string title)

    WebView {
        id: view
        anchors.fill: parent
        settings.localStorageEnabled: true
        settings.javaScriptEnabled: true
        settings.allowFileAccess: true
        settings.localContentCanAccessFileUrls: true
        url: root.studioUrl

        onLoadingChanged: function (request) {
            if (request.status === WebView.LoadStartedStatus) {
                root.progressChanged(0.05);
            } else if (request.status === WebView.LoadSucceededStatus) {
                root.progressChanged(1);
                root.pageLoaded();
            } else if (request.status === WebView.LoadFailedStatus) {
                root.pageFailed(request.errorString || "The field studio could not be reached.");
            }
        }

        onLoadProgressChanged: root.progressChanged(loadProgress / 100)

        onTitleChanged: root.titleChanged(title)
    }

    function runJavaScript(script, callback) {
        view.runJavaScript(script, callback);
    }

    function reload() {
        view.reload();
    }

    function stop() {
        view.stop();
    }
}
