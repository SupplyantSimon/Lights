# Simon's Lights - macOS Menubar App

A macOS menubar app to control all your lights: Hue lights (Unit, TV Left, BigBoy) + Monkey Tuya light. With macro pad support, voice control, and a color picker!

## Features

- 🎛️ **Menubar Access** — Always one click away
- 💡 **Quick Actions** — All On, All Off, Party Mode, Movie Mode
- 🎨 **Color Picker** — 9 preset colors, click or cycle through
- 🐵 **Monkey Light** — Tuya/Smart Life integration
- 🎤 **Voice Control** — Say commands like "All on", "Party", "Blue"
- ⌨️ **Macro Pad Support** — Global hotkeys (B, C, D, E + F-keys)
- 🔄 **Live Status** — See all light states in real-time

## Requirements

- macOS 12.0 (Monterey) or later
- Philips Hue Bridge on your network
- Swift/Xcode Command Line Tools
- Python 3 (for Monkey light control)

## Quick Start

### 1. Clone the Repo

```bash
git clone https://github.com/simonm/simons-lights.git
cd simons-lights
```

Or download and extract the bundle.

### 2. Set Up Environment

Add to your `~/.zshrc`:

```bash
export TUYA_PASSWORD="your-tuya-password"
```

Then reload:

```bash
source ~/.zshrc
```

### 3. Build the App

```bash
chmod +x build.sh
./build.sh
```

This creates "Simon's Lights.app" in the HueControl folder.

### 4. Install

```bash
cp -r "HueControl/Simon's Lights.app" /Applications/
```

Or just run it directly:

```bash
open "HueControl/Simon's Lights.app"
```

## Macro Pad Setup

Edit `HueControl/config.json` to customize hotkeys:

```json
{
  "hotkeys": {
    "allOn": "b",
    "allOff": "c",
    "partyMode": "d",
    "movieMode": "e",
    "monkeyToggle": "f17",
    "bigboyToggle": "f18",
    "colorCycle": "f19",
    "voiceMode": "f20"
  }
}
```

Supported keys: a-z, 0-9, f1-f20, left, right, up, down, space, return, tab

## Voice Commands

Press the mic button or F20, then say:

- **"All on"** / **"Lights on"** — Turn everything on
- **"All off"** / **"Lights off"** — Turn everything off
- **"Party"** — Party mode (multi-color)
- **"Movie"** / **"Dim"** — Dim all lights
- **"Monkey on"** / **"Monkey off"** — Toggle Monkey light
- **"BigBoy on"** / **"BigBoy off"** — Toggle BigBoy light
- **"White"** / **"Red"** / **"Blue"** / **"Green"** — Set color

## Lights

| Light | Type | Location |
|-------|------|----------|
| Unit | Hue | Right side |
| TV Left | Hue | Left side |
| BigBoy | Hue | BigBoy |
| Monkey | Tuya | Monkey |

## Configuration

Edit `HueControl/config.json`:

```json
{
  "bridgeIP": "192.168.50.228",
  "apiKey": "your-hue-api-key",
  "tuya": {
    "username": "simon@supplyant.com",
    "region": "eu",
    "platform": "smart_life"
  },
  "colors": [
    {"name": "White", "hue": 0, "sat": 0},
    {"name": "Red", "hue": 0, "sat": 254},
    ...
  ]
}
```

## Development

### Project Structure

```
SimonsLights/
├── HueControl/
│   ├── HueControlApp.swift    # Main SwiftUI app
│   ├── config.json            # User configuration
│   ├── control_monkey.py      # Tuya light controller
│   ├── Info.plist            # App metadata
│   └── Package.swift         # Swift Package Manager
├── build.sh                  # Build script
└── README.md
```

### Building Manually

```bash
cd HueControl
swift build -c release
```

### Adding Voice Commands

Edit `handleVoiceCommand()` in `HueControlApp.swift`:

```swift
if lower.contains("your command") {
    // Do something
    showNotification(title: "Voice", message: "Did something")
}
```

## Troubleshooting

### "App is damaged" error

Run:

```bash
xattr -cr "/Applications/Simon's Lights.app"
codesign --force --deep --sign - "/Applications/Simon's Lights.app"
```

### Microphone permission denied

Go to System Preferences → Security & Privacy → Microphone → Enable "Simon's Lights"

### Monkey light not working

Check that `control_monkey.py` is in the same folder as the app, and that `TUYA_PASSWORD` is set in your environment.

## License

MIT — Built with ❤️ for SimonM
