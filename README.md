# FloatingTimer

A sleek, always-on-top countdown timer for macOS. Perfect for presentations, teaching, and time management.

![FloatingTimer Screenshot](docs/screenshot.png)

## Features

- **Always on top** - Stays visible over ALL apps, including Keynote presentation mode
- **Drag anywhere** - Position it flush against any corner or anywhere on screen
- **Click to edit** - Tap minutes or seconds to set custom time
- **Tab navigation** - Tab between minutes and seconds fields
- **Visual warnings** - Background changes as time runs low
- **Alarm sound** - Repeating alert when timer ends (click to dismiss)
- **Resizable** - Use +/- buttons or arrow keys to resize
- **Transparent design** - Semi-transparent background, smooth rounded corners

## Installation

1. Download the latest release from the [Releases page](https://github.com/victordelrosal/FloatingTimer/releases)
2. Unzip and drag `FloatingTimer.app` to your Applications folder
3. **Important:** Remove the quarantine flag (required for unsigned apps):
   ```bash
   xattr -cr /Applications/FloatingTimer.app
   ```
4. Double-click to run

> **Note:** macOS may show "app is damaged" for unsigned apps downloaded from the internet. The `xattr -cr` command removes the quarantine flag and allows the app to run.

## Usage

- **Set time**: Click on minutes or seconds, type a value, press Enter or click outside
- **Start/Stop**: Click the green play button (or pause when running)
- **Reset**: Click the reset button
- **Resize**: Use +/- buttons in top-right, or arrow keys
- **Move**: Drag anywhere on the timer
- **Dismiss alarm**: Click anywhere on the timer when alarm is playing
- **Quit**: Click the X in top-left corner

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Tab | Move between minutes/seconds fields |
| Enter | Confirm time entry |
| Escape | Cancel time entry |
| ← / - | Decrease size |
| → / + | Increase size |

## Building from Source

Requires macOS and Xcode command line tools.

```bash
cd src
./build.sh
```

## License

MIT License - Feel free to use, modify, and distribute.

## Author

Created by Victor del Rosal
