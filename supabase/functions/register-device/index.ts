// register-device: Registriert ein iOS-Gerät für Push-Benachrichtigungen.
// Wenn ein JWT vorhanden ist, wird die user_id aus dem Token extrahiert.
// Deploy: supabase functions deploy register-device

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { token, player_name, platform } = await req.json();

    if (!token || typeof token !== "string") {
      return new Response(
        JSON.stringify({ error: "token is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Versuche user_id aus JWT zu extrahieren (falls eingeloggt)
    let userId: string | null = null;
    const authHeader = req.headers.get("authorization") || "";
    const jwtToken = authHeader.replace("Bearer ", "");

    if (jwtToken && jwtToken !== supabaseAnonKey) {
      try {
        const userClient = createClient(supabaseUrl, supabaseAnonKey, {
          global: { headers: { Authorization: `Bearer ${jwtToken}` } },
        });
        const { data: { user } } = await userClient.auth.getUser();
        if (user) {
          userId = user.id;
        }
      } catch {
        // JWT ungültig — kein User, weiter ohne user_id
      }
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // UPSERT: Token aktualisieren falls schon vorhanden
    const upsertData: any = {
      token,
      player_name: player_name || "Unknown",
      platform: platform || "ios",
      updated_at: new Date().toISOString(),
    };

    // user_id nur setzen wenn vorhanden (nicht überschreiben mit null)
    if (userId) {
      upsertData.user_id = userId;
    }

    const { error } = await supabase
      .from("device_tokens")
      .upsert(upsertData, { onConflict: "token" });

    if (error) {
      console.error("DB error:", error);
      return new Response(
        JSON.stringify({ error: "Database error" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
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
