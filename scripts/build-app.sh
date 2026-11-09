#!/bin/sh
# Builds Gridle.app, signs it with your Apple Development certificate, installs it
# to ~/Applications. Run it again after any code change; the permission survives.
set -eu
cd "$(dirname "$0")/.."

swift build -c release
APP=.build/Gridle.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Gridle "$APP/Contents/MacOS/Gridle"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Never sign ad hoc: each ad-hoc build looks like a new app to macOS and loses the
# Accessibility permission. A real certificate keeps the same identity every build.
ID=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')
if [ -z "$ID" ]; then
  echo "No Apple Development certificate found; refusing to sign ad hoc." >&2
  exit 1
fi
codesign --force --sign "$ID" "$APP"

pkill -x Gridle 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Gridle.app"
cp -R "$APP" "$HOME/Applications/Gridle.app"
echo "Installed ~/Applications/Gridle.app (signed: $ID)"

# Start the new build. LaunchServices needs a moment after the copy, so retry briefly.
for _ in 1 2 3 4 5; do
  if open "$HOME/Applications/Gridle.app" 2>/dev/null; then echo "Gridle restarted."; exit 0; fi
  sleep 1
done
echo "Built, but could not start Gridle; open it from ~/Applications." >&2
