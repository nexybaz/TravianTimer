// discord-bot/bot.js
// TravianTimer Discord Bot v2.1
// Erkennt Deff-Calls in Discord, synct Pledges bidirektional.
//
// Features:
// 1. Call Detection: Erkennt Call-Format → push-call Edge Function → DB
// 2. Manual Crop Update: Erkennt "15/50k" → UPDATE crop_pledged_total
// 3. Webhook Server: Empfaengt Pledge-Updates → postet/editiert in Discord
// 4. Message Consolidation: Editiert letzte Bot-Nachricht statt Spam

require("dotenv").config();
const { Client, GatewayIntentBits, Events } = require("discord.js");
const express = require("express");
const { createClient } = require("@supabase/supabase-js");

// ─── Config ─────────────────────────────────────────────────────────────────

const DISCORD_BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BOT_SECRET = process.env.BOT_SECRET;
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET;
const WEBHOOK_PORT = parseInt(process.env.WEBHOOK_PORT || "3000", 10);
const WATCHED_CHANNELS = (process.env.WATCHED_CHANNELS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const BOT_SYSTEM_USER_ID =
  process.env.BOT_SYSTEM_USER_ID || "00000000-0000-0000-0000-000000000001";
const PUSH_CALL_URL = `${SUPABASE_URL}/functions/v1/push-call`;

// ─── Supabase Client (Service Role) ─────────────────────────────────────────

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ─── Crop per Hour Lookup (matches iOS TroopKind.cropPerHour) ───────────────

const CROP_PER_HOUR = {
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

// ─── Parsing Functions ──────────────────────────────────────────────────────

/**
 * Entfernt Discord-Unicode-Formatierung (fett, kursiv, Emojis etc.)
 * Gleiche Logik wie CallParser.cleanDiscordText() in Swift.
 */
function cleanDiscordText(text) {
  return text
    .replace(/[\u200B-\u200D\uFEFF]/g, "") // Zero-width chars
    .replace(/\*{1,3}([^*]+)\*{1,3}/g, "$1") // Bold/Italic
    .replace(/__([^_]+)__/g, "$1") // Underline
    .replace(/~~([^~]+)~~/g, "$1") // Strikethrough
    .replace(/`([^`]+)`/g, "$1") // Inline code
    .trim();
}

/**
 * Erkennt Koordinaten: (12|8), (12/8), (-4|6), x:-4/y:6
 */
function parseCoordinates(text) {
  // Pattern 1: (x|y) oder (x/y)
  const bracketMatch = text.match(/\((-?\d+)\s*[|/]\s*(-?\d+)\)/);
  if (bracketMatch) {
    return { x: parseInt(bracketMatch[1]), y: parseInt(bracketMatch[2]) };
  }

  // Pattern 2: x:N/y:N (aus Link)
  const xyMatch = text.match(/x[=:](-?\d+).*?y[=:](-?\d+)/i);
  if (xyMatch) {
    return { x: parseInt(xyMatch[1]), y: parseInt(xyMatch[2]) };
  }

  return null;
}

/**
 * Erkennt Ankunftszeit: HH:MM oder HH:MM:SS
 * Bevorzugt Zeilen mit "ankunft", "vor", "bis", "punkt"
 */
/**
 * Baut aus h/m/s (Europe/Berlin) einen UTC-ISO-String.
 * Behandelt CET (+1) und CEST (+2) automatisch.
 */
function buildBerlinArrival(h, m, s) {
  const now = new Date();

  // Aktuellen Berlin-Offset ermitteln (CET=+1h, CEST=+2h)
  const berlin = new Date(now.toLocaleString("en-US", { timeZone: "Europe/Berlin" }));
  const utc = new Date(now.toLocaleString("en-US", { timeZone: "UTC" }));
  const berlinOffsetMs = berlin.getTime() - utc.getTime();

  // Gewuenschte Uhrzeit als UTC setzen, dann Berlin-Offset abziehen
  const arrival = new Date(now);
  arrival.setUTCHours(h, m, s, 0);
  arrival.setTime(arrival.getTime() - berlinOffsetMs);

  // Wenn mehr als 12h in der Vergangenheit → morgen
  if (arrival.getTime() - now.getTime() < -12 * 60 * 60 * 1000) {
    arrival.setUTCDate(arrival.getUTCDate() + 1);
  }

  return arrival.toISOString();
}

function parseArrival(text) {
  const lines = text.split("\n");

  // Zuerst Zeilen mit Schluesselwoertern pruefen
  const keywords = ["ankunft", "vor", "bis", "punkt", "um"];
  for (const line of lines) {
    const lower = line.toLowerCase();
    if (keywords.some((kw) => lower.includes(kw))) {
      const match = line.match(/(\d{1,2}):(\d{2})(?::(\d{2}))?/);
      if (match) {
        const h = parseInt(match[1]);
        const m = parseInt(match[2]);
        const s = match[3] ? parseInt(match[3]) : 0;
        return buildBerlinArrival(h, m, s);
      }
    }
  }

  // Fallback: Erste Zeitangabe im Text
  const fallbackMatch = text.match(/(\d{1,2}):(\d{2})(?::(\d{2}))?/);
  if (fallbackMatch) {
    const h = parseInt(fallbackMatch[1]);
    const m = parseInt(fallbackMatch[2]);
    const s = fallbackMatch[3] ? parseInt(fallbackMatch[3]) : 0;
    return buildBerlinArrival(h, m, s);
  }

  return null;
}

/**
 * Erkennt Crop-Limit: 0/50k, 12k/50k, 15000/50000
 * Returns { pledged, limit } in absoluten Zahlen
 * WICHTIG: Muss Koordinaten (12|8) und (12/8) ausschliessen!
 */
function parseCropLimit(text) {
  // Zuerst Koordinaten-Klammern entfernen damit (12/8) nicht als Crop gematcht wird
  const cleaned = text.replace(/\((-?\d+)\s*[|/]\s*(-?\d+)\)/g, "");

  const match = cleaned.match(
    /(\d+(?:[.,]\d+)?)\s*k?\s*\/\s*(\d+(?:[.,]\d+)?)\s*k/i
  );
  if (!match) {
    // Fallback ohne "k" — aber nur wenn rechte Seite >= 10 (sonst wahrscheinlich keine Crop-Angabe)
    const match2 = cleaned.match(
      /(\d+(?:[.,]\d+)?)\s*\/\s*(\d+(?:[.,]\d+)?)/i
    );
    if (!match2) return null;
    const r = parseFloat(match2[2].replace(",", "."));
    if (r < 10) return null; // Zu klein fuer Crop-Limit, wahrscheinlich Koordinaten-Rest
    // Fallthrough mit match2
    return parseCropValues(match2);
  }

  return parseCropValues(match);
}

function parseCropValues(match) {
  let pledged = parseFloat(match[1].replace(",", "."));
  let limit = parseFloat(match[2].replace(",", "."));

  // "k" Multiplikator erkennen
  const fullMatch = match[0];
  const parts = fullMatch.split("/");

  if (parts[0].toLowerCase().includes("k")) pledged *= 1000;
  else if (pledged < 1000 && limit >= 10) pledged *= 1000; // Heuristik: 15/50k → 15k

  if (parts[1].toLowerCase().includes("k")) limit *= 1000;
  else if (limit < 1000 && limit >= 10) limit *= 1000; // 0/50 → 50k

  return { pledged: Math.round(pledged), limit: Math.round(limit) };
}

/**
 * Erkennt Kingdoms Link
 */
function parseLink(text) {
  const match = text.match(/(https?:\/\/[^\s]*kingdoms[^\s]*)/i);
  return match ? match[1] : null;
}

/**
 * Leitet Titel ab: Erste Zeile ohne Link/Crop/Zeit
 */
function deriveTitle(text) {
  const lines = text.split("\n").map((l) => l.trim()).filter(Boolean);
  for (const line of lines) {
    // Ueberspringe Links, reine Zahlen, Crop-Format
    if (line.startsWith("http")) continue;
    if (/^\d+[.,]?\d*k?\s*\/\s*\d+/.test(line)) continue;
    if (/^\d{1,2}:\d{2}/.test(line)) continue;

    // Nimm die erste sinnvolle Zeile, entferne bekannte Prefixe
    let title = line
      .replace(/^(deff[- ]?call|def[- ]?call)\s*(fuer|für|auf|nach)?\s*/i, "")
      .trim();

    if (title.length >= 3) return title;
  }
  return "Deff-Call";
}

/**
 * Erkennt manuelles Crop-Update Format: "15/50k" (alleinstehend)
 * Nur wenn die Nachricht NUR dieses Format enthaelt (kein vollstaendiger Call)
 */
function isManualCropUpdate(text) {
  const cleaned = text.trim();
  // Nur Crop-Format, keine Koordinaten, kein Link
  return (
    /^\d+(?:[.,]\d+)?\s*k?\s*\/\s*\d+(?:[.,]\d+)?\s*k?\s*$/i.test(cleaned) &&
    !parseCoordinates(cleaned) &&
    !parseLink(cleaned)
  );
}

// ─── Suppressed Call IDs (Loop-Vermeidung fuer manuelle Discord-Updates) ────
// Wenn der Bot selbst einen Discord-Pledge speichert, feuert der DB-Trigger
// pledge-to-discord → Webhook zurueck an den Bot. Das darf nicht nochmal
// gepostet werden, weil der Discord-User ja schon selbst geschrieben hat.
const suppressedCallIds = new Map(); // callId → timestamp

function cleanupSuppressed() {
  const now = Date.now();
  for (const [callId, ts] of suppressedCallIds) {
    if (now - ts > 30_000) suppressedCallIds.delete(callId);
  }
}

// ─── Call Dedup (verhindert Doppel-Calls bei Forum/Thread-Erstellung) ───────
// Discord feuert bei Forum-Posts zwei MessageCreate Events (Channel + Thread).
// Dedup per "parentChannel:x:y" innerhalb 30 Sekunden.
const recentCallKeys = new Map(); // key → timestamp

function isDuplicateCall(channelId, parentId, x, y) {
  const effectiveId = parentId || channelId;
  const key = `${effectiveId}:${x}:${y}`;
  const now = Date.now();

  // Alte Eintraege aufraeumen
  for (const [k, ts] of recentCallKeys) {
    if (now - ts > 30_000) recentCallKeys.delete(k);
  }

  if (recentCallKeys.has(key) && (now - recentCallKeys.get(key)) < 30_000) {
    return true;
  }

  recentCallKeys.set(key, now);
  return false;
}

// ─── Call Detection ─────────────────────────────────────────────────────────

async function handleCallDetection(message) {
  const text = cleanDiscordText(message.content);
  const coords = parseCoordinates(text);

  // Koordinaten sind Pflicht fuer einen Call
  if (!coords) return;

  // Wenn es nur ein Crop-Update ist, nicht als Call behandeln
  if (isManualCropUpdate(text)) return;

  let arrival = parseArrival(text);
  const crop = parseCropLimit(text);
  const link = parseLink(text);

  // Forum-Channels: Der Parent-Event enthaelt nur den Post-Titel (Coords, aber
  // keine Arrival/Crop/Link). Der Thread-Event hat den vollstaendigen Inhalt.
  // Nachrichten die NUR Koordinaten enthalten werden uebersprungen.
  if (!arrival && !crop && !link) {
    console.log(`[CallDetector] Nur Koordinaten in #${message.channel.name} — uebersprungen (kein Arrival/Crop/Link)`);
    return;
  }

  // Duplikat-Schutz: gleiche Koordinaten im gleichen (Parent-)Channel innerhalb 30s
  if (isDuplicateCall(message.channel.id, message.channel.parentId, coords.x, coords.y)) {
    console.log(`[CallDetector] Duplikat-Schutz: (${coords.x}|${coords.y}) bereits verarbeitet — uebersprungen`);
    return;
  }

  // Thread-Name als Titel nutzen (wenn vorhanden), sonst aus Text ableiten
  const isThread = message.channel.isThread?.() || false;
  const title = isThread && message.channel.name
    ? message.channel.name
    : deriveTitle(text);

  // Arrival ist Pflichtfeld in der DB — Default: jetzt + 4h
  if (!arrival) {
    const defaultArrival = new Date(Date.now() + 4 * 60 * 60 * 1000);
    arrival = defaultArrival.toISOString();
    console.log(`[CallDetector] Keine Ankunftszeit erkannt — Default: +4h`);
  }

  console.log(`[CallDetector] Call erkannt in #${message.channel.name}:`);
  console.log(`  Title: ${title}`);
  console.log(`  Coords: (${coords.x}|${coords.y})`);
  console.log(`  Arrival: ${arrival}`);
  console.log(`  Crop: ${crop ? `${crop.pledged}/${crop.limit}` : "nicht erkannt"}`);

  // Reagiere sofort mit 🔄 (wird verarbeitet)
  try {
    await message.react("🔄");
  } catch (e) {
    console.warn("[CallDetector] Konnte nicht reagieren:", e.message);
  }

  // Push an Edge Function
  try {
    // Bei Threads: Parent Channel ID nutzen (dort ist das Kingdom-Mapping)
    const effectiveChannelId = message.channel.parentId || message.channel.id;
    // Thread-ID merken, damit Pledge-Updates im richtigen Thread landen
    const threadId = message.channel.isThread() ? message.channel.id : null;

    const payload = {
      discord_channel_id: effectiveChannelId,
      discord_thread_id: threadId,
      discord_message_id: message.id,
      title,
      target_x: coords.x,
      target_y: coords.y,
      arrival: arrival || null,
      link: link || null,
      crop_limit: crop ? crop.limit : null,
      crop_pledged_total: crop ? crop.pledged : 0,
    };

    const response = await fetch(PUSH_CALL_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BOT_SECRET}`,
      },
      body: JSON.stringify(payload),
    });

    const result = await response.json();
    console.log("[CallDetector] push-call Antwort:", result);

    // Reaktionen aktualisieren
    try {
      // Entferne 🔄
      const botReactions = message.reactions.cache.get("🔄");
      if (botReactions) await botReactions.users.remove(message.client.user.id);
    } catch (e) {
      // Ignorieren
    }

    if (result.duplicate) {
      await message.react("🔄"); // Duplikat
      console.log("[CallDetector] Duplikat erkannt");
    } else if (result.success || result.callId) {
      await message.react("✅"); // Erfolgreich
      console.log(`[CallDetector] Call erstellt: ${result.callId}`);
    } else {
      await message.react("❌"); // Fehler
      console.error("[CallDetector] Fehler:", result.error);
    }
  } catch (err) {
    console.error("[CallDetector] Netzwerk-Fehler:", err);
    try {
      const botReactions = message.reactions.cache.get("🔄");
      if (botReactions) await botReactions.users.remove(message.client.user.id);
      await message.react("❌");
    } catch (e) {
      // Ignorieren
    }
  }
}

// ─── Manual Crop Update ─────────────────────────────────────────────────────

async function handleManualCropUpdate(message) {
  const text = cleanDiscordText(message.content);

  if (!isManualCropUpdate(text)) return;

  const crop = parseCropLimit(text);
  if (!crop) return;

  const discordPlayerName =
    message.member?.displayName || message.author.displayName || message.author.username;

  console.log(
    `[CropUpdate] Manuelles Update von ${discordPlayerName} in #${message.channel.name}: ${crop.pledged}/${crop.limit}`
  );

  // Letzten offenen Call in diesem Channel/Thread finden
  const channelId = message.channel.id;
  const isThread = message.channel.isThread?.() || false;

  let calls, error;
  if (isThread) {
    ({ data: calls, error } = await supabase
      .from("calls")
      .select("id, crop_limit, crop_pledged_total")
      .eq("discord_thread_id", channelId)
      .eq("status", "open")
      .order("created_at", { ascending: false })
      .limit(1));
  } else {
    ({ data: calls, error } = await supabase
      .from("calls")
      .select("id, crop_limit, crop_pledged_total")
      .eq("discord_channel_id", channelId)
      .eq("status", "open")
      .order("created_at", { ascending: false })
      .limit(1));
  }

  if (error || !calls || calls.length === 0) {
    console.log("[CropUpdate] Kein offener Call in diesem Channel gefunden");
    await message.react("❓");
    return;
  }

  const call = calls[0];
  const currentDbValue = call.crop_pledged_total || 0;

  // Discord zeigt gerundete Tausender (6128 → "6/50k").
  // Wenn ein Spieler "8/50k" schreibt, ist die Differenz zum letzten Discord-Stand
  // relevant, nicht der absolute Wert. So bleiben die exakten App-Pledges erhalten.
  //
  // Beispiel: DB = 6128, Discord zeigte "6/50k", Spieler schreibt "8/50k"
  //   → lastDiscordValue = 6000 (gerundet)
  //   → diff = 8000 - 6000 = 2000
  //   → Bestehender Discord-Pledge dieses Users: count = 1000
  //   → Neuer count = 1000 + 2000 = 3000
  const lastDiscordValue = Math.round(currentDbValue / 1000) * 1000;
  const diff = crop.pledged - lastDiscordValue;

  if (diff === 0) {
    console.log(`[CropUpdate] Keine Aenderung (Discord-Wert unveraendert: ${crop.pledged})`);
    await message.react("👌");
    return;
  }

  if (diff < 0) {
    console.log(`[CropUpdate] Negative Differenz (${diff}) — ignoriert (kein Runtersetzen)`);
    await message.react("⚠️");
    return;
  }

  // Bestehenden Discord-Pledge dieses Users fuer diesen Call suchen
  const { data: existingPledges, error: pledgeError } = await supabase
    .from("pledges")
    .select("id, count")
    .eq("call_id", call.id)
    .eq("user_id", BOT_SYSTEM_USER_ID)
    .eq("player_name", discordPlayerName)
    .eq("troop_kind", "unknown");

  if (pledgeError) {
    console.error("[CropUpdate] Pledge-Abfrage fehlgeschlagen:", pledgeError);
    await message.react("❌");
    return;
  }

  const existing = existingPledges && existingPledges.length > 0 ? existingPledges[0] : null;
  const newCount = (existing ? existing.count : 0) + diff;

  console.log(
    `[CropUpdate] DB: ${currentDbValue}, Discord alt: ${lastDiscordValue}, Discord neu: ${crop.pledged}, ` +
    `Diff: +${diff}, Bestehend: ${existing ? existing.count : 0} → Neuer Pledge-Count: ${newCount}`
  );

  // Suppress: DB-Trigger wird diesen Pledge an pledge-to-discord → Webhook senden.
  // Bot soll das nicht nochmal posten (User hat ja schon selbst geschrieben).
  suppressedCallIds.set(call.id, Date.now());
  cleanupSuppressed();

  if (existing) {
    // Bestehenden Discord-Pledge updaten
    const { error: updateError } = await supabase
      .from("pledges")
      .update({ count: newCount })
      .eq("id", existing.id);

    if (updateError) {
      console.error("[CropUpdate] Pledge-Update fehlgeschlagen:", updateError);
      suppressedCallIds.delete(call.id);
      await message.react("❌");
      return;
    }
  } else {
    // Neuen Discord-Pledge erstellen
    const { error: insertError } = await supabase
      .from("pledges")
      .insert({
        call_id: call.id,
        user_id: BOT_SYSTEM_USER_ID,
        player_name: discordPlayerName,
        village_name: "Discord",
        village_x: 0,
        village_y: 0,
        troop_kind: "unknown",
        count: newCount,
      });

    if (insertError) {
      console.error("[CropUpdate] Pledge-Insert fehlgeschlagen:", insertError);
      suppressedCallIds.delete(call.id);
      await message.react("❌");
      return;
    }
  }

  console.log(
    `[CropUpdate] Discord-Pledge gespeichert fuer ${discordPlayerName}: ${newCount} Getreide/h`
  );
  await message.react("✅");
}

