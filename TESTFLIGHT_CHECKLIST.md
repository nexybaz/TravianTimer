# TestFlight Release Checkliste — TravianTimer

Stand: 23. Februar 2026

---

## PHASE 1: Xcode-Projekt vorbereiten

### 1.1 Privacy Manifest pruefen
- [ ] `TravianTimer/PrivacyInfo.xcprivacy` ist im Xcode-Projekt sichtbar (Target > Build Phases > Copy Bundle Resources)
- [ ] Falls nicht: Datei in Xcode per Drag-and-Drop zum TravianTimer-Target hinzufuegen

### 1.2 Deployment Target korrigieren
- [ ] Xcode > TravianTimer Target > General > Minimum Deployments
- [ ] Auf `iOS 17.0` setzen (oder `16.0` falls aeltere Geraete unterstuetzen)
- [ ] Aktueller Wert `26.0` ist ungueltig und wird abgelehnt

### 1.3 Entitlements pruefen
- [ ] `aps-environment` steht auf `development` — das ist korrekt fuer TestFlight
- [ ] Apple schaltet automatisch auf `production` beim App Store Upload

### 1.4 Bundle Identifier bestaetigen
- [ ] Bundle ID: `tt.TravianTimer`
- [ ] Muss mit App Store Connect App uebereinstimmen

### 1.5 Version und Build setzen
- [ ] MARKETING_VERSION = `2.0.0` (bereits gesetzt)
- [ ] CURRENT_PROJECT_VERSION = `1` (bereits gesetzt)
- [ ] Bei jedem neuen Upload: Build Number um 1 erhoehen

---

## PHASE 2: App Store Connect einrichten

### 2.1 App erstellen (falls noch nicht geschehen)
- [ ] App Store Connect > Apps > Pluszeichen > Neue App
- [ ] Plattform: iOS
- [ ] Name: `TravianTimer`
- [ ] Primaere Sprache: Deutsch
- [ ] Bundle-ID: `tt.TravianTimer`
- [ ] SKU: `traviantimer`

### 2.2 App-Informationen
- [ ] App Store Connect > App > App-Informationen
- [ ] Kategorie: Unterhaltung (Primary), Dienstprogramme (Secondary)
- [ ] Inhaltliche Rechte: "Nein" (App enthaelt keine Inhalte Dritter die lizenziert werden muessen)

### 2.3 Altersfreigabe
- [ ] App Store Connect > App > Altersfreigabe
- [ ] Alle Fragen mit den folgenden Angaben beantworten:

| Frage | Antwort | Begruendung |
|---|---|---|
| Cartoon or Fantasy Violence | Selten/Gering | Militaerische Einheiten im Spielkontext |
| Realistic Violence | Nein | Keine realistische Gewalt |
| Prolonged Graphic or Sadistic Violence | Nein | — |
| Profanity or Crude Humor | Nein | — |
| Mature/Suggestive Themes | Nein | — |
| Horror/Fear Themes | Nein | — |
| Medical/Treatment Information | Nein | — |
| Alcohol, Tobacco, or Drug Use | Nein | — |
| Simulated Gambling | Nein | — |
| Sexual Content or Nudity | Nein | — |
| Unrestricted Web Access | Nein | Kein eingebetteter Browser mit freier Navigation |
| Gambling with Real Currency | Nein | — |

Erwartetes Rating: **4+** oder **9+** (wegen militaerischem Spielkontext)

### 2.4 Datenschutz-URL
- [ ] Die Datei `docs/privacy-policy.html` muss gehostet werden
- [ ] Option A: GitHub Pages aktivieren (Settings > Pages > Source: main, Folder: /docs)
  - URL wird: `https://nexybaz.github.io/TravianTimer/privacy-policy.html`
- [ ] Option B: Eigene Domain
- [ ] Die URL eintragen unter: App Store Connect > App > App-Datenschutz > Datenschutzrichtlinien-URL

