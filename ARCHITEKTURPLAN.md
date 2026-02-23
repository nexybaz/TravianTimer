# TravianTimer v2 — Architekturplan

> Cloud-Auth, Rollen, Realtime, Travian API, Discord-Bot

---

## Übersicht

Die App wird von einer lokalen Einzelspieler-App zu einer Multi-User-Plattform erweitert.
Spieler loggen sich ein, werden über die Travian-API verifiziert, sehen Deff-Calls live
und sichern Truppen zu — alles in Echtzeit synchronisiert.
Deff-Calls werden im Discord erstellt und automatisch in die App gepusht.
Truppen-Zusicherungen aus der App werden zurück in den Discord-Chat geschrieben.

### Kernkomponenten

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  iOS App    │◄───►│  Supabase    │◄───►│  Travian API    │
│  (SwiftUI)  │     │  (Backend)   │     │  (1x täglich)   │
└─────────────┘     └──────────────┘     └─────────────────┘
      │                    │
      │  Realtime WS       │  Auth + DB + Realtime + Edge Functions
      └────────────────────┘
                           │
                    ┌──────┴───────┐
                    │  Discord Bot │
                    │  (Node.js)   │
                    └──────────────┘
                           │
                    ┌──────┴───────┐
                    │  Discord     │
                    │  Chat        │
                    └──────────────┘
```

### Datenfluss Discord ↔ App

```
Discord Chat                    Supabase                    iOS App
────────────                    ────────                    ───────

1. Caller postet Deff-Call
   "Deff-Call für 003 ...
    0/50k"
        │
        ▼
2. Bot erkennt Call-Format
   → Edge Function: push-call
                                3. INSERT calls
                                   discord_channel_id
                                   discord_message_id
                                   crop_pledged = 0
                                        │
                                        ├─── Realtime ──────► 4. Neuer Call erscheint
                                        │                        in der Liste
                                        └─── Push ──────────► "Neuer Defcall für
                                                                003 Flying Hirsch"

                                                              5. Spieler öffnet Call
                                                                 Sichert 2000 Phalanx zu
                                                                 (1 Getreide/h × 2000 = 2k)
                                                                      │
                                                                      ▼
                                6. INSERT pledges ◄────────── savePledge()
                                   Getreide-Summe neu berechnen
                                   crop_pledged = 2000
                                        │
                                        ▼
7. Bot postet im Chat:  ◄────  Edge Function: pledge-to-discord
   "2/50k                       → Discord Bot Webhook
    (+2 von SpielerName)"

8. Nächster Spieler sichert zu (App oder Discord)
   → Zyklus wiederholt sich
