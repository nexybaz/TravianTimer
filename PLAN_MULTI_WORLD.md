# Multi-World Feature — Spielwelt-Wechsel in der App

> Erstellt: 22.02.2026
> Status: GEPLANT (noch nicht implementiert)

---

## Idee

In den Einstellungen kann man auf "Spielwelt" tippen und eine andere Welt auswaehlen.
Die gesamte App passt sich danach an: Koenigreich, Spieler, Rolle, Truppen, Calls usw.
Ein User kann also auf mehreren Welten gleichzeitig spielen (z.B. de1n + testx5).

---

## Ist-Zustand (aktuell)

### Datenbank
- `profiles` hat EIN `world_id` Feld → 1 User = 1 Welt
- `villages` hat `user_id` FK aber **kein** `world_id` → alle Doerfer in einem Topf
- `calls` filtert nach `kingdom_id` (nicht world_id)
- `pledges` hat `call_id` FK aber **kein** `world_id`
- `troop_snapshots` hat `user_id` aber **kein** `world_id`
- `gameworlds` Tabelle existiert bereits mit allen Welten + API-Keys

### App
- `AuthService.profile` → EIN `UserProfile` mit `worldId`, `kingdomId`, `tribe`
- `ProfileStore.loadFromSupabase()` → laedt ALLE Villages des Users (kein world_id Filter)
- `CallsStore.loadCalls()` → filtert nach `kingdom_id`
- `@AppStorage("selectedWorldId")` → wird nur fuer Verifizierung/Truppen-Link genutzt

---

## Ziel-Architektur

### Kern-Idee: `user_worlds` Tabelle

Statt ein `world_id` in `profiles` zu speichern, gibt es eine neue **`user_worlds`** Tabelle:

```sql
CREATE TABLE user_worlds (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    world_id    TEXT REFERENCES gameworlds(world_id) NOT NULL,

    -- Travian-Verifizierung pro Welt
    is_verified    BOOLEAN DEFAULT false,
    player_name    TEXT,
    tribe          TEXT,
    kingdom_id     INT,
    kingdom_tag    TEXT,

    -- Timestamps
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now(),

    UNIQUE(user_id, world_id)
);
```

### Betroffene Tabellen — world_id hinzufuegen

| Tabelle | Aenderung |
|---------|----------|
| `villages` | + `world_id TEXT REFERENCES gameworlds(world_id)` |
| `calls` | + `world_id TEXT REFERENCES gameworlds(world_id)` (zusaetzlich zu kingdom_id) |
| `pledges` | Braucht KEIN world_id (laeuft ueber call_id → calls.world_id) |
| `troop_snapshots` | + `world_id TEXT` |
| `profiles` | `world_id`, `tribe`, `kingdom_id` etc. → wandern nach `user_worlds` |
| `profiles` | + `active_world_id TEXT` (aktuell ausgewaehlte Welt) |

### Migration-Strategie

```sql
-- Migration 021: Multi-World Support

-- 1. user_worlds Tabelle erstellen
CREATE TABLE user_worlds ( ... );

-- 2. Bestehende Daten migrieren (profiles → user_worlds)
INSERT INTO user_worlds (user_id, world_id, is_verified, player_name, tribe, kingdom_id, kingdom_tag)
SELECT id, world_id, is_verified, player_name, tribe, kingdom_id, kingdom_tag
FROM profiles
WHERE world_id IS NOT NULL;

-- 3. world_id zu villages hinzufuegen
ALTER TABLE villages ADD COLUMN world_id TEXT REFERENCES gameworlds(world_id);
-- Bestehende Villages: world_id aus profiles uebernehmen
UPDATE villages v SET world_id = p.world_id
FROM profiles p WHERE v.user_id = p.id;

-- 4. world_id zu calls hinzufuegen
ALTER TABLE calls ADD COLUMN world_id TEXT REFERENCES gameworlds(world_id);

-- 5. world_id zu troop_snapshots hinzufuegen
ALTER TABLE troop_snapshots ADD COLUMN world_id TEXT;

-- 6. active_world_id zu profiles hinzufuegen
ALTER TABLE profiles ADD COLUMN active_world_id TEXT REFERENCES gameworlds(world_id);
UPDATE profiles SET active_world_id = world_id WHERE world_id IS NOT NULL;

-- 7. RLS Policies anpassen (world_id in Queries einbauen)
-- villages: user_id + world_id Filterung
-- calls: kingdom_id + world_id Filterung

-- 8. Unique Constraint fuer villages anpassen
-- ALTER TABLE villages DROP CONSTRAINT IF EXISTS villages_user_id_x_y_key;
-- ALTER TABLE villages ADD CONSTRAINT villages_user_world_coords_key UNIQUE(user_id, world_id, x, y);
```

---

## App-Aenderungen

### Phase 1: Datenmodell (Backend)

#### AuthService.swift
```
Aenderungen:
- UserProfile behaelt world_id als "active_world_id"
- Neues Struct: UserWorld (id, worldId, isVerified, playerName, tribe, kingdomId, kingdomTag)
- Neue Methode: loadUserWorlds() → [UserWorld]
- Neue Methode: switchWorld(worldId:) → setzt active_world_id in profiles
- profile?.worldId liefert immer die AKTIVE Welt
```

#### ProfileStore.swift
```
Aenderungen:
- loadFromSupabase() → Filter: user_id + world_id (aktive Welt)
- syncToSupabase() → world_id beim Insert/Update mitsenden
- Neuer Observer: Wenn AuthService.activeWorldId aendert → villages neu laden
```

