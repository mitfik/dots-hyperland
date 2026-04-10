package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Steps in the installer wizard
type step int

const (
	stepWelcome step = iota
	stepMode
	stepDistro
	stepFeatures
	stepConfigs
	stepConfirm
	stepInstall
	stepFiles
	stepDone
)

// installMode controls what the installer does.
type installMode int

const (
	modeFullInstall installMode = iota
	modeConfigsOnly
)

// FeatureGroup represents an installable feature group.
type FeatureGroup struct {
	ID          string
	Name        string
	Description string
	Enabled     bool
	Required    bool
}

// ConfigOption represents a config file group.
type ConfigOption struct {
	ID          string
	Name        string
	Description string
	Enabled     bool
}

type model struct {
	step          step
	width, height int
	program       *tea.Program

	// Mode
	mode    installMode
	modeCur int

	// Distro
	distro DistroInfo

	// Feature selection
	features []FeatureGroup
	featCur  int

	// Config options
	configs []ConfigOption
	confCur int

	// Install (deps + setup phase)
	installing bool
	err        error

	// File deployment
	repoRoot     string
	newFiles     []FileConflict
	conflicts    []FileConflict
	conflictIdx  int
	conflictMode FileAction // ActionAcceptAll or ActionSkipAll if bulk chosen
	filesApplied int
	filesSkipped int

	// Cancel confirmation
	showCancelConfirm bool
	cancelReturnStep  step
}

func defaultFeatures() []FeatureGroup {
	return []FeatureGroup{
		{ID: "basic", Name: "Core System Tools", Description: "Essential tools the shell needs to function (clipboard, file sync, data processing)", Enabled: true, Required: true},
		{ID: "hyprland", Name: "Window Manager", Description: "Hyprland tiling window manager, copy-paste support, and night light", Enabled: true, Required: true},
		{ID: "quickshell", Name: "Desktop Shell", Description: "The panels, sidebars, notifications, and on-screen displays", Enabled: true, Required: true},
		{ID: "audio", Name: "Sound & Music", Description: "Volume control, media playback buttons, audio visualizer in sidebar", Enabled: true},
		{ID: "backlight", Name: "Screen Brightness", Description: "Brightness slider for laptop and external monitors, auto night light by location", Enabled: true},
		{ID: "screencapture", Name: "Screenshots & Recording", Description: "Take screenshots, annotate them, record your screen, extract text from images (OCR)", Enabled: true},
		{ID: "widgets", Name: "Desktop Widgets", Description: "App launcher, lock screen, idle auto-lock, color picker, calculator, logout menu", Enabled: true},
		{ID: "kde", Name: "File Manager & System", Description: "Dolphin file manager, Bluetooth settings, WiFi settings, permission prompts", Enabled: true},
		{ID: "portal", Name: "App Integration", Description: "Lets apps use native file pickers, screen sharing, and open links properly", Enabled: true},
		{ID: "fonts-themes", Name: "Look & Feel", Description: "Fonts, icon themes, cursor theme, GTK/Qt theming, wallpaper-based color generation", Enabled: true},
		{ID: "python", Name: "Color & Theming Engine", Description: "Powers the dynamic color scheme that adapts to your wallpaper", Enabled: true},
		{ID: "toolkit", Name: "Battery & Input", Description: "Battery status in panel, virtual keyboard input for clipboard and automation", Enabled: true},
		{ID: "microtex", Name: "Math Formulas in AI Chat", Description: "Renders LaTeX math expressions in the AI chat sidebar (rarely needed)", Enabled: false},
		{ID: "bibata", Name: "Cursor Style", Description: "Modern flat cursor theme that fits the desktop aesthetic", Enabled: true},
	}
}