### 2.5 App-Datenschutz (Privacy Nutrition Labels)
- [ ] App Store Connect > App > App-Datenschutz > Loslegen

**Frage: Erhebt die App Daten?**
Antwort: Ja

**Datentypen auswaehlen und konfigurieren:**

#### Kontaktdaten
- [x] E-Mail-Adresse
  - Verwendung: App-Funktionalitaet
  - Mit Identitaet verknuepft: Ja
  - Tracking: Nein

#### Name
- [x] Name
  - Verwendung: App-Funktionalitaet
  - Mit Identitaet verknuepft: Ja
  - Tracking: Nein

#### Kennungen
- [x] Benutzer-ID
  - Verwendung: App-Funktionalitaet
  - Mit Identitaet verknuepft: Ja
  - Tracking: Nein
- [x] Geraete-ID (APNs Token)
  - Verwendung: App-Funktionalitaet
  - Mit Identitaet verknuepft: Ja
  - Tracking: Nein

#### Gameplay-Inhalte
- [x] Gameplay Content
  - Verwendung: App-Funktionalitaet
  - Mit Identitaet verknuepft: Ja
  - Tracking: Nein

**Alle anderen Kategorien: Nein / Nicht auswaehlen**
- Kein Standort
- Keine Gesundheit
- Keine Finanzdaten
- Kein Browserverlauf
- Keine Suchverlauf
- Keine Kaufhistorie
- Keine sensiblen Daten
- Kein Tracking

**Frage: Wird die App zum Tracking verwendet?**
Antwort: Nein

### 2.6 Export Compliance
- [ ] Beim ersten Build-Upload fragt Apple nach Verschluesselung
- [ ] Frage: "Verwendet die App Verschluesselung?"
- [ ] Antwort: **Ja**
- [ ] Frage: "Ist die Verschluesselung auf Standard-HTTPS/TLS beschraenkt?"
- [ ] Antwort: **Ja** (App nutzt nur HTTPS via URLSession + CryptoKit SHA-256 fuer Apple Sign-In PKCE)
- [ ] Ergebnis: Keine weitere Dokumentation noetig, kein ERN erforderlich

Alternative: Key `ITSAppUsesNonExemptEncryption` in Info.plist auf `false` setzen, um die Frage beim Upload zu ueberspringen.

---

## PHASE 3: Build hochladen

### 3.1 Archive erstellen
- [ ] Xcode > Product > Archive
- [ ] Ziel: "Any iOS Device (arm64)"
- [ ] Warten bis Archiv fertig

### 3.2 Upload
- [ ] Organizer > Distribute App > App Store Connect
- [ ] Upload
- [ ] Warten auf "Processing" in App Store Connect (5-30 Minuten)

---

## PHASE 4: TestFlight konfigurieren

### 4.1 Interne Tests (automatisch)
- [ ] Build erscheint unter TestFlight > Builds > iOS
- [ ] Status muss "Ready to Test" sein
- [ ] Falls "Missing Compliance": Export Compliance beantworten (siehe 2.6)

### 4.2 Oeffentlicher TestFlight Link einrichten
- [ ] App Store Connect > TestFlight > Oeffentlicher Link (linke Sidebar)
- [ ] Neue Gruppe erstellen: "Public Beta"
- [ ] Oeffentlichen Link aktivieren
- [ ] Tester-Limit setzen (max 10.000)
- [ ] Build zuweisen

### 4.3 TestFlight-Pflichtfelder

**Beta App Description (Deutsch):**
```
TravianTimer ist ein Companion-Tool fuer Travian Kingdoms. Die App hilft bei der Koordination von Deff-Calls innerhalb eines Koenigreichs.

Funktionen:
- Deff-Call Uebersicht mit Echtzeit-Updates
- Truppen-Pledges fuer koordinierte Verteidigung
- Truppen-Verwaltung und Historie
- Gebaeude- und Helden-Tools
- Push-Benachrichtigungen bei neuen Calls
- Discord-Integration (serverseitig)

Voraussetzung: Travian Kingdoms Account auf einem aktiven Server.
```

