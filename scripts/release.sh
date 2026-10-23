#!/bin/zsh
# Builds a signed, notarised release of BreakTime Neo from a tag and
# publishes it on Forgejo and GitHub.
#
#   scripts/release.sh 1.0.1            build, sign, notarise and check the zip
#   scripts/release.sh 1.0.1 --publish  create both releases with that zip
#
# The app is built from the tagged sources, not from the working copy.
# Needs a "Developer ID Application" certificate and a notarytool keychain
# profile (NOTARY_PROFILE, default "notary"); publishing also needs `tea`
# logged in to Forgejo (FORGEJO_LOGIN, default "forgejo") and `gh` logged in
# to GitHub. The tag vX.Y.Z must already be on Forgejo; the push mirror
# brings it to GitHub.
set -euo pipefail
cd "${0:A:h}/.."

version=${1:?usage: scripts/release.sh <version> [--publish]}
tag="v$version"
title="BreakTime Neo $version"
out=build/release/$version
src="$out/src"
app="$out/DerivedData/Build/Products/Release/BreakTime Neo.app"
zip="$out/BreakTime-Neo-$version.zip"
notes="$out/notes.md"

fail() { echo "$1" >&2; exit 1; }

git rev-parse -q --verify "refs/tags/$tag" >/dev/null || fail "There is no tag $tag."

if [[ ${2:-} == --publish ]]; then
  [[ -f $zip && -f $notes ]] || fail "No notarised zip for $tag; run scripts/release.sh $version first."
  # Both releases hang from the existing tag. GitHub must not create a tag
  # of its own: the next mirror push from Forgejo would delete it again.
  [[ $(git ls-remote github "refs/tags/$tag" | cut -f1) == $(git rev-parse "$tag") ]] \
    || fail "$tag is not on GitHub yet; push it to Forgejo, the mirror brings it over."
  tea releases create --login "${FORGEJO_LOGIN:-forgejo}" --repo sascha/breaktime-neo \
    --tag "$tag" --title "$title" --note-file "$notes" --asset "$zip"
  gh release create "$tag" "$zip" --repo saschafiedler/breaktime-neo \
    --verify-tag --title "$title" --notes-file "$notes"
  exit 0
fi

rm -rf "$out"
mkdir -p "$src"
git archive "$tag" | tar -x -C "$src"
grep -q "MARKETING_VERSION = $version;" "$src/BreakTimeNeo.xcodeproj/project.pbxproj" \
  || fail "MARKETING_VERSION in $tag is not $version."

# Release notes: the version's section of the changelog, plus how to install.
awk -v v="$version" '
  index($0, "## [" v "]") == 1 { found = 1; next }
  found && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  found && /^$/ { if (started) blank++; next }
  found { while (blank > 0) { print ""; blank-- }; print; started = 1 }
' "$src/CHANGELOG.md" > "$notes"
[[ -s $notes ]] || fail "No section for $version in the changelog of $tag."
cat >> "$notes" <<EOF

### Install

Download \`BreakTime-Neo-$version.zip\`, unzip it and move \`BreakTime Neo.app\` to the Applications folder. Needs a Mac with Apple silicon and macOS 27 or later. The app is signed with a Developer ID and notarised by Apple.
EOF

# A plain build adds the debugging entitlement get-task-allow, which Apple
# refuses to notarise; only archives leave it out.
xcodebuild -project "$src/BreakTimeNeo.xcodeproj" -scheme BreakTimeNeo -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$out/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS=--timestamp build -quiet
codesign --verify --strict --deep "$app"

# Apple notarises a zip; the ticket is then stapled to the app itself, so
# it also opens without a network check. The published zip holds the
# stapled app. `notarytool --wait` exits 0 even when Apple rejects the app.
ditto -c -k --keepParent "$app" "$zip"
profile=${NOTARY_PROFILE:-notary}
submission=$(xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait --output-format json)
if [[ $(plutil -extract status raw -o - - <<< "$submission") != Accepted ]]; then
  xcrun notarytool log "$(plutil -extract id raw -o - - <<< "$submission")" --keychain-profile "$profile"
  fail "Apple did not accept the app for notarisation; see the log above."
fi
xcrun stapler staple "$app"
spctl --assess --type execute --verbose "$app"
rm "$zip"
ditto -c -k --keepParent "$app" "$zip"

shasum -a 256 "$zip"
echo "Built $zip. Try it, then publish with: scripts/release.sh $version --publish"
