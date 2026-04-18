import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.synchronizer
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property var tabButtonList: [
        {
            "icon": "keyboard",
            "name": Translation.tr("Keybinds")
        },
        {
            "icon": "experiment",
            "name": Translation.tr("Elements")
        },
        {
            "icon": "terminal",
            "name": Translation.tr("Tmux")
        },
        {
            "icon": "pets",
            "name": Translation.tr("Kitty")
        },
        {
            "icon": "edit_note",
            "name": Translation.tr("Neovim")
        },
    ]

    Loader {
        id: cheatsheetLoader
        active: false

        sourceComponent: PanelWindow { // Window
            id: cheatsheetRoot
            visible: cheatsheetLoader.active

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            function hide() {
                cheatsheetLoader.active = false;
            }
            exclusiveZone: 0
            implicitWidth: cheatsheetBackground.width + Appearance.sizes.elevationMargin * 2
            implicitHeight: cheatsheetBackground.height + Appearance.sizes.elevationMargin * 2
            WlrLayershell.namespace: "quickshell:cheatsheet"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            mask: Region {
                item: cheatsheetBackground
            }

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(cheatsheetRoot);
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(cheatsheetRoot);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    cheatsheetRoot.hide();
                }
            }

            // Background
            StyledRectangularShadow {
                target: cheatsheetBackground
            }
            Rectangle {
                id: cheatsheetBackground
                anchors.centerIn: parent
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.windowRounding
                property real padding: 20
                implicitWidth: cheatsheetColumnLayout.implicitWidth + padding * 2
                implicitHeight: cheatsheetColumnLayout.implicitHeight + padding * 2

                focus: cheatsheetRoot.visible

                Keys.onPressed: event => { // Esc to close
                    if (event.key === Qt.Key_Escape) {
                        cheatsheetRoot.hide();
                    }
                    if (event.key === Qt.Key_Left) {
                        tabBar.setCurrentIndex((tabBar.currentIndex - 1 + root.tabButtonList.length) % root.tabButtonList.length);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        tabBar.setCurrentIndex((tabBar.currentIndex + 1) % root.tabButtonList.length);
                        event.accepted = true;
                    }
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_PageDown) {
                            tabBar.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            tabBar.decrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            tabBar.setCurrentIndex((tabBar.currentIndex + 1) % root.tabButtonList.length);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Backtab) {
                            tabBar.setCurrentIndex((tabBar.currentIndex - 1 + root.tabButtonList.length) % root.tabButtonList.length);
                            event.accepted = true;
                        }
                    }
                }

                RippleButton { // Close button
                    id: closeButton
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.full
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 20
                        rightMargin: 20
                    }

                    onClicked: {
                        cheatsheetRoot.hide();
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.title
                        text: "close"
                    }
                }

                ColumnLayout { // Real content
                    id: cheatsheetColumnLayout
                    anchors.centerIn: parent
                    spacing: 10

                    Toolbar {
                        Layout.alignment: Qt.AlignHCenter
                        enableShadow: false
                        ToolbarTabBar {
                            id: tabBar
                            tabButtonList: root.tabButtonList

                            Synchronizer on currentIndex {
                                property alias source: contentContainer.currentIndex
                            }
                        }
                    }

                    Item { // Content pages
                        id: contentContainer
                        Layout.topMargin: 5

                        property int currentIndex: Persistent.states.cheatsheet.tabIndex
                        property int _previousIndex: -1
                        property int _direction: 0 // -1 = left, 1 = right
                        property var _components: [
                            compKeybinds, compElements, compTmux, compKitty, compNvim
                        ]

                        Component { id: compKeybinds; CheatsheetKeybinds {} }
                        Component { id: compElements; CheatsheetPeriodicTable {} }
                        Component { id: compTmux; CheatsheetTmux {} }
                        Component { id: compKitty; CheatsheetKitty {} }
                        Component { id: compNvim; CheatsheetNvim {} }

                        // Fixed size based on window so all tabs share the same dimensions
                        implicitWidth: cheatsheetRoot.width * 0.45
                        implicitHeight: cheatsheetRoot.height * 0.5

                        onCurrentIndexChanged: {
                            if (_previousIndex >= 0 && _previousIndex !== currentIndex) {
                                _direction = currentIndex > _previousIndex ? 1 : -1;
                            }
                            Persistent.states.cheatsheet.tabIndex = currentIndex;
                            _previousIndex = currentIndex;
                        }

                        clip: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: contentContainer.width
                                height: contentContainer.height
                                radius: Appearance.rounding.small
                            }
                        }

                        Loader {
                            id: currentPage
                            anchors.centerIn: parent
                            sourceComponent: contentContainer._components[contentContainer.currentIndex]
                            opacity: 1
                            property real slideX: 0
                            transform: Translate { x: currentPage.slideX }

                            onSourceComponentChanged: {
                                // Slide in from the direction of navigation
                                slideX = contentContainer._direction * contentContainer.width * 0.3;
                                opacity = 0;
                                slideInAnim.restart();
                            }

                            ParallelAnimation {
                                id: slideInAnim
                                NumberAnimation {
                                    target: currentPage
                                    property: "slideX"
                                    to: 0
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                                NumberAnimation {
                                    target: currentPage
                                    property: "opacity"
                                    to: 1
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            cheatsheetLoader.active = !cheatsheetLoader.active;
        }

        function close(): void {
            cheatsheetLoader.active = false;
        }

        function open(): void {
            cheatsheetLoader.active = true;
        }
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggles cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = !cheatsheetLoader.active;
        }
    }

    GlobalShortcut {
        name: "cheatsheetOpen"
        description: "Opens cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = true;
        }
    }

    GlobalShortcut {
        name: "cheatsheetClose"
        description: "Closes cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = false;
        }
    }
}
