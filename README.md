# Hue Control - macOS Menubar App

A sleek macOS menubar app to control your Philips Hue lights. Perfect for macro pad keyboards!

![Hue Control](screenshot.png)

## Features

- 🎛️ **Menubar Access** — Always one click away
- 💡 **Quick Actions** — All On, All Off, Party Mode, Warm White
- ⌨️ **Macro Pad Support** — Global hotkeys for F13-F16
- 🔄 **Live Status** — See light states in real-time
- 🎨 **Native SwiftUI** — Feels like a real Mac app

## Requirements

- macOS 12.0 (Monterey) or later
- Philips Hue Bridge on your network
- Xcode 13+ (to build)

## Setup

### 1. Get Your Hue Bridge API Key

Run the setup script:

```bash
cd HueControl
python3 setup_bridge.py
```

Then press the **physical button** on your Hue Bridge when prompted.

### 2. Update the Config

Open `HueControl/HueControlApp.swift` and update:

```swift
struct HueConfig {
    static let bridgeIP = "192.168.50.228"  // Your bridge IP
    static let apiKey = "YOUR-API-KEY-HERE" // From setup script
}
```

### 3. Build & Run

```bash
swift build
swift run
```

Or open in Xcode and build with ⌘+R

## Macro Pad Hotkeys

The app registers global hotkeys for:

| Key | Action |
|-----|--------|
| **F13** | All Lights On |
| **F14** | All Lights Off |
| **F15** | Party Mode 🎉 |
| **F16** | Warm White |

Map these in your macro pad software to control lights instantly!

## Customization

### Adding More Hotkeys

Edit `setupHotkeys()` in `HueControlApp.swift`:

```swift
(key: 0x70, action: { [weak self] in self?.hueService.someCustomAction() })
```

Common key codes:
- F13: `0x69`
- F14: `0x6B`
- F15: `0x71`
- F16: `0x6A`
- F17: `0x40`
- F18: `0x4F`
- F19: `0x50`

### Adding Scenes

Add new methods to `HueService`:

```swift
func movieMode() {
    lights.forEach { light in
        setLightState(id: light.id, on: true, brightness: 50)
        // Set warm orange color
    }
}
```

## Architecture

```
HueControl/
├── HueControlApp.swift    # Main app + hotkey handling
├── Info.plist             # App configuration
└── setup_bridge.py        # Bridge discovery & auth
```

## Future Ideas

- [ ] Custom scenes editor
- [ ] Brightness sliders
- [ ] Color picker
- [ ] Schedule/automation
- [ ] Apple Shortcuts integration

---

Built with ❤️ for SimonM
