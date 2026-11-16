#!/bin/sh
# mac/dmg-background.tiff: the Mac disk image's window background, 640 x 427 pt at 1x and
# 2x: a close render of the autumn 3D board's left corner (local, in
# ~/Downloads/draughts-store/dmg-0.1/, whose README.md says how it was rendered), with a
# glass card in its middle drawn as the app's autumn glass is (docs/architecture/rendering.md, "Look"): the photo blurred,
# saturated 1.3 and dimmed to 0.9, tinted #2b1e18 at 66%, a white border at 14% and top
# highlight at 12%, a shadow 0 12 32 -14 of black at 55%, corners of 28 pt. scripts/mac.py
# places the app's and Applications' icons on it, an arrow in the text color between them.
# Needs ImageMagick. Sizes below are the 2x image's pixels.
set -e
cd "$(dirname "$0")/.."
src=${1:-$HOME/Downloads/draughts-store/dmg-0.1/board-1280x853.png}
out=${2:-mac/dmg-background.tiff}
tmp=$(mktemp -d)
card="160,232 1120,600"      # x0,y0 x1,y1
r=56
magick "$src" -resize 1280x854^ -gravity center -extent 1280x854 "$tmp/photo.png"
magick "$tmp/photo.png" -blur 0x40 -modulate 90,130 -fill '#2b1e18' -colorize 66% "$tmp/glass.png"
magick -size 1280x854 xc:black -fill white -draw "roundrectangle $card $r,$r" -type TrueColor "$tmp/mask.png"
# the shadow: the card shrunk by 28, blurred by 64, moved down 24, black at 55%
magick -size 1280x854 xc:black -fill white -draw "roundrectangle 188,260 1092,572 $r,$r" \
    -blur 0x32 -roll +0+24 -evaluate multiply 0.55 -type TrueColor "$tmp/shadow.png"
magick "$tmp/photo.png" \
    \( -size 1280x854 xc:black \) "$tmp/shadow.png" -composite \
    "$tmp/glass.png" "$tmp/mask.png" -composite \
    -fill none -stroke 'rgba(255,255,255,0.14)' -strokewidth 2 \
    -draw "roundrectangle 161,233 1119,599 $r,$r" \
    -stroke 'rgba(255,255,255,0.12)' -draw "line 216,235 1064,235" \
    -stroke 'rgba(248,243,230,0.85)' -strokewidth 8 \
    -draw "path 'M 480,400 L 800,400'" -draw "path 'M 766,366 L 802,400 L 766,434'" \
    -strip "$tmp/bg@2x.png"
magick "$tmp/bg@2x.png" -resize 640x427 -units PixelsPerInch -density 72 "$tmp/bg.png"
magick "$tmp/bg@2x.png" -units PixelsPerInch -density 144 "$tmp/bg@2x.png"
tiffutil -cathidpicheck "$tmp/bg.png" "$tmp/bg@2x.png" -out "$tmp/bg.tiff" >/dev/null
magick "$tmp/bg.tiff" -compress jpeg -quality 88 "$out"
rm -r "$tmp"
