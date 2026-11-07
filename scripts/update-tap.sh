#!/bin/sh
# Writes the Homebrew cask for a released version of Panes into the tap clone, then commits and pushes.
# Run after scripts/release.sh <version> --publish (the GitHub release must exist: brew downloads from it).
# Usage: sh scripts/update-tap.sh 0.1.0 [tap-folder]   (default tap folder: ../homebrew-tap)
set -eu
cd "$(dirname "$0")/.."
version=${1:?usage: sh scripts/update-tap.sh <version> [tap-folder]}
tap=${2:-../homebrew-tap}
zip=dist/Panes-$version.zip
[ -f "$zip" ] || { echo "No $zip - run scripts/release.sh $version first." >&2; exit 1; }
sha=$(shasum -a 256 "$zip" | awk '{ print $1 }')
mkdir -p "$tap/Casks"
cat > "$tap/Casks/panes.rb" <<CASK
cask "panes" do
  version "$version"
  sha256 "$sha"

  url "https://github.com/joyahmed/panes/releases/download/v#{version}/Panes-#{version}.zip"
  name "Panes"
  desc "Snap windows from the keyboard or by dragging to an edge"
  homepage "https://github.com/joyahmed/panes"

  depends_on macos: :sonoma

  app "Panes.app"

  zap trash: "~/Library/Preferences/com.joyahmed.panes.plist"
end
CASK
# The URL must serve exactly the zip we hashed, or brew refuses the install.
remote=$(curl -fsSL "https://github.com/joyahmed/panes/releases/download/v$version/Panes-$version.zip" | shasum -a 256 | awk '{ print $1 }')
[ "$remote" = "$sha" ] || { echo "The release zip on GitHub does not match $zip - not updating the tap." >&2; exit 1; }
cd "$tap"
git add Casks/panes.rb
git commit -m "✅TAP: Panes $version" -m "Cask points at the GitHub release v$version, sha256 $sha (checked against the downloaded zip)."
git push
echo "Tap updated: brew install joyahmed/tap/panes"
