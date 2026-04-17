pragma ComponentBehavior: Bound

import "tmux_cheatsheet.js" as TmuxData
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    readonly property var sections: TmuxData.sections
    property real spacing: 20
    property real titleSpacing: 7
    property real padding: 4
    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: row.implicitHeight + padding * 2

    Row {
        id: row
        spacing: root.spacing

        Repeater {
            model: root.sections

            delegate: Column {
                spacing: root.spacing
                required property var modelData
                anchors.top: row.top

                Repeater {
                    model: modelData

                    delegate: Item {
                        id: sectionItem
                        required property var modelData
                        implicitWidth: sectionColumn.implicitWidth
                        implicitHeight: sectionColumn.implicitHeight

                        Column {
                            id: sectionColumn
                            anchors.centerIn: parent
                            spacing: root.titleSpacing

                            StyledText {
                                font {
                                    family: Appearance.font.family.title
                                    pixelSize: Appearance.font.pixelSize.title
                                    variableAxes: Appearance.font.variableAxes.title
                                }
                                color: Appearance.colors.colOnLayer0
                                text: sectionItem.modelData.name
                            }

                            GridLayout {
                                columns: 2
                                columnSpacing: 4
                                rowSpacing: 4

                                Repeater {
                                    model: {
                                        var result = [];
                                        for (var i = 0; i < sectionItem.modelData.entries.length; i++) {
                                            var entry = sectionItem.modelData.entries[i];
                                            result.push({
                                                "type": "keys",
                                                "keys": entry.keys,
                                            });
                                            result.push({
                                                "type": "desc",
                                                "desc": entry.desc,
                                            });
                                        }
                                        return result;
                                    }

                                    delegate: Item {
                                        required property var modelData
                                        implicitWidth: loader.implicitWidth
                                        implicitHeight: loader.implicitHeight

                                        Loader {
                                            id: loader
                                            sourceComponent: (modelData.type === "keys") ? keysComponent : descComponent
                                        }

                                        Component {
                                            id: keysComponent
                                            Row {
                                                spacing: 4
                                                Repeater {
                                                    model: modelData.keys.split("  ")
                                                    delegate: KeyboardKey {
                                                        required property var modelData
                                                        key: modelData
                                                        pixelSize: Appearance.font.pixelSize.smaller
                                                    }
                                                }
                                            }
                                        }

                                        Component {
                                            id: descComponent
                                            Item {
                                                implicitWidth: descText.implicitWidth + 8 * 2
                                                implicitHeight: descText.implicitHeight

                                                StyledText {
                                                    id: descText
                                                    anchors.centerIn: parent
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    text: modelData.desc
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
