#!/usr/bin/env bash
# Packages app/ into dist/ChapelLive.zip, the file you upload to the Roku.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
rm -f dist/ChapelLive.zip
(cd app && zip -qr -X ../dist/ChapelLive.zip manifest source components images)
echo "Built dist/ChapelLive.zip"
