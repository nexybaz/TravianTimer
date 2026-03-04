// supabase/functions/push-notification/index.ts
// Sendet APNs Push Notifications.
//
// Unterstuetzte Typen:
// 1. Neuer Deff-Call:      { call_id, kingdom_id, title, target_x, target_y, created_by }
// 2. Guide-Fortschritt:    { type: "guide_progress", session_id, step_id, checked_by }
//
// Auth: Service-Role Key (wird von DB Webhook aufgerufen)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// APNs JWT Token erstellen (ES256)
async function createAPNsJWT(): Promise<string> {
  const teamId = Deno.env.get("APNS_TEAM_ID") ?? "";
  const keyId = Deno.env.get("APNS_KEY_ID") ?? "";
  const keyContent = Deno.env.get("APNS_KEY_CONTENT") ?? "";

  if (!teamId || !keyId || !keyContent) {
    throw new Error("APNs Konfiguration fehlt (APNS_TEAM_ID, APNS_KEY_ID, APNS_KEY_CONTENT)");
  }

  // Base64url encode
  const base64url = (data: Uint8Array): string => {
    const base64 = btoa(String.fromCharCode(...data));
    return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  };

  const encoder = new TextEncoder();

  // Header
  const header = { alg: "ES256", kid: keyId };
  const headerB64 = base64url(encoder.encode(JSON.stringify(header)));

  // Payload
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: teamId, iat: now };
  const payloadB64 = base64url(encoder.encode(JSON.stringify(payload)));

  // Sign
  const signingInput = `${headerB64}.${payloadB64}`;

  // Parse PEM key
  const pemClean = keyContent
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemClean), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    encoder.encode(signingInput)
  );

  // DER to raw R||S (64 bytes)
  const sigArray = new Uint8Array(signature);
  let r: Uint8Array, s: Uint8Array;

  if (sigArray.length === 64) {
    r = sigArray.slice(0, 32);
    s = sigArray.slice(32);
  } else {
    // DER format: 0x30 len 0x02 rlen r 0x02 slen s
    const rLen = sigArray[3];
    const rStart = 4;
    r = sigArray.slice(rStart, rStart + rLen);
    const sLen = sigArray[rStart + rLen + 1];
    const sStart = rStart + rLen + 2;
    s = sigArray.slice(sStart, sStart + sLen);
    // Trim leading zeros
    if (r.length > 32) r = r.slice(r.length - 32);
    if (s.length > 32) s = s.slice(s.length - 32);
    // Pad if needed
    if (r.length < 32) {
      const padded = new Uint8Array(32);
      padded.set(r, 32 - r.length);
      r = padded;
    }
    if (s.length < 32) {
      const padded = new Uint8Array(32);
      padded.set(s, 32 - s.length);
      s = padded;
    }
  }

  const rawSig = new Uint8Array(64);
  rawSig.set(r, 0);
  rawSig.set(s, 32);

  const signatureB64 = base64url(rawSig);
  return `${headerB64}.${payloadB64}.${signatureB64}`;
}

// APNs Push senden
async function sendPush(
  token: string,
  title: string,
  body: string,
  extraData: Record<string, string>,
  jwt: string
): Promise<boolean> {
  const bundleId = "tt.TravianTimer";
  // Development: api.sandbox.push.apple.com, Production: api.push.apple.com
  const apnsHost = Deno.env.get("APNS_PRODUCTION") === "true"
    ? "api.push.apple.com"
    : "api.sandbox.push.apple.com";

  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      badge: 1,
    },
    ...extraData,
  };

  try {
    const response = await fetch(
      `https://${apnsHost}/3/device/${token}`,
      {
        method: "POST",
        headers: {
          Authorization: `bearer ${jwt}`,
          "apns-topic": bundleId,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      }
    );

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(`[APNs] Push fehlgeschlagen fuer Token ${token.slice(0, 8)}...: ${response.status} ${errorBody}`);
      return false;
    }

    return true;
  } catch (err) {
    console.error(`[APNs] Netzwerk-Fehler fuer Token ${token.slice(0, 8)}...:`, err);
    return false;
  }
}

// ============================================================
// Guide-Progress Handler
// ============================================================

