#!/bin/zsh
# Builds BreakTime Neo (Release) and installs it to /Applications, then starts it.
# A fixed location matters for "start at login".
set -euo pipefail
cd "${0:A:h}/.."

xcodebuild -project BreakTimeNeo.xcodeproj -scheme BreakTimeNeo -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData build -quiet

pkill -x "BreakTime Neo" 2>/dev/null || true
# Wait until the old instance is gone; opening too early fails with -600.
for _ in {1..50}; do
  pgrep -x "BreakTime Neo" >/dev/null || break
  sleep 0.1
done
rm -rf "/Applications/BreakTime Neo.app"
cp -R "build/DerivedData/Build/Products/Release/BreakTime Neo.app" /Applications/
open "/Applications/BreakTime Neo.app"
echo "BreakTime Neo is installed and running (stopwatch icon in the menu bar)."
