#!/usr/bin/env bash
# release-batch-2026-11-05.sh — rulle-fiks i 28 plugins, ÉN commit og ÉN push.
# Kjør fra roten av faktiskorg-studio-plugins:   bash release-batch-2026-11-05.sh
# Endring: sidepanel og forhåndsvisning ruller hver for seg (style.css). minStudioVersion i registeret beholdes.
# Podkast er holdt utenfor (har usluppede 0.2.4-endringer lokalt).
set -euo pipefail
STUDIO_DIR="../Faktisk Studio"
RAW="https://raw.githubusercontent.com/stianbrathen/faktiskorg-studio-plugins/main"
CHANGELOG="Sidepanel og forhåndsvisning kan rulles på små skjermer"
RELEASES=(
  "bevissikring|0.1.2"
  "bilde-markering|0.1.12"
  "bilde-sensur|0.1.1"
  "bildeanalyse|0.1.32"
  "bildemal|0.1.10"
  "chatbobler|0.2.1"
  "for-og-etter|0.1.7"
  "hendelseskart|0.1.1"
  "keynote-klipp|0.2.1"
  "klippsamler|0.1.1"
  "logo-nettverk|0.2.1"
  "loop-illustrasjon|0.1.3"
  "medieslider|0.1.2"
  "mobilnettverk|0.1.6"
  "parallax-collage|0.3.6"
  "personbilde|0.2.1"
  "pop-up|0.3.7"
  "prikkeklode|0.1.4"
  "skjermarkiv|0.1.1"
  "some-bilde|0.1.2"
  "utklipp-boks|0.1.2"
  "video-hoydepunkter|0.1.4"
  "video-player|0.1.13"
  "video-sensur|0.1.4"
  "videoslider|0.1.2"
  "tabell|0.2.3"
  "kontokart|0.1.2"
  "metodeboks|0.1.1"
)

[[ -f registry.json && -d "$STUDIO_DIR/plugins" ]] || { echo "❌ Kjør fra roten av faktiskorg-studio-plugins."; exit 1; }
echo "→ Henter siste fra GitHub..."; git pull --ff-only

for r in "${RELEASES[@]}"; do
  IFS='|' read -r id ver <<<"$r"
  mv=$(node -e "console.log(require('$STUDIO_DIR/plugins/$id/manifest.json').version)")
  [[ "$mv" == "$ver" ]] || { echo "❌ $id: manifest sier $mv, forventet $ver"; exit 1; }
done
echo "✓ ${#RELEASES[@]} manifester stemmer"

[[ -f "$STUDIO_DIR/plugins/_shared/sync-shared.js" ]] && node "$STUDIO_DIR/plugins/_shared/sync-shared.js" >/dev/null && echo "✓ Delte filer synket"

for r in "${RELEASES[@]}"; do
  IFS='|' read -r id ver <<<"$r"
  node build-bundle.js "$STUDIO_DIR/plugins/$id" "./plugins/$id/$ver/bundle.json" >/dev/null && echo "✓ bygget $id $ver"
done

printf '%s\n' "${RELEASES[@]}" > .batch.tmp
RAW="$RAW" CHANGELOG="$CHANGELOG" node <<'NODE'
const fs = require('fs'), crypto = require('crypto');
const reg = JSON.parse(fs.readFileSync('registry.json', 'utf-8'));
for (const line of fs.readFileSync('.batch.tmp', 'utf-8').trim().split('\n')) {
  const [id, version] = line.split('|');
  const e = reg.plugins.find(p => p.id === id);
  if (!e) { console.error('❌ ' + id + ' finnes ikke i registry.json'); process.exit(1); }
  const bundle = `plugins/${id}/${version}/bundle.json`;
  e.version = version;
  e.bundleUrl = `${process.env.RAW}/${bundle}`;
  e.changelog = process.env.CHANGELOG;
  e.sha256 = crypto.createHash('sha256').update(fs.readFileSync(bundle)).digest('hex');
}
reg.updatedAt = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
fs.writeFileSync('registry.json', JSON.stringify(reg, null, 2) + '\n', 'utf-8');
console.log('✓ registry.json oppdatert');
NODE
rm -f .batch.tmp

echo "→ Verifiserer..."; node verify-registry.js | tail -3

PATHS=(registry.json)
for r in "${RELEASES[@]}"; do IFS='|' read -r id ver <<<"$r"; PATHS+=("plugins/$id/$ver/bundle.json"); done
echo ""; git status --short -- "${PATHS[@]}" | head -40
echo ""; read -p "Commit + push alle ${#RELEASES[@]} i én commit? [y/N] " OK
[[ "$OK" == "y" || "$OK" == "Y" ]] || { echo "Avbrutt. Endringene ligger uncommitted."; exit 0; }
git add -- "${PATHS[@]}"
git commit -m "Batch: rulling i sidepanel og forhåndsvisning for ${#RELEASES[@]} plugins"
git push
echo ""; echo "✅ Pushet. Studio ser oppdateringene når GitHub-cachen er fornyet (opptil ca. 5 min)."
