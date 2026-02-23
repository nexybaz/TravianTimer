# Versionierung — TravianTimer

## Semantic Versioning (SemVer)

Format: **`MAJOR.MINOR.PATCH`** — z.B. `2.1.0`

| Teil      | Wann erhöhen                              | Beispiel                        |
|-----------|-------------------------------------------|---------------------------------|
| **MAJOR** | App grundlegend neu / Breaking Changes    | v1 → v2 (neues Backend)        |
| **MINOR** | Neues Feature                             | Multi-World, Chat, neue Tools   |
| **PATCH** | Bugfix, kleine Verbesserung               | Login-Fix, UI-Korrektur         |

## Xcode-Versionen

| Feld                     | Key                          | Bedeutung                                 |
|--------------------------|------------------------------|-------------------------------------------|
| **Marketing Version**    | `MARKETING_VERSION`          | Im App Store sichtbar → `2.0.0`          |
| **Build Number**         | `CURRENT_PROJECT_VERSION`    | Interner Zähler, steigt bei jedem Upload  |

### Regeln

- **Marketing Version** = Git-Tag (ohne `v`-Prefix)
- **Build Number** startet bei `1` und wird bei jedem App Store Upload (TestFlight oder Release) um 1 erhöht
- Build Number wird **nie** zurückgesetzt

## Git-Tags

Format: **`v{MAJOR}.{MINOR}.{PATCH}`** — z.B. `v2.1.0`

```bash
# Tag erstellen (immer annotated, nie lightweight)
git tag -a v2.1.0 -m "v2.1.0 — Kurze Beschreibung"
git push origin v2.1.0
```

### Tag-Regeln

- Tags werden **nur auf `main`** gesetzt (nach Merge von `develop`)
- Jeder Tag = ein potenzieller App Store Release
- Keine Suffixe wie `-stable`, `-beta`, `-rc` — nur `vX.Y.Z`

## Release-Workflow

```
1. Auf develop arbeiten + committen
2. Wenn release-ready:

   git checkout main
   git merge develop

3. Version in Xcode setzen:
   - MARKETING_VERSION → z.B. 2.1.0
   - CURRENT_PROJECT_VERSION → um 1 erhöhen

4. Commit + Tag:
   git add .
   git commit -m "release: v2.1.0 (Build X)"
   git tag -a v2.1.0 -m "v2.1.0 — Beschreibung"
   git push origin main --tags

5. Xcode → Product → Archive → App Store Upload

6. Tag zurück nach develop mergen:
   git checkout develop
   git merge main
   git push origin develop
```

## Branch-Strategie

| Branch          | Zweck                           | Regeln                                    |
|-----------------|----------------------------------|-------------------------------------------|
| `main`          | Stabile Releases                 | Nur Merges von `develop`, nie direkt committen |
| `develop`       | Aktive Entwicklung (Default)     | Tägliche Arbeit, kleine Fixes             |
| `feature/*`     | Grössere Features (>1 Tag)       | Von `develop` abzweigen, per Merge zurück |
| `fix/*`         | Hotfixes                         | Von `main` wenn dringend, sonst `develop` |

## Versions-Historie

| Version  | Build | Datum      | Beschreibung                                          |
|----------|-------|------------|-------------------------------------------------------|
| `v2.0.0` | 1     | 2026-02-23 | Feature-complete: Auth, Notifications, Tools, Discord, Verification, Biometric Lock |
| `v1.0.0` | —     | 2025-02-17 | Erster stabiler Stand: Parser, Sortierung, Reminder   |

## Wann welche Version?

```
Bugfix (Login-Crash gefixt)         → v2.0.1
Kleine Verbesserung (UI-Polish)     → v2.0.2
Neues Feature (Multi-World)         → v2.1.0
Neues Feature (Chat)                → v2.2.0
Kompletter App-Rewrite              → v3.0.0
```

## Checkliste vor Release

- [ ] Alle Features auf `develop` getestet
- [ ] `develop` → `main` gemergt
- [ ] `MARKETING_VERSION` in Xcode aktualisiert
- [ ] `CURRENT_PROJECT_VERSION` erhöht
- [ ] Commit-Message: `release: vX.Y.Z (Build N)`
- [ ] Git-Tag gesetzt und gepusht
- [ ] Xcode Archive + App Store Upload
- [ ] `main` zurück nach `develop` gemergt
- [ ] Versions-Historie in dieser Datei aktualisiert