func defaultConfigs() []ConfigOption {
	return []ConfigOption{
		{ID: "quickshell", Name: "Desktop Shell Layout", Description: "Panel positions, sidebar content, widget settings, and shell behavior", Enabled: true},
		{ID: "hyprland", Name: "Window Manager Settings", Description: "Keybindings, window rules, animations, and workspace behavior", Enabled: true},
		{ID: "hyprland-entry", Name: "Main Hyprland Config", Description: "The root config file — disable this to keep your own hyprland.conf", Enabled: true},
		{ID: "fish", Name: "Terminal Shell (Fish)", Description: "Fish shell config with custom prompt and aliases", Enabled: true},
		{ID: "fontconfig", Name: "Font Rendering", Description: "How fonts look on screen — hinting, antialiasing, default fonts", Enabled: true},
		{ID: "miscconf", Name: "App Configs", Description: "Settings for terminal (kitty), prompt (starship), video player, logout screen, etc.", Enabled: true},
	}
}

func initialModel() model {
	return model{
		step:     stepWelcome,
		distro:   DetectDistro(),
		features: defaultFeatures(),
		configs:  defaultConfigs(),
		repoRoot: findRepoRoot(),
	}
}

func (m *model) Init() tea.Cmd {
	return nil
}

// --- Styles ---

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#cba6f7")).
			MarginBottom(1)

	subtitleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#a6adc8")).
			MarginBottom(1)

	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#a6e3a1"))

	dimStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#585b70"))

	accentStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#f9e2af"))

	errorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#f38ba8"))

	addStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#a6e3a1"))

	removeStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#f38ba8"))

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#585b70")).
			Padding(1, 2)

	checkOn  = selectedStyle.Render("[x]")
	checkOff = dimStyle.Render("[ ]")
	lockOn   = dimStyle.Render("[x]")
)

// --- Messages ---

type installDoneMsg struct{ err error }
type finalizeDoneMsg struct{ err error }
type filesScanDoneMsg struct {
	newFiles  []FileConflict
	conflicts []FileConflict
	err       error
}

// --- Update ---

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case installDoneMsg:
		m.installing = false
		if msg.err != nil {
			m.err = msg.err
			m.step = stepDone
			return m, nil
		}
		// Deps+setup done, now scan files for conflicts
		return m, m.scanFiles()

	case finalizeDoneMsg:
		if msg.err != nil {
			m.err = msg.err
		}
		m.step = stepDone
		return m, nil

	case filesScanDoneMsg:
		if msg.err != nil {
			m.err = msg.err
			m.step = stepDone
			return m, nil
		}
		m.newFiles = msg.newFiles
		m.conflicts = msg.conflicts
		m.conflictIdx = 0
		m.conflictMode = ActionSkip // default: ask per file

		// Copy all new files immediately
		if err := CopyNewFiles(m.newFiles); err != nil {
			m.err = fmt.Errorf("copying new files: %w", err)
			m.step = stepDone
			return m, nil
		}

		if len(m.conflicts) > 0 {
			m.step = stepFiles
		} else {
			// No conflicts, go straight to done
			return m, m.finalize()
		}
		return m, nil

	case tea.KeyMsg:
		if m.showCancelConfirm {
			return m.updateCancelConfirm(msg)
		}

		switch msg.String() {
		case "ctrl+c":
			m.showCancelConfirm = true
			m.cancelReturnStep = m.step
			return m, nil
		case "esc":
			if m.step == stepWelcome {
				return m, tea.Quit
			}
			m.showCancelConfirm = true
			m.cancelReturnStep = m.step
			return m, nil
		case "q":
			if m.step == stepWelcome || m.step == stepDistro || m.step == stepDone {
				return m, tea.Quit
			}
			if m.step == stepConfirm {
				m.showCancelConfirm = true
				m.cancelReturnStep = m.step
				return m, nil
			}
		}
	}

	switch m.step {
	case stepWelcome:
		return m.updateWelcome(msg)
	case stepMode:
		return m.updateMode(msg)
	case stepDistro:
		return m.updateDistro(msg)
	case stepFeatures:
		return m.updateFeatures(msg)
	case stepConfigs:
		return m.updateConfigs(msg)
	case stepConfirm:
		return m.updateConfirm(msg)
	case stepInstall:
		return m, nil // no user input during install
	case stepFiles:
		return m.updateFiles(msg)
	case stepDone:
		return m.updateDone(msg)
	}

	return m, nil
}

// --- Cancel Confirmation ---

