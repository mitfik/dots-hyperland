# Dependencies → Features Map

## Display & Window Management
| Package | Feature |
|---|---|
| **hyprland** | Wayland compositor / window manager |
| **hyprctl** | Window/workspace control, monitor queries |
| **hypridle** | Idle detection and automatic actions |
| **hyprlock** | Screen locking |
| **hyprsunset** | Night light / blue light filter |
| **hyprpicker** | Color picker tool |
| **hyprshot** | Screenshot wrapper |
| **xdg-desktop-portal, xdg-desktop-portal-hyprland, xdg-desktop-portal-gtk, xdg-desktop-portal-kde** | Desktop integration (screen sharing, file dialogs, etc.) |

## Audio & Media
| Package | Feature |
|---|---|
| **pipewire, pipewire-pulse, wireplumber** | Audio server and session management |
| **pavucontrol-qt** | Audio device/volume GUI |
| **playerctl** | Media player control (play/pause/next/prev) |
| **libdbusmenu-gtk3** | Media tray/MPRIS integration |
| **cava** | Audio visualizer |
| **songrec** | Music recognition (Shazam-like) |
| **wf-recorder** | Screen/region recording |
| **ffmpeg/ffplay** | Video thumbnails, notification sounds |

## Brightness & Display Calibration
| Package | Feature |
|---|---|
| **brightnessctl** | Laptop backlight control |
| **ddcutil** | External monitor brightness via DDC/CI |
| **geoclue** | Location services for auto night-light |

## Screenshots & Screen Capture
| Package | Feature |
|---|---|
| **grim** | Screenshot capture |
| **slurp** | Region selection for screenshots/recording |
| **swappy** | Screenshot annotation/editing |
| **tesseract, tesseract-data-eng** | OCR (extract text from screenshots) |

## Clipboard
| Package | Feature |
|---|---|
| **wl-clipboard** | Wayland copy/paste |
| **cliphist** | Clipboard history management |

## Input Simulation
| Package | Feature |
|---|---|
| **wtype** | Wayland keyboard input simulation |
| **ydotool** | Generic input simulation (clipboard paste, etc.) |

## Theming & Fonts
| Package | Feature |
|---|---|
| **matugen** | Material Design 3 color generation from wallpaper |
| **adw-gtk-theme** | GTK theme |
| **breeze, breeze-plus** | KDE cursor/icon theme |
| **darkly** | Additional theme |
| **bibata-cursor** | Cursor theme |
| **fontconfig** | Font rendering config |
| **ttf-jetbrains-mono-nerd** | Terminal/code font |
| **ttf-material-symbols-variable** | Icon font for widgets |
| **ttf-readex-pro** | UI body font |
| **otf-space-grotesk** | UI heading font |
| **ttf-rubik-vf** | Additional UI font |
| **ttf-twemoji** | Emoji support |

## Shell & Terminal
| Package | Feature |
|---|---|
| **kitty** | Terminal emulator |
| **fish** | Shell |
| **starship** | Shell prompt |
| **eza** | Modern `ls` replacement |
| **fuzzel** | Application launcher |

## KDE Integration
| Package | Feature |
|---|---|
| **bluedevil** | Bluetooth management |
| **plasma-nm, networkmanager** | Network/WiFi management |
| **polkit-kde-agent** | Privilege escalation dialogs |
| **dolphin** | File manager |
| **systemsettings** | KDE system settings |
| **gnome-keyring** | Credential/secret storage |
| **kdialog** | File picker dialogs |

## Quickshell (Widget Engine)
| Package | Feature |
|---|---|
| **qt6-base, qt6-declarative** | QML runtime |
| **qt6-wayland** | Wayland shell integration |
| **qt6-svg, qt6-imageformats** | Image format support |
| **qt6-multimedia** | Media playback in widgets |
| **qt6-5compat** | Qt5 compatibility |
| **kirigami, syntax-highlighting** | KDE Frameworks for UI components |
| **jemalloc, cpptrace** | Performance and debugging |
| **mesa, libdrm, libxcb** | GPU rendering |

## Widgets & Utilities
| Package | Feature |
|---|---|
| **imagemagick** | Image cropping, format conversion, color analysis |
| **glib2** | GSettings for theme management |
| **libqalculate** | Calculator engine |
| **translate-shell** | Text translation |
| **wlogout** | Logout/power menu |
| **upower** | Battery status monitoring |

## Build & CLI Tools
| Package | Feature |
|---|---|
| **cmake** | Building Quickshell and MicroTeX |
| **bc** | Math calculations for layout/scaling |
| **jq, go-yq** | JSON/YAML parsing for configs |
| **curl, wget** | HTTP requests (wallpaper upscaling, downloads) |
| **ripgrep** | Fast text search |
| **rsync** | File synchronization during install |
| **xdg-user-dirs** | XDG directory paths |

## Python Ecosystem
| Package | Feature |
|---|---|
| **uv** | Python package manager |
| **clang** | Build native Python extensions |
| **gtk4, libadwaita, gobject-introspection** | Python GTK bindings |

## Python Packages (sdata/uv/requirements.in)
| Package | Feature |
|---|---|
| **pillow** | Image processing |
| **opencv-contrib-python, numpy** | Advanced image processing, screen translator |
| **materialyoucolor, material-color-utilities** | Material You color palette generation |
| **kde-material-you-colors** | KDE theming integration |
| **libsass** | SASS/CSS compilation |
| **pycairo, pygobject** | GTK/Cairo rendering from Python |
| **psutil** | System process monitoring |
| **pywayland** | Wayland protocol bindings |
| **google-auth, requests** | Google Gemini AI API authentication |
| **tqdm** | Progress bars for scripts |
| **loguru** | Logging framework |
| **setproctitle** | Process naming |

## AI Features (optional)
| External Service | Feature |
|---|---|
| **ollama** (local) | Local LLM inference |
| **Google Gemini API** | AI summarization, shell command generation |
| **OpenAI/Mistral APIs** | Alternative cloud AI models |

## MicroTeX (LaTeX rendering)
| Package | Feature |
|---|---|
| **tinyxml2, gtkmm3, gtksourceviewmm, cairomm** | Build dependencies for LaTeX math rendering in widgets |
