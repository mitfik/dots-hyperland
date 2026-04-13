pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Simple Pomodoro time manager.
 */
Singleton {
    id: root

    property int focusTime: Config.options.time.pomodoro.focus
    property int breakTime: Config.options.time.pomodoro.breakTime
    property int longBreakTime: Config.options.time.pomodoro.longBreak
    property int cyclesBeforeLongBreak: Config.options.time.pomodoro.cyclesBeforeLongBreak

    property bool pomodoroRunning: Persistent.states.timer.pomodoro.running
    property bool pomodoroBreak: Persistent.states.timer.pomodoro.isBreak
    property bool pomodoroLongBreak: Persistent.states.timer.pomodoro.isBreak && (pomodoroCycle + 1 == cyclesBeforeLongBreak);
    property int pomodoroLapDuration: pomodoroLongBreak ? longBreakTime : pomodoroBreak ? breakTime : focusTime // This is a binding that's to be kept
    property int pomodoroSecondsLeft: pomodoroLapDuration // Reasonable init value, to be changed
    property int pomodoroCycle: Persistent.states.timer.pomodoro.cycle

    property bool stopwatchRunning: Persistent.states.timer.stopwatch.running
    property int stopwatchTime: 0
    property int stopwatchStart: Persistent.states.timer.stopwatch.start
    property var stopwatchLaps: Persistent.states.timer.stopwatch.laps

    property bool countdownRunning: Persistent.states.timer.countdown.running
    property int countdownDuration: Persistent.states.timer.countdown.duration
    property int countdownSecondsLeft: Persistent.states.timer.countdown.duration
    property int countdownSetHours: Persistent.states.timer.countdown.setHours
    property int countdownSetMinutes: Persistent.states.timer.countdown.setMinutes
    property int countdownSetSeconds: Persistent.states.timer.countdown.setSeconds
    property bool countdownDone: false

    // General
    Component.onCompleted: {
        if (!stopwatchRunning)
            stopwatchReset();
    }

    function getCurrentTimeInSeconds() {  // Pomodoro uses Seconds
        return Math.floor(Date.now() / 1000);
    }

    function getCurrentTimeIn10ms() {  // Stopwatch uses 10ms
        return Math.floor(Date.now() / 10);
    }

    // Pomodoro
    function refreshPomodoro() {
        // Work <-> break ?
        if (getCurrentTimeInSeconds() >= Persistent.states.timer.pomodoro.start + pomodoroLapDuration) {
            // Reset counts
            Persistent.states.timer.pomodoro.isBreak = !Persistent.states.timer.pomodoro.isBreak;
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds();

            // Send notification
            let notificationMessage;
            if (Persistent.states.timer.pomodoro.isBreak && (pomodoroCycle + 1 == cyclesBeforeLongBreak)) {
                notificationMessage = Translation.tr(`🌿 Long break: %1 minutes`).arg(Math.floor(longBreakTime / 60));
            } else if (Persistent.states.timer.pomodoro.isBreak) {
                notificationMessage = Translation.tr(`☕ Break: %1 minutes`).arg(Math.floor(breakTime / 60));
            } else {
                notificationMessage = Translation.tr(`🔴 Focus: %1 minutes`).arg(Math.floor(focusTime / 60));
            }

            Quickshell.execDetached(["notify-send", "Pomodoro", notificationMessage, "-a", "Shell"]);
            if (Config.options.sounds.pomodoro) {
                Audio.playSystemSound("alarm-clock-elapsed")
            }

            if (!pomodoroBreak) {
                Persistent.states.timer.pomodoro.cycle = (Persistent.states.timer.pomodoro.cycle + 1) % root.cyclesBeforeLongBreak;
            }
        }

        pomodoroSecondsLeft = pomodoroLapDuration - (getCurrentTimeInSeconds() - Persistent.states.timer.pomodoro.start);
    }

    Timer {
        id: pomodoroTimer
        interval: 200
        running: root.pomodoroRunning
        repeat: true
        onTriggered: refreshPomodoro()
    }

    function togglePomodoro() {
        Persistent.states.timer.pomodoro.running = !pomodoroRunning;
        if (Persistent.states.timer.pomodoro.running) {
            // Start/Resume
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds() + pomodoroSecondsLeft - pomodoroLapDuration;
        }
    }

    function resetPomodoro() {
        Persistent.states.timer.pomodoro.running = false;
        Persistent.states.timer.pomodoro.isBreak = false;
        Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds();
        Persistent.states.timer.pomodoro.cycle = 0;
        refreshPomodoro();
    }

    // Stopwatch
    function refreshStopwatch() {  // Stopwatch stores time in 10ms
        stopwatchTime = getCurrentTimeIn10ms() - stopwatchStart;
    }

    Timer {
        id: stopwatchTimer
        interval: 10
        running: root.stopwatchRunning
        repeat: true
        onTriggered: refreshStopwatch()
    }

    function toggleStopwatch() {
        if (root.stopwatchRunning)
            stopwatchPause();
        else
            stopwatchResume();
    }

    function stopwatchPause() {
        Persistent.states.timer.stopwatch.running = false;
    }

    function stopwatchResume() {
        if (stopwatchTime === 0) Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = true;
        Persistent.states.timer.stopwatch.start = getCurrentTimeIn10ms() - stopwatchTime;
    }

    function stopwatchReset() {
        stopwatchTime = 0;
        Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = false;
    }

    function stopwatchRecordLap() {
        Persistent.states.timer.stopwatch.laps.push(stopwatchTime);
    }

    // Countdown
    function refreshCountdown() {
        let elapsed = getCurrentTimeInSeconds() - Persistent.states.timer.countdown.start;
        countdownSecondsLeft = Math.max(0, countdownDuration - elapsed);
        if (countdownSecondsLeft <= 0 && countdownRunning) {
            Persistent.states.timer.countdown.running = false;
            countdownDone = true;
            Quickshell.execDetached(["notify-send", Translation.tr("Countdown"), Translation.tr("Time is up!"), "-a", "Shell", "-u", "critical"]);
            if (Config.options.sounds.pomodoro) {
                Audio.playSystemSound("alarm-clock-elapsed")
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 200
        running: root.countdownRunning
        repeat: true
        onTriggered: refreshCountdown()
    }

    function startCountdown() {
        let total = countdownSetHours * 3600 + countdownSetMinutes * 60 + countdownSetSeconds;
        if (total <= 0) return;
        Persistent.states.timer.countdown.duration = total;
        countdownDuration = total;
        countdownSecondsLeft = total;
        countdownDone = false;
        Persistent.states.timer.countdown.start = getCurrentTimeInSeconds();
        Persistent.states.timer.countdown.running = true;
    }

    function toggleCountdown() {
        if (countdownRunning) {
            Persistent.states.timer.countdown.running = false;
        } else {
            if (countdownDone || countdownSecondsLeft === countdownDuration) {
                startCountdown();
            } else {
                Persistent.states.timer.countdown.start = getCurrentTimeInSeconds() + countdownSecondsLeft - countdownDuration;
                Persistent.states.timer.countdown.running = true;
            }
        }
    }

    function resetCountdown() {
        Persistent.states.timer.countdown.running = false;
        countdownDone = false;
        countdownSecondsLeft = countdownDuration;
    }

    function clearCountdown() {
        Persistent.states.timer.countdown.running = false;
        countdownDone = false;
        let total = countdownSetHours * 3600 + countdownSetMinutes * 60 + countdownSetSeconds;
        countdownDuration = total;
        countdownSecondsLeft = total;
    }
}
