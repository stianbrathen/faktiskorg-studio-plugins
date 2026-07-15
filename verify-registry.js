#!/usr/bin/env node
// verify-registry.js — sjekk at registry.json og bundles er konsistente.
//
// Bruk:
//   node verify-registry.js
//
// Sjekker:
//   1. Hver plugin i registry.json har en tilhørende bundle.json på riktig sti
//   2. Bundlens manifest.json version matcher registry-versjonen
//   3. Bundlens manifest.json id matcher registry-id
//   4. Ingen bundle-mapper er "foreldreløse" (uten registry-oppføring)
//   5. Kilden i Studio-repoen har manifest som matcher siste registry-versjon
//
// Løser F3 fra kodegjennomgangen: fanger opp drift mellom kilde og register.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const REGISTRY_PATH = './registry.json';
const PLUGINS_DIR = './plugins';
const STUDIO_PLUGINS = '../Faktisk Studio/plugins';

if (!fs.existsSync(REGISTRY_PATH)) {
  console.error('❌ registry.json finnes ikke. Kjør fra plugin-repo-roten.');
  process.exit(1);
}

const registry = JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf-8'));
const problems = [];
const warnings = [];
const ok = [];

// 1-3: Sjekk hver registry-entry
for (const entry of registry.plugins) {
  const bundlePath = path.join(PLUGINS_DIR, entry.id, entry.version, 'bundle.json');

  if (!fs.existsSync(bundlePath)) {
    problems.push(`${entry.id} v${entry.version}: bundle mangler på ${bundlePath}`);
    continue;
  }

  let bundle;
  try {
    bundle = JSON.parse(fs.readFileSync(bundlePath, 'utf-8'));
  } catch (e) {
    problems.push(`${entry.id} v${entry.version}: bundle er ugyldig JSON — ${e.message}`);
    continue;
  }

  const manifestKey = Object.keys(bundle).find(k => k === 'manifest.json' || k.endsWith('/manifest.json'));
  if (!manifestKey) {
    problems.push(`${entry.id} v${entry.version}: bundle mangler manifest.json`);
    continue;
  }

  let manifest;
  try {
    manifest = JSON.parse(bundle[manifestKey]);
  } catch (e) {
    problems.push(`${entry.id} v${entry.version}: manifest.json i bundle er ugyldig JSON`);
    continue;
  }

  if (manifest.id !== entry.id) {
    problems.push(`${entry.id} v${entry.version}: bundle-manifest.id="${manifest.id}" ≠ registry.id="${entry.id}"`);
    continue;
  }

  if (manifest.version !== entry.version) {
    problems.push(`${entry.id} v${entry.version}: bundle-manifest.version="${manifest.version}" ≠ registry.version="${entry.version}"`);
    continue;
  }

  // 3b: Sjekk sha256 hvis den er satt i registry
  if (entry.sha256) {
    const buf = fs.readFileSync(bundlePath);
    const actualHash = crypto.createHash('sha256').update(buf).digest('hex');
    if (actualHash !== entry.sha256) {
      problems.push(`${entry.id} v${entry.version}: sha256 mismatch — bundle er endret siden hash ble beregnet.\n    Registry: ${entry.sha256}\n    Faktisk:  ${actualHash}`);
      continue;
    }
  } else {
    warnings.push(`${entry.id} v${entry.version}: mangler sha256 i registry — kjør release-plugin.sh eller add manuelt.`);
  }

  // 5: Sjekk at Studios kilde matcher siste registry-versjon
  const studioManifestPath = path.join(STUDIO_PLUGINS, entry.id, 'manifest.json');
  if (fs.existsSync(studioManifestPath)) {
    const studioManifest = JSON.parse(fs.readFileSync(studioManifestPath, 'utf-8'));
    if (studioManifest.version !== entry.version) {
      warnings.push(`${entry.id}: Studio-kilde er v${studioManifest.version}, registry viser v${entry.version} (drift — sync mangler?)`);
    }
  } else {
    warnings.push(`${entry.id}: Studio-kilde finnes ikke på ${studioManifestPath}`);
  }

  ok.push(`${entry.id} v${entry.version}`);
}

// 4: Sjekk om det finnes bundle-mapper som ikke er referert i registry
if (fs.existsSync(PLUGINS_DIR)) {
  const pluginFolders = fs.readdirSync(PLUGINS_DIR, { withFileTypes: true })
    .filter(e => e.isDirectory())
    .map(e => e.name);

  for (const folder of pluginFolders) {
    const versions = fs.readdirSync(path.join(PLUGINS_DIR, folder), { withFileTypes: true })
      .filter(e => e.isDirectory())
      .map(e => e.name);
    for (const v of versions) {
      const inRegistry = registry.plugins.some(p => p.id === folder && p.version === v);
      if (!inRegistry) {
        // Kun advarsel — gamle versjoner er OK å ha liggende
        warnings.push(`${folder} v${v}: bundle finnes, men ikke referert i registry (kan være gammel versjon — OK om intensjonelt)`);
      }
    }
  }
}

// Rapport
console.log(`Sjekket ${registry.plugins.length} plugin-oppføring${registry.plugins.length === 1 ? '' : 'er'}:\n`);

if (ok.length > 0) {
  console.log('✓ OK:');
  ok.forEach(x => console.log(`  ${x}`));
}

if (warnings.length > 0) {
  console.log('\n⚠ Advarsler:');
  warnings.forEach(x => console.log(`  ${x}`));
}

if (problems.length > 0) {
  console.log('\n❌ Feil:');
  problems.forEach(x => console.log(`  ${x}`));
  process.exit(1);
}

console.log(`\n✅ ${ok.length} plugin${ok.length === 1 ? '' : 's'} verifisert. ${warnings.length} advarsel(er). Ingen kritiske feil.`);
