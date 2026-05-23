import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property color sectionBackgroundColor: Color.mSurfaceVariant

    property var editSettings: JSON.parse(JSON.stringify(pluginApi?.pluginSettings ?? pluginApi?.manifest?.metadata?.defaultSettings ?? {}))

    function saveSettings() {
        pluginApi.pluginSettings = JSON.parse(JSON.stringify(root.editSettings));
        pluginApi.saveSettings();
    }

    spacing: Style.marginL

    NText {
        text: "Hubstaff Settings"
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
    }

    Rectangle {
        Layout.fillWidth: true
        color: root.sectionBackgroundColor
        radius: Style.radiusS
        implicitHeight: generalColumn.implicitHeight + Style.marginXL

        ColumnLayout {
            id: generalColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginL
            }
            spacing: Style.marginM

            NText {
                text: "General"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightSemiBold
                color: Color.mPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "CLI path"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }
                NText {
                    text: "Full path to HubstaffCLI.bin.x86_64 inside your Hubstaff install."
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }

                NTextInput {
                    Layout.fillWidth: true
                    placeholderText: "/home/<user>/Hubstaff/HubstaffCLI.bin.x86_64"
                    text: editSettings?.cliPath ?? ""
                    onTextChanged: {
                        editSettings.cliPath = text;
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    text: "Refresh interval (seconds)"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                }
                NText {
                    text: "How often to poll Hubstaff for the current timer state."
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }

                NSpinBox {
                    from: 2
                    to: 60
                    value: editSettings?.refreshIntervalSec ?? 5
                    stepSize: 1
                    onValueChanged: {
                        editSettings.refreshIntervalSec = value;
                    }
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Item {
            Layout.fillWidth: true
        }

        NButton {
            text: "Reset"
            onClicked: {
                root.editSettings = JSON.parse(JSON.stringify(pluginApi?.manifest?.metadata?.defaultSettings ?? {}));
            }
        }
    }
}
