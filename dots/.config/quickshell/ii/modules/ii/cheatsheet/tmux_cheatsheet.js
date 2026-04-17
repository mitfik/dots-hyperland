// Tmux cheatsheet data
// Prefix key is typically Ctrl+b

var sections = [
    // Column 1
    [
        {
            "name": "Sessions",
            "entries": [
                { "keys": "tmux new -s name", "desc": "New session" },
                { "keys": "tmux ls", "desc": "List sessions" },
                { "keys": "tmux a -t name", "desc": "Attach to session" },
                { "keys": "tmux kill-session -t name", "desc": "Kill session" },
                { "keys": "Prefix  d", "desc": "Detach" },
                { "keys": "Prefix  $", "desc": "Rename session" },
                { "keys": "Prefix  s", "desc": "Session list" },
                { "keys": "Prefix  (", "desc": "Previous session" },
                { "keys": "Prefix  )", "desc": "Next session" },
            ],
        },
        {
            "name": "Windows",
            "entries": [
                { "keys": "Prefix  c", "desc": "New window" },
                { "keys": "Prefix  ,", "desc": "Rename window" },
                { "keys": "Prefix  &", "desc": "Close window" },
                { "keys": "Prefix  w", "desc": "Window list" },
                { "keys": "Prefix  n", "desc": "Next window" },
                { "keys": "Prefix  p", "desc": "Previous window" },
                { "keys": "Prefix  0-9", "desc": "Go to window #" },
                { "keys": "Prefix  l", "desc": "Last active window" },
            ],
        },
    ],
    // Column 2
    [
        {
            "name": "Panes",
            "entries": [
                { "keys": "Prefix  %", "desc": "Split vertically" },
                { "keys": "Prefix  \"", "desc": "Split horizontally" },
                { "keys": "Prefix  x", "desc": "Close pane" },
                { "keys": "Prefix  o", "desc": "Next pane" },
                { "keys": "Prefix  ;", "desc": "Last active pane" },
                { "keys": "Prefix  {", "desc": "Move pane left" },
                { "keys": "Prefix  }", "desc": "Move pane right" },
                { "keys": "Prefix  q", "desc": "Show pane numbers" },
                { "keys": "Prefix  z", "desc": "Toggle zoom" },
                { "keys": "Prefix  !", "desc": "Pane to window" },
                { "keys": "Prefix  ↑↓←→", "desc": "Navigate panes" },
                { "keys": "Prefix  Space", "desc": "Toggle layouts" },
            ],
        },
        {
            "name": "Resizing",
            "entries": [
                { "keys": "Prefix Ctrl ↑", "desc": "Resize up" },
                { "keys": "Prefix Ctrl ↓", "desc": "Resize down" },
                { "keys": "Prefix Ctrl ←", "desc": "Resize left" },
                { "keys": "Prefix Ctrl →", "desc": "Resize right" },
            ],
        },
    ],
    // Column 3
    [
        {
            "name": "Copy Mode",
            "entries": [
                { "keys": "Prefix  [", "desc": "Enter copy mode" },
                { "keys": "Prefix  ]", "desc": "Paste buffer" },
                { "keys": "q", "desc": "Quit copy mode" },
                { "keys": "Space", "desc": "Start selection" },
                { "keys": "Enter", "desc": "Copy selection" },
                { "keys": "/", "desc": "Search forward" },
                { "keys": "?", "desc": "Search backward" },
                { "keys": "n", "desc": "Next search match" },
                { "keys": "N", "desc": "Previous search match" },
            ],
        },
        {
            "name": "Misc",
            "entries": [
                { "keys": "Prefix  :", "desc": "Command prompt" },
                { "keys": "Prefix  t", "desc": "Show clock" },
                { "keys": "Prefix  ?", "desc": "List keybindings" },
                { "keys": "Prefix  i", "desc": "Display info" },
                { "keys": "Prefix  r", "desc": "Reload config" },
                { "keys": "tmux source ~/.tmux.conf", "desc": "Source config" },
            ],
        },
    ],
];
