#!/usr/bin/env bash
# release-plugin.sh — bygg + publiser en plugin til registeret på GitHub.
#
# Bruk:
#   ./release-plugin.sh <plugin-id> <versjon> "<changelog>"
#
# Eksempel:
#   ./release-plugin.sh bildeanalyse 0.1.28 "Bytt embed-font til Unica77"
#
# Forutsetter:
#   - Kjøres fra roten av faktiskorg-studio-plugins-repoen
#   - Studio-repoen ligger på ../Faktisk Studio/
#   - Plugin-mappens manifest.json er allerede bumpet til <versjon>
#   - Node, git, curl er tilgjengelig
#
# Scriptet fanger vanlige feilmoduser som har brent oss tidligere:
#   - Versjonsmismatch mellom argument og manifest.json
#   - Glemt registry-oppdatering (bundle uten registry = usynlig for Studio)
#   - Manglende plugin-mappe eller manifest.json

set -euo pipefail

PLUGIN_ID="${1:-}"
VERSION="${2:-}"
CHANGELOG="${3:-}"

if [[ -z "$PLUGIN_ID" || -z "$VERSION" || -z "$CHANGELOG" ]]; then
  cat <<EOF
Bruk: $0 <plugin-id> <versjon> "<changelog>"

Eksempel:
  $0 bildeanalyse 0.1.28 "Bytt embed-font til Unica77"

Krever at plugin-mappens manifest.json allerede er bumpet.
EOF
  exit 1
fi

# Semver-sjekk
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Versjon må være semver (X.Y.Z), fikk: $VERSION"
  exit 1
fi

STUDIO_DIR="../Faktisk Studio"
PLUGIN_SRC="$STUDIO_DIR/plugins/$PLUGIN_ID"
BUNDLE_OUT="./plugins/$PLUGIN_ID/$VERSION/bundle.json"

# Sanity checks
if [[ ! -d "$PLUGIN_SRC" ]]; then
  echo "❌ Plugin-mappe finnes ikke: $PLUGIN_SRC"
  echo "   Er du i faktiskorg-studio-plugins-roten?"
  echo "   Ligger Studio-repoen på ../Faktisk Studio ?"
  exit 1
fi

if [[ ! -f "$PLUGIN_SRC/manifest.json" ]]; then
  echo "❌ manifest.json mangler i $PLUGIN_SRC"
  exit 1
fi

# Sjekk at manifest.json faktisk matcher versjonen
MANIFEST_VERSION=$(node -e "console.log(require('$PLUGIN_SRC/manifest.json').version)")
if [[ "$MANIFEST_VERSION" != "$VERSION" ]]; then
  echo "❌ Versjonsmismatch:"
  echo "   Argument:      $VERSION"
  echo "   manifest.json: $MANIFEST_VERSION"
  echo ""
  echo "   Bump $PLUGIN_SRC/manifest.json først, så kjør igjen."
  exit 1
fi

echo "✓ Plugin:  $PLUGIN_ID"
echo "✓ Versjon: $VERSION"
echo ""

# 1) Bygg bundle
echo "→ Bygger bundle..."
node build-bundle.js "$PLUGIN_SRC" "$BUNDLE_OUT"

# 2) Oppdater registry.json
echo "→ Oppdaterer registry.json..."
CHANGELOG_ESCAPED=$(node -e "console.log(JSON.stringify(process.argv[1]))" "$CHANGELOG")
node <<NODE_SCRIPT
const fs = require('fs');
const path = './registry.json';
const reg = JSON.parse(fs.readFileSync(path, 'utf-8'));
const entry = reg.plugins.find(p => p.id === '${PLUGIN_ID}');
if (!entry) {
  console.error('❌ Fant ikke plugin "${PLUGIN_ID}" i registry.json.');
  console.error('   Legg til entry manuelt første gang, så tar scriptet over etterpå.');
  process.exit(1);
}
entry.version = '${VERSION}';
entry.bundleUrl = 'https://raw.githubusercontent.com/stianbrathen/faktiskorg-studio-plugins/main/plugins/${PLUGIN_ID}/${VERSION}/bundle.json';
entry.changelog = ${CHANGELOG_ESCAPED};
reg.updatedAt = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
fs.writeFileSync(path, JSON.stringify(reg, null, 2) + '\n', 'utf-8');
console.log('  ✓ Registry-entry oppdatert til v${VERSION}');
NODE_SCRIPT

# 3) Vis git status før commit
echo ""
echo "→ Git status:"
git status --short

echo ""
read -p "Se OK ut? Commit + push? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Avbrutt. Endringer ligger unstaged."
  exit 0
fi

# 4) Commit + push
git add -A
git commit -m "${PLUGIN_ID} ${VERSION}: ${CHANGELOG}"
git push

# 5) Verifiser at registry er oppdatert på raw-URL (etter kort delay for CDN)
echo ""
echo "→ Venter 3 sekunder før verifisering..."
sleep 3

LIVE_VERSION=$(curl -s "https://raw.githubusercontent.com/stianbrathen/faktiskorg-studio-plugins/main/registry.json?cachebust=$(date +%s)" | node -e "
const chunks = [];
process.stdin.on('data', c => chunks.push(c));
process.stdin.on('end', () => {
  try {
    const reg = JSON.parse(Buffer.concat(chunks).toString());
    const entry = reg.plugins.find(p => p.id === '${PLUGIN_ID}');
    console.log(entry ? entry.version : 'NOT_FOUND');
  } catch (e) {
    console.log('PARSE_ERROR');
  }
});
")

if [[ "$LIVE_VERSION" == "$VERSION" ]]; then
  echo "  ✓ Registry på GitHub viser v${VERSION} for ${PLUGIN_ID}."
  echo "  ✓ Studio vil se oppdateringen ved neste poll."
elif [[ "$LIVE_VERSION" == "NOT_FOUND" ]]; then
  echo "  ⚠ ${PLUGIN_ID} ikke funnet i registry (uventet — push kan ha feilet)."
else
  echo "  ⚠ Registry viser fortsatt v${LIVE_VERSION} (CDN-cache — vent 5 min og verifiser igjen)."
fi

echo ""
echo "✅ Ferdig. Åpne Studio og sjekk at ${PLUGIN_ID} tilbys oppdatering til v${VERSION}."
