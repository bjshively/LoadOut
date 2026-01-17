# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LoadOut is a native macOS menu bar utility for saving and restoring window layouts. It uses SwiftUI with AppKit integration, targeting macOS 13.0+. The app captures window positions via the Accessibility API and can restore them along with launching associated apps and URLs.

## Build Commands

```bash
# Build debug (from project root)
xcodebuild -project LoadOut.xcodeproj -scheme LoadOut -configuration Debug

# Build release
xcodebuild -project LoadOut.xcodeproj -scheme LoadOut -configuration Release

# Archive for distribution (creates notarizable archive)
xcodebuild -project LoadOut.xcodeproj -scheme LoadOut archive -archivePath build/LoadOut.xcarchive

# Export with notarization settings
xcodebuild -exportArchive -archivePath build/LoadOut.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

No automated test suite exists. Manual testing is required.

## Architecture

### Core Components

**LoadOutApp.swift** - Entry point. Defines the WindowGroup scene and creates AppDelegate which initializes WindowManager and MenuBarController.

**WindowManager.swift** - Central ObservableObject that manages all state and business logic:
- `runningApps`: Discovered apps with visible windows (via NSWorkspace + Accessibility API)
- `presets`: Saved window layouts (persisted to UserDefaults as JSON)
- Handles window capture/restore via AXUIElement accessibility APIs
- Manages settings: launch at login (SMAppService), dock icon visibility, onboarding state

**ContentView.swift** - Main SwiftUI UI with two-panel layout:
- Left: Running apps list with selection checkboxes
- Right: Saved presets with drag-to-reorder
- Modal sheets for: onboarding, save preset, edit preset, settings

**MenuBarController.swift** - NSStatusBar menu providing quick preset access and app window management.

**BlueprintTheme.swift** - Design system with colors (deep/mid/light blues, cyan accent), typography (SF Mono/SF Pro), and reusable components (buttons, toggles, grid backgrounds, toast notifications).

### Data Flow

```
NSWorkspace → WindowManager.refreshRunningApps() → runningApps (Published)
                     ↓
User selects apps → savePreset() → presets (Published) → UserDefaults
                     ↓
applyPreset() → AXUIElement window positioning + NSWorkspace app launching
```

### Key Patterns

- **MVVM**: WindowManager as ViewModel, ContentView as View
- **Reactive**: @Published properties drive automatic UI updates
- **Combine**: AppDelegate subscribes to `windowManager.$presets` for menu updates

### System Integration

- **Accessibility API (AXUIElement)**: Reads/writes window position, size, minimized/fullscreen state. Requires user permission.
- **NSWorkspace**: App discovery, launching apps/files/URLs
- **ServiceManagement (SMAppService)**: Launch at login registration
- **CGEvent**: Keyboard simulation for exiting fullscreen (Cmd+Ctrl+F)

### Data Models (in WindowManager.swift)

- `RunningApp`: PID, name, bundleID, icon, isSelected
- `WindowInfo`: App identifier, position, size, dimensions, windowTitle, windowIndex (Codable)
- `LaunchItem`: URL or file path to open with preset (Codable)
- `Preset`: Name, array of WindowInfo, array of LaunchItem (Codable)

## Important Implementation Details

- App is not sandboxed (required for Accessibility API window control)
- Window positioning includes retry logic with exponential backoff for app startup delays
- Fullscreen detection uses both AXUIElement attributes and screen bounds comparison as fallback
- `adjustWindowInfoForCurrentScreens()` validates positions against current display configuration
- Presets are reorderable via drag-and-drop, order persists to UserDefaults
- Multiple windows per app are supported via `windowTitle` and `windowIndex` fields with score-based matching
- Multi-display preview uses `ScreenConfiguration` to properly render windows across all connected monitors
