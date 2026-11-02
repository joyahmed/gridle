#!/bin/sh
# Records Panes's hands-free demo and turns it into:
#   media/demo-free.gif          for the README (free features only)
#   media/short-<edition>.mp4    a 1080 x 1920 vertical video for YouTube Shorts
# Usage: sh scripts/record-demo.sh [free|pro]      (default: free)
#
# Needs: Panes installed (sh scripts/build-app.sh), ffmpeg, python3 with Pillow, and Screen
# Recording allowed for the app running this script (System Settings → Privacy & Security →
# Screen & System Audio Recording). The demo hides your other apps for about 30 s and brings
# exactly those back.
set -eu
cd "$(dirname "$0")/.."
edition=${1:-free}
flag=--demo-free
[ "$edition" = pro ] && flag=--demo
mkdir -p media
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT   # the raw recording shows the whole screen; never leave it behind
raw=$work/demo.mov

if ! screencapture -x "$raw.png" 2>/dev/null; then
  echo "Screen recording is not allowed for this terminal yet." >&2
  echo "System Settings → Privacy & Security → Screen & System Audio Recording → turn it on, then run again." >&2
  exit 1
fi
rm -f "$raw.png"

# ⛔ A full-screen app (like a full-screen terminal) sits on its own Space: the demo windows then
# open on the desktop out of sight and the recording shows that app instead - private text
# included. Take every app out of full screen first.
echo "Recording starts in 5 s. No app may be in full screen (the demo windows would be hidden)."
sleep 5

# Record the main display while the demo plays; stop the recording when the demo ends.
# The running Panes could rearrange the demo windows; quit it and start it again afterwards.
was_running=0
if pgrep -x Panes >/dev/null; then was_running=1; pkill -x Panes; sleep 1; fi
# The demo and this script take turns through files in $work/signals, so the recording holds
# only the demo: it starts after the demo has hidden every app ("ready") and stops before the
# demo brings them back ("done" -> "stopped").
sig=$work/signals
mkdir -p "$sig"
# Through `open`, so macOS checks Panes's own Accessibility permission, not the terminal's.
open -n -W --env "PANES_DEMO_SIGNALS=$sig" --stdout "$work/demo.log" ~/Applications/Panes.app --args "$flag" &
demo=$!
i=0; while [ ! -e "$sig/ready" ] && [ $i -lt 300 ]; do sleep 0.1; i=$((i+1)); done
[ -e "$sig/ready" ] || { kill "$demo" 2>/dev/null; echo "The demo never got ready." >&2; exit 1; }
screencapture -v -x "$raw" &
rec=$!
sleep 1
touch "$sig/recording"
i=0; while [ ! -e "$sig/done" ] && [ $i -lt 900 ]; do sleep 0.1; i=$((i+1)); done
kill -INT "$rec" 2>/dev/null || true
wait "$rec" 2>/dev/null || true
touch "$sig/stopped"
wait "$demo" 2>/dev/null || true
grep -q "DEMO DONE" "$work/demo.log" || { echo "The demo did not finish:" >&2; cat "$work/demo.log" >&2; exit 1; }
if [ "$was_running" = 1 ]; then
  # macOS needs a moment after the demo quits before it opens Panes again.
  for _ in 1 2 3 4 5; do open ~/Applications/Panes.app 2>/dev/null && break; sleep 1; done
fi
[ -s "$raw" ] || { echo "The recording is empty." >&2; exit 1; }

# README GIF: 960 wide, 15 frames a second, its own colour palette so it stays sharp.
gif=media/demo-$edition.gif
ffmpeg -loglevel error -y -i "$raw" -vf "crop=iw:ih-40:0:40,fps=15,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" "$gif"

# YouTube Short: screen scaled to 1000 wide (40 px margin each side) in the middle of a 1080 x 1920 frame, a title
# above and a line below, drawn by Pillow (this ffmpeg has no text filter).
cards=$work
python3 - "$cards" "$edition" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
out, edition = sys.argv[1], sys.argv[2]
def font(size):
    for path in ("/System/Library/Fonts/HelveticaNeue.ttc", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(path, size, index=1)
        except Exception:
            pass
    return ImageFont.load_default()
img = Image.new("RGBA", (1080, 1920), (11, 19, 32, 255))
d = ImageDraw.Draw(img)
def centre(text, y, size, fill):
    f = font(size)
    w = d.textlength(text, font=f)
    d.text(((1080 - w) / 2, y), text, font=f, fill=fill)
centre("Windows-style window", 300, 84, (230, 238, 248, 255))
centre("snapping for Mac", 400, 84, (230, 238, 248, 255))
centre("Ctrl + Alt + arrows  ·  Win+D  ·  drag to edge", 560, 40, (95, 180, 255, 255))
centre("Panes", 1380, 96, (230, 238, 248, 255))
line = "Free on GitHub: joyahmed/panes" if edition == "free" else "Free + Pro · joyahmed/panes"
centre(line, 1510, 44, (147, 164, 187, 255))
img.save(f"{out}/frame.png")
PY
short=media/short-$edition.mp4
ffmpeg -loglevel error -y -loop 1 -i "$cards/frame.png" -i "$raw" -filter_complex \
  "[1:v]crop=iw:ih-40:0:40,scale=1000:-2:flags=lanczos[s];[0:v][s]overlay=40:(H-h)/2:shortest=1,format=yuv420p" \
  -r 30 -c:v libx264 -crf 20 -preset slow -movflags +faststart -an "$short"

echo "GIF:   $gif ($(du -h "$gif" | cut -f1))"
echo "Short: $short ($(du -h "$short" | cut -f1))"
