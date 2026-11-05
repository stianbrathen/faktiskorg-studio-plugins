#!/usr/bin/env bash
# release-batch-2026-11-04.sh — slipper 8 plugins i ÉN commit og ÉN push
# (batch-flyten fra CLAUDE.md). Kjøres fra roten av faktiskorg-studio-plugins:
#
#   ./release-batch-2026-11-04.sh
#
# Videoslider krever Studio 0.7.13: TikTok-IPC-ene (tiktok-list / tiktok-import)
# finnes i 0.7.13-bygget fra 02.11 (sjekket i app.asar), ikke i eldre versjoner.
set -euo pipefail

STUDIO_DIR="../Faktisk Studio"
RAW="https://raw.githubusercontent.com/stianbrathen/faktiskorg-studio-plugins/main"

# id|versjon|changelog
RELEASES=(
  "tabell|0.2.0|Prosentmodus (ferdige prosenter, søyler mot 100), detaljlinje per rad og sorteringsknapp"
  "medieslider|0.1.0|Ny plugin: slider med egne bilder og videoer fra Labrador, med bildetekst, kilde, dato og lenke"
  "videoslider|0.1.0|Ny plugin: slider med stående videoer (f.eks. TikTok) fra Labrador"
  "hendelseskart|0.1.0|Ny plugin: nummererte, klikkbare punkter på kart eller bilde med popup"
  "mobilnettverk|0.1.5|«Antall» følger antall skjermbilder (maks 3), så bilde nr. 3 vises"
  "personbilde|0.2.0|Komprimerte bildevarianter fra Studio gir <picture> med AVIF/JPG i flere bredder"
  "prikkeklode|0.1.3|Samme embed kan limes inn flere ganger på én side"
  "video-sensur|0.1.3|Bruk video rett fra Macen – ingen opplasting og ingen 100 MB-grense"
)

VIDEOSLIDER_MIN="0.7.13"

[[ -f registry.json && -d "$STUDIO_DIR/plugins" ]] || { echo "❌ Kjør fra roten av faktiskorg-studio-plugins (med ../Faktisk Studio ved siden av)."; exit 1; }

echo "→ Henter siste fra GitHub..."
git pull --ff-only

# 1) Sjekk manifest-versjoner før noe bygges
for r in "${RELEASES[@]}"; do
  IFS='|' read -r id ver _ <<<"$r"
  mv=$(node -e "console.log(require('$STUDIO_DIR/plugins/$id/manifest.json').version)")
  [[ "$mv" == "$ver" ]] || { echo "❌ $id: manifest.json sier $mv, forventet $ver"; exit 1; }
  echo "✓ $id $ver"
done

# 2) Synk delte filer én gang
if [[ -f "$STUDIO_DIR/plugins/_shared/sync-shared.js" ]]; then
  echo "→ Synker delte filer fra _shared/..."
  node "$STUDIO_DIR/plugins/_shared/sync-shared.js"
fi

# 3) Bygg alle bundlene
for r in "${RELEASES[@]}"; do
  IFS='|' read -r id ver _ <<<"$r"
  echo "→ Bygger $id $ver"
  node build-bundle.js "$STUDIO_DIR/plugins/$id" "./plugins/$id/$ver/bundle.json"
done

# 4) Oppdater registry.json (nye plugins legges til, minStudioVersion fra manifest)
printf '%s\n' "${RELEASES[@]}" > .batch-releases.tmp
STUDIO_DIR="$STUDIO_DIR" RAW="$RAW" VIDEOSLIDER_MIN="$VIDEOSLIDER_MIN" node <<'NODE'
const fs = require('fs'), crypto = require('crypto');
const reg = JSON.parse(fs.readFileSync('registry.json', 'utf-8'));
const lines = fs.readFileSync('.batch-releases.tmp', 'utf-8').trim().split('\n');
for (const line of lines) {
  const [id, version, ...rest] = line.split('|');
  const changelog = rest.join('|');
  const man = JSON.parse(fs.readFileSync(`${process.env.STUDIO_DIR}/plugins/${id}/manifest.json`, 'utf-8'));
  const bundle = `plugins/${id}/${version}/bundle.json`;
  let entry = reg.plugins.find(p => p.id === id);
  const isNew = !entry;
  if (isNew) { entry = { id }; reg.plugins.push(entry); }
  entry.name = man.name;
  entry.version = version;
  entry.description = man.description;
  entry.minStudioVersion = id === 'videoslider' ? process.env.VIDEOSLIDER_MIN : man.minStudioVersion;
  entry.bundleUrl = `${process.env.RAW}/${bundle}`;
  entry.changelog = changelog;
  entry.sha256 = crypto.createHash('sha256').update(fs.readFileSync(bundle)).digest('hex');
  console.log(`  ✓ ${isNew ? 'NY ' : ''}${id} ${version} (min Studio ${entry.minStudioVersion})`);
}
reg.updatedAt = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
fs.writeFileSync('registry.json', JSON.stringify(reg, null, 2) + '\n', 'utf-8');
NODE
rm -f .batch-releases.tmp

# 5) Verifiser lokalt FØR commit
echo "→ Verifiserer registry mot bundlene..."
node verify-registry.js

# 6) Commit kun registry + de nye bundlene (ikke .DS_Store o.l.)
PATHS=(registry.json verify-registry.js)
for r in "${RELEASES[@]}"; do IFS='|' read -r id ver _ <<<"$r"; PATHS+=("plugins/$id/$ver/bundle.json"); done
echo ""; git status --short -- "${PATHS[@]}"
echo ""; read -p "Commit + push alle 8 i én commit? [y/N] " OK
[[ "$OK" == "y" || "$OK" == "Y" ]] || { echo "Avbrutt. Endringene ligger uncommitted."; exit 0; }
git add -- "${PATHS[@]}"
git commit -m "Batch (+ verify-registry-fiks): tabell 0.2.0, medieslider 0.1.0, videoslider 0.1.0, hendelseskart 0.1.0, mobilnettverk 0.1.5, personbilde 0.2.0, prikkeklode 0.1.3, video-sensur 0.1.3"
git push

# 7) Sjekk live-registeret
sleep 3
curl -s "$RAW/registry.json?cachebust=$(date +%s)" | node -e '
let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{const r=JSON.parse(s);
for (const id of ["tabell","medieslider","videoslider","hendelseskart","mobilnettverk","personbilde","prikkeklode","video-sensur"]) {
  const e=r.plugins.find(p=>p.id===id); console.log((e?"  ✓ ":"  ⚠ ")+id+" "+(e?e.version:"IKKE FUNNET"));}
console.log("Viser noe gammel versjon: CDN-cache, sjekk igjen om 5 min.");});'
