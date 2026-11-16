#!/bin/sh
# mac/dmg-background.tiff: the Mac disk image's window background, 640 x 427 pt at 1x and
# 2x: the App Store's search art without the name (store/README.md; local, in
# ~/Downloads/draughts-store/apple-header-0.1/), the board below and a frosted strip over
# the forest above it, where scripts/mac.py places the app's and Applications' icons with
# an arrow between them. Needs ImageMagick.
set -e
cd "$(dirname "$0")/.."
src=${1:-$HOME/Downloads/draughts-store/apple-header-0.1/search-3840x2560-plain.png}
tmp=$(mktemp -d)
magick "$src" -resize 1280x854^ -gravity center -extent 1280x854 "$tmp/photo.png"
# the strip: the photo under it blurred and lightened, with rounded corners
magick "$tmp/photo.png" -blur 0x24 -fill white -colorize 50% "$tmp/frost.png"
magick -size 1280x854 xc:black -fill white -draw "roundrectangle 96,20 1184,288 32,32" \
    "$tmp/mask.png"
magick "$tmp/photo.png" "$tmp/frost.png" "$tmp/mask.png" -composite \
    -stroke 'rgba(40,40,40,0.6)' -strokewidth 8 -fill none \
    -draw "path 'M 470,140 L 800,140'" -draw "path 'M 766,106 L 802,140 L 766,174'" \
    -strip "$tmp/bg@2x.png"
magick "$tmp/bg@2x.png" -resize 640x427 -units PixelsPerInch -density 72 "$tmp/bg.png"
magick "$tmp/bg@2x.png" -units PixelsPerInch -density 144 "$tmp/bg@2x.png"
tiffutil -cathidpicheck "$tmp/bg.png" "$tmp/bg@2x.png" -out "$tmp/bg.tiff"
magick "$tmp/bg.tiff" -compress jpeg -quality 88 mac/dmg-background.tiff
rm -r "$tmp"
