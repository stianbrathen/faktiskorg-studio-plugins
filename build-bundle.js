#!/usr/bin/env node
// build-bundle.js — pakker en plugin-mappe til en bundle.json klar for registry.
//
// Bruk:
//   node build-bundle.js <plugin-mappe> <output-fil>
//
// Eksempel:
//   node build-bundle.js ../../plugins/looping-video ./plugins/looping-video/0.2.0/bundle.json

const fs = require('fs');
const path = require('path');

const [, , inputDir, outputFile] = process.argv;
if (!inputDir || !outputFile) {
  console.error('Bruk: node build-bundle.js <plugin-mappe> <output-fil>');
  process.exit(1);
}

if (!fs.existsSync(inputDir) || !fs.statSync(inputDir).isDirectory()) {
  console.error('Plugin-mappe finnes ikke:', inputDir);
  process.exit(1);
}

function walk(dir, baseDir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...walk(full, baseDir));
    } else if (entry.isFile()) {
      out.push({
        relativePath: path.relative(baseDir, full),
        absolutePath: full,
      });
    }
  }
  return out;
}

const files = walk(inputDir, inputDir);
const bundle = {};
for (const f of files) {
  // Bruk forward-slash i nøkler så det funker på tvers av plattformer
  const key = f.relativePath.split(path.sep).join('/');
  bundle[key] = fs.readFileSync(f.absolutePath, 'utf-8');
}

fs.mkdirSync(path.dirname(outputFile), { recursive: true });
fs.writeFileSync(outputFile, JSON.stringify(bundle, null, 2), 'utf-8');

const sizeKb = (fs.statSync(outputFile).size / 1024).toFixed(1);
console.log(`✓ Bundle skrevet til ${outputFile} (${files.length} filer, ${sizeKb} KB)`);