async function handleGuideProgress(body: any): Promise<Response> {
  const sessionId = body.session_id;
  const checkedBy = body.checked_by;

  if (!sessionId || !checkedBy) {
    return new Response(JSON.stringify({ error: "session_id oder checked_by fehlt" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  // 1. Name des Abhakers laden
  const { data: profile } = await supabase
    .from("profiles")
    .select("player_name")
    .eq("id", checkedBy)
    .single();

  const checkerName = profile?.player_name ?? "Ein Spieler";

  // 2. Session-Mitglieder laden
  const { data: members, error: membersError } = await supabase
    .from("guide_session_members")
    .select("user_id")
    .eq("session_id", sessionId);

  if (membersError || !members || members.length === 0) {
    console.log("[push-notification] Keine Session-Mitglieder gefunden");
    return new Response(JSON.stringify({ sent: 0, reason: "no_members" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const memberIds = members.map((m: any) => m.user_id);

  // 3. Preferences laden — nur User mit guide_progress=true
  const { data: prefs } = await supabase
    .from("notification_preferences")
    .select("user_id, guide_progress")
    .in("user_id", memberIds);

  const disabledUserIds = new Set(
    (prefs ?? [])
      .filter((p: any) => p.guide_progress === false)
      .map((p: any) => p.user_id)
  );

  // 4. Device Tokens laden
  const { data: deviceTokens, error: tokensError } = await supabase
    .from("device_tokens")
    .select("token, user_id")
    .in("user_id", memberIds);

  if (tokensError) {
    console.error("[push-notification] Token-Abfrage fehlgeschlagen:", tokensError);
  }

  // Abhaker ausschliessen + User mit deaktivierter Preference
  const recipientTokens = (deviceTokens ?? []).filter(
    (t) => t.user_id !== checkedBy && !disabledUserIds.has(t.user_id)
  );

  if (recipientTokens.length === 0) {
    console.log("[push-notification] Keine Empfaenger fuer Guide-Progress");
    return new Response(JSON.stringify({ sent: 0, reason: "no_recipients" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 5. APNs JWT erstellen + Push senden
  const jwt = await createAPNsJWT();
  const pushTitle = "Schnellsiedelguide";
  const pushBody = `${checkerName} hat Fortschritte eingetragen!`;
  let sentCount = 0;
  let failedCount = 0;

  for (const { token } of recipientTokens) {
    const success = await sendPush(token, pushTitle, pushBody, { session_id: sessionId }, jwt);
    if (success) {
      sentCount++;
    } else {
      failedCount++;
    }
  }

  console.log(
    `[push-notification] Guide-Progress Session ${sessionId}: ${sentCount} gesendet, ${failedCount} fehlgeschlagen`
  );

  return new Response(
    JSON.stringify({ sent: sentCount, failed: failedCount, total: recipientTokens.length }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

// ============================================================
// New-Call Handler (bestehende Logik)
// ============================================================

async function handleNewCall(body: any): Promise<Response> {
  const { call_id, kingdom_id, title, target_x, target_y, created_by, arrival } = body?.record ?? body;

  const callId = call_id ?? body?.record?.id;
  const kingdomId = kingdom_id ?? body?.record?.kingdom_id;
  const callTitle = title ?? body?.record?.title ?? "Neuer Deff-Call";
  const targetX = target_x ?? body?.record?.target_x;
  const targetY = target_y ?? body?.record?.target_y;
  const createdBy = created_by ?? body?.record?.created_by;
  const arrivalRaw = arrival ?? body?.record?.arrival;

  if (!callId) {
    return new Response(JSON.stringify({ error: "call_id fehlt" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!kingdomId) {
    console.log("[push-notification] Kein kingdom_id — kein Push");
    return new Response(JSON.stringify({ sent: 0, reason: "no_kingdom" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Supabase Admin Client (Service Role)
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  // 1. Alle Kingdom-Mitglieder laden
  const { data: members, error: membersError } = await supabase
    .from("profiles")
    .select("id")
    .eq("kingdom_id", kingdomId);

  if (membersError || !members || members.length === 0) {
    console.log("[push-notification] Keine Kingdom-Mitglieder gefunden");
    return new Response(JSON.stringify({ sent: 0, reason: "no_members" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const memberIds = members.map((m: any) => m.id);

  // 2. Notification Preferences laden — nur User mit new_call=true erhalten Push
  const { data: prefs } = await supabase
    .from("notification_preferences")
    .select("user_id, new_call")
    .in("user_id", memberIds);

  const disabledUserIds = new Set(
    (prefs ?? [])
      .filter((p: any) => p.new_call === false)
      .map((p: any) => p.user_id)
  );

  // 3. Device Tokens fuer berechtigte Mitglieder laden
  const { data: deviceTokens, error: tokensError } = await supabase
    .from("device_tokens")
    .select("token, user_id")
    .in("user_id", memberIds);

  if (tokensError) {
    console.error("[push-notification] Token-Abfrage fehlgeschlagen:", tokensError);
  }

  // Ersteller ausschliessen + User mit deaktivierter Preference
  const recipientTokens = (deviceTokens ?? []).filter(
    (t) => t.user_id !== createdBy && !disabledUserIds.has(t.user_id)
  );

  if (recipientTokens.length === 0) {
    console.log("[push-notification] Keine Empfaenger gefunden");
    return new Response(JSON.stringify({ sent: 0, reason: "no_recipients" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 4. APNs JWT erstellen
  const jwt = await createAPNsJWT();

  // 5. Push an alle senden
  let pushBody = callTitle;
  if (arrivalRaw) {
    // Ankunftszeit in Europe/Berlin formatieren (HH:MM)
    const arrivalDate = new Date(arrivalRaw);
    const timeStr = arrivalDate.toLocaleString("de-DE", {
      timeZone: "Europe/Berlin",
      hour: "2-digit",
      minute: "2-digit",
    });
    pushBody += ` — Ankunft vor ${timeStr}`;
  } else {
    pushBody += ` (${targetX}|${targetY})`;
  }
  let sentCount = 0;
  let failedCount = 0;

  for (const { token } of recipientTokens) {
    const success = await sendPush(token, "Neuer Deff-Call", pushBody, { call_id: callId }, jwt);
    if (success) {
      sentCount++;
    } else {
      failedCount++;
    }
  }

  console.log(
    `[push-notification] Call ${callId}: ${sentCount} gesendet, ${failedCount} fehlgeschlagen`
  );

  return new Response(
    JSON.stringify({ sent: sentCount, failed: failedCount, total: recipientTokens.length }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

// ============================================================
// Router
// ============================================================

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();

    // Guide-Progress Typ
    if (body?.type === "guide_progress") {
      return await handleGuideProgress(body);
    }

    // Default: Neuer Call
    return await handleNewCall(body);
  } catch (err) {
    console.error("[push-notification] Fehler:", err);
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
