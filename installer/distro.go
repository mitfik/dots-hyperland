package main

import (
	"os"
	"runtime"
	"strings"
)

// DistroInfo holds detected distribution details.
type DistroInfo struct {
	ID        string // e.g. "arch", "endeavouros", "fedora"
	IDLike    string // ID_LIKE field from os-release
	Name      string // PRETTY_NAME
	GroupID   string // classified: "arch" or "unsupported"
	Arch      string // machine architecture
	Supported bool   // true only for arch-based
}

// DetectDistro reads /etc/os-release and classifies the system.
func DetectDistro() DistroInfo {
	info := DistroInfo{Arch: runtime.GOARCH}

	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		info.ID = "unknown"
		info.Name = "Unknown Distribution"
		info.GroupID = "unsupported"
		return info
	}

	for _, line := range strings.Split(string(data), "\n") {
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		val = strings.Trim(val, "\"")
		switch key {
		case "ID":
			info.ID = val
		case "ID_LIKE":
			info.IDLike = val
		case "PRETTY_NAME":
			info.Name = val
		}
	}

	if info.ID == "" {
		info.ID = "unknown"
	}
	if info.Name == "" {
		info.Name = info.ID
	}

	// Classify into group
	archIDs := map[string]bool{"arch": true, "endeavouros": true, "cachyos": true}
	if archIDs[info.ID] || strings.Contains(info.IDLike, "arch") {
		info.GroupID = "arch"
		info.Supported = true
	} else {
		info.GroupID = "unsupported"
		info.Supported = false
	}

	return info
}
