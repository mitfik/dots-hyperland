// Neovim plugin keybindings from ~/.config/nvim
// Leader key is Space

var sections = [
    // Column 1
    [
        {
            "name": "LSP",
            "entries": [
                { "keys": "gd", "desc": "Go to definition" },
                { "keys": "Leader  ca", "desc": "Code action" },
                { "keys": "Leader  e", "desc": "Show diagnostic" },
                { "keys": "Leader  f", "desc": "Format (keep folds)" },
            ],
        },
        {
            "name": "Git (Fugitive)",
            "entries": [
                { "keys": "Leader  gs", "desc": "Git status" },
                { "keys": "Leader  gc", "desc": "Git commit" },
                { "keys": "Leader  gp", "desc": "Git push" },
                { "keys": "Leader  gl", "desc": "Git pull" },
            ],
        },
        {
            "name": "Git (Gitsigns)",
            "entries": [
                { "keys": "]c", "desc": "Next hunk" },
                { "keys": "[c", "desc": "Previous hunk" },
                { "keys": "Leader  hs", "desc": "Stage hunk" },
                { "keys": "Leader  hr", "desc": "Reset hunk" },
                { "keys": "Leader  hS", "desc": "Stage buffer" },
                { "keys": "Leader  hu", "desc": "Undo stage hunk" },
                { "keys": "Leader  hR", "desc": "Reset buffer" },
                { "keys": "Leader  hp", "desc": "Preview hunk" },
                { "keys": "Leader  hb", "desc": "Blame line" },
                { "keys": "Leader  tb", "desc": "Toggle line blame" },
                { "keys": "Leader  hd", "desc": "Diff this" },
                { "keys": "Leader  hD", "desc": "Diff against HEAD~" },
                { "keys": "Leader  td", "desc": "Toggle deleted" },
            ],
        },
    ],
    // Column 2
    [
        {
            "name": "Telescope",
            "entries": [
                { "keys": "Leader  ff", "desc": "Find files" },
                { "keys": "Leader  gf", "desc": "Git files" },
                { "keys": "Leader  ps", "desc": "Live grep" },
            ],
        },
        {
            "name": "Harpoon",
            "entries": [
                { "keys": "Ctrl+E", "desc": "Open harpoon list" },
                { "keys": "Leader  a", "desc": "Add file to harpoon" },
                { "keys": "Alt  1-4", "desc": "Jump to slot 1-4" },
                { "keys": "Ctrl+Shift  P", "desc": "Previous buffer" },
                { "keys": "Ctrl+Shift  N", "desc": "Next buffer" },
                { "keys": "Alt  D", "desc": "Remove from harpoon" },
            ],
        },
        {
            "name": "Debug (DAP)",
            "entries": [
                { "keys": "Leader  dc", "desc": "Continue" },
                { "keys": "Leader  dl", "desc": "Step into" },
                { "keys": "Leader  dj", "desc": "Step over" },
                { "keys": "Leader  dk", "desc": "Step out" },
                { "keys": "Leader  db", "desc": "Toggle breakpoint" },
                { "keys": "Leader  dd", "desc": "Conditional breakpoint" },
                { "keys": "Leader  de", "desc": "Terminate" },
                { "keys": "Leader  dr", "desc": "Run last" },
                { "keys": "Leader  dt", "desc": "Toggle debug UI" },
            ],
        },
    ],
    // Column 3
    [
        {
            "name": "Completion",
            "entries": [
                { "keys": "Ctrl  N", "desc": "Next item" },
                { "keys": "Ctrl  P", "desc": "Previous item" },
                { "keys": "Ctrl  D", "desc": "Scroll docs up" },
                { "keys": "Ctrl  F", "desc": "Scroll docs down" },
                { "keys": "Ctrl  Space", "desc": "Trigger completion" },
                { "keys": "Enter", "desc": "Confirm selection" },
                { "keys": "Tab", "desc": "Accept Tabnine" },
                { "keys": "Ctrl  ]", "desc": "Dismiss Tabnine" },
            ],
        },
        {
            "name": "Rust",
            "entries": [
                { "keys": "Leader  dt", "desc": "Rust testables" },
                { "keys": "Leader  cf", "desc": "Crate features" },
            ],
        },
        {
            "name": "Utilities",
            "entries": [
                { "keys": "Leader  pv", "desc": "File explorer" },
                { "keys": "Leader  u", "desc": "Toggle undo tree" },
                { "keys": "Leader  ?", "desc": "Show keymaps" },
                { "keys": "Leader  y", "desc": "Yank to clipboard" },
                { "keys": "Leader  Y", "desc": "Yank line to clipboard" },
                { "keys": "Leader  p", "desc": "Paste (keep register)" },
                { "keys": "Leader  yl", "desc": "Copy path:line" },
                { "keys": "Leader  tp", "desc": "Typst preview" },
                { "keys": "Leader  ts", "desc": "Typst stop" },
            ],
        },
    ],
];
