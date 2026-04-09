package main

import (
	"bytes"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// FileConflict represents a config file that differs between source and destination.
type FileConflict struct {
	RelPath string // relative path for display (e.g. ".config/hypr/hyprland.conf")
	SrcPath string // absolute source path
	DstPath string // absolute destination path
	IsNew   bool   // true if destination doesn't exist
	Diff    string // unified diff output (empty if IsNew)
}

// FileAction is what the user chose to do with a conflict.
type FileAction int

const (
	ActionOverwrite FileAction = iota
	ActionSkip
	ActionEdit
	ActionAcceptAll
	ActionSkipAll
)

// ConfigMapping defines a source→destination copy rule.
type ConfigMapping struct {
	Src      string   // relative to repo root (e.g. "dots/.config/quickshell")
	Dst      string   // absolute destination
	IsDir    bool     // true for directory, false for single file
	Excludes []string // subdirectories/files to skip
}

// XDGDirs holds resolved XDG directory paths.
type XDGDirs struct {
	Config string
	Data   string
	State  string
	Cache  string
	Bin    string
	Home   string
}

// ResolveXDGDirs returns XDG paths, using env vars with fallbacks.
func ResolveXDGDirs() XDGDirs {
	home, _ := os.UserHomeDir()
	return XDGDirs{
		Config: envOrDefault("XDG_CONFIG_HOME", filepath.Join(home, ".config")),
		Data:   envOrDefault("XDG_DATA_HOME", filepath.Join(home, ".local", "share")),
		State:  envOrDefault("XDG_STATE_HOME", filepath.Join(home, ".local", "state")),
		Cache:  envOrDefault("XDG_CACHE_HOME", filepath.Join(home, ".cache")),
		Bin:    envOrDefault("XDG_BIN_HOME", filepath.Join(home, ".local", "bin")),
		Home:   home,
	}
}

func envOrDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// BuildConfigMappings creates the list of file operations based on selected config groups.
func BuildConfigMappings(repoRoot string, xdg XDGDirs, selectedConfigs map[string]bool) []ConfigMapping {
	var mappings []ConfigMapping

	if selectedConfigs["miscconf"] {
		// All dirs/files in dots/.config/ except excluded ones
		excluded := map[string]bool{"quickshell": true, "fish": true, "hypr": true, "fontconfig": true}
		dotsCfg := filepath.Join(repoRoot, "dots", ".config")
		entries, _ := os.ReadDir(dotsCfg)
		for _, e := range entries {
			if excluded[e.Name()] {
				continue
			}
			mappings = append(mappings, ConfigMapping{
				Src:   filepath.Join("dots", ".config", e.Name()),
				Dst:   filepath.Join(xdg.Config, e.Name()),
				IsDir: e.IsDir(),
			})
		}
		// Konsole data
		mappings = append(mappings, ConfigMapping{
			Src:   filepath.Join("dots", ".local", "share", "konsole"),
			Dst:   filepath.Join(xdg.Data, "konsole"),
			IsDir: true,
		})
	}

	if selectedConfigs["quickshell"] {
		mappings = append(mappings, ConfigMapping{
			Src:   filepath.Join("dots", ".config", "quickshell"),
			Dst:   filepath.Join(xdg.Config, "quickshell"),
			IsDir: true,
		})
	}

	if selectedConfigs["fish"] {
		mappings = append(mappings, ConfigMapping{
			Src:      filepath.Join("dots", ".config", "fish"),
			Dst:      filepath.Join(xdg.Config, "fish"),
			IsDir:    true,
			Excludes: []string{"conf.d"},
		})
	}

	if selectedConfigs["fontconfig"] {
		mappings = append(mappings, ConfigMapping{
			Src:   filepath.Join("dots", ".config", "fontconfig"),
			Dst:   filepath.Join(xdg.Config, "fontconfig"),
			IsDir: true,
		})
	}

	if selectedConfigs["hyprland"] {
		// Main hyprland config dir
		mappings = append(mappings, ConfigMapping{
			Src:   filepath.Join("dots", ".config", "hypr", "hyprland"),
			Dst:   filepath.Join(xdg.Config, "hypr", "hyprland"),
			IsDir: true,
		})
		// Individual config files
		for _, f := range []string{"hyprlock.conf", "monitors.conf", "workspaces.conf", "hypridle.conf"} {
			mappings = append(mappings, ConfigMapping{
				Src: filepath.Join("dots", ".config", "hypr", f),
				Dst: filepath.Join(xdg.Config, "hypr", f),
			})
		}
		// Custom dir — only if doesn't exist
		customDst := filepath.Join(xdg.Config, "hypr", "custom")
		if _, err := os.Stat(customDst); os.IsNotExist(err) {
			mappings = append(mappings, ConfigMapping{
				Src:   filepath.Join("dots", ".config", "hypr", "custom"),
				Dst:   customDst,
				IsDir: true,
			})
		}
	}

	if selectedConfigs["hyprland-entry"] {
		mappings = append(mappings, ConfigMapping{
			Src: filepath.Join("dots", ".config", "hypr", "hyprland.conf"),
			Dst: filepath.Join(xdg.Config, "hypr", "hyprland.conf"),
		})
	}

	// Icon file (always)
	mappings = append(mappings, ConfigMapping{
		Src: filepath.Join("dots", ".local", "share", "icons", "illogical-impulse.svg"),
		Dst: filepath.Join(xdg.Data, "icons", "illogical-impulse.svg"),
	})

	return mappings
}

// ScanConflicts walks all config mappings and returns files that are new or changed.
func ScanConflicts(repoRoot string, mappings []ConfigMapping) (newFiles []FileConflict, conflicts []FileConflict) {
	for _, m := range mappings {
		srcAbs := filepath.Join(repoRoot, m.Src)

		if m.IsDir {
			scanDirConflicts(srcAbs, m.Dst, m.Excludes, &newFiles, &conflicts)
		} else {
			scanFileConflict(srcAbs, m.Dst, &newFiles, &conflicts)
		}
	}
	return
}

func scanDirConflicts(srcDir, dstDir string, excludes []string, newFiles, conflicts *[]FileConflict) {
	excludeSet := make(map[string]bool)
	for _, e := range excludes {
		excludeSet[e] = true
	}

	filepath.WalkDir(srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			// Check if this directory should be excluded
			if d != nil && d.IsDir() {
				rel, _ := filepath.Rel(srcDir, path)
				if excludeSet[rel] || excludeSet[d.Name()] {
					return filepath.SkipDir
				}
			}
			return err
		}

		rel, _ := filepath.Rel(srcDir, path)
		dstPath := filepath.Join(dstDir, rel)

		scanFileConflict(path, dstPath, newFiles, conflicts)
		return nil
	})
}

