// supabase/functions/scrape-tier-dates/index.ts
// Scrapt den Travian Kingdoms Spielwelt-Kalender und aktualisiert
// die Tier-Daten (start_date, tier2_date, tier3_date) in der gameworlds-Tabelle.
//
// Quelle: https://blog.kingdoms.com/de/game-world-calendar/
//
// Aufruf:
//   - Manuell via POST (mit Service Role Key oder Auth Header)
//   - Per Cron (z.B. taeglich)
//
// Die Function upserted nur Welten die bereits in gameworlds existieren,
// ODER legt neue an falls noch nicht vorhanden.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.38/deno-dom-wasm.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const CALENDAR_URL = "https://blog.kingdoms.com/de/game-world-calendar/";

// DD.MM.YYYY → YYYY-MM-DD (ISO)
function parseDate(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed || trimmed === "-" || trimmed === "–" || trimmed === "—") return null;

  const match = trimmed.match(/^(\d{2})\.(\d{2})\.(\d{4})$/);
  if (!match) return null;

  const [, day, month, year] = match;
  return `${year}-${month}-${day}`;
}

// Spielwelt-ID normalisieren: "DE1n" → "de1n", "COM2" → "com2"
function normalizeWorldId(raw: string): string {
  return raw.trim().toLowerCase().replace(/\s+/g, "");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Supabase Admin Client
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // 1. Kalender-Seite abrufen
    console.log(`[scrape-tier-dates] Fetching ${CALENDAR_URL}`);
    const response = await fetch(CALENDAR_URL, {
      headers: {
        "User-Agent": "TravianTimer/1.0 (Tier-Date-Scraper)",
        "Accept-Language": "de-DE,de;q=0.9",
      },
    });

    if (!response.ok) {
      return new Response(
        JSON.stringify({ error: `Kalender nicht erreichbar: ${response.status}` }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const html = await response.text();

    // 2. HTML parsen
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!doc) {
      return new Response(
        JSON.stringify({ error: "HTML konnte nicht geparst werden" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 3. Tabelle finden — suche nach der Tabelle mit den richtigen Headern
    const tables = doc.querySelectorAll("table");
    let targetTable: any = null;

    for (const table of tables) {
      const headerText = table.textContent ?? "";
      if (headerText.includes("Tier 2") && headerText.includes("Tier 3")) {
        targetTable = table;
        break;
      }
    }

    if (!targetTable) {
      return new Response(
        JSON.stringify({ error: "Kalender-Tabelle nicht gefunden" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 4. Header-Spalten identifizieren
    const headerRow = targetTable.querySelector("tr");
    const headers: string[] = [];
    for (const th of headerRow?.querySelectorAll("th, td") ?? []) {
      headers.push((th.textContent ?? "").trim().toLowerCase());
    }

    // Spalten-Indizes ermitteln
    const colWorld = headers.findIndex((h) => h.includes("game world") || h.includes("spielwelt"));
    const colStart = headers.findIndex((h) => h.includes("start"));
    const colSpeed = headers.findIndex((h) => h.includes("speed"));
    const colTier2 = headers.findIndex((h) => h.includes("tier 2"));
    const colTier3 = headers.findIndex((h) => h.includes("tier 3"));

    if (colWorld === -1 || colTier2 === -1 || colTier3 === -1) {
      return new Response(
        JSON.stringify({
          error: "Spalten nicht gefunden",
          headers,
          indices: { colWorld, colStart, colTier2, colTier3 },
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 5. Datenzeilen parsen
    const rows = targetTable.querySelectorAll("tr");
    const worlds: Array<{
      world_id: string;
      start_date: string | null;
      tier2_date: string | null;
      tier3_date: string | null;
      speed: number;
    }> = [];

    for (let i = 1; i < rows.length; i++) {
      const cells = rows[i].querySelectorAll("td");
      if (cells.length < Math.max(colWorld, colTier2, colTier3) + 1) continue;

      const rawWorld = (cells[colWorld]?.textContent ?? "").trim();
      if (!rawWorld) continue;

      const worldId = normalizeWorldId(rawWorld);
      const startDate = colStart >= 0 ? parseDate(cells[colStart]?.textContent ?? "") : null;
      const tier2Date = parseDate(cells[colTier2]?.textContent ?? "");
      const tier3Date = parseDate(cells[colTier3]?.textContent ?? "");

      // Speed parsen: "x3" → 3, "x1" → 1
      let speed = 1;
      if (colSpeed >= 0) {
        const speedText = (cells[colSpeed]?.textContent ?? "").trim().toLowerCase();
        const speedMatch = speedText.match(/x(\d+)/);
        if (speedMatch) speed = parseInt(speedMatch[1]);
      }

      worlds.push({ world_id: worldId, start_date: startDate, tier2_date: tier2Date, tier3_date: tier3Date, speed });
    }

    console.log(`[scrape-tier-dates] ${worlds.length} Welten geparst`);

    // 6. DB: Upserten (nur tier-relevante Felder, API-Keys etc. nicht ueberschreiben)
    let updated = 0;
    let created = 0;

    for (const world of worlds) {
      // Pruefen ob Welt existiert
      const { data: existing } = await supabaseAdmin
        .from("gameworlds")
        .select("world_id")
        .eq("world_id", world.world_id)
        .maybeSingle();

      if (existing) {
        // Nur Tier-Daten + Speed aktualisieren (Keys nicht anfassen!)
        const { error } = await supabaseAdmin
          .from("gameworlds")
          .update({
            start_date: world.start_date,
            tier2_date: world.tier2_date,
            tier3_date: world.tier3_date,
            speed: world.speed,
          })
          .eq("world_id", world.world_id);

        if (!error) updated++;
        else console.error(`[scrape-tier-dates] Update Fehler fuer ${world.world_id}:`, error.message);
      } else {
        // Neue Welt anlegen (ohne API-Keys)
        const { error } = await supabaseAdmin
          .from("gameworlds")
          .insert({
            world_id: world.world_id,
            speed: world.speed,
            speed_troops: world.speed,
            start_date: world.start_date,
            tier2_date: world.tier2_date,
            tier3_date: world.tier3_date,
          });

        if (!error) created++;
        else console.error(`[scrape-tier-dates] Insert Fehler fuer ${world.world_id}:`, error.message);
      }
    }

    const result = {
      scraped: worlds.length,
      updated,
      created,
      worlds: worlds.map((w) => ({
        world_id: w.world_id,
        start: w.start_date,
        tier2: w.tier2_date,
        tier3: w.tier3_date,
        speed: w.speed,
      })),
    };

    console.log(`[scrape-tier-dates] Fertig: ${updated} aktualisiert, ${created} neu angelegt`);

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("[scrape-tier-dates] Fehler:", err);
    return new Response(
      JSON.stringify({ error: "Interner Fehler", details: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
