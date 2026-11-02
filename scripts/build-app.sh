#!/bin/sh
# Builds Panes.app, signs it with your Apple Development certificate, installs it
# to ~/Applications. Run it again after any code change; the permission survives.
set -eu
cd "$(dirname "$0")/.."

swift build -c release
APP=.build/Panes.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Panes "$APP/Contents/MacOS/Panes"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Never sign ad hoc: each ad-hoc build looks like a new app to macOS and loses the
# Accessibility permission. A real certificate keeps the same identity every build.
ID=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')
if [ -z "$ID" ]; then
  echo "No Apple Development certificate found; refusing to sign ad hoc." >&2
  exit 1
fi
codesign --force --sign "$ID" "$APP"

pkill -x Panes 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Panes.app"
cp -R "$APP" "$HOME/Applications/Panes.app"
echo "Installed ~/Applications/Panes.app (signed: $ID)"

# Start the new build. LaunchServices needs a moment after the copy, so retry briefly.
for _ in 1 2 3 4 5; do
  if open "$HOME/Applications/Panes.app" 2>/dev/null; then echo "Panes restarted."; exit 0; fi
  sleep 1
done
echo "Built, but could not start Panes; open it from ~/Applications." >&2
