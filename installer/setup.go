package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
)

// RunSetup executes Phase 2: system configuration.
func RunSetup(runner *CmdRunner) error {
	if err := installPythonPackages(runner); err != nil {
		return fmt.Errorf("python packages: %w", err)
	}
	if err := setupUserGroups(runner); err != nil {
		return fmt.Errorf("user groups: %w", err)
	}
	if err := setupKernelModules(runner); err != nil {
		return fmt.Errorf("kernel modules: %w", err)
	}
	if err := setupServices(runner); err != nil {
		return fmt.Errorf("services: %w", err)
	}
	setupDesktopSettings(runner)
	return nil
}

func installPythonPackages(runner *CmdRunner) error {
	runner.Log("Setting up Python virtual environment...")

	home, _ := os.UserHomeDir()
	venvDir := filepath.Join(home, ".local", "state", "quickshell", ".venv")
	os.MkdirAll(filepath.Dir(venvDir), 0755)

	// Create venv with Python 3.12 (--clear replaces existing venv)
	if err := runner.Run("uv", "venv", "--prompt", ".venv", "--clear", venvDir, "-p", "3.12"); err != nil {
		runner.Log("Warning: could not create venv with Python 3.12, trying default...")
		if err := runner.Run("uv", "venv", "--prompt", ".venv", "--clear", venvDir); err != nil {
			return fmt.Errorf("venv creation failed: %w", err)
		}
	}

	// Install packages from requirements.txt
	reqFile := filepath.Join(runner.repoRoot, "sdata", "uv", "requirements.txt")
	if _, err := os.Stat(reqFile); err != nil {
		return fmt.Errorf("requirements.txt not found: %w", err)
	}

	runner.Log("Installing Python packages...")
	cmd := exec.CommandContext(runner.ctx, "uv", "pip", "install", "-r", reqFile)
	cmd.Env = append(os.Environ(),
		"VIRTUAL_ENV="+venvDir,
		"UV_NO_MODIFY_PATH=1",
	)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("pip install failed: %w", err)
	}

	return nil
}

func setupUserGroups(runner *CmdRunner) error {
	runner.Log("Configuring user groups...")

	// Create i2c group if it doesn't exist
	if err := exec.Command("getent", "group", "i2c").Run(); err != nil {
		runner.RunSudoIgnoreErr("groupadd", "i2c")
	}

	// Add current user to required groups
	u, err := user.Current()
	if err != nil {
		return fmt.Errorf("could not determine current user: %w", err)
	}

	return runner.RunSudo("usermod", "-aG", "video,i2c,input", u.Username)
}

func setupKernelModules(runner *CmdRunner) error {
	runner.Log("Loading kernel modules...")

	// Write i2c-dev module config via shell redirect
	return runner.RunSudo("sh", "-c", `echo "i2c-dev" > /etc/modules-load.d/i2c-dev.conf`)
}

func setupServices(runner *CmdRunner) error {
	runner.Log("Enabling system services...")

	// Check if systemd is available
	if !CommandExists("systemctl") {
		runner.Log("Warning: systemctl not found, skipping service setup")
		return nil
	}

	// Enable ydotool user service
	if os.Getenv("DBUS_SESSION_BUS_ADDRESS") != "" {
		runner.RunSudoIgnoreErr("systemctl", "--user", "enable", "ydotool", "--now")
	} else {
		u, _ := user.Current()
		runner.RunSudoIgnoreErr("systemctl",
			"--machine="+u.Username+"@.host",
			"--user", "enable", "ydotool", "--now")
	}

	// Enable bluetooth
	return runner.RunSudo("systemctl", "enable", "bluetooth", "--now")
}

func setupDesktopSettings(runner *CmdRunner) {
	runner.Log("Applying desktop settings...")

	// GNOME settings
	if CommandExists("gsettings") {
		runner.Run("gsettings", "set", "org.gnome.desktop.interface",
			"font-name", "Google Sans Flex Medium 11 @opsz=11,wght=500")
		runner.Run("gsettings", "set", "org.gnome.desktop.interface",
			"color-scheme", "prefer-dark")
	}

	// KDE settings
	if CommandExists("kwriteconfig6") {
		runner.Run("kwriteconfig6", "--file", "kdeglobals",
			"--group", "KDE", "--key", "widgetStyle", "Darkly")
	}
}

