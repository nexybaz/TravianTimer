// supabase/functions/list-worlds/index.ts
// Laedt aktive Spielwelten von status.kingdoms.com
// Die Seite liefert JSON in einem <script id="__GW_DATA__"> Tag.
// Upserted sie in die gameworlds-Tabelle.
// Registriert automatisch API-Keys fuer neue Welten via requestApiKey.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// App-Registrierungsdaten fuer Travian API
const APP_EMAIL = "traviantimer@proton.me";
const APP_SITE_NAME = "TravianTimer";
const APP_SITE_URL = "https://traviantimer.app";

// Speed aus dem World-ID-String extrahieren (z.B. "de1nx3" -> 3, "testx5" -> 5)
function parseSpeed(worldId: string): number {
  const match = worldId.match(/x(\d+)$/);
  return match ? parseInt(match[1]) : 1;
}

// Subdomain aus URL extrahieren (z.B. "https://arabia1n.kingdoms.com" -> "arabia1n")
function extractSubdomain(url: string): string {
  const match = url.match(/https?:\/\/([^.]+)\.kingdoms\.com/);
  return match ? match[1] : "";
}

// API-Key bei Travian registrieren
async function requestApiKey(subdomain: string): Promise<{ privateApiKey: string; publicSiteKey: string } | null> {
  try {
    const apiUrl = `https://${subdomain}.kingdoms.com/api/external.php?action=requestApiKey`;
    const response = await fetch(apiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `email=${encodeURIComponent(APP_EMAIL)}&siteName=${encodeURIComponent(APP_SITE_NAME)}&siteUrl=${encodeURIComponent(APP_SITE_URL)}&public=true`,
    });

    if (!response.ok) {
      console.warn(`[list-worlds] requestApiKey fehlgeschlagen fuer ${subdomain}: HTTP ${response.status}`);
      return null;
    }

    const data = await response.json();
    if (data.response?.privateApiKey && data.response?.publicSiteKey) {
      return {
        privateApiKey: data.response.privateApiKey,
        publicSiteKey: data.response.publicSiteKey,
      };
    }

    console.warn(`[list-worlds] requestApiKey unerwartete Antwort fuer ${subdomain}:`, data);
    return null;
  } catch (err) {
    console.warn(`[list-worlds] requestApiKey Fehler fuer ${subdomain}:`, err);
    return null;
  }
}

serve(async (req: Request) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Status-Seite abrufen
    const statusUrl = "https://status.kingdoms.com/embed";
    const response = await fetch(statusUrl);
    if (!response.ok) {
      return new Response(JSON.stringify({ error: "Status-Seite nicht erreichbar" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const html = await response.text();

    // 2. Spielwelten aus eingebettetem JSON parsen
    const jsonMatch = html.match(/<script\s+id="__GW_DATA__"[^>]*>([\s\S]*?)<\/script>/);
    if (!jsonMatch) {
      console.error("[list-worlds] __GW_DATA__ script tag nicht gefunden");
      return new Response(JSON.stringify({ error: "Spielwelt-Daten nicht gefunden" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const gwData = JSON.parse(jsonMatch[1]);
    const items = gwData.items;
    if (!items || typeof items !== "object") {
      console.error("[list-worlds] items nicht im erwarteten Format:", gwData);
      return new Response(JSON.stringify({ error: "Spielwelt-Daten im falschen Format" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Items in Array umwandeln
    const worlds: Array<{ world_id: string; subdomain: string; speed: number; speed_troops: number }> = [];
    for (const [key, entry] of Object.entries(items)) {
      const gw = entry as { name: string; url: string; state: number };
      const worldId = gw.name || key;
      const subdomain = extractSubdomain(gw.url) || worldId;
      const speed = parseSpeed(worldId);
      worlds.push({
        world_id: worldId,
        subdomain,
        speed,
        speed_troops: speed,
      });
    }

    if (worlds.length === 0) {
      return new Response(JSON.stringify({ error: "Keine Spielwelten gefunden" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`[list-worlds] ${worlds.length} Spielwelten geparst`);

    // 4. Supabase Admin Client
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 5. Welten upserten (bestehende API-Keys NICHT ueberschreiben)
    for (const w of worlds) {
      await supabaseAdmin.from("gameworlds").upsert(
        {
          world_id: w.world_id,
          subdomain: w.subdomain,
          speed: w.speed,
          speed_troops: w.speed_troops,
        },
        { onConflict: "world_id", ignoreDuplicates: false },
      );
    }

    // 6. Welten ohne API-Keys finden und automatisch registrieren
    const { data: unconfigured } = await supabaseAdmin
      .from("gameworlds")
      .select("world_id, subdomain")
      .is("private_api_key", null);

    let registered = 0;
    if (unconfigured && unconfigured.length > 0) {
      console.log(`[list-worlds] ${unconfigured.length} Welten ohne API-Key — registriere...`);

      for (const gw of unconfigured) {
        const subdomain = gw.subdomain || gw.world_id;
        const keys = await requestApiKey(subdomain);
        if (keys) {
          await supabaseAdmin.from("gameworlds").update({
            private_api_key: keys.privateApiKey,
            public_site_key: keys.publicSiteKey,
          }).eq("world_id", gw.world_id);
          registered++;
          console.log(`[list-worlds] API-Key registriert fuer ${gw.world_id}`);
        }
      }

      console.log(`[list-worlds] ${registered}/${unconfigured.length} API-Keys erfolgreich registriert`);
    }

    // 7. Aktuelle Liste aus DB zuruecklesen
    const { data: dbWorlds } = await supabaseAdmin
      .from("gameworlds")
      .select("world_id, subdomain, speed, speed_troops, public_site_key")
      .order("world_id");

    return new Response(JSON.stringify({ worlds: dbWorlds, scraped: worlds.length, registered }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("[list-worlds] Fehler:", err);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
