// TravianTimer Discord Bot
// Überwacht konfigurierte Channels/Threads auf Deff-Calls und pusht sie an Supabase.
//
// Koordinaten-Muster: (x|y) oder (x/y) — gleich wie in der iOS-App
// Ankunftszeit-Muster: HH:MM oder HH:MM:SS (bevorzugt nach "Ankunft", "vor", "bis")
// Crop-Limit-Muster: z.B. "0/50k" oder "12k/50k"
// Link-Muster: https://...kingdoms...

require("dotenv").config();
const { Client, GatewayIntentBits, Events } = require("discord.js");

// --- Config ---

const BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;
const SUPABASE_PUSH_URL = process.env.SUPABASE_PUSH_URL;
const BOT_SECRET = process.env.BOT_SECRET;
const WATCHED_CHANNELS = (process.env.WATCHED_CHANNELS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

if (!BOT_TOKEN || !SUPABASE_PUSH_URL) {
  console.error(
    "DISCORD_BOT_TOKEN und SUPABASE_PUSH_URL müssen gesetzt sein."
  );
  process.exit(1);
}

// --- Parsing ---

/**
 * Erkennt Koordinaten im Format (x|y) oder (x/y).
 * Gibt { x, y } oder null zurück.
 */
function parseCoordinates(text) {
  // Muster 1: Klammern mit | oder /
  const coordRegex = /\(\s*(-?\d+)\s*[/|]\s*(-?\d+)\s*\)/;
  const m = text.match(coordRegex);
  if (m) {
    return { x: parseInt(m[1], 10), y: parseInt(m[2], 10) };
  }

  // Muster 2: x:-4/y:6 (aus Travian-Links)
  const linkCoordRegex = /x:(-?\d+)\s*\/\s*y:(-?\d+)/;
  const m2 = text.match(linkCoordRegex);
  if (m2) {
    return { x: parseInt(m2[1], 10), y: parseInt(m2[2], 10) };
  }

  return null;
}

/**
 * Erkennt eine Ankunftszeit.
 * Bevorzugt Zeilen mit "ankunft", "vor", "bis".
 * Gibt ein Date-Objekt zurück.
 */
function parseArrival(text) {
  const timeRegex = /(\d{1,2}):(\d{2})(?::(\d{2}))?/g;
  const lines = text.split("\n");

  // Bevorzugte Zeilen (mit Schlüsselwort)
  const keywords = ["ankunft", "vor", "bis"];
  for (const line of lines) {
    const lower = line.toLowerCase();
    if (keywords.some((kw) => lower.includes(kw))) {
      const m = line.match(timeRegex);
      if (m) {
        return buildDate(m[0]);
      }
    }
  }

  // Fallback: erste Zeit im Text
  const m = text.match(timeRegex);
  if (m) {
    return buildDate(m[0]);
  }

  return null;
}

/**
 * Baut ein Date-Objekt aus "HH:MM" oder "HH:MM:SS".
 * Wenn die Zeit >12h in der Vergangenheit liegt, wird morgen genommen.
 */
function buildDate(timeStr) {
  const parts = timeStr.split(":");
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  const s = parts[2] ? parseInt(parts[2], 10) : 0;

  const now = new Date();
  const date = new Date(now);
  date.setHours(h, m, s, 0);

  // Wenn >12h in der Vergangenheit: morgen
  const diffMs = date.getTime() - now.getTime();
  if (diffMs < -12 * 60 * 60 * 1000) {
    date.setDate(date.getDate() + 1);
  }

  return date;
}

/**
 * Erkennt ein Crop-Limit, z.B. "0/50k" oder "12k/50k".
 * Gibt die Zahl (z.B. 50000) oder null zurück.
 */
function parseCropLimit(text) {
  const cropRegex = /(\d+)k?\s*\/\s*(\d+)k/i;
  const m = text.match(cropRegex);
  if (m) {
    return parseInt(m[2], 10) * 1000;
  }
  return null;
}

/**
 * Extrahiert einen Travian-Kingdoms-Link.
 */
function parseLink(text) {
  const linkRegex = /https?:\/\/[^\s]+kingdoms\.[^\s]+/i;
  const m = text.match(linkRegex);
  return m ? m[0] : null;
}

/**
 * Versucht einen Titel aus dem Text abzuleiten.
 * Gleiche Logik wie CallsStore.deriveTitle in der iOS-App.
 */
function deriveTitle(text) {
  const lines = text
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  // Zeile mit Koordinaten: Name vor der Klammer
  for (const line of lines) {
    if (
      line.includes("(") &&
      (line.includes("/") || line.includes("|")) &&
      line.includes(")")
    ) {
      const idx = line.indexOf("(");
      const name = line.substring(0, idx).trim();
      if (name) return name;
    }
  }

  // Zeile mit "für": Text danach
  for (const line of lines) {
    const lower = line.toLowerCase();
    const idx = lower.indexOf("für");
    if (idx !== -1) {
      const after = line.substring(idx + 3).trim();
      if (after) return after;
    }
  }

  return "Deff-Call";
}

// --- Push an Supabase ---

async function pushCall(callData) {
  try {
    const res = await fetch(SUPABASE_PUSH_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BOT_SECRET}`,
      },
      body: JSON.stringify(callData),
    });

    const body = await res.json();
    console.log(`[Push] Status ${res.status}:`, body);
    return body;
  } catch (err) {
    console.error("[Push] Fehler:", err.message);
    return null;
  }
}

// --- Discord Client ---

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

client.once(Events.ClientReady, (c) => {
  console.log(`[Bot] Eingeloggt als ${c.user.tag}`);
  console.log(
    `[Bot] Überwache ${WATCHED_CHANNELS.length} Channel(s): ${WATCHED_CHANNELS.join(", ")}`
  );
});

client.on(Events.MessageCreate, async (message) => {
  // Eigene Nachrichten ignorieren
  if (message.author.bot) return;

  // Debug: jede Nachricht loggen
  const channelId = message.channelId;
  const parentId = message.channel.parentId;
  console.log(`[Debug] Nachricht in Channel ${channelId} (Parent: ${parentId || "keiner"}) von ${message.author.username}: "${message.content.substring(0, 80)}"`);
  console.log(`[Debug] Watched Channels: ${JSON.stringify(WATCHED_CHANNELS)}`);

  // Nur konfigurierte Channels (inkl. Threads in diesen Channels)
  const isWatched =
    WATCHED_CHANNELS.includes(channelId) ||
    (parentId && WATCHED_CHANNELS.includes(parentId));

  if (!isWatched) {
    console.log(`[Debug] Channel ${channelId} wird NICHT überwacht — ignoriert.`);
    return;
  }

  const text = message.content;

  // Koordinaten erkennen (Pflicht)
  const coords = parseCoordinates(text);
  if (!coords) {
    console.log(`[Debug] Keine Koordinaten gefunden — ignoriert.`);
    return;
  }

  console.log(`[Bot] Call erkannt von ${message.author.username}: (${coords.x}|${coords.y})`);

  // Optionale Felder
  const arrival = parseArrival(text);
  const cropLimit = parseCropLimit(text);
  const link = parseLink(text);
  const title = deriveTitle(text);

  const callData = {
    title,
    target_x: coords.x,
    target_y: coords.y,
    arrival: arrival ? arrival.toISOString() : new Date().toISOString(),
    link,
    crop_limit: cropLimit,
    discord_message_id: message.id,
  };

  const result = await pushCall(callData);

  // Bestätigung im Channel posten
  if (result && result.success) {
    if (result.duplicate) {
      await message.react("🔄");
    } else {
      await message.react("✅");
      const pushed = result.pushed || 0;
      if (pushed > 0) {
        console.log(`[Bot] Push an ${pushed} Gerät(e) gesendet`);
      }
    }
  } else {
    await message.react("❌");
  }
});

// --- Start ---

client.login(BOT_TOKEN);
