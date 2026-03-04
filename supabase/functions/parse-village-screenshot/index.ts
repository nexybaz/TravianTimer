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

serve(async (req: Request) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Body: Base64-Bild extrahieren
    // Auth wird automatisch vom Supabase Gateway ueber JWT-Verification gehandhabt.
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
      console.error("[parse-village-screenshot] ANTHROPIC_API_KEY nicht konfiguriert");
      return errorResponse("KI-Service nicht konfiguriert.");
    }

    const systemPrompt = `Du analysierst Screenshots von Travian Kingdoms Ressourcenfeldern.

Identifiziere alle 18 Rohstofffelder und gib fuer jedes an:
- type: "wood" (gruen/Wald, Holzfaeller), "clay" (braun/rot, Lehmgrube), "iron" (grau/Berg, Eisenmine), "crop" (gelb/Getreide)
- level: Die Zahl auf dem Feld-Badge (1-20). Wenn ein Stern-Symbol auf dem Badge ist, ist das Feld auf der angezeigten Stufe.

Bestimme den Dorf-Typ anhand der Verteilung:
- Zaehle wie viele Felder pro Typ vorhanden sind
- z.B. 4 wood, 4 clay, 4 iron, 6 crop = "4-4-4-6"
- Reihenfolge immer: wood-clay-iron-crop

Antworte NUR mit validem JSON in diesem exakten Format (kein Markdown, kein Text davor oder danach):
{
  "villageType": "4-4-4-6",
  "fields": [
    {"type": "wood", "level": 12},
    {"type": "clay", "level": 10},
    ...
  ]
}

Regeln:
- fields Array muss genau 18 Eintraege haben
- Gueltige Typen: wood, clay, iron, crop
- Gueltige Level: 0-20 (0 wenn nicht erkennbar)
- Gruppiere die Felder nach Typ: erst alle wood, dann clay, dann iron, dann crop
- Die Anzahl pro Typ muss zur villageType Angabe passen`;

    console.log(`[parse-village-screenshot] Sende ${(imageBase64.length / 1024).toFixed(0)} KB Bild an Claude...`);

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
                text: "Analysiere diesen Travian Kingdoms Screenshot und extrahiere die Rohstofffeld-Daten.",
              },
            ],
          },
        ],
      }),
    });

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text();
      console.error(`[parse-village-screenshot] Claude API Fehler ${claudeResponse.status}: ${errorText}`);
      return errorResponse(`KI-Analyse fehlgeschlagen (${claudeResponse.status}).`);
    }

    const claudeResult = await claudeResponse.json();
    const assistantText = claudeResult.content?.[0]?.text ?? "";

    console.log("[parse-village-screenshot] Claude Antwort:", assistantText.substring(0, 200));

    // 3. JSON aus Antwort extrahieren
    let parsed: { villageType: string; fields: { type: string; level: number }[] };

    try {
      // Versuche direktes JSON-Parsing
      parsed = JSON.parse(assistantText.trim());
    } catch {
      // Falls Claude Markdown-Wrapping nutzt: JSON extrahieren
      const jsonMatch = assistantText.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        console.error("[parse-village-screenshot] Kein JSON in Antwort:", assistantText);
        return errorResponse("Screenshot konnte nicht analysiert werden. Bitte einen Screenshot der Ressourcenfelder-Ansicht verwenden.");
      }
      try {
        parsed = JSON.parse(jsonMatch[0]);
      } catch {
        console.error("[parse-village-screenshot] JSON-Parse fehlgeschlagen:", jsonMatch[0]);
        return errorResponse("Analyse-Ergebnis konnte nicht verarbeitet werden.");
      }
    }

    // 4. Validierung
    if (!parsed.villageType || !Array.isArray(parsed.fields)) {
      return errorResponse("Unvollstaendiges Analyse-Ergebnis.");
    }

    // Felder validieren
    const validTypes = new Set(["wood", "clay", "iron", "crop"]);
    const validatedFields = parsed.fields
      .filter((f: any) => validTypes.has(f.type) && typeof f.level === "number")
      .map((f: any) => ({
        type: f.type as string,
        level: Math.max(0, Math.min(20, Math.round(f.level))),
      }));

    if (validatedFields.length < 15) {
      return errorResponse(`Nur ${validatedFields.length} Felder erkannt (18 erwartet). Bitte einen besseren Screenshot verwenden.`);
    }

    // Village-Typ aus tatsaechlicher Verteilung berechnen (Claude-Angabe ggf. korrigieren)
    const counts = { wood: 0, clay: 0, iron: 0, crop: 0 };
    for (const f of validatedFields) {
      counts[f.type as keyof typeof counts]++;
    }
    const correctedType = `${counts.wood}-${counts.clay}-${counts.iron}-${counts.crop}`;

    console.log(`[parse-village-screenshot] Erkannt: ${correctedType}, ${validatedFields.length} Felder`);

    return new Response(
      JSON.stringify({
        villageType: correctedType,
        fields: validatedFields,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("[parse-village-screenshot] Unerwarteter Fehler:", err);
    return errorResponse("Interner Serverfehler.");
  }
});
