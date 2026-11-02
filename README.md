<p align="center">
  <img src="media/banner.png" alt="Panes: Windows-style window snapping for Mac" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-0b1320?style=for-the-badge&logo=apple&logoColor=5fb4ff" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-native-0b1320?style=for-the-badge&logo=swift&logoColor=5fb4ff" alt="Native Swift">
  <img src="https://img.shields.io/badge/license-GPL%20v3-0b1320?style=for-the-badge&labelColor=0b1320&color=1d4f86" alt="GPL v3">
  <img src="https://img.shields.io/badge/price-free-0b1320?style=for-the-badge&labelColor=0b1320&color=1d7fd6" alt="Free">
</p>

<p align="center">
  <img src="media/demo-free.gif" alt="Panes snapping windows to halves, corners and thirds, then showing the desktop" width="100%">
</p>

I used Windows for years. <kbd>Win</kbd> + <kbd>←</kbd> to snap a window, <kbd>Win</kbd> + <kbd>D</kbd> to see my
desktop, and I never thought about it. Then I moved to a Mac with a Windows keyboard, and window
management became the thing I fought with every day.

So I built **Panes**: a small, free menu-bar app, written in Swift, that moves windows the way my
hands already expect.

## ⌨️ What it does

Every key is <kbd>Ctrl</kbd> + <kbd>Alt</kbd> plus one more key. On a Windows keyboard that's exactly what's printed on
the keys, so Panes shows them that way too: **Ctrl+Alt+←**, not Mac symbols.

| Keys | What happens |
|---|---|
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>←</kbd> / <kbd>→</kbd> | 🟦 left half / right half |
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>↑</kbd> / <kbd>↓</kbd> | 🟦 top half / bottom half |
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>Return</kbd> | ⬜ fill the screen |
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>C</kbd> | ⬜ center |
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>U</kbd> <kbd>I</kbd> <kbd>J</kbd> <kbd>K</kbd> | 🟧 top-left, top-right, bottom-left, bottom-right |
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>1</kbd> <kbd>2</kbd> <kbd>3</kbd> | 🟪 left, middle, right third |
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>D</kbd> | 🖥️ show desktop, like <kbd>Win</kbd> + <kbd>D</kbd>. Press again and exactly the apps it hid come back |
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>N</kbd> | ↪️ send the window to the next screen |

Or drag a window by its title bar to a screen edge, like on Windows: left or right edge for a half,
a corner for a quarter, the top edge to fill the screen. A preview shows where it'll land before
you let go.

### ✨ A few things I cared about

- **Small windows behave.** Some windows refuse to resize, like a settings window. Panes still puts
  them in the corner you asked for, and `Up` only moves them up. It doesn't slide them to the middle.
- **Every key can change.** Settings → Keys, click a key, press a new combination. Panes refuses a
  combination that's already taken and tells you which action has it.
- **An ignore list** for apps you never want moved.
- **Gaps** between windows, from 0 to 24 points.

Open Panes again from Spotlight while it's running and Settings comes up.

There's also a Pro edition with automatic stacking and saved layouts. This repo is the free one, and
it stays free.

## 📦 Install

Build it from source. You need macOS 14 or newer and Xcode.

```
git clone https://github.com/joyahmed/panes.git
cd panes
sh scripts/build-app.sh
```

That builds `Panes.app`, signs it with your Apple Development certificate, puts it in
`~/Applications`, and starts it. The first time, macOS asks to let Panes control your computer:
turn it on in System Settings → Privacy & Security → Accessibility. That's how any window manager
moves other apps' windows.

If you use Rectangle, quit it first. It uses the same keys.

## ✅ Checking it

```
sh scripts/verify.sh
```

Build, unit tests and the style check, in a few seconds. The window math lives in its own module
(`PanesCore`) with no Mac UI code in it, so it's tested without moving a single window.

```
open -n -W --stdout /tmp/panes-selftest.txt ~/Applications/Panes.app --args --selftest
```

The self-test opens its own test windows and moves them through every snap, including a window
that can't resize. It never touches your real windows.

## 🐞 Found a problem?

Open an issue with your macOS version, how many screens you have, and which app's window misbehaved.

## 📄 License

Copyright (C) 2026 Joy Ahmed. Panes is free software under the GNU General Public License v3:
you can use it, change it and share it, and any copy you share stays under the same license.
See [LICENSE](LICENSE).