func scanFileConflict(srcPath, dstPath string, newFiles, conflicts *[]FileConflict) {
	// Make a nice relative path for display
	home, _ := os.UserHomeDir()
	displayPath := dstPath
	if strings.HasPrefix(dstPath, home) {
		displayPath = "~" + dstPath[len(home):]
	}

	dstInfo, err := os.Stat(dstPath)
	if os.IsNotExist(err) {
		*newFiles = append(*newFiles, FileConflict{
			RelPath: displayPath,
			SrcPath: srcPath,
			DstPath: dstPath,
			IsNew:   true,
		})
		return
	}

	// Compare contents
	if filesIdentical(srcPath, dstPath, dstInfo) {
		return // identical, skip
	}

	diff := generateDiff(srcPath, dstPath, displayPath)
	*conflicts = append(*conflicts, FileConflict{
		RelPath: displayPath,
		SrcPath: srcPath,
		DstPath: dstPath,
		Diff:    diff,
	})
}

func filesIdentical(srcPath, dstPath string, dstInfo os.FileInfo) bool {
	srcInfo, err := os.Stat(srcPath)
	if err != nil {
		return false
	}
	if srcInfo.Size() != dstInfo.Size() {
		return false
	}

	srcData, err := os.ReadFile(srcPath)
	if err != nil {
		return false
	}
	dstData, err := os.ReadFile(dstPath)
	if err != nil {
		return false
	}
	return bytes.Equal(srcData, dstData)
}

