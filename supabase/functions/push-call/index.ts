// push-call: Speichert einen Deff-Call und sendet Push an alle Geräte.
// Deploy: supabase functions deploy push-call
//
// Supabase Secrets benötigt:
//   APNS_KEY_ID       - Apple Key ID
//   APNS_TEAM_ID      - Apple Team ID (BHMEWMQUJE)
//   APNS_PRIVATE_KEY  - .p8 Datei-Inhalt (PEM)
//   APNS_SANDBOX      - "true" für Development, "false" für Production
//   BOT_SECRET        - Shared secret für Authentifizierung vom Discord Bot

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  create,
  getNumericDate,
} from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// --- APNs JWT Token generieren ---

async function createApnsJwt(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY")!;

  // PEM -> CryptoKey
  const pemContent = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const jwt = await create(
    { alg: "ES256", kid: keyId },
    { iss: teamId, iat: getNumericDate(0) },
    cryptoKey
  );

  return jwt;
}

// --- APNs Push senden ---

async function sendApnsPush(
  token: string,
  payload: Record<string, unknown>,
  jwt: string
): Promise<boolean> {
  const sandbox = Deno.env.get("APNS_SANDBOX") === "true";
  const host = sandbox
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";

  const url = `${host}/3/device/${token}`;

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": "tt.TravianTimer",
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (res.status === 200) {
      return true;
    }

    const body = await res.text();
    console.error(`APNs error for ${token.slice(0, 8)}...: ${res.status} ${body}`);

    // 410 Gone = Token ungültig -> soll gelöscht werden
    if (res.status === 410) {
      return false;
    }

    return false;
  } catch (err) {
    console.error(`APNs fetch error for ${token.slice(0, 8)}...:`, err);
    return false;
  }
}

// --- Main Handler ---

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Authentifizierung: BOT_SECRET als Bearer-Token prüfen
    const authHeader = req.headers.get("authorization") || "";
    const botSecret = Deno.env.get("BOT_SECRET") || "";

    if (botSecret && !authHeader.includes(botSecret)) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const {
      title,
      target_x,
      target_y,
      arrival,
      link,
      crop_limit,
      discord_message_id,
      guild_id,
    } = await req.json();

    // Validierung
    if (target_x === undefined || target_y === undefined || !arrival) {
      return new Response(
        JSON.stringify({ error: "target_x, target_y, arrival required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Deduplizierung: gleiche discord_message_id?
    if (discord_message_id) {
      const { data: existing } = await supabase
        .from("calls")
        .select("id")
        .eq("discord_message_id", discord_message_id)
        .maybeSingle();

      if (existing) {
        return new Response(
          JSON.stringify({ success: true, duplicate: true }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Call in DB speichern
    const callData = {
      title: title || "Deff-Call",
      target_x,
      target_y,
      arrival,
      link: link || null,
      crop_limit: crop_limit || null,
      discord_message_id: discord_message_id || null,
      guild_id: guild_id || null,
    };

    const { error: insertError } = await supabase.from("calls").insert(callData);

    if (insertError) {
      console.error("Insert error:", insertError);
      // Bei Unique-Constraint-Verletzung trotzdem ok
      if (insertError.code !== "23505") {
        return new Response(
          JSON.stringify({ error: "Database error" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Device-Tokens holen (Team-scoped wenn guild_id vorhanden)
    let devices: { token: string }[] = [];

    if (guild_id) {
      // Team-Members für diese Guild holen
      const { data: members } = await supabase
        .from("team_members")
        .select("user_id")
        .eq("guild_id", guild_id);

      const memberUserIds = (members || []).map((m: any) => m.user_id);

      if (memberUserIds.length > 0) {
        // Nur Devices dieser Team-Members
        const { data: teamDevices } = await supabase
          .from("device_tokens")
          .select("token")
          .in("user_id", memberUserIds);
        devices = teamDevices || [];
        console.log(`Team-scoped push: ${devices.length} devices for guild ${guild_id}`);
      }
    }

    // Fallback: Wenn keine Team-Devices oder keine guild_id → alle Devices
    if (devices.length === 0) {
      const { data: allDevices, error: devicesError } = await supabase
        .from("device_tokens")
        .select("token");

      if (devicesError || !allDevices || allDevices.length === 0) {
        console.log("No devices registered");
        return new Response(
          JSON.stringify({ success: true, pushed: 0 }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      devices = allDevices;
    }

    // APNs Payload bauen
    const apnsPayload = {
      aps: {
        alert: {
          title: "Deff-Call",
          body: `${title || "Deff-Call"} (${target_x}|${target_y})`,
        },
        sound: "default",
        "content-available": 1,
      },
      call: {
        title: title || "Deff-Call",
        targetX: target_x,
        targetY: target_y,
        arrival,
        link: link || null,
        cropLimit: crop_limit || null,
        discordMessageId: discord_message_id || null,
        guildId: guild_id || null,
      },
    };

    // JWT für APNs erzeugen
    const jwt = await createApnsJwt();

    // Push an alle Geräte senden
    const invalidTokens: string[] = [];
    let successCount = 0;

    const pushResults = await Promise.allSettled(
      devices.map(async (d: { token: string }) => {
        const ok = await sendApnsPush(d.token, apnsPayload, jwt);
        if (ok) {
          successCount++;
        } else {
          invalidTokens.push(d.token);
        }
      })
    );

    // Ungültige Tokens aufräumen
    if (invalidTokens.length > 0) {
      console.log(`Cleaning up ${invalidTokens.length} invalid tokens`);
      await supabase
        .from("device_tokens")
        .delete()
        .in("token", invalidTokens);
    }

    console.log(
      `Push sent: ${successCount}/${devices.length} successful, ${invalidTokens.length} removed`
    );

    return new Response(
      JSON.stringify({
        success: true,
        pushed: successCount,
        total: devices.length,
        removed: invalidTokens.length,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