func (m *model) updateCancelConfirm(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "y", "enter":
		m.showCancelConfirm = false
		m.err = fmt.Errorf("installation cancelled by user")
		m.step = stepDone
		m.installing = false
		return m, nil
	case "n", "esc", "backspace":
		m.showCancelConfirm = false
		return m, nil
	case "ctrl+c":
		return m, tea.Quit
	}
	return m, nil
}

func (m *model) viewCancelConfirm() string {
	s := errorStyle.Render("Cancel installation?") + "\n\n"
	if m.installing {
		s += "The install process is currently running.\n"
		s += "Cancelling will " + errorStyle.Render("kill the running process") + ".\n"
		s += "Your system may be in a partially configured state.\n\n"
	} else {
		s += "Your selections will be lost.\n\n"
	}
	s += accentStyle.Render("y") + " confirm  " + accentStyle.Render("n") + " go back  " + dimStyle.Render("ctrl+c force quit")
	return boxStyle.Render(s)
}

// --- Step: Welcome ---

func (m *model) updateWelcome(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		if key.String() == "enter" || key.String() == " " {
			m.step = stepMode
		}
	}
	return m, nil
}

func (m *model) viewWelcome() string {
	s := titleStyle.Render("dots-hyprland Installer") + "\n"
	s += subtitleStyle.Render("aka illogical-impulse") + "\n\n"
	s += "A complete Hyprland desktop environment with a custom\n"
	s += "widget shell built on Quickshell (Qt6/QML).\n\n"
	s += "This installer will guide you through:\n\n"
	s += accentStyle.Render("  1.") + " Detecting your distribution\n"
	s += accentStyle.Render("  2.") + " Selecting feature groups to install\n"
	s += accentStyle.Render("  3.") + " Choosing which configs to deploy\n"
	s += accentStyle.Render("  4.") + " Installing packages and setting up the system\n"
	s += accentStyle.Render("  5.") + " Reviewing and deploying config files\n\n"
	s += dimStyle.Render("Press Enter to continue  •  Esc to quit")
	return boxStyle.Render(s)
}

// --- Step: Mode ---

func (m *model) updateMode(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.String() {
		case "up", "k":
			if m.modeCur > 0 {
				m.modeCur--
			}
		case "down", "j":
			if m.modeCur < 1 {
				m.modeCur++
			}
		case "enter", " ":
			m.mode = installMode(m.modeCur)
			if m.mode == modeConfigsOnly {
				m.step = stepConfigs
			} else {
				m.step = stepDistro
			}
		case "backspace":
			m.step = stepWelcome
		}
	}
	return m, nil
}

func (m *model) viewMode() string {
	s := titleStyle.Render("Install Mode") + "\n"
	s += subtitleStyle.Render("What would you like to do?") + "\n\n"

	type modeOption struct {
		name string
		desc string
	}
	options := []modeOption{
		{"Full Install", "Install packages, configure system, and deploy config files"},
		{"Deploy Configs Only", "Skip package installation — just copy config files (fast)"},
	}

	for i, opt := range options {
		cursor := "  "
		if i == m.modeCur {
			cursor = accentStyle.Render("> ")
		}

		name := opt.name
		if i == m.modeCur {
			name = lipgloss.NewStyle().Bold(true).Render(name)
		}

		s += fmt.Sprintf("%s%s\n", cursor, name)
		if i == m.modeCur {
			s += "    " + dimStyle.Render(opt.desc) + "\n"
		}
	}

	s += "\n" + dimStyle.Render("j/k: navigate  •  Enter: select  •  Backspace: back  •  Esc: cancel")
	return boxStyle.Render(s)
}

// --- Step: Distro ---

func (m *model) updateDistro(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.String() {
		case "enter", " ":
			m.step = stepFeatures
		case "backspace":
			m.step = stepMode
		}
	}
	return m, nil
}

func (m *model) viewDistro() string {
	s := titleStyle.Render("System Detection") + "\n\n"

	s += "  Distribution:  " + accentStyle.Render(m.distro.Name) + "\n"
	s += "  ID:            " + accentStyle.Render(m.distro.ID) + "\n"
	s += "  Architecture:  " + accentStyle.Render(m.distro.Arch) + "\n\n"

	if m.distro.Supported {
		s += selectedStyle.Render("  Fully supported") + "\n"
	} else {
		s += errorStyle.Render("  Not supported yet — only Arch-based distros are currently supported") + "\n"
	}

	s += "\n" + dimStyle.Render("Enter: continue  •  Backspace: back  •  Esc: cancel")
	return boxStyle.Render(s)
}

