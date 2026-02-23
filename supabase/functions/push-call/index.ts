// supabase/functions/push-call/index.ts
// Empfaengt Call-Daten vom Discord Bot und erstellt einen neuen Call in der DB.
//
// Auth: BOT_SECRET als Bearer Token
// Body: { discord_channel_id, discord_thread_id?, discord_message_id, title, target_x, target_y, arrival?, link?, crop_limit?, crop_pledged_total? }
//
// Ablauf:
// 1. Auth pruefen (BOT_SECRET)
// 2. Kingdom-ID via discord_channels Tabelle ermitteln
// 3. Duplikat-Check (discord_message_id)
// 4. Call in DB einfuegen (created_by = BOT_SYSTEM_USER_ID)
// 5. Push Notification wird automatisch vom on_new_call_push Trigger ausgeloest

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Auth pruefen
    const botSecret = Deno.env.get("BOT_SECRET") ?? "";
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");

    if (!botSecret || token !== botSecret) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Body lesen
    const body = await req.json();
    const {
      discord_channel_id,
      discord_thread_id,
      discord_message_id,
      title,
      target_x,
      target_y,
      arrival,
      link,
      crop_limit,
      crop_pledged_total,
    } = body;

    // Pflichtfelder pruefen
    if (!discord_channel_id || target_x === undefined || target_y === undefined) {
      return new Response(
        JSON.stringify({
          error: "discord_channel_id, target_x und target_y sind Pflicht",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Supabase Admin Client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 2. Kingdom-ID via discord_channels Tabelle ermitteln
    const { data: channelMapping, error: channelError } = await supabase
      .from("discord_channels")
      .select("kingdom_id")
      .eq("discord_channel_id", discord_channel_id)
      .single();

    if (channelError || !channelMapping) {
      console.error(
        `[push-call] Kein Kingdom-Mapping fuer Channel ${discord_channel_id}:`,
        channelError
      );
      return new Response(
        JSON.stringify({
          error: "Kein Kingdom fuer diesen Discord Channel konfiguriert",
          discord_channel_id,
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const kingdomId = channelMapping.kingdom_id;

    // 3. Duplikat-Check
    if (discord_message_id) {
      const { data: existing } = await supabase
        .from("calls")
        .select("id")
        .eq("discord_message_id", discord_message_id)
        .limit(1);

      if (existing && existing.length > 0) {
        console.log(
          `[push-call] Duplikat: discord_message_id=${discord_message_id} → call=${existing[0].id}`
        );
        return new Response(
          JSON.stringify({
            duplicate: true,
            callId: existing[0].id,
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    // 4. Call einfuegen
    const botUserId = Deno.env.get("BOT_SYSTEM_USER_ID") ?? "";
    if (!botUserId) {
      console.error("[push-call] BOT_SYSTEM_USER_ID nicht konfiguriert");
      return new Response(
        JSON.stringify({ error: "BOT_SYSTEM_USER_ID fehlt" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const callData: Record<string, unknown> = {
      kingdom_id: kingdomId,
      created_by: botUserId,
      title: title || "Deff-Call",
      target_x,
      target_y,
      status: "open",
      discord_channel_id,
      discord_thread_id: discord_thread_id || null,
      discord_message_id: discord_message_id || null,
    };

    // Optionale Felder
    if (arrival) callData.arrival = arrival;
    if (link) callData.link = link;
    if (crop_limit) callData.crop_limit = crop_limit;
    if (crop_pledged_total !== undefined)
      callData.crop_pledged_total = crop_pledged_total;

    const { data: newCall, error: insertError } = await supabase
      .from("calls")
      .insert(callData)
      .select("id")
      .single();

    if (insertError) {
      console.error("[push-call] Insert fehlgeschlagen:", insertError);
      return new Response(
        JSON.stringify({ error: "Call konnte nicht erstellt werden", details: insertError.message }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(
      `[push-call] Call erstellt: ${newCall.id} (Kingdom ${kingdomId}, ${target_x}|${target_y})`
    );

    // Push Notification wird automatisch vom on_new_call_push DB Trigger ausgeloest!

    return new Response(
      JSON.stringify({
        success: true,
        callId: newCall.id,
        kingdomId,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[push-call] Fehler:", err);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
