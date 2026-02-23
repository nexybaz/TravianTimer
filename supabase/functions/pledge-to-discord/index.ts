// supabase/functions/pledge-to-discord/index.ts
// Wird von DB-Trigger nach INSERT/UPDATE/DELETE auf pledges aufgerufen.
// Berechnet crop_pledged_total und sendet Update an Discord Bot Webhook.
//
// Body (vom Trigger): { call_id, event: "INSERT"|"UPDATE"|"DELETE" }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Crop per Hour Lookup (muss mit iOS TroopKind.cropPerHour uebereinstimmen)
const CROP_PER_HOUR: Record<string, number> = {
  // Romans
  "romans.legionnaire": 1,
  "romans.praetorian": 1,
  "romans.imperian": 1,
  "romans.equitesLegati": 2,
  "romans.equitesImperatoris": 3,
  "romans.equitesCaesaris": 4,
  "romans.batteringRam": 3,
  "romans.fireCatapult": 6,
  "romans.senator": 5,
  "romans.settler": 1,
  // Teutons
  "teutons.clubswinger": 1,
  "teutons.spearfighter": 1,
  "teutons.axefighter": 1,
  "teutons.scout": 1,
  "teutons.paladin": 2,
  "teutons.teutonicKnight": 3,
  "teutons.ram": 3,
  "teutons.catapult": 6,
  "teutons.chief": 4,
  "teutons.settler": 1,
  // Gauls
  "gauls.phalanx": 1,
  "gauls.swordsman": 1,
  "gauls.pathfinder": 1,
  "gauls.theutatesThunder": 2,
  "gauls.druidrider": 2,
  "gauls.haeduan": 3,
  "gauls.ram": 3,
  "gauls.trebuchet": 6,
  "gauls.chieftain": 4,
  "gauls.settler": 1,
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const callId = body.call_id;
    const event = body.event || "UNKNOWN";

    if (!callId) {
      return new Response(JSON.stringify({ error: "call_id fehlt" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Supabase Admin Client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Call-Daten laden
    const { data: call, error: callError } = await supabase
      .from("calls")
      .select("id, discord_channel_id, discord_thread_id, crop_limit, title")
      .eq("id", callId)
      .single();

    if (callError || !call) {
      console.error(`[pledge-to-discord] Call ${callId} nicht gefunden:`, callError);
      return new Response(
        JSON.stringify({ error: "Call nicht gefunden" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Nur wenn der Call einen Discord Channel hat
    if (!call.discord_channel_id) {
      console.log(`[pledge-to-discord] Call ${callId} hat keinen Discord Channel — skip`);
      return new Response(
        JSON.stringify({ skipped: true, reason: "no_discord_channel" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Alle Pledges fuer diesen Call laden
    const { data: pledges, error: pledgesError } = await supabase
      .from("pledges")
      .select("troop_kind, count, player_name, user_id")
      .eq("call_id", callId);

    if (pledgesError) {
      console.error(`[pledge-to-discord] Pledges laden fehlgeschlagen:`, pledgesError);
      return new Response(
        JSON.stringify({ error: "Pledges laden fehlgeschlagen" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 3. crop_pledged_total berechnen: SUM(count * cropPerHour)
    // Fuer troop_kind = "unknown" (Discord-Pledges) ist count bereits Getreide/h,
    // daher ist der Fallback ?? 1 korrekt (count * 1 = count).
    let cropPledgedTotal = 0;
    for (const pledge of pledges ?? []) {
      const cph = CROP_PER_HOUR[pledge.troop_kind] ?? 1;
      cropPledgedTotal += pledge.count * cph;
    }

    // 4. crop_pledged_total in DB aktualisieren
    const { error: updateError } = await supabase
      .from("calls")
      .update({ crop_pledged_total: cropPledgedTotal })
      .eq("id", callId);

    if (updateError) {
      console.error(`[pledge-to-discord] Update fehlgeschlagen:`, updateError);
    }

    // 5. Letzten Pledge-Ersteller ermitteln (fuer die Discord-Nachricht)
    // Bei DELETE haben wir keinen "letzten" Pledge, nehmen also den Event-Typ
    let playerName = body.player_name || "Unbekannt";
    if (playerName === "Unbekannt" && pledges && pledges.length > 0) {
      playerName = pledges[pledges.length - 1].player_name || "Unbekannt";
    }

    // 5b. Pledges pro Spieler zusammenfassen (fuer Discord-Zusammenfassung)
    const pledgesByPlayer: Record<string, { troops: { kind: string; count: number; crop: number }[]; totalCrop: number }> = {};
    for (const p of pledges ?? []) {
      const name = p.player_name || "Unbekannt";
      if (!pledgesByPlayer[name]) {
        pledgesByPlayer[name] = { troops: [], totalCrop: 0 };
      }
      const cph = CROP_PER_HOUR[p.troop_kind] ?? 1;
      const crop = p.count * cph;
      pledgesByPlayer[name].troops.push({ kind: p.troop_kind, count: p.count, crop });
      pledgesByPlayer[name].totalCrop += crop;
    }

    // 6. An Discord Bot Webhook senden
    const webhookUrl = Deno.env.get("DISCORD_BOT_WEBHOOK_URL");
    const webhookSecret = Deno.env.get("WEBHOOK_SECRET");

    if (!webhookUrl) {
      console.log("[pledge-to-discord] DISCORD_BOT_WEBHOOK_URL nicht gesetzt — skip Discord");
      return new Response(
        JSON.stringify({
          success: true,
          crop_pledged_total: cropPledgedTotal,
          discord_skipped: true,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      const webhookPayload = {
        call_id: callId,
        discord_channel_id: call.discord_channel_id,
        discord_thread_id: call.discord_thread_id || null,
        player_name: playerName,
        crop_pledged_total: cropPledgedTotal,
        crop_limit: call.crop_limit || 0,
        call_title: call.title || "Deff-Call",
        event,
        pledges_by_player: pledgesByPlayer,
      };

      const webhookResponse = await fetch(`${webhookUrl}/webhook/pledge-update`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${webhookSecret}`,
        },
        body: JSON.stringify(webhookPayload),
      });

      if (!webhookResponse.ok) {
        const errText = await webhookResponse.text();
        console.error(`[pledge-to-discord] Webhook Fehler: ${webhookResponse.status} ${errText}`);
      } else {
        console.log(`[pledge-to-discord] Discord Update gesendet: ${cropPledgedTotal} crop`);
      }
    } catch (webhookErr) {
      console.error("[pledge-to-discord] Webhook Netzwerk-Fehler:", webhookErr);
      // Nicht abbrechen — DB Update war erfolgreich
    }

    return new Response(
      JSON.stringify({
        success: true,
        crop_pledged_total: cropPledgedTotal,
        pledges_count: (pledges ?? []).length,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("[pledge-to-discord] Fehler:", err);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