func generateDiff(srcPath, dstPath, displayPath string) string {
	// Read both files and produce a simple unified-style diff
	oldData, err := os.ReadFile(dstPath)
	if err != nil {
		return "(could not read existing file)"
	}
	newData, err := os.ReadFile(srcPath)
	if err != nil {
		return "(could not read new file)"
	}

	oldLines := strings.Split(string(oldData), "\n")
	newLines := strings.Split(string(newData), "\n")

	var diff strings.Builder
	diff.WriteString(fmt.Sprintf("--- %s (current)\n", displayPath))
	diff.WriteString(fmt.Sprintf("+++ %s (new)\n", displayPath))

	// Simple line-by-line comparison showing changes
	// For a proper unified diff we'd need a diff algorithm,
	// but a summary of differences is more useful in a TUI
	maxLines := len(oldLines)
	if len(newLines) > maxLines {
		maxLines = len(newLines)
	}

	changes := 0
	var changedLines []string
	for i := 0; i < maxLines; i++ {
		oldLine := ""
		newLine := ""
		if i < len(oldLines) {
			oldLine = oldLines[i]
		}
		if i < len(newLines) {
			newLine = newLines[i]
		}
		if oldLine != newLine {
			changes++
			if changes <= 30 { // cap diff output
				if i < len(oldLines) {
					changedLines = append(changedLines, fmt.Sprintf("- %s", oldLine))
				}
				if i < len(newLines) {
					changedLines = append(changedLines, fmt.Sprintf("+ %s", newLine))
				}
			}
		}
	}

	if changes > 30 {
		diff.WriteString(fmt.Sprintf("(%d lines changed, showing first 30)\n", changes))
	} else {
		diff.WriteString(fmt.Sprintf("(%d lines changed)\n", changes))
	}
	for _, l := range changedLines {
		diff.WriteString(l + "\n")
	}

	return diff.String()
}

// CopyNewFiles copies all files that don't exist at the destination.
func CopyNewFiles(files []FileConflict) error {
	for _, f := range files {
		if err := copyFile(f.SrcPath, f.DstPath); err != nil {
			return fmt.Errorf("copy %s: %w", f.RelPath, err)
		}
	}
	return nil
}

// ApplyConflict overwrites the destination with the source.
func ApplyConflict(c FileConflict) error {
	return copyFile(c.SrcPath, c.DstPath)
}

func copyFile(src, dst string) error {
	// Ensure parent directory exists
	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}

	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	srcInfo, err := srcFile.Stat()
	if err != nil {
		return err
	}

	dstFile, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, srcInfo.Mode())
	if err != nil {
		return err
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	return err
}

// InstallGoogleSansFlex installs the font if not already present.
func InstallGoogleSansFlex(runner *CmdRunner, xdg XDGDirs) error {
	// Check if font is already installed
	out, err := exec.Command("fc-list").Output()
	if err == nil && strings.Contains(strings.ToLower(string(out)), "google sans flex") {
		runner.Log("Google Sans Flex font already installed")
		return nil
	}

	runner.Log("Installing Google Sans Flex font...")
	cacheDir := filepath.Join(runner.repoRoot, "cache", "google-sans-flex")
	targetDir := filepath.Join(xdg.Data, "fonts", "illogical-impulse-google-sans-flex")

	os.MkdirAll(cacheDir, 0755)

	// Clone if not already cached
	if _, err := os.Stat(filepath.Join(cacheDir, ".git")); os.IsNotExist(err) {
		if err := runner.Run("git", "clone", "https://github.com/end-4/google-sans-flex", cacheDir); err != nil {
			return err
		}
	} else {
		runner.RunInDir(cacheDir, "git", "pull", "origin", "main")
	}

	// Copy to target
	os.MkdirAll(targetDir, 0755)
	filepath.WalkDir(cacheDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		if strings.HasSuffix(path, ".ttf") || strings.HasSuffix(path, ".otf") {
			rel, _ := filepath.Rel(cacheDir, path)
			copyFile(path, filepath.Join(targetDir, rel))
		}
		return nil
	})

	runner.Run("fc-cache", "-fv")
	return nil
}
