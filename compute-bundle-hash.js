#!/usr/bin/env node
// compute-bundle-hash.js — beregner sha256 av en bundle.json.
//
// Bruk:
//   node compute-bundle-hash.js <path-til-bundle.json>
//
// Skriver hex-hash til stdout. Brukes av release-plugin.sh for å fylle
// inn "sha256" i registry.json og av verify-registry.js for å bekrefte
// at bundlen ikke er tuklet med.

const fs = require('fs');
const crypto = require('crypto');

const bundlePath = process.argv[2];
if (!bundlePath) {
  console.error('Bruk: node compute-bundle-hash.js <bundle.json>');
  process.exit(1);
}
if (!fs.existsSync(bundlePath)) {
  console.error('❌ Fil finnes ikke:', bundlePath);
  process.exit(1);
}

const buf = fs.readFileSync(bundlePath);
const hash = crypto.createHash('sha256').update(buf).digest('hex');
console.log(hash);