// --- Step: Features ---

func (m *model) updateFeatures(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.String() {
		case "up", "k":
			if m.featCur > 0 {
				m.featCur--
			}
		case "down", "j":
			if m.featCur < len(m.features)-1 {
				m.featCur++
			}
		case " ", "x":
			if !m.features[m.featCur].Required {
				m.features[m.featCur].Enabled = !m.features[m.featCur].Enabled
			}
		case "a":
			for i := range m.features {
				m.features[i].Enabled = true
			}
		case "n":
			for i := range m.features {
				if !m.features[i].Required {
					m.features[i].Enabled = false
				}
			}
		case "enter":
			m.step = stepConfigs
		case "backspace":
			m.step = stepDistro
		}
	}
	return m, nil
}

func (m *model) viewFeatures() string {
	s := titleStyle.Render("Feature Selection") + "\n"
	s += subtitleStyle.Render("Choose which feature groups to install") + "\n\n"

	for i, f := range m.features {
		cursor := "  "
		if i == m.featCur {
			cursor = accentStyle.Render("> ")
		}

		check := checkOff
		if f.Enabled && f.Required {
			check = lockOn
		} else if f.Enabled {
			check = checkOn
		}

		name := f.Name
		if i == m.featCur {
			name = lipgloss.NewStyle().Bold(true).Render(name)
		}

		line := fmt.Sprintf("%s%s %s", cursor, check, name)
		if f.Required {
			line += dimStyle.Render(" (required)")
		}
		s += line + "\n"

		if i == m.featCur {
			s += "       " + dimStyle.Render(f.Description) + "\n"
		}
	}

	s += "\n" + dimStyle.Render("j/k: navigate  •  Space: toggle  •  a/n: all/none  •  Enter: next  •  Esc: cancel")
	return boxStyle.Render(s)
}

// --- Step: Configs ---

func (m *model) updateConfigs(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.String() {
		case "up", "k":
			if m.confCur > 0 {
				m.confCur--
			}
		case "down", "j":
			if m.confCur < len(m.configs)-1 {
				m.confCur++
			}
		case " ", "x":
			m.configs[m.confCur].Enabled = !m.configs[m.confCur].Enabled
		case "a":
			for i := range m.configs {
				m.configs[i].Enabled = true
			}
		case "n":
			for i := range m.configs {
				m.configs[i].Enabled = false
			}
		case "enter":
			if m.mode == modeConfigsOnly {
				// Skip install, go straight to file scanning
				return m, m.scanFiles()
			}
			m.step = stepConfirm
		case "backspace":
			if m.mode == modeConfigsOnly {
				m.step = stepMode
			} else {
				m.step = stepFeatures
			}
		}
	}
	return m, nil
}

func (m *model) viewConfigs() string {
	s := titleStyle.Render("Configuration Files") + "\n"
	s += subtitleStyle.Render("Choose which config files to deploy") + "\n\n"

	for i, c := range m.configs {
		cursor := "  "
		if i == m.confCur {
			cursor = accentStyle.Render("> ")
		}

		check := checkOff
		if c.Enabled {
			check = checkOn
		}

		name := c.Name
		if i == m.confCur {
			name = lipgloss.NewStyle().Bold(true).Render(name)
		}

		s += fmt.Sprintf("%s%s %s\n", cursor, check, name)
		if i == m.confCur {
			s += "       " + dimStyle.Render(c.Description) + "\n"
		}
	}

	s += "\n" + dimStyle.Render("j/k: navigate  •  Space: toggle  •  a/n: all/none  •  Enter: next  •  Esc: cancel")
	return boxStyle.Render(s)
}

// --- Step: Confirm ---

