// supabase/functions/verify-player/index.ts
// Einmalige Travian-Account Verifizierung
// Spieler gibt worldId + accessToken ein → wir identifizieren ihn via externalLoginToken
// API-Keys werden pro Spielwelt aus der gameworlds-Tabelle gelesen

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Tribe-ID → deutscher Name
const TRIBE_MAP: Record<string, string> = {
  "1": "Roemer",
  "2": "Germanen",
  "3": "Gallier",
};

// Travian API player.role → App-Rolle
// 0 = Statthalter (governor), 1 = Herzog (duke), 2 = Vize-Koenig (viceking), 3 = Koenig (king)
const ROLE_MAP: Record<number, string> = {
  0: "governor",
  1: "duke",
  2: "viceking",
  3: "king",
};

// MD5 Hash berechnen
async function md5(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("MD5", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Mock-Daten fuer Tests ohne API-Key
function getMockResponse() {
  return {
    player: {
      playerId: 12345,
      name: "TestSpieler",
      tribeId: 3,
      tribe: "Gallier",
      kingdomId: 42,
      kingdomTag: "~TEST~",
      role: 0,
    },
    villages: [
      { villageId: 1001, name: "Hauptdorf", x: -12, y: 8, population: 534, isMainVillage: true, isCity: false },
      { villageId: 1002, name: "Zweites Dorf", x: -10, y: 6, population: 312, isMainVillage: false, isCity: false },
      { villageId: 1003, name: "Stadt", x: -14, y: 10, population: 891, isMainVillage: false, isCity: true },
    ],
    gameworld: {
      speed: 1,
      speedTroops: 1,
    },
    mock: true,
  };
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Auth: JWT validieren
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Nicht authentifiziert" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Supabase Admin Client (Service Role fuer DB-Writes)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Supabase Auth Client (User JWT)
    const supabaseAuth = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Ungueltige Session" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Body lesen
    const { worldId, accessToken } = await req.json();
    if (!worldId || !accessToken) {
      return new Response(JSON.stringify({ error: "worldId und accessToken sind erforderlich" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. API-Key + Subdomain aus gameworlds-Tabelle laden (pro Spielwelt)
    const { data: gwRow } = await supabaseAdmin
      .from("gameworlds")
      .select("private_api_key, public_site_key, subdomain")
      .eq("world_id", worldId)
      .single();

    // Subdomain fuer API-URL (bei den meisten Welten = worldId, aber z.B. ae1n -> arabia1n)
    const apiSubdomain = gwRow?.subdomain || worldId;

    const privateApiKey = gwRow?.private_api_key;

    if (!privateApiKey) {
      // Mock-Mode: kein API-Key fuer diese Spielwelt konfiguriert
      console.log(`[verify-player] MOCK MODE — kein API-Key fuer ${worldId}`);
      const mockData = getMockResponse();

      // Mock-Daten trotzdem in DB schreiben (damit die App den Flow testen kann)
      // Rolle aus Travian API zuweisen (admin nicht ueberschreiben)
      const mockRole = ROLE_MAP[mockData.player.role] ?? "governor";
      const { data: mockProfile } = await supabaseAdmin.from("profiles").select("role").eq("id", user.id).single();
      const mockUpdateRole = mockProfile?.role !== "admin" ? mockRole : mockProfile.role;

      await supabaseAdmin.from("profiles").update({
        travian_player_id: mockData.player.playerId,
        player_name: mockData.player.name,
        tribe: mockData.player.tribe,
        kingdom_id: mockData.player.kingdomId,
        kingdom_tag: mockData.player.kingdomTag,
        world_id: worldId,
        is_verified: true,
        role: mockUpdateRole,
      }).eq("id", user.id);

      // Mock-Doerfer in DB
      for (const v of mockData.villages) {
        await supabaseAdmin.from("villages").upsert({
          user_id: user.id,
          travian_village_id: v.villageId,
          name: v.name,
          x: v.x,
          y: v.y,
          population: v.population,
          is_city: v.isCity,
        }, { onConflict: "user_id,travian_village_id", ignoreDuplicates: false });
      }

      // Gameworld anlegen falls nicht vorhanden
      await supabaseAdmin.from("gameworlds").upsert({
        world_id: worldId,
        speed: mockData.gameworld.speed,
        speed_troops: mockData.gameworld.speedTroops,
        last_fetched: new Date().toISOString(),
      }, { onConflict: "world_id" });

      return new Response(JSON.stringify(mockData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. externalLoginToken berechnen: md5(accessToken + privateApiKey)
    const expectedToken = await md5(accessToken + privateApiKey);

    // 5. Travian API aufrufen
    const apiUrl = `https://${apiSubdomain}.kingdoms.com/api/external.php?action=getMapData`;
    const apiResponse = await fetch(apiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `privateApiKey=${encodeURIComponent(privateApiKey)}`,
    });

    if (!apiResponse.ok) {
      return new Response(JSON.stringify({ error: `Travian API Fehler: ${apiResponse.status}` }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const apiData = await apiResponse.json();
    if (apiData.error) {
      return new Response(JSON.stringify({ error: `Travian API: ${apiData.error.message}` }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { response } = apiData;
    if (!response?.players) {
      return new Response(JSON.stringify({ error: "Unerwartete API-Antwort" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 6. Spieler finden anhand externalLoginToken
    const player = response.players.find(
      (p: any) => p.externalLoginToken === expectedToken,
    );

    if (!player) {
      return new Response(JSON.stringify({ error: "Spieler nicht gefunden. Bitte Access-Token pruefen." }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 7. Kingdom-Tag holen
    const kingdom = response.kingdoms?.find(
      (k: any) => String(k.kingdomId) === String(player.kingdomId),
    );
    const kingdomTag = kingdom?.kingdomTag ?? null;

    // 8. Tribe-Name bestimmen
    const tribeName = TRIBE_MAP[String(player.tribeId)] ?? "Gallier";

    // 9. DB: Profil aktualisieren (Rolle aus Travian API zuweisen, admin nicht ueberschreiben)
    const travianRole = ROLE_MAP[parseInt(player.role)] ?? "governor";
    const { data: existingProfile } = await supabaseAdmin.from("profiles").select("role").eq("id", user.id).single();
    const newRole = existingProfile?.role !== "admin" ? travianRole : existingProfile.role;

    await supabaseAdmin.from("profiles").update({
      travian_player_id: parseInt(player.playerId),
      player_name: player.name,
      tribe: tribeName,
      kingdom_id: parseInt(player.kingdomId) || null,
      kingdom_tag: kingdomTag,
      world_id: worldId,
      is_verified: true,
      role: newRole,
    }).eq("id", user.id);

    // 10. DB: Doerfer upserten
    const villages = player.villages ?? [];
    for (const v of villages) {
      const { error: upsertError } = await supabaseAdmin.from("villages").upsert({
        user_id: user.id,
        travian_village_id: parseInt(v.villageId),
        name: v.name,
        x: parseInt(v.x),
        y: parseInt(v.y),
        population: parseInt(v.population),
        is_city: v.isCity === true || v.isCity === "true",
      }, { onConflict: "user_id,travian_village_id", ignoreDuplicates: false });
      if (upsertError) {
        console.error(`[verify-player] Village Upsert FEHLER fuer '${v.name}':`, upsertError.message);
      }
    }

    // 11. DB: Gameworld-Metadaten upserten (Keys nicht ueberschreiben!)
    const gw = response.gameworld;
    if (gw) {
      await supabaseAdmin.from("gameworlds").update({
        speed: gw.speed ?? 1,
        speed_troops: gw.speedTroops ?? 1,
        last_fetched: new Date().toISOString(),
      }).eq("world_id", worldId);
    }

    // 12. Response an App (nur eigene Daten)
    const result = {
      player: {
        playerId: parseInt(player.playerId),
        name: player.name,
        tribeId: parseInt(player.tribeId),
        tribe: tribeName,
        kingdomId: parseInt(player.kingdomId) || null,
        kingdomTag,
        role: parseInt(player.role) || 0,
      },
      villages: villages.map((v: any) => ({
        villageId: parseInt(v.villageId),
        name: v.name,
        x: parseInt(v.x),
        y: parseInt(v.y),
        population: parseInt(v.population),
        isMainVillage: v.isMainVillage === true || v.isMainVillage === "true",
        isCity: v.isCity === true || v.isCity === "true",
      })),
      gameworld: {
        speed: gw?.speed ?? 1,
        speedTroops: gw?.speedTroops ?? 1,
      },
      mock: false,
    };

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("[verify-player] Fehler:", err);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
