#!/bin/sh
# Builds a release of Gridle that anyone can download and open:
#   signed with a Developer ID certificate, hardened runtime, notarized by Apple, ticket stapled,
#   zipped as dist/Gridle-<version>.zip, checked with Gatekeeper.
# Usage: sh scripts/release.sh 0.1.0 [--publish]
#   --publish also creates the GitHub release on joyahmed/gridle with the zip attached.
#
# One-time setup on this Mac (needs the Apple team; see docs/commercial-plan.md Phase F):
#   1. Xcode signed in to an Apple account on team AXMUG2K6X2 that has "Access to Cloud Managed
#      Developer ID Certificate". Signing goes through Xcode's export, so Apple's cloud holds the
#      key and nothing is needed in the keychain. (Works since 2026-11-04.)
#   2. Nothing else: the same Xcode export uploads the app to Apple's notary service with Xcode's
#      signed-in account, so no notarytool password or API key is stored anywhere.
#
# If Apple is slow (a new team's first check took over 15 minutes on 2026-11-04), the script stops
# after 60 minutes but keeps the upload. Finish it later without building or uploading again:
#   GRIDLE_RESUME=<folder it printed> sh scripts/release.sh 0.1.0 [--publish]
set -eu
cd "$(dirname "$0")/.."
version=${1:?usage: sh scripts/release.sh <version> [--publish]}
publish=${2:-}

team=AXMUG2K6X2

# This folder with Pro code builds the Pro edition. Only the free copy may go on the public release.
if [ "$publish" = "--publish" ] && [ -d Sources/GridleCore/Pro ]; then
  echo "Refusing: this is the Pro code. Run --publish from the public clone (scripts/export-public.sh)." >&2
  exit 1
fi

if [ -n "${GRIDLE_RESUME:-}" ]; then
  work=$GRIDLE_RESUME
  archive=$work/Gridle.xcarchive
  [ -d "$archive" ] || { echo "No archive in $work." >&2; exit 1; }
else
sh scripts/verify.sh

swift build -c release
# Xcode's export signs with the cloud-managed Developer ID certificate. It needs an archive, so we
# make a minimal one around the app SwiftPM built.
work=$(mktemp -d)
archive=$work/Gridle.xcarchive
inner=$archive/Products/Applications/Gridle.app
mkdir -p "$inner/Contents/MacOS"
cp .build/release/Gridle "$inner/Contents/MacOS/Gridle"
cp Resources/Info.plist "$inner/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$inner/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(git rev-list --count HEAD)" "$inner/Contents/Info.plist"
bundle_id=$(plutil -extract CFBundleIdentifier raw "$inner/Contents/Info.plist")
# Ad-hoc sign with the hardened runtime first: the export keeps that flag, and notarization needs it.
codesign --force --options runtime --sign - "$inner"
cat > "$archive/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>ApplicationProperties</key><dict>
    <key>ApplicationPath</key><string>Applications/Gridle.app</string>
    <key>CFBundleIdentifier</key><string>$bundle_id</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>Team</key><string>$team</string>
  </dict>
  <key>ArchiveVersion</key><integer>2</integer>
  <key>Name</key><string>Gridle</string>
</dict></plist>
PLIST
cat > "$work/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>upload</string>
</dict></plist>
PLIST
# Signs with Developer ID AND sends it to Apple's notary service.
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$work/export.plist" \
  -exportPath "$work/up" -allowProvisioningUpdates
fi
# Fetch the approved, stapled app. Apple usually answers in 1-5 minutes; give up after 60.
tries=0
until xcodebuild -exportNotarizedApp -archivePath "$archive" -exportPath "$work/out" >"$work/notary.log" 2>&1; do
  tries=$((tries + 1))
  if [ "$tries" -ge 120 ]; then
    tail -3 "$work/notary.log" >&2
    echo "Apple has not approved it after 60 minutes. The upload is kept; finish later with:" >&2
    echo "  GRIDLE_RESUME=$work sh scripts/release.sh $version $publish" >&2
    exit 1
  fi
  rm -rf "$work/out"; sleep 30
done
app=dist/Gridle.app
rm -rf dist && mkdir -p dist
ditto "$work/out/Gridle.app" "$app"
rm -rf "$work"

# Must say Developer ID and hardened runtime.
codesign -dv --verbose=2 "$app" 2>&1 | grep -q "Authority=Developer ID Application" || { echo "Not signed with Developer ID." >&2; exit 1; }
codesign -dv "$app" 2>&1 | grep -q "(runtime)" || { echo "Hardened runtime is off." >&2; exit 1; }
codesign --verify --deep --strict --verbose=2 "$app"   # every executable inside, not just the outer bundle

zip=dist/Gridle-$version.zip
xcrun stapler validate "$app"   # the approval ticket is inside the app
ditto -c -k --keepParent "$app" "$zip"

# What a downloader's Mac will say: must be "accepted" and "Notarized Developer ID".
spctl --assess --type execute --verbose=2 "$app" 2>&1 | tee /dev/stderr | grep -q "Notarized Developer ID" || {
  echo "Gatekeeper does not accept the app - do not publish." >&2
  exit 1
}
# Act like a download: unzip the FINAL zip into a fresh folder with the quarantine flag a browser
# sets, then ask Gatekeeper again. This is the file people get, not the copy that was signed here.
check=$(mktemp -d)
cp "$zip" "$check/"
xattr -w com.apple.quarantine "0081;$(printf %x "$(date +%s)");Safari;" "$check/$(basename "$zip")"
ditto -x -k "$check/$(basename "$zip")" "$check"
# ditto does not carry the flag from the zip to what it unzips (Safari's unzip does), so set it here.
xattr -w -r com.apple.quarantine "0081;$(printf %x "$(date +%s)");Safari;" "$check/Gridle.app"
spctl --assess --type execute --verbose=2 "$check/Gridle.app" 2>&1 | grep -q "Notarized Developer ID" || {
  echo "The downloaded copy is refused by Gatekeeper - do not publish." >&2
  exit 1
}
xcrun stapler validate "$check/Gridle.app"
rm -rf "$check"
echo "Downloaded-copy check passed. Still needed before announcing: one person installs it on a Mac with no Xcode."
shasum -a 256 "$zip"

if [ "$publish" = "--publish" ]; then
  gh release create "v$version" "$zip" -R joyahmed/gridle --title "Gridle $version" \
    --notes "Download Gridle-$version.zip, unzip, move Gridle to Applications and open it. macOS asks once to let Gridle control your computer (Accessibility); that is how any window manager moves windows."
fi
echo "Release ready: $zip"