func (m *model) updateConfirm(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.String() {
		case "enter", "y":
			m.step = stepInstall
			m.installing = true
			// Run sudo auth + full install as a subprocess with terminal access.
			// This lets yay/pacman prompt the user for Y/n.
			self, _ := os.Executable()
			args := append([]string{"--exec-install", m.repoRoot}, m.selectedFeatureIDs()...)
			cmd := exec.Command(self, args...)
			return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
				m.installing = false
				if err != nil {
					return installDoneMsg{err: fmt.Errorf("install failed: %w", err)}
				}
				return installDoneMsg{err: nil}
			})
		case "backspace":
			m.step = stepConfigs
		}
	}
	return m, nil
}

func (m *model) viewConfirm() string {
	s := titleStyle.Render("Review & Confirm") + "\n\n"

	s += accentStyle.Render("Features to install:") + "\n"
	for _, f := range m.features {
		if f.Enabled {
			s += selectedStyle.Render("  + ") + f.Name + "\n"
		} else {
			s += dimStyle.Render("  - " + f.Name) + "\n"
		}
	}

	s += "\n" + accentStyle.Render("Configs to deploy:") + "\n"
	for _, c := range m.configs {
		if c.Enabled {
			s += selectedStyle.Render("  + ") + c.Name + "\n"
		} else {
			s += dimStyle.Render("  - " + c.Name) + "\n"
		}
	}

	s += "\n" + dimStyle.Render("Enter: start installation  •  Backspace: go back  •  Esc: cancel")
	return boxStyle.Render(s)
}

// --- Step: Install (deps + system setup) ---
// Install runs as a subprocess via tea.ExecProcess (see updateConfirm).
// The TUI is suspended while yay/pacman run with full terminal access.

func (m *model) viewInstall() string {
	// This view is shown briefly before tea.ExecProcess takes over
	s := titleStyle.Render("Installing...") + "\n\n"
	s += "The terminal will be handed over to the package manager.\n"
	s += "You may be prompted to confirm package installations.\n\n"
	s += dimStyle.Render("Please wait...")
	return boxStyle.Render(s)
}

// --- Step: Files (interactive conflict resolution) ---

func (m *model) scanFiles() tea.Cmd {
	return func() tea.Msg {
		xdg := ResolveXDGDirs()
		selectedConfigs := m.selectedConfigIDs()
		mappings := BuildConfigMappings(m.repoRoot, xdg, selectedConfigs)
		newFiles, conflicts := ScanConflicts(m.repoRoot, mappings)
		return filesScanDoneMsg{newFiles: newFiles, conflicts: conflicts}
	}
}

func (m *model) updateFiles(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		if m.conflictIdx >= len(m.conflicts) {
			// All conflicts handled
			if key.String() == "enter" {
				return m, m.finalize()
			}
			return m, nil
		}

		// If bulk mode was chosen, apply it
		if m.conflictMode == ActionAcceptAll || m.conflictMode == ActionSkipAll {
			return m, nil // shouldn't reach here, but safety
		}

		switch key.String() {
		case "y":
			// Overwrite this file
			if err := ApplyConflict(m.conflicts[m.conflictIdx]); err != nil {
				m.err = err
				m.step = stepDone
				return m, nil
			}
			m.filesApplied++
			m.conflictIdx++
			if m.conflictIdx >= len(m.conflicts) {
				return m, m.finalize()
			}
		case "n":
			// Skip this file
			m.filesSkipped++
			m.conflictIdx++
			if m.conflictIdx >= len(m.conflicts) {
				return m, m.finalize()
			}
		case "e":
			// Open in editor
			return m, m.openEditor()
		case "a":
			// Accept all remaining
			for i := m.conflictIdx; i < len(m.conflicts); i++ {
				if err := ApplyConflict(m.conflicts[i]); err != nil {
					m.err = err
					m.step = stepDone
					return m, nil
				}
				m.filesApplied++
			}
			m.conflictIdx = len(m.conflicts)
			return m, m.finalize()
		case "s":
			// Skip all remaining
			m.filesSkipped += len(m.conflicts) - m.conflictIdx
			m.conflictIdx = len(m.conflicts)
			return m, m.finalize()
		}
	}
	return m, nil
}

func (m *model) openEditor() tea.Cmd {
	if m.conflictIdx >= len(m.conflicts) {
		return nil
	}
	c := m.conflicts[m.conflictIdx]
	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = "nano"
	}
	cmd := exec.Command(editor, c.DstPath)
	return tea.ExecProcess(cmd, func(err error) tea.Msg {
		// After editor closes, move to next conflict
		return tea.KeyMsg{} // will be handled on next update
	})
}