// ─── Discord Client ─────────────────────────────────────────────────────────

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
    GatewayIntentBits.GuildMessageReactions,
  ],
  // Threads: Discord.js empfaengt automatisch Thread-Nachrichten wenn
  // GuildMessages aktiv ist. Aber wir muessen den Channel-Check anpassen
  // damit Thread-Nachrichten auch verarbeitet werden (thread.parentId).
});

client.once(Events.ClientReady, (c) => {
  console.log(`[Bot] Eingeloggt als ${c.user.tag}`);
  console.log(`[Bot] Ueberwachte Channels: ${WATCHED_CHANNELS.join(", ") || "(alle)"}`);
});

// ─── Message Edit Tracking ──────────────────────────────────────────────────
// Trackt die letzte Bot-Nachricht pro Channel, damit bei mehreren Pledges
// die Nachricht editiert wird statt Spam zu erzeugen.
// Reset wenn ein anderer User im Channel schreibt.
// Key: channelId, Value: { messageId, timestamp }
const lastBotMessages = new Map();

// Timeout: Nach 10 Minuten wird eine neue Nachricht gesendet
const EDIT_TIMEOUT_MS = 10 * 60 * 1000;

client.on(Events.MessageCreate, async (message) => {
  // ─── Edit Tracker: Fremde Nachrichten resetten das Tracking ───────
  if (message.author.id !== client.user?.id && !message.author.bot) {
    const channelId = message.channel.id;
    if (lastBotMessages.has(channelId)) {
      console.log(`[EditTracker] Reset in #${message.channel.name} — ${message.author.username} hat geschrieben`);
      lastBotMessages.delete(channelId);
    }
  }

  // ─── Call/Crop Detection (nur nicht-Bot Nachrichten) ──────────────
  if (message.author.bot) return;

  // Nur ueberwachte Channels (wenn konfiguriert)
  // Bei Threads: parentId pruefen (Thread gehoert zum ueberwachten Channel)
  if (WATCHED_CHANNELS.length > 0) {
    const channelId = message.channel.id;
    const parentId = message.channel.parentId; // Fuer Threads: Parent Channel ID
    const isWatched =
      WATCHED_CHANNELS.includes(channelId) ||
      (parentId && WATCHED_CHANNELS.includes(parentId));
    if (!isWatched) return;
  }

  try {
    // Zuerst pruefen ob es ein manuelles Crop-Update ist
    if (isManualCropUpdate(cleanDiscordText(message.content))) {
      await handleManualCropUpdate(message);
    } else {
      // Sonst als Call pruefen
      await handleCallDetection(message);
    }
  } catch (err) {
    console.error("[Bot] Unerwarteter Fehler:", err);
  }
});