**What to Test:**
```
Bitte testet folgende Bereiche:

1. Account erstellen (E-Mail oder Apple Sign-In)
2. Travian-Account verknuepfen (Profilbeschreibung-Methode)
3. Truppen importieren und aktualisieren
4. Deff-Calls ansehen und Truppen pledgen
5. Push-Benachrichtigungen empfangen
6. Tools: Gebaeude-Rechner, Helden-Items, Guides
7. Einstellungen: App-Sperre mit Face ID / Touch ID
8. Account loeschen (bitte nur mit Test-Account)

Bekannte Einschraenkungen:
- Nur Travian Kingdoms (nicht Travian Legends)
- Server-Auswahl aktuell auf aktive Welten beschraenkt
```

**Kontaktinformationen:**
```
E-Mail: [DEINE E-MAIL]
```

**Review-Hinweise (fuer Apple Review, falls relevant):**
```
Demo-Account:
E-Mail: [TEST-ACCOUNT-EMAIL ERSTELLEN]
Passwort: [TEST-ACCOUNT-PASSWORT]

Die App erfordert einen aktiven Travian Kingdoms Account fuer volle Funktionalitaet.
Ohne Travian-Verknuepfung sind die Tools trotzdem nutzbar.
Die Travian-Verifizierung kann uebersprungen werden.

Die App kommuniziert mit:
- Supabase Backend (pnawukicutnnbtkogvnm.supabase.co) fuer Auth und Daten
- Apple Push Notification Service fuer Benachrichtigungen
- Travian Kingdoms API fuer Spieler-Verifizierung (nur bei manueller Verknuepfung)

Keine In-App-Kaeufe. Keine Werbung. Keine externen Tracker.
```

---

## PHASE 5: Vor Aktivierung pruefen

- [ ] Build-Status in TestFlight: "Ready to Test"
- [ ] Keine "Missing Compliance" Warnung
- [ ] Oeffentlicher Link ist aktiv und kopierbar
- [ ] Testgeraet: App ueber Link installiert und funktionsfaehig

---

## REVIEW-TRIGGER UND ABLEHNUNGSGRUENDE

### Hohes Risiko

| Problem | Status | Massnahme |
|---|---|---|
| Account-Deletion fehlt (Guideline 5.1.1v) | Implementiert | `delete-account` Edge Function deployed, Button in AccountDetailView |
| Datenschutz-URL fehlt | Erstellt | `docs/privacy-policy.html` — muss gehostet werden |
| Privacy Manifest fehlt | Erstellt | `PrivacyInfo.xcprivacy` hinzugefuegt |
| Deployment Target ungueltig (26.0) | Offen | In Xcode auf 17.0 korrigieren |

### Mittleres Risiko

| Problem | Begruendung | Massnahme |
|---|---|---|
| Clipboard-Zugriff ohne Erklaerung | App liest Clipboard fuer Truppen-Import | UIPasteboard-Read ist ab iOS 16 ohne Prompt erlaubt, aber Info-Text im UI vorhanden |
| Travian-API Zugriff | Drittanbieter-Game-API | Review-Notes erklaeren den Zusammenhang |
| Keine Screenshots im App Store Listing | TestFlight braucht keine, aber Apple koennte nachfragen | Fuer spaeter vorbereiten |

### Kein Risiko

| Thema | Status |
|---|---|
| IDFA / Tracking | Nicht vorhanden |
| In-App Purchases | Nicht vorhanden |
| Werbung | Nicht vorhanden |
| Standort | Nicht verwendet |
| Kamera | Nicht verwendet (nur PhotosPicker) |
| Hintergrund-Aktivitaet | Nur Push-Notifications |