func (m *model) viewFiles() string {
	s := titleStyle.Render("Deploy Config Files") + "\n"

	// Summary of new files
	s += fmt.Sprintf("%d new files copied", len(m.newFiles))
	if len(m.conflicts) > 0 {
		s += fmt.Sprintf("  •  %d files with changes\n\n", len(m.conflicts))
	} else {
		s += "\n\n"
	}

	if m.conflictIdx >= len(m.conflicts) {
		s += selectedStyle.Render("All files processed!") + "\n"
		s += fmt.Sprintf("  Applied: %d  •  Skipped: %d\n\n", m.filesApplied, m.filesSkipped)
		s += dimStyle.Render("Press Enter to continue")
		return boxStyle.Render(s)
	}

	c := m.conflicts[m.conflictIdx]
	s += fmt.Sprintf("File %d/%d — %s\n\n",
		m.conflictIdx+1, len(m.conflicts),
		accentStyle.Render(c.RelPath))

	// Show diff with colors
	diffLines := strings.Split(c.Diff, "\n")
	maxDiffLines := m.height - 16
	if maxDiffLines < 10 {
		maxDiffLines = 10
	}
	if len(diffLines) > maxDiffLines {
		diffLines = diffLines[:maxDiffLines]
		diffLines = append(diffLines, dimStyle.Render("... (truncated)"))
	}
	for _, line := range diffLines {
		if strings.HasPrefix(line, "+") {
			s += addStyle.Render(line) + "\n"
		} else if strings.HasPrefix(line, "-") {
			s += removeStyle.Render(line) + "\n"
		} else {
			s += dimStyle.Render(line) + "\n"
		}
	}

	s += "\n"
	s += accentStyle.Render("y") + " overwrite  "
	s += accentStyle.Render("n") + " skip  "
	s += accentStyle.Render("e") + " edit  "
	s += accentStyle.Render("a") + " accept all  "
	s += accentStyle.Render("s") + " skip all"

	return s
}

// --- Step: Done ---

func (m *model) finalize() tea.Cmd {
	return func() tea.Msg {
		// Try to reload hyprland
		exec.Command("hyprctl", "reload").Run()

		// Install Google Sans Flex font
		if m.repoRoot != "" {
			xdg := ResolveXDGDirs()
			runner := NewCmdRunner(context.Background(), func(string) {}, m.repoRoot)
			InstallGoogleSansFlex(runner, xdg)
		}

		return finalizeDoneMsg{err: nil}
	}
}

