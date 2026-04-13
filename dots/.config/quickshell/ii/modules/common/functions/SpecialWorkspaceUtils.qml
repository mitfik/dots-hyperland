pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    function getIcon(workspaceName) {
        const name = workspaceName.toLowerCase().replace("special:", "");

        // Check user-configured icons first
        const customIcons = Config.options.specialWorkspaces.icons;
        for (let i = 0; i < customIcons.length; i++) {
            if (customIcons[i].name === name)
                return customIcons[i].icon;
        }

        // Built-in icon map
        if (name === "special") return "star";
        if (name === "communication") return "forum";
        if (name === "im") return "forum";
        if (name === "music") return "music_cast";
        if (name === "todo") return "checklist";
        if (name === "sysmon") return "monitor_heart";
        if (name === "steam" || name === "games") return "sports_esports";
        if (name === "discord" || name === "chat") return "chat";
        if (name === "mail" || name === "email") return "mail";
        if (name === "browser" || name === "web") return "language";
        if (name === "terminal" || name === "term") return "terminal";
        if (name === "files") return "folder";
        if (name === "video") return "movie";

        // Fallback: first letter
        return name.length > 0 ? name[0].toUpperCase() : "?";
    }
}
