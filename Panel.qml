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
    property real contentPreferredHeight: 220 * Style.uiScaleRatio

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
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

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    text: (root.mainInstance?.isRunning ?? false) ? "Resume" : "Start"
                    icon: "media-play"
                    Layout.fillWidth: true
                    onClicked: root.mainInstance?.actionStart()
                }

                NButton {
                    text: "Stop"
                    icon: "stop"
                    outlined: true
                    enabled: root.mainInstance?.isRunning ?? false
                    Layout.fillWidth: true
                    onClicked: root.mainInstance?.actionStop()
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
