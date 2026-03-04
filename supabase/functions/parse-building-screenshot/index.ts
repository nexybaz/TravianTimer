import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Hilfsfunktion: Fehler-Response (immer HTTP 200, damit Swift SDK den Body lesen kann)
function errorResponse(error: string) {
  return new Response(
    JSON.stringify({ error }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

// Gueltige Gebaeude-IDs (ohne Rohstofffelder 1-4)
const VALID_BUILDING_IDS = new Set([
  5, 6, 7, 8, 9,           // Ressourcen-Gebaeude
  10, 11,                   // Lager, Kornspeicher
  13, 14, 15, 16, 17, 18,  // Schmiede, Turnierplatz, HG, VP, Markt, Botschaft
  19, 20, 21, 22, 23,      // Kaserne, Stall, Werkstatt, Akademie, Versteck
  24, 25, 26, 27, 28,      // Rathaus, Residenz, Palast, Schatzkammer, Handelskontor
  29, 30, 31, 32, 33, 34,  // Gr. Kaserne, Gr. Stall, Mauern, Steinmetz
  35, 36,                   // Brauerei, Fallensteller
  41, 42, 46,               // Pferdetraenke, Wassergraben, Heilzelt
]);

serve(async (req: Request) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Body: Base64-Bild extrahieren
    const body = await req.json();
    const imageBase64: string | undefined = body.image;

    if (!imageBase64 || imageBase64.length < 100) {
      return errorResponse("Kein Bild gesendet oder Bild zu klein.");
    }

    // Groesse pruefen (~4MB base64 limit)
    if (imageBase64.length > 5_500_000) {
      return errorResponse("Bild zu gross (max. ~4 MB).");
    }

    // 2. Claude API aufrufen
    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!anthropicKey) {
      console.error("[parse-building-screenshot] ANTHROPIC_API_KEY nicht konfiguriert");
      return errorResponse("KI-Service nicht konfiguriert.");
    }

    const systemPrompt = `Du analysierst Screenshots der Travian Kingdoms Dorfuebersicht (Gebaeude-Ansicht im Dorf).

Identifiziere alle sichtbaren Gebaeude und gib fuer jedes an:
- buildingId: Die Gebaeude-ID (siehe Liste unten)
- level: Die Stufe/Zahl auf dem Badge des Gebaeudes (1-20). Wenn ein Stern-Symbol auf dem Badge ist, ist das Gebaeude auf der angezeigten Stufe.

Gebaeude-IDs und ihre Namen:
5=Saegewerk (verarbeitet Holz, Zahnrad-Symbol)
6=Lehmbrennerei (verarbeitet Lehm, Flammen)
7=Eisenschmelze (verarbeitet Eisen, Blitz)
8=Getreidemuehle (verarbeitet Getreide, Muehle/Windrad)
9=Baeckerei (verarbeitet Getreide, Kuchen/Brot)
10=Lager (lagert Rohstoffe, grosses Lagerhaus)
11=Kornspeicher (lagert Getreide, Silo/Scheune)
13=Schmiede (Hammer und Amboss, Upgrade Truppen-Angriff)
14=Turnierplatz (Reitplatz, Upgrade Truppen-Verteidigung)
15=Hauptgebaeude (zentrales grosses Gebaeude, Baugeschwindigkeit)
16=Versammlungsplatz (offener Platz mit Fahnen, Truppen-Uebersicht)
17=Marktplatz (Handelskarren/Wagen, Ressourcen-Handel)
18=Botschaft (Fahne/Flagge, Allianz-Funktionen)
19=Kaserne (Infanterie-Ausbildung, Soldaten-Figuren)
20=Stall (Kavallerie-Ausbildung, Pferde/Tiere)
21=Werkstatt (Belagerungsgeraete, Katapulte/Rammen)
22=Akademie (Forscher/Buecher, Einheiten erforschen)
23=Versteck (versteckt Rohstoffe, unterirdisch/getarnt)
24=Rathaus (Feste feiern, grosses Verwaltungsgebaeude)
25=Residenz (schuetzt vor Eroberung, Wohngebaeude)
26=Palast (wie Residenz aber groesser, Krone/Thron)
27=Schatzkammer (Schaetze lagern, Gold/Muenzen)
28=Handelskontor (verbessert Haendler, Handelsposten)
29=Grosse Kaserne (wie Kaserne aber groesser, 2. Ausbildungsschlange)
30=Grosser Stall (wie Stall aber groesser, 2. Ausbildungsschlange)
31=Stadtmauer (Roemer-Mauer, Steinmauer)
32=Erdwall (Germanen-Mauer, Erdwall/Holzpalisade)
33=Palisade (Gallier-Mauer, Holzzaun)
34=Steinmetz (Steinbearbeitung, nur Hauptstadt)
35=Brauerei (Bierbrauen, nur Germanen-Hauptstadt)
36=Fallensteller (Fallen bauen, nur Gallier)
41=Pferdetraenke (Pferde-Upgrade, nur Roemer)
42=Wassergraben (Verteidigung, Graben mit Wasser)
46=Heilzelt (heilt verwundete Truppen, Kreuz/Medizin)

Antworte NUR mit validem JSON in diesem exakten Format (kein Markdown, kein Text davor oder danach):
{
  "buildings": [
    {"buildingId": 15, "level": 20},
    {"buildingId": 16, "level": 20},
    {"buildingId": 10, "level": 18}
  ]
}

Regeln:
- Nur Gebaeude auflisten die sichtbar sind
- NICHT IDs 1-4 verwenden (das sind Rohstofffelder der Aussenansicht)
- Level: 1-20 (0 wenn Zahl nicht erkennbar)
- Die Mauer ist das Gebaeude am Rand/Ring des Dorfes (31 fuer Roemer, 32 fuer Germanen, 33 fuer Gallier)
- Der Versammlungsplatz (16) ist immer vorhanden (offener Platz in der Mitte)
- Das Hauptgebaeude (15) ist immer vorhanden (groesstes Gebaeude)
- Maximal 23 Gebaeude moeglich
- Jede buildingId sollte nur einmal vorkommen (keine Duplikate)
- Wenn ein Bauplatz leer/unbebaut ist, diesen NICHT auflisten`;

    console.log(`[parse-building-screenshot] Sende ${(imageBase64.length / 1024).toFixed(0)} KB Bild an Claude...`);

    const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 1024,
        system: systemPrompt,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/jpeg",
                  data: imageBase64,
                },
              },
              {
                type: "text",
                text: "Analysiere diesen Travian Kingdoms Dorfuebersicht-Screenshot und extrahiere alle sichtbaren Gebaeude mit ihren Stufen.",
              },
            ],
          },
        ],
      }),
    });

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text();
      console.error(`[parse-building-screenshot] Claude API Fehler ${claudeResponse.status}: ${errorText}`);
      return errorResponse(`KI-Analyse fehlgeschlagen (${claudeResponse.status}).`);
    }

    const claudeResult = await claudeResponse.json();
    const assistantText = claudeResult.content?.[0]?.text ?? "";

    console.log("[parse-building-screenshot] Claude Antwort:", assistantText.substring(0, 300));

    // 3. JSON aus Antwort extrahieren
    let parsed: { buildings: { buildingId: number; level: number }[] };

    try {
      parsed = JSON.parse(assistantText.trim());
    } catch {
      // Falls Claude Markdown-Wrapping nutzt: JSON extrahieren
      const jsonMatch = assistantText.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        console.error("[parse-building-screenshot] Kein JSON in Antwort:", assistantText);
        return errorResponse("Screenshot konnte nicht analysiert werden. Bitte einen Screenshot der Dorfuebersicht verwenden.");
      }
      try {
        parsed = JSON.parse(jsonMatch[0]);
      } catch {
        console.error("[parse-building-screenshot] JSON-Parse fehlgeschlagen:", jsonMatch[0]);
        return errorResponse("Analyse-Ergebnis konnte nicht verarbeitet werden.");
      }
    }

    // 4. Validierung
    if (!Array.isArray(parsed.buildings)) {
      return errorResponse("Unvollstaendiges Analyse-Ergebnis.");
    }

    // Gebaeude validieren: nur gueltige IDs, Level 0-20, keine Duplikate
    const seenIds = new Set<number>();
    const validatedBuildings = parsed.buildings
      .filter((b: any) => {
        if (!VALID_BUILDING_IDS.has(b.buildingId)) return false;
        if (typeof b.level !== "number") return false;
        if (seenIds.has(b.buildingId)) return false;
        seenIds.add(b.buildingId);
        return true;
      })
      .map((b: any) => ({
        buildingId: b.buildingId as number,
        level: Math.max(0, Math.min(20, Math.round(b.level))),
      }));

    if (validatedBuildings.length < 3) {
      return errorResponse(`Nur ${validatedBuildings.length} Gebaeude erkannt. Bitte einen besseren Screenshot der Dorfuebersicht verwenden.`);
    }

    console.log(`[parse-building-screenshot] Erkannt: ${validatedBuildings.length} Gebaeude`);

    return new Response(
      JSON.stringify({
        buildings: validatedBuildings,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("[parse-building-screenshot] Unerwarteter Fehler:", err);
    return errorResponse("Interner Serverfehler.");
  }
});