// ─── Webhook Server (Express) ───────────────────────────────────────────────

const app = express();
app.use(express.json());

/**
 * Crop in "k" formatieren
 */
/**
 * Baut die Pledge-Nachricht auf.
 * Format: 2/50k (Update von bowser)
 * Pledged und Limit werden in Tausend angezeigt, nur Limit bekommt "k".
 */
function buildPledgeMessage({ crop_pledged_total, crop_limit, player_name }) {
  const pledged = Math.round((crop_pledged_total || 0) / 1000);
  const limit = Math.round((crop_limit || 0) / 1000);
  const name = player_name || "Unbekannt";

  return `${pledged}/${limit}k (Update von ${name})`;
}

// Health Check
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    bot: client.isReady() ? "connected" : "disconnected",
    uptime: process.uptime(),
  });
});

// Pledge Update Webhook
app.post("/webhook/pledge-update", async (req, res) => {
  // Auth pruefen
  const authHeader = req.headers.authorization;
  if (authHeader !== `Bearer ${WEBHOOK_SECRET}`) {
    console.warn("[Webhook] Unauthorized request");
    return res.status(401).json({ error: "Unauthorized" });
  }

  try {
    const {
      discord_channel_id,
      discord_thread_id,
      player_name,
      crop_pledged_total,
      crop_limit,
      call_id,
    } = req.body;

    if (!discord_channel_id) {
      return res.status(400).json({ error: "discord_channel_id fehlt" });
    }

    // Loop-Vermeidung: Wenn dieses Update von einem manuellen Discord-Hochzaehlen
    // stammt, nicht nochmal posten (der User hat ja schon selbst geschrieben)
    if (call_id && suppressedCallIds.has(call_id)) {
      suppressedCallIds.delete(call_id);
      console.log(`[Webhook] Suppressed: Call ${call_id} (manuelles Discord-Update)`);
      return res.json({ success: true, suppressed: true });
    }

    // Ziel-Channel bestimmen: Thread-ID hat Vorrang (Pledge-Updates sollen im Thread landen)
    const targetId = discord_thread_id || discord_channel_id;
    const channel = await client.channels.fetch(targetId);
    if (!channel || !channel.isTextBased()) {
      console.warn(`[Webhook] Channel/Thread ${targetId} nicht gefunden`);
      return res.status(404).json({ error: "Channel nicht gefunden" });
    }

    // Nachricht aufbauen
    const text = buildPledgeMessage({
      crop_pledged_total,
      crop_limit,
      player_name,
    });

    // Pruefen ob wir die letzte Nachricht editieren koennen
    // Tracking key ist die tatsaechliche Ziel-ID (Thread oder Channel)
    const tracked = lastBotMessages.get(targetId);
    const now = Date.now();
    let edited = false;

    if (tracked && (now - tracked.timestamp) < EDIT_TIMEOUT_MS) {
      // Letzte Nachricht editieren (solange kein Fremder dazwischen geschrieben hat)
      try {
        const oldMessage = await channel.messages.fetch(tracked.messageId);
        if (oldMessage && oldMessage.author.id === client.user.id) {
          await oldMessage.edit(text);
          tracked.timestamp = now;
          edited = true;
          console.log(`[Webhook] Nachricht editiert in #${channel.name}`);
        }
      } catch (editErr) {
        console.warn(`[Webhook] Edit fehlgeschlagen, sende neue Nachricht:`, editErr.message);
      }
    }

    if (!edited) {
      // Neue Nachricht senden
      const sentMessage = await channel.send(text);
      lastBotMessages.set(targetId, {
        messageId: sentMessage.id,
        timestamp: now,
      });
      console.log(`[Webhook] Neue Nachricht in #${channel.name}`);
    }

    res.json({ success: true, edited });
  } catch (err) {
    console.error("[Webhook] Fehler:", err);
    res.status(500).json({ error: "Interner Fehler" });
  }
});

// ─── Start ──────────────────────────────────────────────────────────────────

async function start() {
  // Webhook Server starten
  app.listen(WEBHOOK_PORT, () => {
    console.log(`[Webhook] Server laeuft auf Port ${WEBHOOK_PORT}`);
  });

  // Discord Bot verbinden
  if (!DISCORD_BOT_TOKEN) {
    console.error("[Bot] DISCORD_BOT_TOKEN fehlt!");
    process.exit(1);
  }

  await client.login(DISCORD_BOT_TOKEN);
}

start().catch((err) => {
  console.error("[Bot] Start fehlgeschlagen:", err);
  process.exit(1);
});
