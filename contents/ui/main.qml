/*
    SPDX-FileCopyrightText: 2014 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick 2.0
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.10 as Kirigami
import org.kde.taskmanager 0.1 as TaskManager

Item {
    id: root

    property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical

    Layout.fillWidth: Plasmoid.configuration.expanding
    Layout.fillHeight: Plasmoid.configuration.expanding

    Layout.minimumWidth: Plasmoid.nativeInterface.containment.editMode ? PlasmaCore.Units.gridUnit * 2 : 1
    Layout.minimumHeight: Plasmoid.nativeInterface.containment.editMode ? PlasmaCore.Units.gridUnit * 2 : 1
    Layout.preferredWidth: horizontal
        ? (Plasmoid.configuration.expanding ? optimalSize : Plasmoid.configuration.length)
        : 0
    Layout.preferredHeight: horizontal
        ? 0
        : (Plasmoid.configuration.expanding ? optimalSize : Plasmoid.configuration.length)

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    property int optimalSize: PlasmaCore.Units.largeSpacing

    function action_expanding() {
        Plasmoid.configuration.expanding = Plasmoid.action("expanding").checked;
    }

    property var activeTaskLocal: null
    property bool noWindowActive: true
    property bool currentWindowMaximized: false
    property bool isActiveWindowPinned: false

    // Toggle maximize with mouse wheel/left click from https://invent.kde.org/plasma/plasma-active-window-control

    //
    // MODEL
    //
    TaskManager.TasksModel {
        id: tasksModel
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        groupMode: TaskManager.TasksModel.GroupDisabled

        screenGeometry: plasmoid.screenGeometry
        filterByScreen: true //plasmoid.configuration.showForCurrentScreenOnly

        onActiveTaskChanged: {
            updateActiveWindowInfo()
        }
        onDataChanged: {
            updateActiveWindowInfo()
        }
        onCountChanged: {
            updateActiveWindowInfo()
        }
    }



    function updateActiveWindowInfo() {

        var activeTaskIndex = tasksModel.activeTask

        // fallback for Plasma 5.8
        var abstractTasksModel = TaskManager.AbstractTasksModel || {}
        var isActive = abstractTasksModel.IsActive || 271
        var appName = abstractTasksModel.AppName || 258
        var isMaximized = abstractTasksModel.IsMaximized || 276
        var virtualDesktop = abstractTasksModel.VirtualDesktop || 286

        if (!tasksModel.data(activeTaskIndex, isActive)) {
            activeTaskLocal = {}
        } else {
            activeTaskLocal = {
                display: tasksModel.data(activeTaskIndex, Qt.DisplayRole),
                decoration: tasksModel.data(activeTaskIndex, Qt.DecorationRole),
                AppName: tasksModel.data(activeTaskIndex, appName),
                IsMaximized: tasksModel.data(activeTaskIndex, isMaximized),
                VirtualDesktop: tasksModel.data(activeTaskIndex, virtualDesktop)
            }
        }

        var actTask = activeTask()
        noWindowActive = !activeTaskExists()
        currentWindowMaximized = !noWindowActive && actTask.IsMaximized === true
        isActiveWindowPinned = actTask.VirtualDesktop === -1;
        // if (noWindowActive) {
        //     windowTitleText.text = composeNoWindowText()
        //     iconItem.source = plasmoid.configuration.noWindowIcon
        // } else {
        //     windowTitleText.text = (textType === 1 ? actTask.AppName : null) || replaceTitle(actTask.display)
        //     iconItem.source = actTask.decoration
        // }
        //updateTooltip()
    }



    function activeTask() {
        return activeTaskLocal
    }

    function activeTaskExists() {
        return activeTaskLocal.display !== undefined
    }


    function toggleMaximized() {
        tasksModel.requestToggleMaximized(tasksModel.activeTask);
    }

    function setMaximized(maximized) {
        if ((maximized && !activeTask().IsMaximized)
            || (!maximized && activeTask().IsMaximized)) {
            print('toggle maximized')
            toggleMaximized()
        }
    }

    PlasmaCore.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: disconnectSource(sourceName)

        function exec(cmd) {
            executable.connectSource(cmd)
        }
    }


    // Search the actual gridLayout of the panel
    property GridLayout panelLayout: {
        var candidate = root.parent;
        while (candidate) {
            if (candidate instanceof GridLayout) {
                return candidate;
            }
            candidate = candidate.parent;
        }
        return null;
    }

    Component.onCompleted: {
        Plasmoid.setAction("expanding", i18n("Set flexible size"));
        var action = Plasmoid.action("expanding");
        action.checkable = true;
        action.checked = Qt.binding(function() {return Plasmoid.configuration.expanding});

        Plasmoid.removeAction("configure");
    }

    property real middleItemsSizeHint: {
        if (!twinSpacer || !panelLayout || !leftTwin || !rightTwin) {
            optimalSize = horizontal ? Plasmoid.nativeInterface.containment.width : Plasmoid.nativeInterface.containment.height;
            return 0;
        }

        var leftTwinParent = leftTwin.parent;
        var rightTwinParent = rightTwin.parent;
        if (!leftTwinParent || !rightTwinParent) {
            return 0;
        }
        var firstSpacerFound = false;
        var secondSpacerFound = false;
        var leftItemsHint = 0;
        var middleItemsHint = 0;
        var rightItemsHint = 0;

        // Children order is guaranteed to be the same as the visual order of items in the layout
        for (var i in panelLayout.children) {
            var child = panelLayout.children[i];
            if (!child.visible) {
                continue;
            } else if (child == leftTwinParent) {
                firstSpacerFound = true;
            } else if (child == rightTwinParent) {
                secondSpacerFound = true;
            } else if (secondSpacerFound) {
                if (root.horizontal) {
                    rightItemsHint += Math.min(child.Layout.maximumWidth, Math.max(child.Layout.minimumWidth, child.Layout.preferredWidth)) + panelLayout.rowSpacing;
                } else {
                    rightItemsHint += Math.min(child.Layout.maximumWidth, Math.max(child.Layout.minimumHeight, child.Layout.preferredHeight)) + panelLayout.columnSpacing;
                }
            } else if (firstSpacerFound) {
                if (root.horizontal) {
                    middleItemsHint += Math.min(child.Layout.maximumWidth, Math.max(child.Layout.minimumWidth, child.Layout.preferredWidth)) + panelLayout.rowSpacing;
                } else {
                    middleItemsHint += Math.min(child.Layout.maximumWidth, Math.max(child.Layout.minimumHeight, child.Layout.preferredHeight)) + panelLayout.columnSpacing;
                }
            } else {
                if (root.horizontal) {
                    leftItemsHint += Math.min(child.Layout.maximumWidth, Math.max(child.Layout.minimumWidth, child.Layout.preferredWidth)) + panelLayout.rowSpacing;
                } else {
                    leftItemsHint += Math.min(child.Layout.maximumHeight, Math.max(child.Layout.minimumHeight, child.Layout.preferredHeight)) + panelLayout.columnSpacing;
                }
            }
        }

        var halfContainment = root.horizontal ?Plasmoid.nativeInterface.containment.width/2 : Plasmoid.nativeInterface.containment.height/2;

        if (leftTwin == plasmoid) {
            optimalSize = Math.max(PlasmaCore.Units.smallSpacing, halfContainment - middleItemsHint/2 - leftItemsHint)
        } else {
            optimalSize = Math.max(PlasmaCore.Units.smallSpacing, halfContainment - middleItemsHint/2 - rightItemsHint)
        }
        return middleItemsHint;
    }

    readonly property Item twinSpacer: Plasmoid.configuration.expanding && Plasmoid.nativeInterface.twinSpacer && Plasmoid.nativeInterface.twinSpacer.configuration.expanding ? Plasmoid.nativeInterface.twinSpacer : null
    readonly property Item leftTwin: {
        if (!twinSpacer) {
            return null;
        }

        if (root.horizontal) {
            return root.Kirigami.ScenePosition.x < twinSpacer.Kirigami.ScenePosition.x ? plasmoid : twinSpacer;
        } else {
            return root.Kirigami.ScenePosition.y < twinSpacer.Kirigami.ScenePosition.y ? plasmoid : twinSpacer;
        }
    }
    readonly property Item rightTwin: {
        if (!twinSpacer) {
            return null;
        }

        if (root.horizontal) {
            return root.Kirigami.ScenePosition.x >= twinSpacer.Kirigami.ScenePosition.x ? plasmoid : twinSpacer;
        } else {
            return root.Kirigami.ScenePosition.y >= twinSpacer.Kirigami.ScenePosition.y ? plasmoid : twinSpacer;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: PlasmaCore.Theme.highlightColor
        visible: Plasmoid.nativeInterface.containment.editMode
    }


    MouseArea {
        anchors.fill: parent

        hoverEnabled: true

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        // onEntered: {
        //     // mouseHover = true
        //     // controlButtonsArea.mouseInWidget = showControlButtons && !noWindowActive
        //     console.log("onEntered")
        // }

        // onExited: {
        //     // mouseHover = false
        //     // controlButtonsArea.mouseInWidget = false
        //     console.log("onExited")
        // }

        onDoubleClicked: {
            //if (doubleClickMaximizes && mouse.button == Qt.LeftButton) {
            toggleMaximized()
            //executable.exec('notify-send -t 1000 "Mouse double click" "Toggle Maximize"');
            //console.log("onDoubleClicked")
            //}
        }

        onWheel: {
            if (wheel.angleDelta.y > 0) {
                //if (wheelUpMaximizes) {
                    //console.log("Mouse wheel Up")
                    //executable.exec('notify-send -t 1000 "Mouse wheel up" "Maximize true"');
                    setMaximized(true)
                //}
            } else {
                //if (wheelDownMinimizes) {
                //    setMinimized()
                //}
                //if (wheelDownUnmaximizes) {
                    //console.log("Mouse wheel Down")
                    //executable.exec('notify-send -t 1000 "Mouse wheel down" "Maximize False"');
                    setMaximized(false)
                //}
            }
        }
    }
}
