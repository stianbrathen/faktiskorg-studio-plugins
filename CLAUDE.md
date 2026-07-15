# faktiskorg-studio-plugins

Statisk plugin-register for Faktisk Studio. Serveres via `raw.githubusercontent.com` — ingen backend.

## Repo-oversikt

- **`registry.json`** — Sannhetskilden for hvilke plugins Studio kan installere. Studio poll-er denne.
- **`build-bundle.js`** — Script som pakker en plugin-mappe fra Studio-repoen til én JSON-fil.
- **`plugins/<id>/<versjon>/bundle.json`** — Bundlet plugin, referert via `bundleUrl` i registry.json.
- **`plugins/<id>/`** — Alle versjoner av hver plugin i separate mapper.

## KRITISK REGEL

**registry.json OG bundle.json må pushes SAMMEN. ALLTID.** Bundle uten registry-oppføring betyr Studio ser ingen oppdatering.

Vi har opplevd flere uker der bundles ble pushet men registry.json ble glemt lokalt. Sjekk alltid `git status` og `git diff registry.json` før commit. Bekreft push via curl til raw-URL etterpå.

## Standard release-flyt (foretrukket: bruk scriptet)

**Forutsetter:** koden er endret i `~/Dokumenter lokalt/Faktisk prosjekter/Faktisk Studio/plugins/<id>/` og `manifest.json` er bumpet til ny versjon.

```bash
cd ~/Dokumenter\ lokalt/Faktisk\ prosjekter/faktiskorg-studio-plugins
./release-plugin.sh <plugin-id> <versjon> "<changelog>"
```

Scriptet håndterer alt: bygger bundle, oppdaterer registry.json (versjon + bundleUrl + changelog + updatedAt), viser git status for bekreftelse, commit + push, verifiserer via raw-URL. Fanger opp de vanligste feilene før commit (manifest-mismatch, manglende mappe, feil versjons-format).

## Manuell fallback

Hvis scriptet feiler eller du trenger fin-kontroll:

```bash
cd ~/Dokumenter\ lokalt/Faktisk\ prosjekter/faktiskorg-studio-plugins

# 1) Bygg bundle
node build-bundle.js \
  "../Faktisk Studio/plugins/<id>" \
  "./plugins/<id>/<versjon>/bundle.json"

# 2) Oppdater registry.json manuelt (versjon + bundleUrl + changelog)

# 3) Sjekk at BEGGE er med
git status

# 4) Commit + push
git add -A
git commit -m "<id> <versjon>: <beskrivelse>"
git push

# 5) Verifiser
curl -s https://raw.githubusercontent.com/stianbrathen/faktiskorg-studio-plugins/main/registry.json | head -20
```

## Registry-entry-mal

```json
{
  "id": "<plugin-id>",
  "name": "<Visningsnavn>",
  "version": "<versjon>",
  "description": "<kort beskrivelse>",
  "minStudioVersion": "0.2.0",
  "bundleUrl": "https://raw.githubusercontent.com/stianbrathen/faktiskorg-studio-plugins/main/plugins/<id>/<versjon>/bundle.json",
  "changelog": "<hva som endret seg i denne versjonen>"
}
```

`minStudioVersion` bumpes bare hvis pluginen krever nyere Studio-features (feks `openLabrador`-IPC krever 0.5.2+).

## Batch-release (flere plugins samtidig)

Om du oppdaterer flere plugins i én runde (feks token-endringer på tvers), pass på:
- Bygg ALLE bundlene før commit
- Oppdater ALLE registry-entries før commit
- Én commit med alle endringer, én push

Se `~/.../memory/faktisk_studio_release_workflow.md` for eksempel-kommandokjede.

## Verifisering etter push

```bash
# 1) Registry oppdatert?
curl -s https://raw.githubusercontent.com/stianbrathen/faktiskorg-studio-plugins/main/registry.json | grep '"version"'

# 2) Bundle nåbar?
curl -sI https://raw.githubusercontent.com/stianbrathen/faktiskorg-studio-plugins/main/plugins/<id>/<versjon>/bundle.json | head -1
# Skal svare 200 OK
```

I Studio: åpne pluginen, sjekk versjonstall i topbar. Om det står gammel versjon selv etter push → vent på CDN-cache (5 min) og sjekk igjen.

## Vanlige feilmoduser

| Symptom | Årsak | Fiks |
|---|---|---|
| Studio ser ikke ny plugin-versjon | Registry.json ikke pushet (bare bundle) | `git status` + push registry.json |
| Studio ser gammel versjon på raw URL | CDN-cache | Vent 5 min, eller `?cachebust=$(date +%s)` |
| Bundle bygging feiler | Feil sti til plugin-mappe | Bruk absolutt eller korrekt relativ sti |
| Studio installerer men crasher | `minStudioVersion` er høyere enn kjørende | Bump Studio eller senk `minStudioVersion` |

## Relaterte repoer

- **`Faktisk Studio`** — Selve Electron-appen. Se dens CLAUDE.md for Studio-release-flyt.
