#!/usr/bin/env bash
# Packages app/ into a zip you upload to the Roku.
#
#   tools/build.sh                 -> dist/ChapelLive.zip (the real app)
#   tools/build.sh --test 1234567  -> dist/ChapelLive-test.zip, pointed at Vimeo event
#                                     1234567, checking for live every 20 seconds, and
#                                     named "The Chapel (test)" on the Roku. For trying
#                                     the live features with a test event any day.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist

if [[ "${1:-}" == "--test" ]]; then
    event="${2:?usage: tools/build.sh --test <vimeo event number>}"
    [[ "$event" =~ ^[0-9]+$ ]] || { echo "The event number should be digits only, e.g. 2327573" >&2; exit 1; }
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    cp -r app/. "$work/"
    sed -i -E "s/eventId: \"[0-9]+\"/eventId: \"$event\"/; s/pollSeconds: [0-9]+/pollSeconds: 20/" "$work/source/AppConfig.brs"
    sed -i -E "s/^title=.*/title=The Chapel (test)/" "$work/manifest"
    grep -q "eventId: \"$event\"" "$work/source/AppConfig.brs" || { echo "Couldn't set the event number" >&2; exit 1; }
    out="$PWD/dist/ChapelLive-test.zip"
    rm -f "$out"
    (cd "$work" && zip -qr -X "$out" manifest source components images fonts)
    echo "Built dist/ChapelLive-test.zip (event $event)"
    exit 0
fi

rm -f dist/ChapelLive.zip
(cd app && zip -qr -X ../dist/ChapelLive.zip manifest source components images fonts)
echo "Built dist/ChapelLive.zip"
