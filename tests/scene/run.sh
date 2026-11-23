#!/usr/bin/env bash
# Runs tests/scene/scene_test.brs against the real MainScene code in the
# BrightScript interpreter (@rokucommunity/brs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp -r "$ROOT/app/." "$WORK/"
cp "$ROOT"/tests/scene/stubs/*.xml "$WORK/components/"
cp "$ROOT/tests/scene/scene_test.brs" "$WORK/components/"

# The interpreter's Scene has no signalBeacon (a launch-timing call on real Rokus).
sed -i 's|m.top.signalBeacon("AppLaunchComplete")|'"'"' (signalBeacon skipped in tests)|' "$WORK/components/MainScene.brs"

# A copy of MainScene (same layout and script) that also loads the test script.
sed -e 's|<component name="MainScene" extends="Scene">|<component name="HarnessScene" extends="Scene">|' \
    -e '0,/<interface>/s|<interface>|<interface>\n        <function name="runTests" />|' \
    -e 's|<script type="text/brightscript" uri="MainScene.brs" />|<script type="text/brightscript" uri="MainScene.brs" />\n    <script type="text/brightscript" uri="scene_test.brs" />|' \
    "$ROOT/app/components/MainScene.xml" > "$WORK/components/HarnessScene.xml"

cat > "$WORK/test_main.brs" <<'EOF'
sub Main()
    scene = CreateObject("roSGNode", "HarnessScene")
    scene.callFunc("runTests", {})
end sub
EOF

npx --yes @rokucommunity/brs --root "$WORK" "$WORK/test_main.brs" 2>&1 | grep -v -e "extends unknown component 'Task'" -e 'unknown classname "roRegistrySection"'
