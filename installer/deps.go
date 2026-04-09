package main

import (
	"fmt"
	"os"
)

// FeaturePackages maps feature IDs directly to Arch package names.
// No meta-packages or PKGBUILDs — just the real packages.
// Update these lists independently whenever upstream packages change.
var FeaturePackages = map[string][]string{
	"basic": {
		"bc", "coreutils", "cliphist", "cmake", "curl", "wget",
		"ripgrep", "jq", "xdg-user-dirs", "rsync", "go-yq",
	},
	"hyprland": {
		"hyprland", "hyprsunset", "wl-clipboard",
	},
	"quickshell": {
		"cpptrace", "jemalloc", "mesa",
		"qt6-declarative", "qt6-base", "qt6-svg",
		"libdrm", "libpipewire", "libxcb", "wayland",
		"qt6-5compat", "qt6-avif-image-plugin", "qt6-imageformats",
		"qt6-multimedia", "qt6-positioning", "qt6-quicktimeline",
		"qt6-sensors", "qt6-tools", "qt6-translations",
		"qt6-virtualkeyboard", "qt6-wayland",
		"kirigami", "kdialog", "syntax-highlighting",
	},
	"audio": {
		"cava", "pavucontrol-qt", "wireplumber",
		"pipewire-pulse", "libdbusmenu-gtk3", "playerctl",
	},
	"backlight": {
		"geoclue", "brightnessctl", "ddcutil",
	},
	"screencapture": {
		"hyprshot", "slurp", "swappy",
		"tesseract", "tesseract-data-eng", "wf-recorder",
	},
	"widgets": {
		"fuzzel", "glib2", "imagemagick",
		"hypridle", "hyprlock", "hyprpicker",
		"songrec", "translate-shell", "wlogout", "libqalculate",
	},
	"kde": {
		"bluedevil", "gnome-keyring", "networkmanager",
		"plasma-nm", "polkit-kde-agent", "dolphin", "systemsettings",
	},
	"portal": {
		"xdg-desktop-portal", "xdg-desktop-portal-kde",
		"xdg-desktop-portal-gtk", "xdg-desktop-portal-hyprland",
	},
	"fonts-themes": {
		"adw-gtk-theme-git", "breeze", "breeze-plus", "darkly-bin",
		"eza", "fish", "fontconfig", "kitty", "matugen",
		"otf-space-grotesk", "starship",
		"ttf-jetbrains-mono-nerd", "ttf-material-symbols-variable-git",
		"ttf-readex-pro", "ttf-rubik-vf", "ttf-twemoji",
	},
	"python": {
		"clang", "uv", "gtk4", "libadwaita",
		"libsoup3", "libportal-gtk4", "gobject-introspection",
	},
	"toolkit": {
		"upower", "wtype", "ydotool",
	},
	"microtex": {
		"tinyxml2", "gtkmm3", "gtksourceviewmm", "cairomm",
	},
	"bibata": {
		"bibata-cursor-theme-bin",
	},
}

// DeprecatedPackages are old packages that should be removed before installing.
// Includes old -git packages and the illogical-impulse meta-packages
// (replaced by direct package installation).
var DeprecatedPackages = []string{
	// Old -git packages
	"quickshell-git",
	"hyprutils-git",
	"hyprpicker-git",
	"hyprlang-git",
	"hypridle-git",
	"hyprland-qt-support-git",
	"hyprland-qtutils-git",
	"hyprlock-git",
	"xdg-desktop-portal-hyprland-git",
	"hyprcursor-git",
	"hyprwayland-scanner-git",
	"hyprland-git",
	"hyprland-qtutils",
	"matugen-bin",
	// Old illogical-impulse meta-packages (now replaced by direct packages)
	"illogical-impulse-audio",
	"illogical-impulse-backlight",
	"illogical-impulse-basic",
	"illogical-impulse-bibata-modern-classic-bin",
	"illogical-impulse-fonts-themes",
	"illogical-impulse-hyprland",
	"illogical-impulse-kde",
	"illogical-impulse-microtex",
	"illogical-impulse-microtex-git",
	"illogical-impulse-portal",
	"illogical-impulse-pymyc-aur",
	"illogical-impulse-python",
	"illogical-impulse-quickshell-git",
	"illogical-impulse-screencapture",
	"illogical-impulse-toolkit",
	"illogical-impulse-widgets",
	"illogical-impulse-oneui4-icons-git",
}

// InstallDeps runs Phase 1: package installation via yay.
func InstallDeps(runner *CmdRunner, selectedFeatures []string) error {
	// 1. Remove deprecated packages (ignore errors)
	runner.Log("Removing deprecated packages...")
	for _, pkg := range DeprecatedPackages {
		runner.RunSudoIgnoreErr("pacman", "--noconfirm", "-Rdd", pkg)
	}

	// 2. System update (interactive — user confirms)
	runner.Log("Updating system packages...")
	if err := runner.RunSudoInteractive("pacman", "-Syu"); err != nil {
		return fmt.Errorf("system update failed: %w", err)
	}

	// 3. Ensure yay is available
	if !CommandExists("yay") {
		runner.Log("Installing yay (AUR helper)...")
		if err := installYay(runner); err != nil {
			return fmt.Errorf("yay installation failed: %w", err)
		}
	}

	// 4. Collect all packages from selected features
	seen := make(map[string]bool)
	var packages []string
	for _, featureID := range selectedFeatures {
		pkgs, ok := FeaturePackages[featureID]
		if !ok {
			continue
		}
		for _, p := range pkgs {
			if !seen[p] {
				seen[p] = true
				packages = append(packages, p)
			}
		}
	}

	if len(packages) == 0 {
		runner.Log("No packages to install.")
		return nil
	}

	// 5. Install all packages in one shot (interactive — user confirms)
	runner.Log(fmt.Sprintf("Installing %d packages...", len(packages)))
	args := append([]string{"-S", "--needed"}, packages...)
	if err := runner.RunInteractive("yay", args...); err != nil {
		return fmt.Errorf("package installation failed: %w", err)
	}

	return nil
}

func installYay(runner *CmdRunner) error {
	if err := runner.RunSudoInteractive("pacman", "-S", "--needed", "base-devel", "git"); err != nil {
		return err
	}

	tmpDir := "/tmp/buildyay"
	os.RemoveAll(tmpDir)
	if err := runner.Run("git", "clone", "https://aur.archlinux.org/yay-bin.git", tmpDir); err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)

	if err := runner.RunInteractiveInDir(tmpDir, "makepkg", "-si"); err != nil {
		return err
	}
	return nil
}
