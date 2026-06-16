# Faktisk Studio · Plugin-registry

Dette er strukturen Faktisk Studio forventer å finne når den henter `registry.json` ved oppstart.

## Anbefalt GitHub-oppsett

Lag et eget repo, f.eks. `faktiskorg/studio-plugins`:

```
studio-plugins/
├── registry.json
└── plugins/
    └── looping-video/
        ├── 0.1.0/
        │   └── bundle.json
        └── 0.2.0/
            └── bundle.json
```

Filene serveres via `https://raw.githubusercontent.com/faktiskorg/studio-plugins/main/...`. Ingen serverkode trengs — alt er statiske filer.

## registry.json

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-06-16T15:00:00Z",
  "plugins": [
    {
      "id": "looping-video",
      "name": "Looping videoklipp",
      "version": "0.2.0",
      "description": "Kort beskrivelse vist i plugin-markedet",
      "minStudioVersion": "0.2.0",
      "bundleUrl": "https://.../plugins/looping-video/0.2.0/bundle.json",
      "changelog": "Hva som er nytt i denne versjonen"
    }
  ]
}
```

Feltene:

- `id` — matcher mappenavnet i appen (kebab-case, kun a-z, 0-9, -, _)
- `version` — semver, sammenlignes mot installert versjon
- `minStudioVersion` — pluginen vises ikke som installerbar hvis appen er eldre
- `bundleUrl` — peker til bundle-fila som inneholder selve plugin-filene
- `changelog` — vises i plugin-markedet

## bundle.json

Inneholder alle filene som utgjør plugin-en. Filnavn → tekst-innhold:

```json
{
  "manifest.json": "{\n  \"id\": \"looping-video\",\n  ...\n}\n",
  "index.html": "<!doctype html>...",
  "style.css": "...",
  "main.js": "..."
}
```

Strenger må escapes som vanlig JSON. Underkataloger kan brukes i filnavnet (f.eks. `"assets/icon.svg": "..."`), men `..`-segmenter avvises av appen.

## Publish-flyt

1. Sjekk inn nye plugin-filer under `plugins/<id>/<versjon>/`
2. Generer `bundle.json` ved å samle plugin-filene som JSON-objekt (én-linjes Node-script holder)
3. Oppdater `registry.json` med ny versjon + changelog
4. Push til GitHub — endringen er ute hos brukerne neste gang de starter appen (eller klikker "Sjekk på nytt" i plugin-markedet)

## Test lokalt før publish

Faktisk Studio cacher registry-en i 30 minutter. For å teste raskt:

- Endre `registryUrl` i `package.json` til en lokal fil-URL (`file:///...`)
- Eller pek mot en privat staging-branch i GitHub
- Bruk "Sjekk på nytt"-knappen for å tvinge fresh fetch

## Generere bundle.json fra mappe

```bash
node -e '
  const fs = require("fs");
  const path = require("path");
  const dir = "./plugins/looping-video/0.2.0/files";
  const bundle = {};
  for (const f of fs.readdirSync(dir, { recursive: true, withFileTypes: true })) {
    if (!f.isFile()) continue;
    const rel = path.relative(dir, path.join(f.parentPath || f.path, f.name));
    bundle[rel] = fs.readFileSync(path.join(dir, rel), "utf-8");
  }
  fs.writeFileSync(path.join(dir, "../bundle.json"), JSON.stringify(bundle, null, 2));
'
```