#### CallsStore.swift
```
Aenderungen:
- loadCalls() → Filter: kingdom_id UND world_id
- subscribeToRealtime() → Channel nach world_id + kingdom_id
- Bei World-Switch: unsubscribe alte Welt, subscribe neue Welt
```

#### TroopHistoryStore.swift
```
Aenderungen:
- recordSnapshot() → world_id mitspeichern
- loadHistory() → nach world_id filtern
```

### Phase 2: UI

#### SettingsView.swift — World Picker
```
Neue Section: "Spielwelt"
- Zeigt aktive Welt an (z.B. "DE1N")
- Tap → Sheet mit Picker aller verifizierten Welten
- "Neue Welt hinzufuegen" Button → TravianVerifyView oeffnen
- World-Switch:
  1. AuthService.switchWorld(worldId)
  2. ProfileStore neu laden
  3. CallsStore neu laden
  4. App-State reset
```

#### ContentView.swift — World-Aware
```
Aenderungen:
- Reagiert auf AuthService.activeWorldId Changes
- Laedt alles neu bei World-Switch
- Badge/Indicator welche Welt aktiv ist (optional, z.B. in TabBar)
```

#### TravianVerifyView.swift — Neue Welt hinzufuegen
```
Aenderungen:
- Erstellt neuen user_worlds Eintrag statt profiles.world_id zu setzen
- Nach Verifizierung: Automatisch zur neuen Welt wechseln
```

### Phase 3: Edge Functions

#### verify-player
```
Aenderungen:
- Schreibt in user_worlds statt profiles
- Erstellt user_worlds Eintrag bei neuer Verifizierung
```

#### fetch-world-data
```
Aenderungen:
- Villages mit world_id verknuepfen
- Liest aus user_worlds statt profiles
```

#### push-call (Discord Bot)
```
Aenderungen:
- world_id beim Call-Insert mitschicken
- Bot muss wissen welche Welt der Discord-Channel betrifft
  → Discord-Channel ↔ World Mapping (neues Feld in DB oder Config)
```

#### pledge-to-discord
```
Aenderungen:
- Minimal: call_id → calls.world_id fuer Crop-Berechnung
- world_id-aware Speed-Multiplikator
```

### Phase 4: Discord Bot

```
Aenderungen:
- Channel ↔ World Mapping (z.B. in Bot-Config oder DB)
- push-call sendet world_id mit
- Pledge-Messages zeigen Welt-Kontext wenn noetig
```

---

## Aufwand-Schaetzung

| Phase | Bereich | Geschaetzt |
|-------|---------|-----------|
| 1 | DB Migration (021) | 1-2h |
| 1 | RLS Policies anpassen | 1h |
| 2 | AuthService (UserWorld, switchWorld) | 2-3h |
| 2 | ProfileStore (world_id Filter) | 1-2h |
| 2 | CallsStore (world_id Filter + Realtime) | 2h |
| 2 | TroopHistoryStore | 30min |
| 3 | SettingsView World Picker UI | 1-2h |
| 3 | ContentView World-Aware | 1h |
| 3 | TravianVerifyView anpassen | 1h |
| 4 | Edge Functions (verify, fetch, push-call, pledge) | 2-3h |
| 4 | Discord Bot (Channel ↔ World) | 1-2h |
| 5 | Testing & Bugfixes | 2-3h |
| | **Total** | **~16-22h** |

---

## Risiken & Fallstricke

1. **Realtime-Subscriptions**: Pro Welt ein eigener Channel. Bei World-Switch muss der alte Channel sauber unsubscribed werden → Sonst doppelte Updates oder Memory Leaks.

2. **Discord Bot ↔ World Mapping**: Aktuell hat der Bot keine Zuordnung Channel → Welt. Entweder:
   - Ein Discord-Server pro Welt (einfach aber unflexibel)
   - Channel-Naming-Convention (z.B. `#deff-calls-de1n`)
   - DB-Tabelle `discord_channel_worlds` (flexibel)

3. **Bestehende User migrieren**: Alle bestehenden Villages, Calls, Pledges brauchen ein world_id Backfill. Wenn kein world_id in profiles → Default-Welt oder NULL lassen?

4. **Gleichzeitige Welten**: User koennte auf de1n und testx5 gleichzeitig aktive Calls haben. Push Notifications → fuer welche Welt? Badge-Count pro Welt?

5. **Performance**: Mehr Queries pro User (pro Welt filtern). Sollte aber minimal sein da world_id in Index.

---

## Priorisierung / Empfehlung

### Minimal Viable (Phase A — "World Switcher Light")
Nur die **Anzeige** anpassen, ohne volle Multi-World DB:
1. World Picker in Settings
2. Bei Welt-Wechsel: Re-Verify + Re-Fetch (alles neu laden)
3. Villages/Calls werden ueberschrieben (nicht parallel gehalten)
→ **Aufwand: ~6-8h** — Einfacher, aber man verliert Daten der alten Welt

### Voll (Phase B — "True Multi-World")
Komplette `user_worlds` Architektur wie oben beschrieben.
→ **Aufwand: ~16-22h** — Daten aller Welten bleiben erhalten

### Empfehlung
**Phase A zuerst**, dann spaeter Phase B falls Multi-World wirklich benoetigt wird.
Die meisten Spieler spielen 1-2 Welten und wechseln selten gleichzeitig.

---

## Abhaengigkeiten / Voraussetzungen

- [x] Gameworlds-Tabelle mit allen Welten (Migration 010 + 020)
- [x] API-Keys automatisch registriert (list-worlds Edge Function)
- [x] World Picker UI existiert bereits (TravianVerifyView)
- [ ] Onboarding-Flow fertig (Plan: goofy-cuddling-sketch.md)
- [ ] Truppen-Parser stabil fuer alle Welten (gerade implementiert)
