import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property bool isIdle: !TimerService.countdownRunning && !TimerService.countdownDone && TimerService.countdownSecondsLeft === TimerService.countdownDuration

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        CircularProgress {
            Layout.alignment: Qt.AlignHCenter
            lineWidth: 8
            value: TimerService.countdownDuration > 0 ? TimerService.countdownSecondsLeft / TimerService.countdownDuration : 0
            implicitSize: 200
            enableAnimation: true
            colPrimary: TimerService.countdownDone ? Appearance.colors.colError : Appearance.m3colors.m3onSecondaryContainer

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                Loader {
                    Layout.alignment: Qt.AlignHCenter
                    active: true
                    sourceComponent: root.isIdle ? timePickerComp : timeDisplayComp
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.countdownDone ? Translation.tr("Done!") : TimerService.countdownRunning ? Translation.tr("Running") : (TimerService.countdownSecondsLeft < TimerService.countdownDuration && TimerService.countdownSecondsLeft > 0) ? Translation.tr("Paused") : ""
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: TimerService.countdownDone ? Appearance.colors.colError : Appearance.colors.colSubtext
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            RippleButton {
                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (TimerService.countdownDone) return Translation.tr("Restart")
                        if (TimerService.countdownRunning) return Translation.tr("Pause")
                        if (root.isIdle) return Translation.tr("Start")
                        return Translation.tr("Resume")
                    }
                    color: TimerService.countdownRunning ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                }
                implicitHeight: 35
                implicitWidth: 90
                font.pixelSize: Appearance.font.pixelSize.larger
                onClicked: {
                    if (TimerService.countdownDone) {
                        TimerService.startCountdown()
                    } else {
                        TimerService.toggleCountdown()
                    }
                }
                colBackground: TimerService.countdownRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.countdownRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
            }

            RippleButton {
                implicitHeight: 35
                implicitWidth: 90
                font.pixelSize: Appearance.font.pixelSize.larger

                onClicked: TimerService.clearCountdown()
                enabled: !root.isIdle || TimerService.countdownDuration > 0

                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive

                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("Reset")
                    color: Appearance.colors.colOnErrorContainer
                }
            }
        }
    }

    component TimeSpinner: ColumnLayout {
        id: spinner
        property int value: 0
        property int min: 0
        property int max: 59
        signal valueModified(int newValue)

        spacing: 2
        Layout.alignment: Qt.AlignHCenter

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 44
            Layout.preferredHeight: 28
            buttonRadius: Appearance.rounding.small
            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 0)
            colBackgroundHover: Appearance.colors.colLayer2Hover
            onClicked: {
                let v = spinner.value + 1;
                if (v > spinner.max) v = spinner.min;
                spinner.valueModified(v);
            }
            contentItem: MaterialSymbol {
                text: "expand_less"
                iconSize: 20
                color: Appearance.colors.colOnLayer2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 44
            Layout.preferredHeight: 38
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2

            StyledText {
                anchors.centerIn: parent
                text: spinner.value.toString().padStart(2, '0')
                font.pixelSize: 30
                font.weight: 600
                color: Appearance.m3colors.m3onSurface
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 44
            Layout.preferredHeight: 28
            buttonRadius: Appearance.rounding.small
            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 0)
            colBackgroundHover: Appearance.colors.colLayer2Hover
            onClicked: {
                let v = spinner.value - 1;
                if (v < spinner.min) v = spinner.max;
                spinner.valueModified(v);
            }
            contentItem: MaterialSymbol {
                text: "expand_more"
                iconSize: 20
                color: Appearance.colors.colOnLayer2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Component {
        id: timePickerComp

        RowLayout {
            spacing: 4
            Layout.alignment: Qt.AlignHCenter

            TimeSpinner {
                value: TimerService.countdownSetHours
                min: 0
                max: 23
                onValueModified: (v) => TimerService.countdownSetHours = v
            }

            StyledText {
                text: ":"
                font.pixelSize: 30
                font.weight: 600
                color: Appearance.m3colors.m3onSurface
                Layout.alignment: Qt.AlignVCenter
            }

            TimeSpinner {
                value: TimerService.countdownSetMinutes
                min: 0
                max: 59
                onValueModified: (v) => TimerService.countdownSetMinutes = v
            }

            StyledText {
                text: ":"
                font.pixelSize: 30
                font.weight: 600
                color: Appearance.m3colors.m3onSurface
                Layout.alignment: Qt.AlignVCenter
            }

            TimeSpinner {
                value: TimerService.countdownSetSeconds
                min: 0
                max: 59
                onValueModified: (v) => TimerService.countdownSetSeconds = v
            }
        }
    }

    Component {
        id: timeDisplayComp

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: {
                let total = TimerService.countdownSecondsLeft;
                let hours = Math.floor(total / 3600);
                let minutes = Math.floor((total % 3600) / 60).toString().padStart(2, '0');
                let seconds = Math.floor(total % 60).toString().padStart(2, '0');
                if (hours > 0) {
                    return `${hours}:${minutes}:${seconds}`;
                }
                return `${minutes}:${seconds}`;
            }
            font.pixelSize: 40
            color: TimerService.countdownDone ? Appearance.colors.colError : Appearance.m3colors.m3onSurface
        }
    }
}
