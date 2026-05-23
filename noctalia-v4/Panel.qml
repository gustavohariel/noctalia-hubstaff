import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property var mainInstance: pluginApi?.mainInstance

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 320 * Style.uiScaleRatio
    // Lets the panel grow with its content + symmetric marginL padding,
    // matching noctalia's other panel implementations. The previous fixed
    // 220px cap was too small for the new button rows and pinned them to
    // the edge.
    property real contentPreferredHeight: mainColumn.implicitHeight + Style.margin2L

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NIcon {
                    icon: "clock"
                    pointSize: Style.fontSizeXL
                    color: Color.mPrimary
                }

                NText {
                    text: "Hubstaff"
                    pointSize: Style.fontSizeXL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: !!root.mainInstance
                    color: Qt.alpha(root.mainInstance?.isRunning ? Color.mPrimary : Color.mOutline, 0.18)
                    radius: Style.radiusXS
                    implicitWidth: stateLabel.implicitWidth + Style.marginL
                    implicitHeight: stateLabel.implicitHeight + Style.marginS

                    NText {
                        id: stateLabel
                        anchors.centerIn: parent
                        text: (root.mainInstance?.isRunning ?? false) ? "tracking" : "stopped"
                        pointSize: Style.fontSizeS
                        font.weight: Style.fontWeightSemiBold
                        color: (root.mainInstance?.isRunning ?? false) ? Color.mPrimary : Color.mOnSurfaceVariant
                    }
                }

                NIconButton {
                    icon: "power"
                    tooltipText: "Quit Hubstaff — kills the daemon"
                    colorFg: Color.mError
                    colorBorder: Qt.alpha(Color.mError, 0.4)
                    colorBgHover: Qt.alpha(Color.mError, 0.18)
                    colorFgHover: Color.mError
                    onClicked: root.mainInstance?.quitApp()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mOutline
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXXS

                NText {
                    text: (root.mainInstance?.projectName ?? "") !== "" ? root.mainInstance.projectName : "No active project"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                NText {
                    text: root.mainInstance?.formattedTime ?? "—"
                    pointSize: Style.fontSizeXXL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NText {
                    text: "today"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }
            }

            Item {
                Layout.fillHeight: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    readonly property bool running: root.mainInstance?.isRunning ?? false
                    text: running ? "Stop" : "Start"
                    icon: running ? "stop" : "media-play"
                    backgroundColor: running ? Color.mError : Color.mPrimary
                    textColor: running ? Color.mOnError : Color.mOnPrimary
                    Layout.fillWidth: true
                    onClicked: running ? root.mainInstance?.actionStop() : root.mainInstance?.actionStart()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginM

                    NButton {
                        readonly property bool windowOpen: root.mainInstance?.windowOpen ?? false
                        text: windowOpen ? "Hide" : "Open"
                        icon: windowOpen ? "minimize" : "app-window"
                        outlined: true
                        tooltipText: windowOpen ? "Float the Hubstaff window off-screen" : "Bring the Hubstaff window onto the current workspace"
                        Layout.fillWidth: true
                        onClicked: root.mainInstance?.toggleWindow()
                    }

                    NButton {
                        text: "Open dashboard"
                        icon: "external-link"
                        outlined: true
                        tooltipText: "Open app.hubstaff.com"
                        Layout.fillWidth: true
                        onClicked: Qt.openUrlExternally("https://app.hubstaff.com")
                    }
                }
            }

            Rectangle {
                visible: (root.mainInstance?.lastError ?? "") !== ""
                Layout.fillWidth: true
                color: Qt.alpha(Color.mError, 0.12)
                radius: Style.radiusS
                implicitHeight: errorRow.implicitHeight + Style.marginM

                RowLayout {
                    id: errorRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Style.marginM
                    }
                    spacing: Style.marginS

                    NIcon {
                        icon: "warning"
                        pointSize: Style.fontSizeS
                        color: Color.mError
                    }

                    NText {
                        text: root.mainInstance?.lastError ?? ""
                        pointSize: Style.fontSizeXS
                        color: Color.mError
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