func (m *model) updateDone(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.String() {
		case "enter", "q", " ":
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m *model) viewDone() string {
	s := ""
	if m.err != nil {
		s += errorStyle.Render("Installation failed") + "\n\n"
		s += errorStyle.Render(m.err.Error()) + "\n"
	} else {
		s += titleStyle.Render("Installation Complete!") + "\n\n"
		if len(m.newFiles) > 0 || m.filesApplied > 0 {
			s += fmt.Sprintf("  Files: %d new, %d updated, %d kept as-is\n\n",
				len(m.newFiles), m.filesApplied, m.filesSkipped)
		}
		s += "Next steps:\n\n"
		s += accentStyle.Render("  1.") + " Log out and select Hyprland in your display manager\n"
		s += accentStyle.Render("  2.") + " Press " + selectedStyle.Render("Ctrl+Super+T") + " to select a wallpaper\n"
		s += accentStyle.Render("  3.") + " Press " + selectedStyle.Render("Super+/") + " to view keybinds\n"
		s += "\n" + dimStyle.Render("Do NOT select UWSM when logging in.") + "\n"
	}
	s += "\n" + dimStyle.Render("Press Enter to exit")
	return boxStyle.Render(s)
}

// --- View Router ---

func (m *model) View() string {
	if m.showCancelConfirm {
		return "\n" + m.viewCancelConfirm() + "\n"
	}

	var content string
	switch m.step {
	case stepWelcome:
		content = m.viewWelcome()
	case stepMode:
		content = m.viewMode()
	case stepDistro:
		content = m.viewDistro()
	case stepFeatures:
		content = m.viewFeatures()
	case stepConfigs:
		content = m.viewConfigs()
	case stepConfirm:
		content = m.viewConfirm()
	case stepInstall:
		content = m.viewInstall()
	case stepFiles:
		content = m.viewFiles()
	case stepDone:
		content = m.viewDone()
	}

	// Step indicator
	type stepLabel struct {
		s    step
		name string
	}
	var steps []stepLabel
	if m.mode == modeConfigsOnly && m.step > stepMode {
		steps = []stepLabel{
			{stepWelcome, "Welcome"},
			{stepMode, "Mode"},
			{stepConfigs, "Configs"},
			{stepFiles, "Files"},
			{stepDone, "Done"},
		}
	} else {
		steps = []stepLabel{
			{stepWelcome, "Welcome"},
			{stepMode, "Mode"},
			{stepDistro, "System"},
			{stepFeatures, "Features"},
			{stepConfigs, "Configs"},
			{stepConfirm, "Confirm"},
			{stepInstall, "Install"},
			{stepFiles, "Files"},
			{stepDone, "Done"},
		}
	}
	var indicator string
	for i, sl := range steps {
		if sl.s == m.step {
			indicator += accentStyle.Render(sl.name)
		} else if sl.s < m.step {
			indicator += selectedStyle.Render(sl.name)
		} else {
			indicator += dimStyle.Render(sl.name)
		}
		if i < len(steps)-1 {
			indicator += dimStyle.Render(" > ")
		}
	}

	return "\n" + indicator + "\n\n" + content + "\n"
}

// --- Helpers ---

func (m *model) selectedFeatureIDs() []string {
	var ids []string
	for _, f := range m.features {
		if f.Enabled {
			ids = append(ids, f.ID)
		}
	}
	return ids
}

func (m *model) selectedConfigIDs() map[string]bool {
	result := make(map[string]bool)
	for _, c := range m.configs {
		if c.Enabled {
			result[c.ID] = true
		}
	}
	return result
}

// findRepoRoot walks up from CWD looking for the sdata/ directory.
func findRepoRoot() string {
	// Try CWD first
	dir, _ := os.Getwd()
	for i := 0; i < 5; i++ {
		if _, err := os.Stat(filepath.Join(dir, "sdata")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ""
}

func main() {
	// Hidden subcommand: run install phases with full terminal access.
	// Called by the TUI via tea.ExecProcess so yay/pacman can prompt the user.
	if len(os.Args) >= 2 && os.Args[1] == "--exec-install" {
		os.Exit(execInstall())
	}

	u, err := user.Current()
	if err == nil && u.Uid == "0" {
		fmt.Println("Do not run this installer as root or with sudo.")
		os.Exit(1)
	}

	m := initialModel()
	p := tea.NewProgram(&m, tea.WithAltScreen())
	m.program = p

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// execInstall runs deps+setup with full terminal access.
// Called as a subprocess: ii-installer --exec-install <repoRoot> <feature1> <feature2> ...
func execInstall() int {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: ii-installer --exec-install <repoRoot> [features...]")
		return 1
	}

	repoRoot := os.Args[2]
	features := os.Args[3:]

	ctx := context.Background()
	logFunc := func(line string) {
		fmt.Println(line)
	}
	runner := NewCmdRunner(ctx, logFunc, repoRoot)

	stop := SudoKeepalive(ctx)
	defer stop()

	// Phase 1: Dependencies
	fmt.Print("\n=== Phase 1: Installing packages ===\n\n")
	if err := InstallDeps(runner, features); err != nil {
		fmt.Fprintf(os.Stderr, "Package install failed: %v\n", err)
		return 1
	}

	// Phase 2: System setup
	fmt.Print("\n=== Phase 2: System setup ===\n\n")
	if err := RunSetup(runner); err != nil {
		fmt.Fprintf(os.Stderr, "System setup failed: %v\n", err)
		return 1
	}

	fmt.Println("\n=== Packages and system setup complete ===")
	fmt.Println("Press Enter to continue...")
	fmt.Scanln()
	return 0
}
