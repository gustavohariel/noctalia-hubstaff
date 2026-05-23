import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var mainInstance: pluginApi?.mainInstance

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    readonly property bool isRunning: mainInstance?.isRunning ?? false
    readonly property bool hubstaffRunning: mainInstance?.hubstaffRunning ?? false
    readonly property bool windowOpen: mainInstance?.windowOpen ?? false
    readonly property string displayText: mainInstance?.formattedTime ?? "—"
    readonly property string iconName: isRunning ? "stop" : "media-play"

    // The bar host (BarWidgetLoader) collapses the slot when our root opacity drops
    // to zero, so this is the supported way to disappear from the bar.
    opacity: hubstaffRunning ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 180
        }
    }

    readonly property string tooltipText: {
        if (!mainInstance)
            return "Hubstaff";
        const proj = String(mainInstance.projectName ?? "");
        const time = String(mainInstance.formattedTime ?? "—");
        const state = isRunning ? "tracking" : "stopped";
        if (proj === "")
            return "Hubstaff — " + state;
        return proj + " · " + time + " · " + state;
    }

    readonly property real contentWidth: isBarVertical ? capsuleHeight : content.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: isBarVertical ? content.implicitHeight + Style.marginM * 2 : capsuleHeight

    // Close the plugin panel whenever the daemon goes away (Quit click, manual
    // kill, crash). Otherwise the popup stays anchored to a now-invisible bar
    // widget. closePanel is a no-op if no panel is open on this screen.
    Connections {
        target: root.mainInstance
        function onHubstaffRunningChanged() {
            if (!root.mainInstance.hubstaffRunning)
                root.pluginApi?.closePanel(root.screen);
        }
    }

    anchors.centerIn: parent
    implicitWidth: contentWidth
    implicitHeight: contentHeight

    NPopupContextMenu {
        id: contextMenu
        screen: root.screen

        model: [
            {
                "label": "Refresh",
                "action": "refresh",
                "icon": "refresh"
            },
            {
                "label": root.isRunning ? "Stop" : "Start",
                "action": root.isRunning ? "stop" : "start",
                "icon": root.isRunning ? "stop" : "media-play"
            },
            {
                "label": root.windowOpen ? "Hide window" : "Open app",
                "action": "toggleWindow",
                "icon": root.windowOpen ? "minimize" : "app-window"
            }
        ]

        onTriggered: (action, item) => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);
            if (action === "refresh")
                root.mainInstance?.refresh();
            else if (action === "stop")
                root.mainInstance?.actionStop();
            else if (action === "start")
                root.mainInstance?.actionStart();
            else if (action === "toggleWindow")
                root.mainInstance?.toggleWindow();
        }
    }

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Item {
            id: content
            anchors.centerIn: parent
            implicitWidth: rowLayout.visible ? rowLayout.implicitWidth : colLayout.implicitWidth
            implicitHeight: rowLayout.visible ? rowLayout.implicitHeight : colLayout.implicitHeight

            RowLayout {
                id: rowLayout
                visible: !root.isBarVertical
                spacing: Style.marginS

                NIcon {
                    icon: root.iconName
                    pointSize: root.barFontSize
                    applyUiScale: false
                    color: root.isRunning ? Color.mPrimary : Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignVCenter
                }

                NText {
                    text: root.displayText
                    pointSize: root.barFontSize
                    applyUiScale: false
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            ColumnLayout {
                id: colLayout
                visible: root.isBarVertical
                spacing: Style.marginXS

                NIcon {
                    icon: root.iconName
                    pointSize: root.barFontSize
                    applyUiScale: false
                    color: root.isRunning ? Color.mPrimary : Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                }

                NText {
                    text: root.displayText
                    pointSize: root.barFontSize
                    applyUiScale: false
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                TooltipService.hide();
                pluginApi?.togglePanel(root.screen, root);
            } else if (mouse.button === Qt.RightButton) {
                TooltipService.hide();
                PanelService.showContextMenu(contextMenu, root, root.screen);
            }
        }

        onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName))
        onExited: TooltipService.hide()
    }
}
