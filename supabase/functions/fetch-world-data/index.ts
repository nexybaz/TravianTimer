// supabase/functions/fetch-world-data/index.ts
// Taeglicher Refresh: Aktualisiert Profil + Doerfer fuer verifizierte Spieler
// Max 1x pro Tag (Travian API Compliance)
// API-Keys werden pro Spielwelt aus der gameworlds-Tabelle gelesen

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const TRIBE_MAP: Record<string, string> = {
  "1": "Roemer",
  "2": "Germanen",
  "3": "Gallier",
};

// Travian API player.role → App-Rolle
const ROLE_MAP: Record<number, string> = {
  0: "governor",
  1: "duke",
  2: "viceking",
  3: "king",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Nicht authentifiziert" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

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
    const { worldId } = await req.json();
    if (!worldId) {
      return new Response(JSON.stringify({ error: "worldId ist erforderlich" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Profil laden — muss verifiziert sein
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("travian_player_id, is_verified, player_name, tribe, kingdom_id, kingdom_tag, role")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: "Profil nicht gefunden" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!profile.is_verified || !profile.travian_player_id) {
      return new Response(JSON.stringify({ error: "Account nicht verifiziert. Bitte zuerst Travian-Account verknuepfen." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Gameworld laden (API-Key + last_fetched + subdomain)
    const { data: gameworld } = await supabaseAdmin
      .from("gameworlds")
      .select("private_api_key, last_fetched, speed, speed_troops, subdomain")
      .eq("world_id", worldId)
      .single();

    // Subdomain fuer API-URL (bei den meisten Welten = worldId, aber z.B. ae1n -> arabia1n)
    const apiSubdomain = gameworld?.subdomain || worldId;

    // 5. Pruefen ob heute schon abgerufen
    if (gameworld?.last_fetched) {
      const lastFetched = new Date(gameworld.last_fetched);
      const today = new Date();
      if (
        lastFetched.getUTCFullYear() === today.getUTCFullYear() &&
        lastFetched.getUTCMonth() === today.getUTCMonth() &&
        lastFetched.getUTCDate() === today.getUTCDate()
      ) {
        // Bereits heute abgerufen — cached Daten aus DB zurueckgeben
        const { data: villages } = await supabaseAdmin
          .from("villages")
          .select("travian_village_id, name, x, y, population, is_city")
          .eq("user_id", user.id);

        // Wenn keine Villages in DB vorhanden (z.B. wegen frueherem Bug),
        // Cache ignorieren und API trotzdem aufrufen
        if (!villages || villages.length === 0) {
          console.log("[fetch-world-data] Cache ignoriert — 0 Villages in DB, erzwinge API-Abruf");
        } else {
          return new Response(JSON.stringify({
            player: {
              playerId: profile.travian_player_id,
              name: profile.player_name,
              tribe: profile.tribe,
              kingdomId: profile.kingdom_id,
              kingdomTag: profile.kingdom_tag,
            },
            villages: villages.map((v: any) => ({
              villageId: v.travian_village_id,
              name: v.name,
              x: v.x,
              y: v.y,
              population: v.population,
              isCity: v.is_city,
            })),
            cached: true,
          }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }
    }

    // 6. API-Key pruefen (aus gameworlds-Tabelle)
    const privateApiKey = gameworld?.private_api_key;
    if (!privateApiKey) {
      // Mock-Mode: cached Daten zurueckgeben
      console.log(`[fetch-world-data] MOCK MODE — kein API-Key fuer ${worldId}`);
      const { data: villages } = await supabaseAdmin
        .from("villages")
        .select("travian_village_id, name, x, y, population, is_city")
        .eq("user_id", user.id);

      return new Response(JSON.stringify({
        player: {
          playerId: profile.travian_player_id,
          name: profile.player_name,
          tribe: profile.tribe,
          kingdomId: profile.kingdom_id,
          kingdomTag: profile.kingdom_tag,
        },
        villages: (villages ?? []).map((v: any) => ({
          villageId: v.travian_village_id,
          name: v.name,
          x: v.x,
          y: v.y,
          population: v.population,
          isCity: v.is_city,
        })),
        cached: true,
        mock: true,
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 7. Travian API aufrufen
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

    // 8. Eigenen Spieler finden (anhand travian_player_id)
    const player = response.players?.find(
      (p: any) => String(p.playerId) === String(profile.travian_player_id),
    );

    if (!player) {
      return new Response(JSON.stringify({ error: "Spieler nicht mehr in der Spielwelt gefunden" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 9. Kingdom-Tag
    const kingdom = response.kingdoms?.find(
      (k: any) => String(k.kingdomId) === String(player.kingdomId),
    );
    const kingdomTag = kingdom?.kingdomTag ?? null;
    const tribeName = TRIBE_MAP[String(player.tribeId)] ?? profile.tribe;

    // 10. DB: Profil aktualisieren (Rolle aus Travian API zuweisen, admin nicht ueberschreiben)
    const travianRole = ROLE_MAP[parseInt(player.role)] ?? profile.role ?? "governor";
    const profileUpdate: Record<string, any> = {
      player_name: player.name,
      tribe: tribeName,
      kingdom_id: parseInt(player.kingdomId) || null,
      kingdom_tag: kingdomTag,
    };
    // Admin-Rolle nicht durch API ueberschreiben
    if (profile.role !== "admin") {
      profileUpdate.role = travianRole;
    }
    await supabaseAdmin.from("profiles").update(profileUpdate).eq("id", user.id);

    // 11. DB: Doerfer aktualisieren
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
        console.error(`[fetch-world-data] Village Upsert FEHLER fuer '${v.name}':`, upsertError.message);
      }
    }

    // 12. DB: last_fetched aktualisieren (Keys nicht ueberschreiben!)
    const gw = response.gameworld;
    await supabaseAdmin.from("gameworlds").update({
      speed: gw?.speed ?? 1,
      speed_troops: gw?.speedTroops ?? 1,
      last_fetched: new Date().toISOString(),
    }).eq("world_id", worldId);

    // 13. Response
    return new Response(JSON.stringify({
      player: {
        playerId: parseInt(player.playerId),
        name: player.name,
        tribe: tribeName,
        kingdomId: parseInt(player.kingdomId) || null,
        kingdomTag,
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
      cached: false,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("[fetch-world-data] Fehler:", err);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