```

---

## Phase 1: Supabase Backend

### 1.1 Datenbank-Schema

```sql
-- ============================================================
-- PROFILES — Spieler-Profile (1:1 mit auth.users)
-- ============================================================
CREATE TABLE profiles (
    id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    player_name       TEXT NOT NULL,
    tribe             TEXT NOT NULL DEFAULT 'Gallier',
    world_id          TEXT,
    world_speed       TEXT DEFAULT 'x1',
    role              TEXT NOT NULL DEFAULT 'player',   -- 'player' | 'caller' | 'admin'
    is_verified       BOOLEAN DEFAULT false,            -- Travian-Account verifiziert?
    travian_player_id INT,                              -- Spieler-ID aus Travian-API
    kingdom_id        INT,                              -- Kingdom-ID aus Travian-API
    kingdom_tag       TEXT,                             -- Kingdom-Tag (z.B. "~WK~")
    created_at        TIMESTAMPTZ DEFAULT now(),
    updated_at        TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- VILLAGES — Dörfer pro Spieler
-- ============================================================
CREATE TABLE villages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    x               INT NOT NULL,
    y               INT NOT NULL,
    allowed_troops  TEXT[] DEFAULT '{}',         -- Ausgewählte Truppentypen
    troop_counts    JSONB DEFAULT '{}',          -- { "gauls.phalanx": 500, ... }
    travian_village_id INT,                      -- Village-ID aus Travian-API
    population      INT,
    is_city         BOOLEAN DEFAULT false,
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- CALLS — Deff-Calls
-- ============================================================
CREATE TABLE calls (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by          UUID NOT NULL REFERENCES profiles(id),
    kingdom_id          INT,                                    -- Kingdom-Scoping: nur Mitglieder sehen den Call
    title               TEXT NOT NULL,
    target_x            INT NOT NULL,
    target_y            INT NOT NULL,
    arrival             TIMESTAMPTZ NOT NULL,
    link                TEXT,
    crop_limit          INT,
    crop_pledged_total  INT NOT NULL DEFAULT 0,                 -- Aktueller Getreide-Stand (Summe aller Pledges)
    status              TEXT NOT NULL DEFAULT 'open',            -- 'open' | 'inactive' | 'archived'
    discord_channel_id  TEXT,                                    -- Discord Channel des Calls
    discord_message_id  TEXT,                                    -- Message-ID des Original-Posts
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- PLEDGES — Truppen-Zusicherungen (Realtime aktiviert)
-- ============================================================
CREATE TABLE pledges (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id         UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES profiles(id),
    player_name     TEXT NOT NULL,
    village_name    TEXT NOT NULL,
    village_x       INT NOT NULL,
    village_y       INT NOT NULL,
    troop_kind      TEXT NOT NULL,
    count           INT NOT NULL,
    pledged_at      TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- DEVICE_TOKENS — APNs Push-Tokens
-- ============================================================
CREATE TABLE device_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token       TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- TROOP_SNAPSHOTS — Truppen-History pro Spieler
-- ============================================================
CREATE TABLE troop_snapshots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    date            TIMESTAMPTZ NOT NULL,
    village_name    TEXT NOT NULL,
    village_x       INT NOT NULL,
    village_y       INT NOT NULL,
    troop_counts    JSONB NOT NULL DEFAULT '{}',     -- { "gauls.phalanx": 500, ... }
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- GAMEWORLDS — Cache für Travian-API Weltdaten (nur Metadaten)
-- ============================================================
CREATE TABLE gameworlds (
    world_id        TEXT PRIMARY KEY,
    speed           INT NOT NULL DEFAULT 1,
    speed_troops    INT NOT NULL DEFAULT 1,
    last_fetched    TIMESTAMPTZ DEFAULT now()
);
-- HINWEIS: Kein players_json! Spielerdaten werden NICHT gecacht,
-- sondern bei Verifizierung direkt in profiles/villages geschrieben.
-- → Travian-Vorgabe: "Spielerdaten nicht zu eigenen Zwecken sammeln"

-- ============================================================
-- DISCORD_CHANNELS — Mapping Discord-Channel → Kingdom
-- ============================================================
CREATE TABLE discord_channels (
    discord_channel_id  TEXT PRIMARY KEY,
    kingdom_id          INT NOT NULL,
    guild_name          TEXT,                    -- Discord Server-Name (informativ)
    created_at          TIMESTAMPTZ DEFAULT now()
);
```

### 1.1b Indexes

```sql
-- Performance-Indexes für häufige Queries
CREATE INDEX idx_pledges_call_id       ON pledges(call_id);
CREATE INDEX idx_calls_kingdom_id      ON calls(kingdom_id);
CREATE INDEX idx_calls_status          ON calls(status);
CREATE INDEX idx_calls_kingdom_status  ON calls(kingdom_id, status);
CREATE INDEX idx_villages_user_id      ON villages(user_id);
CREATE INDEX idx_snapshots_user_id     ON troop_snapshots(user_id);
CREATE INDEX idx_snapshots_date        ON troop_snapshots(user_id, date DESC);
CREATE INDEX idx_device_tokens_user    ON device_tokens(user_id);
CREATE INDEX idx_discord_channels_kingdom ON discord_channels(kingdom_id);
```

### 1.1c Auto-Update Trigger für updated_at

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_profiles
    BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_calls
    BEFORE UPDATE ON calls FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_villages
    BEFORE UPDATE ON villages FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

### 1.2 RLS Policies

```sql
-- PROFILES
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Eigenes Profil lesen"    ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Eigenes Profil ändern"   ON profiles FOR UPDATE USING (auth.uid() = id);
-- Profile im gleichen Kingdom lesen (für Rollen-Verwaltung)
CREATE POLICY "Kingdom-Mitglieder lesen" ON profiles FOR SELECT
    USING (kingdom_id = (SELECT kingdom_id FROM profiles WHERE id = auth.uid()));

-- VILLAGES
ALTER TABLE villages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Eigene Dörfer"           ON villages FOR ALL USING (user_id = auth.uid());

-- CALLS (Kingdom-scoped: nur Mitglieder sehen ihre Calls)
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Kingdom-Calls lesen"     ON calls FOR SELECT
    USING (
        kingdom_id = (SELECT kingdom_id FROM profiles WHERE id = auth.uid())
    );
CREATE POLICY "Call erstellen"           ON calls FOR INSERT
    WITH CHECK (
        created_by = auth.uid()
        AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('caller', 'admin')
    );
CREATE POLICY "Call-Status ändern"       ON calls FOR UPDATE
    USING (
        created_by = auth.uid()
        OR (SELECT role FROM profiles WHERE id = auth.uid()) IN ('caller', 'admin')
    );
CREATE POLICY "Admin Calls löschen"      ON calls FOR DELETE
    USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    );

-- PLEDGES (Kingdom-scoped über den zugehörigen Call)
ALTER TABLE pledges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Kingdom-Pledges lesen"   ON pledges FOR SELECT
    USING (
        call_id IN (
            SELECT id FROM calls
            WHERE kingdom_id = (SELECT kingdom_id FROM profiles WHERE id = auth.uid())
        )
    );
CREATE POLICY "Eigene Pledges"          ON pledges FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Eigene Pledges ändern"   ON pledges FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Eigene Pledges löschen"  ON pledges FOR DELETE USING (user_id = auth.uid());

-- TROOP_SNAPSHOTS
ALTER TABLE troop_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Eigene Snapshots"        ON troop_snapshots FOR ALL USING (user_id = auth.uid());

-- DEVICE_TOKENS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Eigene Tokens"           ON device_tokens FOR ALL USING (user_id = auth.uid());
```

### 1.3 Realtime aktivieren

```sql
-- Pledges: Live-Updates wenn jemand Truppen zusichert
ALTER PUBLICATION supabase_realtime ADD TABLE pledges;

-- Calls: Live-Updates wenn ein neuer Call erstellt wird
ALTER PUBLICATION supabase_realtime ADD TABLE calls;
```

### 1.4 Edge Functions

| Funktion | Trigger | Zweck |
|---|---|---|
| `push-call` | Discord Bot HTTP-Call | Call aus Discord in DB einfügen + Push senden |
| `push-notification` | DB Trigger nach calls INSERT | Push an Kingdom-Mitglieder (device_tokens JOIN profiles WHERE kingdom_id = call.kingdom_id) |
| `pledge-to-discord` | DB Trigger nach pledges INSERT/UPDATE/DELETE | Getreide-Summe berechnen, an Discord Bot senden |
| `fetch-world-data` | App HTTP-Call | Travian API abrufen (serverseitig, 1x täglich) |

> **Hinweis:** `create-profile` ist KEIN Edge Function sondern ein DB-Trigger (siehe 1.5).
> Der Trigger feuert automatisch bei `auth.users INSERT` und braucht keine separate Funktion.

### 1.5 DB Trigger: Auto-Profil

```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, player_name)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'player_name', 'Spieler'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

---

## Phase 2: Auth + Travian-Verifizierung

### 2.1 AuthService.swift (neu)

```
Services/AuthService.swift
├── ObservableObject, Singleton
├── @Published isAuthenticated: Bool
├── @Published currentUserId: UUID?
├── @Published currentRole: UserRole
├── @Published profile: UserProfile?
│
├── signUp(email, password, playerName)
│   → Supabase Auth signUp
│   → Trigger erstellt Profil
│
├── signIn(email, password)
│   → Supabase Auth signIn
│   → Profil + Rolle laden
│
├── signInWithApple()
│   → Apple Sign-In Flow
│
├── signOut()
│   → Token löschen, State zurücksetzen
│
├── verifyTravianAccount(accessToken)
│   → md5(accessToken + privateApiKey)
│   → Abgleich mit API-Daten
│   → travian_player_id + kingdom_id in profiles speichern
│
└── Token-Speicherung: Keychain
    ├── access_token
    ├── refresh_token
    ├── user_id
    └── email
```

### 2.2 UserRole.swift (neu)

```swift
// Models/UserRole.swift
enum UserRole: String, Codable, CaseIterable {
    case player     // Calls sehen, Truppen zusichern
    case caller     // + Deff-Calls erstellen
    case admin      // + Rollen vergeben, Mitglieder verwalten
}
```

### 2.3 AuthView.swift (neu)

```
Views/AuthView.swift
├── Email + Passwort Felder
├── Login Button
├── Registrierung (Name, Email, Passwort)
├── Apple Sign-In Button (optional)
├── Fehleranzeige
└── Nach Login → Travian-Verifizierung (optional, kann übersprungen werden)
```

### 2.4 TravianVerifyView.swift (neu)

```
Views/TravianVerifyView.swift
├── Anleitung: "Öffne Travian → Einstellungen → Externen Zugang"
├── publicSiteKey anzeigen (kopierbar)
├── TextField für accessToken (Spieler fügt ein)
├── Verifizieren-Button
│   → md5(accessToken + privateApiKey)
│   → Abgleich mit API → Spieler-ID + Kingdom zuweisen
└── Erfolg: Profil wird automatisch befüllt
```

### 2.5 Änderungen bestehende Dateien

**TravianTimerApp.swift:**
```swift
@StateObject private var authService = AuthService.shared
// ...
ContentView()
    .environmentObject(callsStore)
    .environmentObject(authService)
```

**ContentView.swift:**
```swift
if authService.isAuthenticated {
    TabView { /* bestehende Tabs */ }
} else {
    AuthView()
}
```

---

## Phase 3: Travian API Service

### 3.1 TravianAPIService.swift (neu)

```
Services/TravianAPIService.swift
├── privateApiKey: String (in App-Config, NICHT im Client sichtbar → via Edge Function)
├── publicSiteKey: String (für Spieler-Verifizierung)
│
├── fetchWorldData(worldId:) async → MyWorldData
│   → Ruft Edge Function fetch-world-data auf
│   → Edge Function ruft Travian API (getMapData)
│   → Nur eigene Daten werden extrahiert & zurückgegeben
│   → Einmal täglich, nach Server-Reset
│
├── MyWorldData (Rückgabe der Edge Function, NUR eigene Daten)
│   ├── player: TravianPlayer (nur der eigene!)
│   │   ├── playerId, name, tribeId
│   │   ├── kingdomId, kingdomTag
│   │   └── villages: [TravianVillage]
│   │       ├── villageId, name, x, y
│   │       ├── population, isCity
│   │       └── isMainVillage
│   └── gameworld
│       ├── speed, speedTroops
│       └── lastUpdateTime
│
└── Einschränkungen (laut Travian):
    ├── 1x täglich abrufen
    ├── Keine dauerhaften/fortlaufenden Anfragen
    ├── Spielerdaten nicht zu eigenen Zwecken sammeln
    └── Nur eigene Daten verarbeiten → Rest wird verworfen
```

### 3.2 Edge Function: fetch-world-data

```
Warum Edge Function statt Client-Call:
→ privateApiKey darf NICHT im App-Binary sein
→ Edge Function hält den Key serverseitig
→ App ruft Edge Function auf, die die Travian-API anfragt

WICHTIG — Datenschutz-konform (Travian-Vorgabe):
→ Die API-Response wird NICHT als Ganzes in der DB gecacht
→ Nur der eigene Spieler wird aus der Response extrahiert
→ Eigene Daten → direkt in profiles + villages geschrieben
→ Welt-Metadaten (speed, speed_troops) → in gameworlds geschrieben
→ Volle API-Response wird nach Verarbeitung verworfen

supabase/functions/fetch-world-data/index.ts
├── Authentifizierung: Bearer Token (Supabase JWT)
├── Parameter: worldId, travianPlayerId (aus profiles)
├── Prüft: last_fetched < heute → nur 1x täglich
├── Ruft Travian API auf (getMapData)
├── Extrahiert NUR:
│   ├── gameworld.speed, gameworld.speedTroops → UPSERT gameworlds
│   ├── Eigenen Spieler (travianPlayerId) → UPDATE profiles
│   │   ├── player_name, tribe, kingdom_id, kingdom_tag
│   │   └── travian_player_id (Bestätigung)
│   └── Dörfer des eigenen Spielers → UPSERT villages
│       ├── name, x, y, population, is_city, is_main_village
│       └── Gelöschte Dörfer markieren
├── Verwirft die restliche API-Response (kein Caching)
└── Gibt eigene Spielerdaten + Dörfer an App zurück
```

### 3.3 Caching-Strategie

```
Was wird gecacht (Datenschutz-konform):
├── gameworlds-Tabelle: NUR speed + speed_troops + last_fetched
├── profiles-Tabelle: Eigener Spielername, Volk, Kingdom
├── villages-Tabelle: Eigene Dörfer (Name, Koordinaten, Population)
└── UserDefaults: Lokaler Cache der eigenen Daten (Offline-Fallback)

Was wird NICHT gecacht:
├── ❌ Fremde Spielerdaten
├── ❌ Vollständige API-Response (players_json)
├── ❌ Andere Kingdoms/Spieler/Dörfer
└── → Travian-Vorgabe: "Spielerdaten nicht sammeln"

Ablauf:
1. App-Start: Prüfe gameworlds.last_fetched
2. Wenn älter als heutiger Reset → Edge Function aufrufen
   → Edge Function extrahiert NUR eigene Daten
   → Schreibt direkt in profiles + villages
3. Wenn aktuell → Daten aus profiles/villages lesen
4. Lokaler UserDefaults-Cache als Offline-Fallback
```

---

## Phase 4: Profil automatisch befüllen

### 4.1 Nach Travian-Verifizierung

```
Spieler verifiziert sich → travian_player_id steht fest
→ API-Daten für diesen Spieler laden:
  ├── player_name     → profiles.player_name
  ├── tribeId         → profiles.tribe (1=Römer, 2=Germanen, 3=Gallier)
  ├── kingdomId       → profiles.kingdom_id
  ├── kingdomTag      → profiles.kingdom_tag
  └── villages[]      → villages-Tabelle befüllen
```

### 4.2 Änderungen bestehende Dateien

**ProfileStore.swift:**
```
- Von UserDefaults auf Supabase umstellen
- Lokaler Cache bleibt (Offline-Fallback)
- Neue Methode: syncFromAPI(player: TravianPlayer)
  → Dörfer aus API in villages-Tabelle upserten
  → Profil-Felder aktualisieren
```

**SettingsView.swift:**
```
Profil-Section:
- Account-Name: aus API (read-only) oder manuell editierbar
- Volk: aus API (read-only nach Verifizierung)
- Spielwelt: aus API (automatisch)
- Truppengeschwindigkeit: aus API (automatisch)
- Rolle: anzeigen (z.B. "Spieler", "Caller", "Admin")

Neue Buttons:
- "Abmelden" (ganz unten)
- "Rollen verwalten" (nur für Admin)
- "Travian-Account verknüpfen" (wenn noch nicht verifiziert)
```

---

## Phase 5: Dörfer automatisch importieren

### 5.1 Automatischer Import aus API

```
Nach Verifizierung:
1. Alle Dörfer des Spielers aus API lesen
2. In villages-Tabelle schreiben (user_id + travian_village_id)
3. Bestehende Dörfer updaten (Name, Koordinaten, Population)
4. Neue Dörfer hinzufügen
5. Gelöschte Dörfer markieren/entfernen

Was NICHT aus der API kommt:
- allowed_troops → Spieler wählt manuell
- troop_counts → Spieler gibt manuell ein
```

### 5.2 Änderung: VillageImportView.swift

```
Vorher: Manueller Text-Import (Koordinaten eintippen/einfügen)
Nachher:
- Primär: "Aus Travian laden" → API-Dörfer anzeigen, bestätigen
- Sekundär: Manueller Import bleibt als Fallback
```

### 5.3 Tägliche Aktualisierung

```
1x täglich nach API-Fetch:
- Neue Dörfer erkennen (Spieler hat gesiedelt/erobert)
- Gelöschte Dörfer erkennen (verloren/aufgelöst)
- Population aktualisieren
- Truppenzahlen bleiben unberührt (manuell gepflegt)
```

---

## Phase 6: Calls-Sync + Rollen

### 6.1 CallsStore Umbau

```
CallsStore.swift:
├── Laden: Supabase calls-Tabelle (statt UserDefaults)
├── Speichern: Supabase INSERT/UPDATE
├── Löschen: Supabase DELETE
├── Lokaler Cache: Offline-Fallback
│
├── createCallFromParser()
│   → Prüft: authService.currentRole == .caller || .admin
│   → INSERT in calls-Tabelle mit created_by = currentUserId
│
├── createCallManual()
│   → Gleiche Rollenprüfung
│
├── savePledge(for:count:)
│   → UPSERT in pledges-Tabelle
│   → user_id = currentUserId
│
└── options(for:now:)
    → Berechnung bleibt lokal (Calculator)
    → Nutzt lokale villages-Daten
```

### 6.2 UI-Anpassungen per Rolle

```
CallsTabView.swift:
- "+" / Call-erstellen Button: nur .caller / .admin
- Alle Spieler sehen alle Calls

SettingsView.swift:
- Parser-Button: nur .caller / .admin

ContentView.swift:
- Tabs bleiben gleich für alle Rollen
- Parser nur über Settings erreichbar (bereits so)
```

### 6.3 RoleManagementView.swift (neu)

```
Views/RoleManagementView.swift
├── Nur für role == .admin erreichbar
├── Liste: Alle Spieler im gleichen Kingdom
│   → Aus profiles WHERE kingdom_id = mein kingdom_id
├── Pro Spieler:
│   ├── Name + Rolle
│   └── Picker: player / caller / admin
├── Änderung: UPDATE profiles SET role = ... WHERE id = ...
└── RLS prüft: Nur Admin darf fremde Rollen ändern
```

### 6.4 Zusätzliche RLS für Rollen-Vergabe

```sql
CREATE POLICY "Admin darf Rollen ändern" ON profiles FOR UPDATE
    USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
        AND (SELECT kingdom_id FROM profiles WHERE id = auth.uid())
            = kingdom_id
    )
    WITH CHECK (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    );
```

---

## Phase 7: Realtime

### 7.1 RealtimeService.swift (neu)

```
Services/RealtimeService.swift
├── ObservableObject
├── Supabase Realtime Client
│
├── subscribeToCall(callId:)
│   → Channel: pledges WHERE call_id = X
│   → Events: INSERT, UPDATE, DELETE
│   → Callback: CallsStore.mergePledge()
│
├── unsubscribeFromCall(callId:)
│   → Channel entfernen
│
├── subscribeToAllCalls()
│   → Channel: calls
│   → Events: INSERT, UPDATE
│   → Callback: CallsStore.mergeCall()
│
└── Lifecycle:
    ├── App-Start: subscribeToAllCalls()
    ├── CallDetail onAppear: subscribeToCall(id)
    ├── CallDetail onDisappear: unsubscribeFromCall(id)
    └── Logout: alle Channels schliessen
```

### 7.2 CallsStore Ergänzungen

```swift
// Eingehende Realtime-Events verarbeiten
func mergePledge(_ pledge: TroopPledge, event: RealtimeEvent) {
    // INSERT → pledge hinzufügen
    // UPDATE → pledge aktualisieren
    // DELETE → pledge entfernen
    // → @Published calls löst UI-Update aus
}

func mergeCall(_ call: CallItem, event: RealtimeEvent) {
    // INSERT → neuen Call in Liste einfügen
    // UPDATE → bestehenden Call aktualisieren
}
```

### 7.3 Auswirkung auf Views

```
CallDetailView.swift:
- Pledge-Badges aktualisieren sich live
- DefenseOverview zeigt live neue Truppen
- Kein manueller Refresh nötig

CallsTabView.swift:
- Neue Calls erscheinen automatisch in der Liste
- Status-Updates (open → done) live sichtbar
```

---

## Phase 8: Push Notifications

### 8.1 Device Token Registration

```
TravianTimerApp.swift / AppDelegate:
- APNs Token erhalten
- An Supabase device_tokens-Tabelle senden
- Bei jedem App-Start aktualisieren
```

### 8.2 Edge Function: push-notification

```
supabase/functions/push-notification/index.ts
├── DB Trigger: AFTER INSERT ON calls
├── Liest: device_tokens JOIN profiles WHERE kingdom_id = NEW.kingdom_id
├── Sendet: APNs Push nur an Kingdom-Mitglieder
├── Payload:
│   ├── title: "Neuer Deff-Call"
│   ├── body: call.title + Koordinaten
│   └── data: { callId: UUID }
└── App empfängt → Deep-Link zu CallDetailView
```

---

## Phase 9: Discord-Bot Integration

### 9.1 Übersicht

```
Der Discord-Bot ist die Brücke zwischen dem Discord-Chat und der App.
Calls werden im Discord erstellt, Pledges fliessen zurück.

Zwei Richtungen:
  Discord → App:  Bot erkennt Call-Format, pusht in Supabase
  App → Discord:  Pledge wird gespeichert, Edge Function benachrichtigt Bot,
                   Bot postet Getreide-Update im Chat
```

### 9.2 Discord Bot (Node.js)

```
discord-bot/
├── index.ts                        -- Bot-Startup, Discord.js Client
├── commands/
│   └── (keine Slash-Commands nötig — Bot reagiert auf Nachrichten)
├── listeners/
│   ├── callDetector.ts             -- Erkennt Deff-Call Format in Nachrichten
│   └── manualCropUpdate.ts         -- Erkennt manuelles Hochzählen "12000/50k"
├── services/
│   ├── supabaseClient.ts           -- Supabase-Verbindung (Service-Role Key)
│   └── webhookServer.ts            -- HTTP-Server für Pledge-Callbacks
└── config.ts                       -- Discord Token, Supabase URL/Keys, Channel-IDs
```

### 9.3 Call-Erkennung (Discord → App)

```
Bot lauscht auf Nachrichten im konfigurierten Deff-Channel.

Erkanntes Format (wie bestehender Parser):
"Deff-Call für 003 Flying Hirsch (12|8)
 https://de1n.kingdoms.com/...
 Ankunft punkt 18:12:00 Uhr
 0/50k"

Bot extrahiert:
├── title:      "003 Flying Hirsch"
├── target_x:   12
├── target_y:   8
├── link:       "https://de1n.kingdoms.com/..."
├── arrival:    18:12:00 (heute oder morgen, je nach Uhrzeit)
├── crop_limit: 50000
├── discord_channel_id:  Channel-ID der Nachricht
└── discord_message_id:  Message-ID der Nachricht

Bot ruft auf:
→ Supabase Edge Function: push-call
  POST /functions/v1/push-call
  Body: { title, target_x, target_y, arrival, link, crop_limit,
          discord_channel_id, discord_message_id }
  Auth: Service-Role Key (Bot ist kein User, sondern System)
```

### 9.4 Edge Function: push-call

```
supabase/functions/push-call/index.ts
├── Auth: Service-Role Key (nur Bot darf aufrufen, bypassed RLS)
├── Parameter: title, coords, arrival, link, cropLimit,
│              discord_channel_id, discord_message_id
├── 1. Kingdom-Zuordnung:
│      SELECT kingdom_id FROM discord_channels
│      WHERE discord_channel_id = param.discord_channel_id
│      → Wenn kein Mapping: Fehler zurückgeben, Call NICHT erstellen
├── 2. Bot-System-User:
│      → Ein fester UUID als BOT_SYSTEM_USER_ID (in Env-Variable)
│      → Einmalig manuell in profiles anlegen:
│        INSERT INTO profiles (id, player_name, role)
│        VALUES ('BOT-UUID', 'Discord-Bot', 'caller')
│      → Dieser User hat role=caller, kein echtes Kingdom
├── 3. INSERT in calls-Tabelle
│      → created_by = BOT_SYSTEM_USER_ID
│      → kingdom_id = aus discord_channels Mapping
│      → crop_pledged_total = 0
│      → discord_channel_id + discord_message_id gesetzt
├── Trigger: push-notification (APNs Push an Kingdom-Mitglieder)
│   → "Neuer Defcall für 003 Flying Hirsch"
└── Return: { callId: UUID, success: true }
```

### 9.5 Pledge-Rückkanal (App → Discord)

```
Spieler sichert Truppen zu in der App
→ INSERT/UPDATE in pledges-Tabelle
→ DB Trigger: pledge-to-discord

supabase/functions/pledge-to-discord/index.ts
├── Trigger: AFTER INSERT OR UPDATE OR DELETE ON pledges
├── 1. Getreide-Summe für den Call neu berechnen:
│      SELECT SUM(count * crop_per_unit) FROM pledges WHERE call_id = X
│      → Braucht TroopKind → cropPerHour Mapping (serverseitig)
├── 2. calls.crop_pledged_total aktualisieren
├── 3. Discord Bot benachrichtigen:
│      POST http://discord-bot-url/webhook/pledge-update
│      Body: {
│        discord_channel_id,
│        discord_message_id,
│        player_name,
│        crop_delta,           -- +2000 Getreide/h (dieses Pledge, = "+2k")
│        crop_pledged_total,   -- 12000 Getreide/h (Gesamtstand, = "12k")
│        crop_limit            -- 50000 Getreide/h (Obergrenze, = "50k")
│      }
└── Bot empfängt Webhook → postet im Channel
```

### 9.6 Bot postet Getreide-Update

```
Bot empfängt Webhook von pledge-to-discord
→ Postet Nachricht im discord_channel_id:

Format:
"12/50k (+2 von SpielerName)"

Alternative: Bot editiert den Original-Call-Post
und aktualisiert die erste Zeile:
"Deff-Call für 003 Flying Hirsch (12|8)
 ...
 12/50k"
```

### 9.7 Manuelles Hochzählen im Discord

```
Spieler die NICHT die App nutzen zählen manuell hoch im Chat:
"15/50k"

Bot erkennt das Format:
├── Regex: (\d+)\s*/\s*(\d+[k]?)
├── Parsed: crop_pledged = 15000 Getreide/h, crop_limit = 50000 Getreide/h
├── Linke Seite = aktueller Stand (Zahl ohne "k", in Tausend)
├── Rechte Seite = Limit (mit "k" = ×1000)
├── Prüft: Bezieht sich auf den letzten aktiven Call im Channel
│
├── Supabase UPDATE:
│   calls SET crop_pledged_total = 15000
│   WHERE discord_channel_id = X AND status = 'open'
│
└── App sieht über Realtime den aktualisierten Stand

Problem: Die Differenz (15k - 12k = 3k) ist ein "Discord-Pledge"
ohne Truppentyp-Details. Das wird als separater Pledge gespeichert:
→ INSERT pledges:
  user_id = NULL (oder Discord-System-User)
  player_name = "Discord" (oder der Discord-Username)
  troop_kind = "unknown"
  count = 3000 (Getreide/h Differenz — NICHT Truppenanzahl)
  village_name = "Discord"
```

### 9.8 Bidirektionale Sync-Logik

```
Der crop_pledged_total ist IMMER die Wahrheit.
Zwei Quellen füllen ihn:

1. App-Pledges (mit Truppentyp-Details):
   → SUM(count * cropPerHour) über alle App-Pledges
   → Wird exakt berechnet

2. Discord-Pledges (nur Getreide-Zahl):
   → Differenz zwischen manuellem Discord-Stand und App-Summe
   → Gespeichert als "unknown" Truppentyp

Berechnung:
  app_crop    = SUM(pledge.count * troopKind.cropPerHour) WHERE troop_kind != 'unknown'
  discord_crop = crop_pledged_total - app_crop
  → discord_crop Pledge wird ggf. angepasst

Die App zeigt in der Deff-Übersicht:
  ├── Detaillierte Truppen (aus App-Pledges)
  └── "Discord-Zusicherungen: 3k" (Sammelposten ohne Truppentyp-Details)
```

### 9.9 Discord Bot Hosting

```
Optionen:
├── Railway.app (einfach, Node.js, kostenlos/günstig)
├── Fly.io (Container, edge-deployed)
├── Eigener Server / VPS
└── Supabase Edge Function (kein persistent process → NICHT für Bot geeignet)

Bot braucht:
├── Persistent process (immer online für Discord Gateway)
├── HTTP-Server für Webhook-Empfang (Pledge-Updates)
├── Umgebungsvariablen:
│   ├── DISCORD_TOKEN
│   ├── SUPABASE_URL
│   ├── SUPABASE_SERVICE_ROLE_KEY
│   ├── DEFF_CHANNEL_ID (oder mehrere)
│   └── WEBHOOK_SECRET (für pledge-to-discord Authentifizierung)
└── Dependencies: discord.js, express (Webhook), @supabase/supabase-js
```

---

## Neue Dateien (komplett)

```
Models/
├── UserRole.swift                  -- enum: player, caller, admin

Services/
├── AuthService.swift               -- Login/Logout/Token (Keychain)
├── SupabaseClient.swift            -- Supabase-URL + Keys, shared Client
├── TravianAPIService.swift         -- Travian API Anbindung (via Edge Function)
├── RealtimeService.swift           -- Websocket-Subscriptions für Pledges + Calls

Views/
├── AuthView.swift                  -- Login/Registrierung/Passwort vergessen
├── OnboardingView.swift            -- Step-by-Step: Welt → Verifizierung → Dörfer
├── TravianVerifyView.swift         -- Travian-Account verifizieren
├── RoleManagementView.swift        -- Admin: Rollen vergeben
├── MigrationView.swift             -- Einmalig: Lokale Daten → Cloud
├── ArchiveView.swift               -- Archivierte Calls einsehen

supabase/functions/
├── push-call/index.ts              -- Discord Bot → Call in DB + Push
├── push-notification/index.ts      -- Push bei neuem Call (Kingdom-scoped)
├── pledge-to-discord/index.ts      -- Pledge-Update → Discord Bot Webhook
├── fetch-world-data/index.ts       -- Travian API abrufen (serverseitig)
├── cleanup-archived/index.ts       -- Archivierte Calls aufräumen (Admin-Aufruf)

supabase/migrations/
├── 001_schema.sql                  -- Tabellen + Indexes + Trigger
├── 002_rls.sql                     -- RLS Policies
├── 003_realtime.sql                -- Realtime Publications
├── 004_cron.sql                    -- pg_cron Jobs (inactive, cleanup)
├── 005_seed.sql                    -- Bot-System-User + troop_crop_map

discord-bot/
├── index.ts                        -- Bot-Startup, Discord.js Client
├── listeners/
│   ├── callDetector.ts             -- Erkennt Deff-Call Format
│   └── manualCropUpdate.ts         -- Erkennt manuelles Hochzählen
├── services/
│   ├── supabaseClient.ts           -- Supabase-Verbindung
│   └── webhookServer.ts            -- HTTP-Server für Pledge-Callbacks
├── config.ts                       -- Tokens, URLs, Channel-IDs
├── package.json
├── package-lock.json               -- Pinned Dependencies
└── Dockerfile                      -- Für Hosting (Railway/Fly.io)
```

## Geänderte Dateien

```
TravianTimerApp.swift               -- AuthService injizieren, APNs Token, Account-Löschung
ContentView.swift                   -- Auth-Guard (Login vs. Tabs), Offline-Banner
SettingsView.swift                  -- Logout, Rolle anzeigen, Admin-Link, Parser per Rolle,
                                       Discord-Channel Setup, Account löschen, Daten exportieren
CallsTabView.swift                  -- Call-Erstellung per Rolle einschränken, 3 Sektionen
CallDetailView.swift                -- Realtime subscribe/unsubscribe, Pledges an Supabase, Offline-Guard
CallsStore.swift                    -- Supabase CRUD statt UserDefaults, Discord-Pledges mergen, Offline-Guard
ProfileStore.swift                  -- Supabase Sync + API-Import + lokaler Cache
TroopHistoryStore.swift             -- Supabase Sync statt UserDefaults
DefenseOverviewView.swift           -- Discord-Sammelposten anzeigen
VillageImportView.swift             -- "Aus Travian laden" Button + manueller Fallback
Models/CallItem.swift               -- createdBy, kingdom_id, discord_*, crop_pledged_total, status: open/inactive/archived
Models/TroopPledge.swift            -- userId wird Pflichtfeld, troop_kind "unknown" für Discord
Info.plist                          -- SUPABASE_URL + SUPABASE_ANON_KEY Einträge
```

---

## Abhängigkeiten

```
Swift Package: supabase-swift
URL: https://github.com/supabase/supabase-swift
Version: 2.x (exact pinnen in Package.resolved)
→ Beinhaltet: Auth, Realtime, PostgREST, Edge Functions
→ Minimum iOS: 15.0

Discord Bot: Node.js 18+
├── discord.js ^14.16.0
├── @supabase/supabase-js ^2.45.0
├── express ^4.21.0
└── Lock: package-lock.json committed
```

---

## Implementierungs-Reihenfolge

```
Phase 1  →  Supabase Setup (Schema, RLS, Realtime, Trigger)
Phase 2  →  AuthService + AuthView (Login funktioniert)
Phase 3  →  TravianAPIService + Edge Function (API-Daten abrufbar)
Phase 4  →  Profil-Sync + Travian-Verifizierung (automatisches Profil)
Phase 5  →  Dörfer-Import aus API (automatisch statt manuell)
Phase 6  →  Calls-Sync + Rollen-Check (Cloud-Calls, Berechtigungen)
Phase 7  →  Realtime (Live-Pledges, Live-Calls)
Phase 8  →  Push Notifications (neuer Call → Push an alle)
Phase 9  →  Discord-Bot (Call-Erkennung, Pledge-Rückkanal, manuelles Hochzählen)
```

Jede Phase ist eigenständig testbar.

```
Abhängigkeiten:
Phase 1-2  → Voraussetzung für alles Weitere
Phase 3-5  → Können parallel entwickelt werden
Phase 6    → Setzt 1-5 voraus
Phase 7-8  → Unabhängig voneinander, setzen Phase 6 voraus
Phase 9    → Setzt Phase 6 + 7 voraus (Calls + Pledges + Realtime müssen stehen)
             Kann parallel zu Phase 8 (Push) entwickelt werden
```

---

## Querschnittsthemen

### Q1: Offline-Strategie

```
Grundregel: Ohne Internet kann man Calls ANSEHEN aber NICHT interagieren.

App öffnen ohne Internet:
├── Bereits geladene Calls sind sichtbar (lokaler Cache)
├── Pledge-Slider ist deaktiviert / ausgegraut
├── Offline-Banner: Deutlich sichtbarer Hinweis "Offline — keine Verbindung"
│   z.B. roter/oranger Banner am oberen Rand
├── Neue Calls erscheinen nicht (kein Realtime)
└── Parser/Manuell-Erstellung deaktiviert

Pledge offline erstellen:
→ NICHT möglich. Slider/Button ist disabled.
→ Sobald Verbindung da: automatisch reconnecten, Realtime-Channels neu aufbauen

Verbindungsstatus:
├── RealtimeService tracked den Websocket-Status
├── @Published isConnected: Bool → UI reagiert
└── Automatischer Reconnect bei Verbindungswiederherstellung
```

### Q2: Conflict Resolution (Discord ↔ App Hochzählen)

```
Problem: Spieler A zählt im Discord hoch UND Bot postet fast gleichzeitig.

Beispiel:
  Call steht bei 4/10k
  Spieler A postet im Discord: "5/10k" (+1 manuell)
  Bot postet (aus App-Pledge): "5/10k" (+1 aus App)
  → Echter Stand: 4 + 1 (Discord) + 1 (App) = 6

Lösung: Bot addiert immer, statt absolut zu setzen.

Bot-Logik bei eigenem Post:
├── 1. Bot berechnet neuen Stand aus DB: crop_pledged_total
├── 2. Bot liest letzten Discord-Stand (letzte Zahl im Chat)
├── 3. Wenn Discord-Stand > DB-Stand vor dem Pledge:
│      → Jemand hat manuell hochgezählt
│      → Bot addiert sein Delta auf den Discord-Stand
│      → Korrigiert seinen Post: "6/10k (+1 von SpielerName)"
│      → Updated DB: crop_pledged_total = 6000
├── 4. Wenn Discord-Stand == DB-Stand:
│      → Kein Konflikt, normaler Post
└── 5. Bot merkt sich immer den letzten bekannten Discord-Stand pro Call

Bot-Logik bei manuellem Discord-Hochzählen:
├── 1. Spieler postet "5/10k"
├── 2. Bot erkennt: Delta = 5000 - letzter_bekannter_stand
├── 3. Bot prüft: Kommen in den nächsten 2-3 Sekunden eigene Posts?
│      (Race-Condition Fenster)
├── 4. Bot speichert Discord-Delta als Pledge (troop_kind = "unknown")
└── 5. App sieht über Realtime den neuen Stand
```

### Q3: Calls-Scoping (Kingdom-basiert)

```
Regel: Calls sind an ein Kingdom gebunden. Nur Kingdom-Mitglieder sehen ihre Calls.

Schema-Ergänzung:
  calls.kingdom_id  INT REFERENCES ... (Kingdom des Callers)

RLS-Änderung:
  -- Alter: USING (true)
  -- Neu:
  CREATE POLICY "Kingdom-Calls lesen" ON calls FOR SELECT
      USING (
          kingdom_id = (SELECT kingdom_id FROM profiles WHERE id = auth.uid())
      );

Call-Erstellung:
  → kingdom_id wird automatisch aus dem Profil des Callers/Bots gesetzt

Zukunft: Falls Cross-Kingdom nötig wird → eigene "Gruppen"-Tabelle
         statt kingdom_id. Aber vorerst reicht Kingdom-Scoping.
```

### Q4: TroopKind → Getreide Mapping (serverseitig)

```
Das Mapping existiert aktuell nur in Swift (Models.swift TroopKind.cropPerHour).
Für pledge-to-discord Edge Function muss es serverseitig verfügbar sein.

Lösung: JSON-Lookup-Tabelle in Supabase

Option A: Statische JSON-Datei im Edge Function Bundle
  troop_crop_map.json:
  {
    "gauls.phalanx": 1,
    "gauls.swordsman": 1,
    "gauls.haeduan": 3,
    "gauls.druidrider": 2,
    ...
  }

Option B: DB-Tabelle
  CREATE TABLE troop_types (
      kind        TEXT PRIMARY KEY,    -- z.B. "gauls.phalanx"
      crop_per_hour INT NOT NULL       -- z.B. 1
  );

→ Option A ist einfacher und reicht aus (Daten ändern sich nicht).
→ Bei jedem App-Update prüfen ob neue Truppentypen dazukommen.
```

### Q5: Mehrere Calls gleichzeitig im Discord

```
Problem: 2 Calls offen, Spieler postet "5/10k" — welcher Call?

Lösung: Bot trackt aktive Calls pro Channel mit Thread-Kontext.

Variante A: Eigener Thread pro Call
├── Bot erstellt Discord-Thread unter dem Call-Post
├── Hochzählen passiert IM Thread
├── Bot weiss durch Thread-ID welcher Call gemeint ist
└── Vorteil: Klar getrennt, kein Rätselraten

Variante B: Letzter Call im Channel
├── Bot nimmt den LETZTEN offenen Call im Channel
├── Wenn mehrere offen: Bot fragt "Welcher Call?"
│   oder: Spieler muss den Call-Namen erwähnen
└── Nachteil: Fehleranfällig

→ Variante A (Threads) ist sauberer und empfohlen.
```

### Q6: Call-Lifecycle

```
Status-Flow:
  open → inactive → archived

Automatisch:
├── arrival Zeitpunkt erreicht → status = 'inactive'
├── Prüfung: DB Trigger oder App-seitig bei jedem Laden
│   → Besser: Supabase pg_cron Job (jede Minute)
│     UPDATE calls SET status = 'inactive'
│     WHERE status = 'open' AND arrival < now()
└── Inactive Calls: Read-only, keine neuen Pledges möglich

Manuell (nur Admin):
├── "Archivieren" Button → status = 'archived'
├── Archivierte Calls verschwinden aus der Hauptliste
└── Eigener "Archiv"-Bereich in der App (für alle Kingdom-Mitglieder sichtbar)

RLS-Ergänzung:
  -- Nur Admin/Caller darf Status ändern
  CREATE POLICY "Call-Status ändern" ON calls FOR UPDATE
      USING (
          (created_by = auth.uid()
           OR (SELECT role FROM profiles WHERE id = auth.uid()) IN ('caller', 'admin'))
      );

Schema-Ergänzung:
  calls.status: 'open' | 'inactive' | 'archived'

App-Änderungen:
├── CallsTabView: 3 Sektionen (Aktiv / Inaktiv / Archiv)
│   oder: Archiv als eigener Tab/Button
├── Inaktive Calls: Pledge-Slider disabled, Fortschrittsbalken bleibt
└── Archiv-Button nur für Admin sichtbar
```

### Q7: Passwort-Reset / Account-Recovery

```
Supabase Auth bietet built-in:
├── signUp: Email-Bestätigung (Confirmation Email)
├── resetPasswordForEmail: "Passwort vergessen" Link per Mail
└── updateUser: Neues Passwort setzen nach Reset-Link

App-Flow:
├── AuthView → "Passwort vergessen?" Link
├── Email-Eingabe → Supabase sendet Reset-Mail
├── User klickt Link → Deep-Link in App oder Webseite
└── Neues Passwort eingeben → fertig

Konfiguration (Supabase Dashboard):
├── Email Templates: Deutsche Texte
├── Redirect URLs: App-Schema für Deep-Links
└── Rate Limiting: Max 3 Reset-Mails pro Stunde
```

### Q8: TroopHistoryStore Sync

```
TroopHistoryStore (Snapshots) wird gesynct.

Neue Tabelle:
  CREATE TABLE troop_snapshots (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
      date          TIMESTAMPTZ NOT NULL,
      village_name  TEXT NOT NULL,
      village_x     INT NOT NULL,
      village_y     INT NOT NULL,
      troop_counts  JSONB NOT NULL DEFAULT '{}',
      created_at    TIMESTAMPTZ DEFAULT now()
  );

RLS:
  -- Spieler sieht nur eigene Snapshots
  CREATE POLICY "Eigene Snapshots" ON troop_snapshots FOR ALL
      USING (user_id = auth.uid());

TroopHistoryStore.swift Änderungen:
├── Von UserDefaults auf Supabase umstellen
├── Lokaler Cache bleibt (Offline-Ansicht)
├── Snapshot speichern → Supabase INSERT
└── Snapshots laden → Supabase SELECT ORDER BY date DESC
```

### Q9: Datenmigration (lokal → Cloud)

```
Beim ersten Login eines bestehenden Users mit lokalen Daten.

Ablauf:
├── 1. User loggt sich ein (erstmalig)
├── 2. App prüft: Gibt es lokale Daten in UserDefaults?
│      ├── Dörfer in ProfileStore? (profileVillagesV1)
│      ├── Calls in CallsStore? (callsV2)
│      └── Snapshots in TroopHistoryStore? (troopHistoryV1)
├── 3. Wenn ja → Migrations-Dialog:
│      "Du hast lokale Daten. Sollen diese in deinen Account übernommen werden?"
│      ├── [Ja, übernehmen] → Upload zu Supabase
│      └── [Nein, neu starten] → Lokale Daten löschen
├── 4. Upload:
│      ├── Dörfer → villages-Tabelle (user_id = aktueller User)
│      ├── Calls → calls-Tabelle (created_by = aktueller User, kingdom_id setzen)
│      ├── Snapshots → troop_snapshots-Tabelle
│      └── Profil-Felder (accountName, tribe, worldId) → profiles-Tabelle
├── 5. Nach erfolgreicher Migration:
│      ├── Lokale UserDefaults-Keys löschen
│      └── Flag setzen: "migration_completed"
└── 6. Bei erneutem Login: Migration überspringen

Neue View: MigrationView.swift (einmalig beim ersten Login)
```

### Q10: APNs Setup

```
Voraussetzungen für Push Notifications:

Apple Developer Account:
├── APNs Key (.p8 Datei) erstellen
│   → Apple Developer Portal → Keys → "Apple Push Notifications service (APNs)"
│   → Key ID + Team ID notieren
├── App ID mit Push Notification Capability
└── Provisioning Profile mit Push-Berechtigung

Supabase Konfiguration:
├── APNs Key (.p8) in Supabase Edge Function Secrets hinterlegen:
│   ├── APNS_KEY_ID
│   ├── APNS_TEAM_ID
│   ├── APNS_KEY_CONTENT (Base64-encoded .p8)
│   └── APNS_TOPIC (Bundle-ID der App)
├── Edge Function (push-notification) nutzt diese Secrets
└── Sandbox vs. Production: Environment Flag

App (Xcode):
├── Signing & Capabilities → + Push Notifications
├── Background Modes → Remote notifications
└── AppDelegate: didRegisterForRemoteNotificationsWithDeviceToken
```

### Q11: Onboarding-Flow

```
Ablauf nach Registrierung:

1. AuthView
   ├── Email + Passwort → Account erstellen
   └── Supabase Auth signUp → Bestätigungs-Email

2. Email bestätigen
   └── User klickt Link → Account aktiv

3. OnboardingView (neu, step-by-step)
   ├── Step 1: Spielwelt wählen
   │   └── Picker mit verfügbaren Welten (aus API oder manuell)
   │
   ├── Step 2: Travian-Verifizierung (optional)
   │   ├── Anleitung: publicSiteKey im Spiel eingeben
   │   ├── accessToken einfügen → Verifizierung
   │   ├── Erfolg: Profil automatisch befüllt (Name, Volk, Kingdom, Dörfer)
   │   └── "Überspringen" → Account bleibt "Nicht verifiziert"
   │       → Deutlich sichtbar: ⚠️ Badge/Banner "Nicht verifiziert"
   │       → Spieler kann trotzdem Calls sehen und Truppen zusichern
   │       → Dörfer müssen manuell importiert werden
   │
   ├── Step 3: Dörfer bestätigen/importieren
   │   ├── Verifiziert: API-Dörfer anzeigen, Spieler bestätigt
   │   └── Nicht verifiziert: Manueller Import
   │
   └── Step 4: Fertig → Hauptansicht

Verifizierung nachholen:
├── Settings → "Travian-Account verknüpfen"
├── Jederzeit möglich
└── Nach Verifizierung: Profil + Dörfer automatisch aktualisieren

Schema-Ergänzung:
  profiles.is_verified  BOOLEAN DEFAULT false
```

### Q12: SupabaseClient Konfiguration

```
Services/SupabaseClient.swift
├── Singleton: static let shared
├── Konfiguration:
│   ├── supabaseURL:  aus Info.plist Key "SUPABASE_URL"
│   ├── supabaseAnonKey: aus Info.plist Key "SUPABASE_ANON_KEY"
│   └── NICHT hardcoded im Code (damit verschiedene Envs möglich)
│
├── Aufbau:
│   import Supabase
│   let client = SupabaseClient(
│       supabaseURL: URL(string: supabaseURL)!,
│       supabaseKey: supabaseAnonKey
│   )
│
├── Zugriff: SupabaseClient.shared.client
│
└── Env-Variablen in Xcode:
    ├── Debug: Supabase Local / Staging
    └── Release: Supabase Production
    → Via xcconfig-Dateien oder Xcode Build Settings

Info.plist Einträge:
  SUPABASE_URL       = $(SUPABASE_URL)
  SUPABASE_ANON_KEY  = $(SUPABASE_ANON_KEY)
```

### Q13: iOS Mindestversion & Kompatibilität

```
supabase-swift Anforderungen:
├── Minimum: iOS 15.0
├── Empfohlen: iOS 16.0+ (für neuere SwiftUI-Features)
│
├── Aktuelles Deployment Target prüfen:
│   → Xcode → Project → General → Minimum Deployments
│   → Falls < iOS 15: Anheben auf iOS 16
│
├── supabase-swift Version: 2.x (aktuell)
│   → Package.swift oder Xcode SPM: exact Version pinnen
│   → z.B. .package(url: "...", exact: "2.5.0")
│
└── discord.js (Bot):
    → package.json: "discord.js": "^14.0.0"
    → Node.js: >= 16.11.0
```

### Q14: CallItem Status-Migration (lokal → Cloud)

```
Lokales CallItem hat: .open | .done
Cloud calls haben:    'open' | 'inactive' | 'archived'

Mapping bei Migration (Q9):
├── .open   → 'open'     (falls arrival > now)
├── .open   → 'inactive' (falls arrival <= now)
├── .done   → 'archived'
│
├── Zusätzlich: lokales CallItem hat kein kingdom_id
│   → Bei Migration: kingdom_id aus aktuellem User-Profil setzen
│   → Falls User noch kein Kingdom: Calls ohne kingdom_id migrieren,
│     werden erst sichtbar wenn User einem Kingdom beitritt
│
└── MigrationView zeigt Vorschau:
    "X offene Calls, Y abgeschlossene Calls werden übernommen"
```

### Q15: Soft-Delete vs. CASCADE bei Calls

```
Problem: ON DELETE CASCADE auf pledges löscht sofort alle Zusicherungen.

Entscheidung: Kein echtes Löschen von Calls.

Stattdessen:
├── "Löschen" in der App = status auf 'archived' setzen
├── Archivierte Calls bleiben in der DB (mit allen Pledges)
├── Kein DELETE auf calls-Tabelle durch die App
│
├── Admin kann in Settings: "Archiv leeren"
│   → Eigene Edge Function: cleanup-archived
│   → Löscht alle Calls mit status='archived' UND older_than 30 Tage
│   → CASCADE löscht dann auch Pledges automatisch
│
├── ON DELETE CASCADE bleibt als Safety-Net:
│   → Wenn ein User seinen Account löscht → seine Pledges werden entfernt
│   → Aber: Calls bleiben (created_by zeigt auf gelöschten User)
│
└── RLS "Admin Calls löschen" Policy bleibt bestehen
    → Aber nur für den Cleanup-Fall (Archiv leeren), nicht für normalen Betrieb
```

### Q16: Discord Bot Error Handling / Retry

```
Fehlerquellen und Strategien:

1. Bot → Supabase (push-call) fehlschlägt:
   ├── Retry: 3 Versuche mit exponential backoff (1s, 3s, 9s)
   ├── Fallback: Nachricht im Discord: "⚠️ Call konnte nicht erstellt werden"
   └── Logging: Fehler in Bot-Log schreiben

2. Supabase → Bot Webhook (pledge-to-discord) fehlschlägt:
   ├── Edge Function: HTTP POST an Bot-Webhook
   ├── Wenn Bot nicht erreichbar:
   │   → Edge Function loggt Fehler
   │   → Pledge wird trotzdem gespeichert (DB ist Wahrheit)
   │   → Discord-Stand wird beim nächsten erfolgreichen Post korrigiert
   ├── Retry in Edge Function: 2 Versuche (1s delay)
   └── Dead Letter: Fehlgeschlagene Webhooks in separate Tabelle:
       CREATE TABLE webhook_failures (
           id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
           function    TEXT NOT NULL,
           payload     JSONB NOT NULL,
           error       TEXT,
           created_at  TIMESTAMPTZ DEFAULT now()
       );

3. Discord API Rate Limits:
   ├── discord.js handled automatisch (built-in rate limit handling)
   ├── Bot queued Nachrichten bei Rate Limit
   └── Max ~50 Nachrichten/Sekunde pro Channel (selten ein Problem)

4. Bot-Neustart / Crash:
   ├── Process Manager: PM2 oder Docker restart policy
   ├── Bot liest beim Start alle offenen Calls aus DB
   ├── Baut internen State neu auf
   └── Verpasste Webhooks: Bot fragt beim Start nach pending webhook_failures
```

### Q17: Rate Limiting für Edge Functions

```
Schutz vor Missbrauch:

1. Supabase-seitig:
   ├── RLS verhindert bereits unauthorisierte Zugriffe
   ├── Supabase hat built-in Rate Limiting (abhängig vom Plan)
   └── Für Custom Limits: Edge Function prüft manuell

2. pledge-to-discord:
   ├── Debounce: Wenn mehrere Pledges in <2 Sekunden kommen,
   │   nur EINEN Discord-Post senden (mit akkumuliertem Stand)
   ├── Implementierung: Supabase pg_notify + Bot sammelt Events
   └── Max 1 Discord-Post pro Call pro 3 Sekunden

3. push-call:
   ├── Nur Service-Role Key (Bot) darf aufrufen
   ├── Bot prüft: Max 10 Calls pro Channel pro Stunde
   └── Duplicate Check: Gleiche Koordinaten + Arrival = ignorieren

4. fetch-world-data:
   ├── Edge Function prüft: last_fetched < heute
   ├── Wenn bereits abgerufen: Welt-Metadaten aus gameworlds zurückgeben
   ├── Eigene Spielerdaten aus profiles/villages lesen (kein erneuter API-Call)
   ├── Max 1 API-Call pro Spielwelt pro Tag
   └── Keine Fremd-Spielerdaten gecacht (Travian-Compliance)
```

### Q18: Teststrategie

```
Unit Tests (Swift):
├── CalculatorTests
│   ├── Distanzberechnung
│   ├── Sendezeit-Berechnung
│   ├── Speed-Multiplikator
│   └── Edge Cases (gleiche Koordinaten, negative Coords)
│
├── CallParserTests
│   ├── Standard Discord-Format
│   ├── Verschiedene Koordinaten-Formate
│   ├── Zeitformate (HH:MM, HH:MM:SS)
│   ├── Crop-Limit Parsing ("0/50k", "12/50k")
│   ├── Fehlende Felder → korrekte Fehler
│   └── Edge Cases (Mitternacht, Unicode)
│
├── DefenseAggregatorTests
│   ├── Korrekte Summen
│   ├── Unique Player Count
│   └── Leere Pledges
│
└── AuthServiceTests (Mocks)
    ├── Login/Logout Flow
    ├── Token Refresh
    └── Rollen-Check

Integration Tests (Supabase):
├── RLS Policy Tests
│   ├── Kingdom-Scoping: User A sieht nicht User B's Calls
│   ├── Rollen: Player kann keinen Call erstellen
│   ├── Pledges: Nur eigene bearbeiten
│   └── Profil: Nur eigenes ändern
│
├── Edge Function Tests
│   ├── push-call: Korrekter Insert + Push
│   ├── pledge-to-discord: Webhook wird gesendet
│   └── fetch-world-data: Caching funktioniert
│
└── Realtime Tests
    ├── Pledge-Event kommt an
    ├── Call-Status-Update kommt an
    └── Reconnect nach Disconnect

Discord Bot Tests (Node.js):
├── Call-Erkennung Regex
├── Manuelles Hochzählen Regex
├── Conflict Resolution Logik
├── Webhook-Empfang
└── Error/Retry Logik

Testframework:
├── Swift: XCTest (built-in)
├── Edge Functions: Deno.test
├── Discord Bot: Jest oder Vitest
└── E2E: Manuell (Testflight + Discord Test-Server)
```

### Q19: Discord-Bot Kingdom-Zuordnung

```
Problem: Bot erkennt einen Call im Discord — aber welches Kingdom?

Lösung: Mapping-Tabelle discord_channels (siehe Schema 1.1).

Setup (einmalig durch Admin):
├── Admin öffnet App → Settings → "Discord verbinden"
├── Gibt Discord-Channel-ID ein (oder wählt aus Bot-Liste)
├── App sendet: INSERT INTO discord_channels (discord_channel_id, kingdom_id)
│   → kingdom_id = aktuelles Kingdom des Admins
├── Bot bestätigt im Channel: "✅ Verbunden mit Kingdom ~WK~"
│
├── Alternative: Bot-Slash-Command "/setup-kingdom"
│   → Bot fragt Supabase: Welcher User hat diese Discord-ID?
│   → Setzt kingdom_id aus dem User-Profil
│
└── Ein Channel = ein Kingdom (1:1 Mapping)
    → Mehrere Channels pro Kingdom möglich (z.B. #deff-main, #deff-wings)
    → Aber ein Channel gehört immer nur zu einem Kingdom

Bot-Logik bei Call-Erkennung:
├── Channel-ID → discord_channels → kingdom_id
├── Wenn kein Mapping: Bot ignoriert die Nachricht
│   (oder antwortet: "⚠️ Channel nicht konfiguriert. Nutze /setup-kingdom")
└── kingdom_id wird an push-call Edge Function übergeben
```

### Q20: App Store / Deployment

```
TestFlight:
├── Beta-Test mit Kingdom-Mitgliedern
├── Internal Testing: sofort verfügbar
├── External Testing: Apple Review (1-2 Tage)
└── TestFlight Link an Discord senden

App Store Review:
├── Privacy Policy URL nötig (siehe Q21)
├── App-Beschreibung: Deutsch + Englisch
├── Screenshots: iPhone + iPad (optional)
├── Kategorie: Games → Utilities oder Strategy
├── Preis: Kostenlos
└── Hinweis: Drittanbieter-Login (Supabase Auth) erfordert
    Apple Sign-In als Alternative (App Store Guideline 4.8)

Release-Strategie:
├── Phase 1-6: TestFlight (internes Testing)
├── Phase 7-8: TestFlight (externes Testing mit Kingdom)
├── Phase 9: App Store Release
└── Danach: Automatische Releases via Xcode Cloud oder Fastlane
```

### Q21: Datenschutz / DSGVO

```
Gespeicherte personenbezogene Daten:
├── Email-Adresse (Auth)
├── Spielername (Profil)
├── Travian-Spieler-ID (API-Verifizierung)
├── Kingdom-Zugehörigkeit
├── Device Token (Push Notifications)
└── Truppen-Daten (Spielstrategie)

Erforderliche Massnahmen:
├── Privacy Policy (deutsch + englisch)
│   → Gehostet auf eigener Webseite oder GitHub Pages
│   → Link in App Store + App Settings
│
├── Daten-Export:
│   → Settings → "Meine Daten exportieren"
│   → JSON-Export aller eigenen Daten
│
├── Account-Löschung:
│   → Settings → "Account löschen"
│   → Supabase Auth: deleteUser()
│   → CASCADE löscht alle verknüpften Daten
│   → Apple erfordert Account-Löschung in der App (Guideline 5.1.1)
│
├── Keine Weitergabe an Dritte
├── Daten nur auf Supabase-Servern (EU oder US, je nach Projekt)
├── Verschlüsselung in Transit (HTTPS) und at Rest (Supabase default)
│
└── Cookie-Banner: Nicht nötig (native App, keine Cookies)
```

### Q22: Logging / Monitoring

```
Discord Bot:
├── Structured Logging: winston oder pino
├── Log Levels: info (Calls erkannt), warn (Retry), error (Fehler)
├── Output: stdout (Railway/Fly.io loggt automatisch)
└── Alerts: Webhook an privaten Discord-Channel bei Fehlern

Edge Functions:
├── Supabase Dashboard: Logs pro Function einsehbar
├── console.log / console.error → Supabase Logs
└── webhook_failures Tabelle für fehlgeschlagene Webhooks

App (Swift):
├── os.log für Debug-Builds
├── Crashlytics oder Sentry für Production (optional)
└── Keine User-Daten in Logs (DSGVO)

Metriken (nice-to-have):
├── Aktive User pro Tag
├── Calls erstellt pro Tag
├── Pledges pro Call (Durchschnitt)
└── Discord vs. App Pledges Ratio
```

### Q23: Version-Pinning

```
Swift Dependencies (Package.swift / Xcode SPM):
├── supabase-swift:  exact "2.x.x" (aktuell stable)
└── Keine weiteren Dependencies geplant

Discord Bot (package.json):
├── discord.js:          "^14.16.0"
├── @supabase/supabase-js: "^2.45.0"
├── express:             "^4.21.0"
└── Node.js Runtime:     >= 18 LTS

Edge Functions (Supabase):
├── Deno Runtime (managed by Supabase)
├── supabase-js Import: pinned Version in import_map.json
└── Keine externen Dependencies nötig

Lock Files:
├── Bot: package-lock.json committed
└── Swift: Package.resolved committed
```

### Q24: Cleanup-Job (alte Daten aufräumen)

```
pg_cron Jobs (Supabase):

1. Calls → inactive (jede Minute):
   UPDATE calls SET status = 'inactive'
   WHERE status = 'open' AND arrival < now();

2. Archivierte Calls aufräumen (täglich um 03:00):
   DELETE FROM calls
   WHERE status = 'archived'
   AND updated_at < now() - INTERVAL '90 days';
   → CASCADE löscht zugehörige Pledges automatisch

3. Webhook-Failures aufräumen (wöchentlich):
   DELETE FROM webhook_failures
   WHERE created_at < now() - INTERVAL '30 days';

4. Alte Troop-Snapshots aufräumen (monatlich):
   DELETE FROM troop_snapshots
   WHERE created_at < now() - INTERVAL '365 days';

Konfiguration:
├── Supabase Dashboard → Database → Extensions → pg_cron aktivieren
├── SELECT cron.schedule('inactive-calls', '* * * * *', $$ ... $$);
├── SELECT cron.schedule('cleanup-archived', '0 3 * * *', $$ ... $$);
└── SELECT cron.schedule('cleanup-webhooks', '0 4 * * 0', $$ ... $$);
```

---

## Glossar: Getreide/k-Notation

```
Im Travian-Kontext wird in "k" (= 1000 Getreide/h) gezählt, NICHT in Truppenanzahl.
Die "k" beziehen sich immer auf den Getreide-Verbrauch pro Stunde.

Beispiele:
  1000 Phalanx    = 1k   (1 Getreide/h pro Phalanx  × 1000 = 1000 Getreide/h)
  1000 Haeduaner  = 3k   (3 Getreide/h pro Haeduaner × 1000 = 3000 Getreide/h)
  500 Druiden     = 1k   (2 Getreide/h pro Druide    × 500  = 1000 Getreide/h)

Call-Format "0/50k" bedeutet:
  0     = 0 Getreide/h bisher zugesagt
  50k   = 50.000 Getreide/h gewünscht (Obergrenze)

Hochzählen im Discord:
  "5/50k"   → 5.000 Getreide/h zugesagt
  "12/50k"  → 12.000 Getreide/h zugesagt
  usw.

In der App:
  crop_pledged_total  = Summe aller Pledges in Getreide/h
  crop_limit          = Obergrenze in Getreide/h
  TroopKind.cropPerHour = Getreide-Verbrauch pro Einheit pro Stunde

Berechnung pro Pledge:
  pledge_crop = pledge.count × TroopKind(pledge.troop_kind).cropPerHour
```

---

## Travian API Einschränkungen

Laut offizieller Erlaubnis:
- ✅ API-Zugang erlaubt
- ✅ Manuelles Kopieren/Einfügen durch Spieler erlaubt
- ⚠️ 1x täglich abrufen (nach Server-Reset)
- ⚠️ Keine dauerhaften/fortlaufenden Anfragen
- ❌ Kein automatisches Auslesen über inoffizielle Wege
- ❌ Spielerdaten nicht zu eigenen Zwecken sammeln/weiterverwerten

### Umsetzung im Plan (Compliance)

```
Vorgabe: "Spielerdaten nicht zu eigenen Zwecken sammeln/weiterverwerten"

Unsere Lösung:
├── API-Response wird NICHT als Ganzes gespeichert (kein players_json)
├── Nur die Daten des anfragenden Spielers werden extrahiert:
│   ├── Eigener Name, Volk, Kingdom → profiles-Tabelle
│   └── Eigene Dörfer → villages-Tabelle
├── Welt-Metadaten (speed, speed_troops) → gameworlds-Tabelle
├── Alle anderen Spielerdaten werden sofort verworfen
└── Kein Zugriff auf fremde Spieler-/Dörferdaten möglich

Vorgabe: "1x täglich, nach Server-Reset"
├── Edge Function prüft gameworlds.last_fetched < heute
├── Wenn bereits abgerufen → cached Welt-Metadaten verwenden
├── Eigene Daten aus profiles/villages lesen (nicht nochmal API)
└── Max 1 API-Call pro Spielwelt pro Tag (technisch erzwungen)

Vorgabe: "Keine dauerhaften/fortlaufenden Anfragen"
├── Kein Polling, kein Cron-Job für API
├── Nur On-Demand wenn Spieler App öffnet + last_fetched veraltet
└── Kein Background-Fetch der Travian API
```
