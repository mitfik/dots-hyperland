pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

MouseArea {
    id: root
    required property SystemTrayItem item
    property bool targetMenuOpen: false

    signal menuOpened(qsWindow: var)
    signal menuClosed()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: 20
    implicitHeight: 20

    // Left click should always bring up the app. Many apps map the SNI Activate
    // action to a show/hide toggle, so a click on a tray-minimized app can end up
    // hiding it again. If the app's tray menu exposes a "Show"/"Restore"/"Open"
    // entry (only present while the window is hidden), trigger that instead so a
    // left click reliably reveals the window; otherwise fall back to activate().
    function showApp() {
        const showEntry = root.findShowEntry();
        if (showEntry) {
            showEntry.triggered();
        } else {
            item.activate();
        }
    }
    function findShowEntry() {
        if (!item.hasMenu)
            return null;
        const entries = activateMenuOpener.children?.values ?? [];
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (!entry || entry.isSeparator || entry.hasChildren)
                continue;
            const text = (entry.text ?? "").toLowerCase();
            if (text.length === 0)
                continue;
            if (text.includes("hide") || text.includes("minimize") || text.includes("minimise"))
                continue;
            if (text.includes("show") || text.includes("restore") || text.includes("open"))
                return entry;
        }
        return null;
    }

    // Keeps the tray item's menu entries loaded so findShowEntry() can inspect
    // them on the first left click without waiting for a DBus round-trip.
    QsMenuOpener {
        id: activateMenuOpener
        menu: root.item.hasMenu ? root.item.menu : null
    }

    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton:
            root.showApp();
            break;
        case Qt.RightButton:
            if (item.hasMenu)
                if (menu.active && menu.item && typeof menu.item.close === "function")
                    menu.item.close();
                else 
                    menu.open();
            break;
        }
        event.accepted = true;
    }
    onEntered: {
        tooltip.text = TrayService.getTooltipForItem(root.item);
    }

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: root.item.menu
            trayItemId: root.item.id
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuOpened: (window) => root.menuOpened(window);
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }

    IconImage {
        id: trayIcon
        visible: !Config.options.tray.monochromeIcons
        source: root.item.icon
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    Loader {
        active: Config.options.tray.monochromeIcons
        anchors.fill: trayIcon
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false // There's already color overlay
                anchors.fill: parent
                source: trayIcon
                desaturation: 0.8 // 1.0 means fully grayscale
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

}
