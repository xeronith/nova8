#!/bin/sh
# Rebuilds the app icon set and the in-app brand mark from Docs/icon.svg.
# Requires rsvg-convert (brew install librsvg) and sips.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
svg="$root/Docs/icon.svg"
icon_set="$root/Nova8/Resources/Assets.xcassets/AppIcon.appiconset"
brand_set="$root/Nova8/Resources/Assets.xcassets/BrandMark.imageset"

command -v rsvg-convert >/dev/null 2>&1 || {
    echo "rsvg-convert is required: brew install librsvg" >&2
    exit 1
}

# README hero/master image.
rsvg-convert -w 2048 -h 2048 "$svg" -o "$root/Docs/icon-master.png"

# AppIcon slices. Each size is rendered directly from the vector source.
render() {
    size=$1
    name=$2
    rsvg-convert -w "$size" -h "$size" "$svg" -o "$icon_set/$name"
}

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

# Vector version used beside the window title.
rsvg-convert -f pdf -o "$brand_set/brand-mark.pdf" "$svg"

echo "Rebuilt AppIcon, BrandMark and Docs/icon-master.png"
