#!/bin/sh
# Records Gridle's hands-free demo and turns it into:
#   media/demo-free.gif          for the README (free features only)
#   media/short-<edition>.mp4    a 1080 x 1920 vertical video for YouTube Shorts
#   media/video-<edition>.mp4    a 1920 x 1080 walkthrough, played twice as slowly, with title cards
# Usage: sh scripts/record-demo.sh [free|pro] [video]      (default: free, GIF + Short)
#
# Needs: Gridle installed (sh scripts/build-app.sh), ffmpeg, python3 with Pillow, and Screen
# Recording allowed for the app running this script (System Settings → Privacy & Security →
# Screen & System Audio Recording). The demo hides your other apps for about 30 s and brings
# exactly those back.
set -eu
cd "$(dirname "$0")/.."
edition=${1:-free}
mode=${2:-short}
pace=1
[ "$mode" = video ] && pace=2
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
# The running Gridle could rearrange the demo windows; quit it and start it again afterwards.
was_running=0
if pgrep -x Gridle >/dev/null; then was_running=1; pkill -x Gridle; sleep 1; fi
# The demo and this script take turns through files in $work/signals, so the recording holds
# only the demo: it starts after the demo has hidden every app ("ready") and stops before the
# demo brings them back ("done" -> "stopped").
sig=$work/signals
mkdir -p "$sig"
# Through `open`, so macOS checks Gridle's own Accessibility permission, not the terminal's.
open -n -W --env "GRIDLE_DEMO_SIGNALS=$sig" --env "GRIDLE_DEMO_PACE=$pace" --stdout "$work/demo.log" ~/Applications/Gridle.app --args "$flag" &
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
  # macOS needs a moment after the demo quits before it opens Gridle again.
  for _ in 1 2 3 4 5; do open ~/Applications/Gridle.app 2>/dev/null && break; sleep 1; done
fi
[ -s "$raw" ] || { echo "The recording is empty." >&2; exit 1; }

if [ "$mode" = video ]; then
  # Long video: title card, the recording (menu bar cropped, centred on the dark stage), end card.
  python3 - "$work" "$edition" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
out, edition = sys.argv[1], sys.argv[2]
def font(size, bold=True):
    return ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", size, index=1 if bold else 0)
def card(name, lines):
    img = Image.new("RGB", (1920, 1080))
    d = ImageDraw.Draw(img)
    for y in range(1080):
        t = y / 1080
        d.line([(0, y), (1920, y)], fill=(int(10 + 9 * t), int(19 + 33 * t), int(32 + 60 * t)))
    y = 540 - sum(size + 30 for _, size, _ in lines) / 2
    for text, size, colour in lines:
        f = font(size, size > 50)
        w = d.textlength(text, font=f)
        d.text(((1920 - w) / 2, y), text, font=f, fill=colour)
        y += size + 30
    img.save(f"{out}/{name}.png")
white, sky, muted = (232, 240, 250), (95, 180, 255), (150, 170, 195)
card("intro", [("Gridle", 150, white), ("Windows-style window snapping for Mac", 52, muted),
               ("Ctrl + Alt + arrows  ·  Win + D  ·  drag to edge", 40, sky)])
card("outro", [("Free and open source", 64, white), ("github.com/joyahmed/gridle", 56, sky),
               ("macOS 14 or newer", 36, muted)])
PY
  video=media/video-$edition.mp4
  ffmpeg -loglevel error -y \
    -loop 1 -t 3 -i "$work/intro.png" -i "$raw" -loop 1 -t 4 -i "$work/outro.png" -filter_complex \
    "[0:v]fps=30,format=yuv420p,setsar=1[a];[1:v]crop=iw:ih-40:0:40,scale=1920:-2,pad=1920:1080:0:(oh-ih)/2:color=0x0b1320,fps=30,format=yuv420p,setsar=1[b];[2:v]fps=30,format=yuv420p,setsar=1[c];[a][b][c]concat=n=3:v=1:a=0[v]" \
    -map "[v]" -c:v libx264 -crf 20 -preset slow -movflags +faststart -an "$video"
  echo "Video: $video ($(du -h "$video" | cut -f1))"
  exit 0
fi

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
centre("Gridle", 1380, 96, (230, 238, 248, 255))
line = "Free on GitHub: joyahmed/gridle" if edition == "free" else "Free + Pro · joyahmed/gridle"
centre(line, 1510, 44, (147, 164, 187, 255))
img.save(f"{out}/frame.png")
PY
short=media/short-$edition.mp4
ffmpeg -loglevel error -y -loop 1 -i "$cards/frame.png" -i "$raw" -filter_complex \
  "[1:v]crop=iw:ih-40:0:40,scale=1000:-2:flags=lanczos[s];[0:v][s]overlay=40:(H-h)/2:shortest=1,format=yuv420p" \
  -r 30 -c:v libx264 -crf 20 -preset slow -movflags +faststart -an "$short"

echo "GIF:   $gif ($(du -h "$gif" | cut -f1))"
echo "Short: $short ($(du -h "$short" | cut -f1))"
