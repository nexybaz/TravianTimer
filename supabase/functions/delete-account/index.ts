// supabase/functions/delete-account/index.ts
// Loescht den Account des aufrufenden Users vollstaendig.
//
// Auth: User JWT (Bearer Token) — identifiziert den zu loeschenden User
//
// Ablauf:
// 1. User aus JWT identifizieren
// 2. delete_user_data() SQL-Funktion aufrufen (raeumt alle Tabellen auf)
// 3. Auth-User via Admin API loeschen
// 4. Erfolg zurueckgeben

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
    // 1. User aus JWT identifizieren
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");

    if (!token) {
      return new Response(
        JSON.stringify({ error: "Nicht authentifiziert" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Anon-Client um den User aus dem JWT zu lesen
    const supabaseAnon = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: `Bearer ${token}` } },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseAnon.auth.getUser(token);

    if (userError || !user) {
      console.error("[delete-account] User nicht gefunden:", userError);
      return new Response(
        JSON.stringify({ error: "User nicht gefunden" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const userId = user.id;
    console.log(`[delete-account] Lösche Account: ${userId}`);

    // Admin Client (Service Role) für DB-Cleanup und Auth-Deletion
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 2. Alle User-Daten bereinigen via SQL-Funktion
    const { error: rpcError } = await supabaseAdmin.rpc("delete_user_data", {
      target_user_id: userId,
    });

    if (rpcError) {
      console.error("[delete-account] delete_user_data fehlgeschlagen:", rpcError);
      return new Response(
        JSON.stringify({
          error: "Datenbereinigung fehlgeschlagen",
          details: rpcError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`[delete-account] User-Daten bereinigt: ${userId}`);

    // 3. Auth-User via Admin API loeschen
    const { error: deleteError } =
      await supabaseAdmin.auth.admin.deleteUser(userId);

    if (deleteError) {
      console.error("[delete-account] Auth-User löschen fehlgeschlagen:", deleteError);
      return new Response(
        JSON.stringify({
          error: "Auth-User konnte nicht gelöscht werden",
          details: deleteError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`[delete-account] Account vollständig gelöscht: ${userId}`);

    return new Response(
      JSON.stringify({ success: true }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[delete-account] Fehler:", err);
    return new Response(
      JSON.stringify({ error: "Interner Fehler" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
