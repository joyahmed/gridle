#!/bin/sh
# Builds a release of Panes that anyone can download and open:
#   signed with a Developer ID certificate, hardened runtime, notarized by Apple, ticket stapled,
#   zipped as dist/Panes-<version>.zip, checked with Gatekeeper.
# Usage: sh scripts/release.sh 0.1.0 [--publish]
#   --publish also creates the GitHub release on joyahmed/panes with the zip attached.
#
# One-time setup on this Mac (needs the Apple team; see docs/commercial-plan.md Phase F):
#   1. A "Developer ID Application" certificate in the login keychain (from the Account Holder,
#      or cloud-managed through Xcode once that permission is on).
#   2. Notary credentials stored in the keychain under the name panes-notary, e.g. with an
#      App Store Connect API key (Users and Access -> Integrations -> Team Keys):
#        xcrun notarytool store-credentials panes-notary --key AuthKey_XXXX.p8 --key-id XXXX --issuer <issuer-id>
set -eu
cd "$(dirname "$0")/.."
version=${1:?usage: sh scripts/release.sh <version> [--publish]}
publish=${2:-}

identity=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ { print $2; exit }')
if [ -z "$identity" ]; then
  echo "No 'Developer ID Application' certificate in the keychain yet - see the setup notes at the top." >&2
  exit 1
fi
xcrun notarytool history --keychain-profile panes-notary >/dev/null 2>&1 || {
  echo "No notary credentials named panes-notary - see the setup notes at the top." >&2
  exit 1
}

sh scripts/verify.sh

swift build -c release
app=dist/Panes.app
rm -rf dist && mkdir -p "$app/Contents/MacOS"
cp .build/release/Panes "$app/Contents/MacOS/Panes"
cp Resources/Info.plist "$app/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(git rev-list --count HEAD)" "$app/Contents/Info.plist"

# Hardened runtime + secure timestamp: both required for notarization.
codesign --force --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"   # every executable inside, not just the outer bundle

zip=dist/Panes-$version.zip
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile panes-notary --wait
xcrun stapler staple "$app"
rm -f "$zip" && ditto -c -k --keepParent "$app" "$zip"   # zip again, now with the ticket inside

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
spctl --assess --type execute --verbose=2 "$check/Panes.app" 2>&1 | grep -q "Notarized Developer ID" || {
  echo "The downloaded copy is refused by Gatekeeper - do not publish." >&2
  exit 1
}
xcrun stapler validate "$check/Panes.app"
rm -rf "$check"
echo "Downloaded-copy check passed. Still needed before announcing: one person installs it on a Mac with no Xcode."
shasum -a 256 "$zip"

if [ "$publish" = "--publish" ]; then
  gh release create "v$version" "$zip" -R joyahmed/panes --title "Panes $version" \
    --notes "Download Panes-$version.zip, unzip, move Panes to Applications and open it. macOS asks once to let Panes control your computer (Accessibility); that is how any window manager moves windows."
fi
echo "Release ready: $zip"
