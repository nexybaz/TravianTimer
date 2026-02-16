// sync-calls: Cloud-Sync für TravianTimer Calls + Pledges.
// Actions: push, pull, delete
// Auth: JWT (Supabase Auth) — User-ID wird aus dem Token extrahiert.
// Deploy: supabase functions deploy sync-calls

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  try {
    // --- Auth: User-ID aus JWT extrahieren ---
    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.replace("Bearer ", "");

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // User aus JWT validieren
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: jsonHeaders }
      );
    }

    const userId = user.id;

    // Service-Role Client für DB-Zugriffe
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();
    const { action, device_token } = body;

    if (!action) {
      return new Response(
        JSON.stringify({ error: "action required" }),
        { status: 400, headers: jsonHeaders }
      );
    }

    // --- Migration: Bestehende device_token-Calls diesem User zuordnen ---
    if (device_token) {
      await supabase
        .from("calls")
        .update({ user_id: userId })
        .eq("device_token", device_token)
        .is("user_id", null);
    }

    // --- PUSH: Upsert calls + pledges ---
    if (action === "push") {
      const calls = body.calls || [];
      if (calls.length === 0) {
        return new Response(
          JSON.stringify({ success: true, upserted: 0 }),
          { status: 200, headers: jsonHeaders }
        );
      }

      let upserted = 0;

      for (const call of calls) {
        // Prüfe ob ein Discord-Call ohne user_id existiert (vom Bot erstellt)
        if (call.discord_message_id) {
          const { data: existing } = await supabase
            .from("calls")
            .select("id, guild_id")
            .eq("discord_message_id", call.discord_message_id)
            .is("user_id", null)
            .maybeSingle();

          if (existing) {
            // Call vom Bot claimen: user_id setzen + updaten
            await supabase
              .from("calls")
              .update({
                title: call.title,
                status: call.status || "open",
                crop_limit: call.crop_limit ?? null,
                user_id: userId,
                device_token: device_token || null,
                updated_at: call.updated_at || new Date().toISOString(),
              })
              .eq("id", existing.id);

            // Auto-Join: User ins Team eintragen wenn Call eine guild_id hat
            if (existing.guild_id) {
              await supabase.from("team_members").upsert({
                user_id: userId,
                guild_id: existing.guild_id,
              }, { onConflict: "user_id,guild_id" });
            }

            // Pledges für den geclaimten Call (UPSERT statt DELETE+INSERT)
            if (call.pledges && call.pledges.length > 0) {
              const pledgeRows = call.pledges.map((p: any) => ({
                id: p.id,
                call_id: existing.id,
                player_name: p.player_name,
                village_name: p.village_name,
                village_x: p.village_x,
                village_y: p.village_y,
                troop_kind: p.troop_kind,
                count: p.count,
                pledged_at: p.pledged_at || new Date().toISOString(),
                user_id: p.user_id || userId,
              }));
              await supabase
                .from("pledges")
                .upsert(pledgeRows, { onConflict: "id" });
            }

            // Gelöschte Pledges entfernen
            if (call.deleted_pledge_ids && call.deleted_pledge_ids.length > 0) {
              await supabase
                .from("pledges")
                .delete()
                .in("id", call.deleted_pledge_ids)
                .eq("call_id", existing.id);
            }

            upserted++;
            continue;
          }
        }

        // Discord-Dedup: Prüfe ob dieser User bereits einen Call mit gleicher discord_message_id hat
        if (call.discord_message_id) {
          const { data: existingUserCall } = await supabase
            .from("calls")
            .select("id, updated_at")
            .eq("discord_message_id", call.discord_message_id)
            .eq("user_id", userId)
            .maybeSingle();

          if (existingUserCall && existingUserCall.id !== call.id) {
            // Duplikat: anderes Gerät hat den gleichen Discord-Call unter anderer UUID
            const existingTime = new Date(existingUserCall.updated_at).getTime();
            const incomingTime = new Date(call.updated_at || new Date().toISOString()).getTime();

            if (incomingTime >= existingTime) {
              // Incoming ist neuer: bestehenden Call aktualisieren
              await supabase
                .from("calls")
                .update({
                  title: call.title,
                  status: call.status || "open",
                  crop_limit: call.crop_limit ?? null,
                  updated_at: call.updated_at || new Date().toISOString(),
                })
                .eq("id", existingUserCall.id);

              // Pledges in bestehenden Call mergen
              if (call.pledges && call.pledges.length > 0) {
                const pledgeRows = call.pledges.map((p: any) => ({
                  id: p.id,
                  call_id: existingUserCall.id,
                  player_name: p.player_name,
                  village_name: p.village_name,
                  village_x: p.village_x,
                  village_y: p.village_y,
                  troop_kind: p.troop_kind,
                  count: p.count,
                  pledged_at: p.pledged_at || new Date().toISOString(),
                  user_id: p.user_id || userId,
                }));
                await supabase
                  .from("pledges")
                  .upsert(pledgeRows, { onConflict: "id" });
              }
            }

            // Tombstone für die Duplikat-UUID, damit Client sie entfernt
            await supabase.from("deleted_calls").insert({
              call_id: call.id,
              user_id: userId,
            });

            upserted++;
            continue;
          }
        }

        // Normaler UPSERT
        const callRow = {
          id: call.id,
          title: call.title || "Deff-Call",
          target_x: call.target_x,
          target_y: call.target_y,
          arrival: call.arrival,
          link: call.link || null,
          crop_limit: call.crop_limit ?? null,
          status: call.status || "open",
          discord_message_id: call.discord_message_id || null,
          guild_id: call.guild_id || null,
          user_id: userId,
          device_token: device_token || null,
          created_at: call.created_at || new Date().toISOString(),
          updated_at: call.updated_at || new Date().toISOString(),
        };

        const { error: callError } = await supabase
          .from("calls")
          .upsert(callRow, { onConflict: "id" });

        if (callError) {
          console.error("Call upsert error:", callError);
          continue;
        }

        // Pledges: UPSERT statt DELETE+INSERT (additiver Merge)
        if (call.pledges && call.pledges.length > 0) {
          const pledgeRows = call.pledges.map((p: any) => ({
            id: p.id,
            call_id: call.id,
            player_name: p.player_name,
            village_name: p.village_name,
            village_x: p.village_x,
            village_y: p.village_y,
            troop_kind: p.troop_kind,
            count: p.count,
            pledged_at: p.pledged_at || new Date().toISOString(),
            user_id: p.user_id || userId,
          }));

          const { error: pledgeError } = await supabase
            .from("pledges")
            .upsert(pledgeRows, { onConflict: "id" });

          if (pledgeError) {
            console.error("Pledge upsert error:", pledgeError);
          }
        }

        // Gelöschte Pledges entfernen
        if (call.deleted_pledge_ids && call.deleted_pledge_ids.length > 0) {
          await supabase
            .from("pledges")
            .delete()
            .in("id", call.deleted_pledge_ids)
            .eq("call_id", call.id);
        }

        upserted++;
      }

      return new Response(
        JSON.stringify({ success: true, upserted }),
        { status: 200, headers: jsonHeaders }
      );
    }

    // --- PULL: Fetch all calls for user + team calls ---
    if (action === "pull") {
      const since = body.since || null;

      // 1. Eigene Calls laden
      let query = supabase
        .from("calls")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false });

      if (since) {
        query = query.gte("updated_at", since);
      }

      const { data: calls, error: callsError } = await query;

      if (callsError) {
        console.error("Pull calls error:", callsError);
        return new Response(
          JSON.stringify({ error: "Failed to fetch calls" }),
          { status: 500, headers: jsonHeaders }
        );
      }

      const ownCalls = calls || [];

      // 2. Team-Calls laden (von anderen Usern in gleichen Guilds)
      const { data: memberships } = await supabase
        .from("team_members")
        .select("guild_id")
        .eq("user_id", userId);

      const guildIds = (memberships || []).map((m: any) => m.guild_id);
      let teamCalls: any[] = [];

      if (guildIds.length > 0) {
        let teamQuery = supabase
          .from("calls")
          .select("*")
          .in("guild_id", guildIds)
          .neq("user_id", userId)
          .not("user_id", "is", null)
          .order("created_at", { ascending: false });

        if (since) {
          teamQuery = teamQuery.gte("updated_at", since);
        }

        const { data: teamData } = await teamQuery;
        teamCalls = teamData || [];
      }

      // 3. Pledges für ALLE Calls laden (eigene + Team)
      const allCallsList = [...ownCalls, ...teamCalls];

      let callsWithPledges: any[] = [];
      let teamCallsWithPledges: any[] = [];

      if (allCallsList.length > 0) {
        const allCallIds = allCallsList.map((c: any) => c.id);
        const { data: allPledges } = await supabase
          .from("pledges")
          .select("*")
          .in("call_id", allCallIds);

        // Pledges den Calls zuordnen
        const pledgeMap = new Map<string, any[]>();
        for (const p of allPledges || []) {
          const list = pledgeMap.get(p.call_id) || [];
          list.push(p);
          pledgeMap.set(p.call_id, list);
        }

        callsWithPledges = ownCalls.map((c: any) => ({
          ...c,
          pledges: pledgeMap.get(c.id) || [],
        }));

        teamCallsWithPledges = teamCalls.map((c: any) => ({
          ...c,
          is_shared: true,
          pledges: pledgeMap.get(c.id) || [],
        }));
      }

      // 4. Gelöschte Call-IDs der letzten 30 Tage
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
      const { data: deletedRows } = await supabase
        .from("deleted_calls")
        .select("call_id")
        .eq("user_id", userId)
        .gte("deleted_at", thirtyDaysAgo);

      const deletedCallIds = (deletedRows || []).map((r: any) => r.call_id);

      return new Response(
        JSON.stringify({
          success: true,
          calls: callsWithPledges,
          team_calls: teamCallsWithPledges,
          deleted_call_ids: deletedCallIds,
        }),
        { status: 200, headers: jsonHeaders }
      );
    }

    // --- PLEDGE: Upsert pledges on a team call (not owned by this user) ---
    if (action === "pledge") {
      const callId = body.call_id;
      const pledges = body.pledges || [];

      if (!callId || pledges.length === 0) {
        return new Response(
          JSON.stringify({ error: "call_id and pledges required" }),
          { status: 400, headers: jsonHeaders }
        );
      }

      // Verify user is a team member for the call's guild
      const { data: callData } = await supabase
        .from("calls")
        .select("id, guild_id, user_id")
        .eq("id", callId)
        .maybeSingle();

      if (!callData) {
        return new Response(
          JSON.stringify({ error: "Call not found" }),
          { status: 404, headers: jsonHeaders }
        );
      }

      // User darf auf eigene Calls oder Team-Calls pledgen
      if (callData.user_id !== userId && callData.guild_id) {
        const { data: membership } = await supabase
          .from("team_members")
          .select("id")
          .eq("user_id", userId)
          .eq("guild_id", callData.guild_id)
          .maybeSingle();

        if (!membership) {
          return new Response(
            JSON.stringify({ error: "Not a team member" }),
            { status: 403, headers: jsonHeaders }
          );
        }
      }

      // Pledges upserten
      const pledgeRows = pledges.map((p: any) => ({
        id: p.id,
        call_id: callId,
        player_name: p.player_name,
        village_name: p.village_name,
        village_x: p.village_x,
        village_y: p.village_y,
        troop_kind: p.troop_kind,
        count: p.count,
        pledged_at: p.pledged_at || new Date().toISOString(),
        user_id: userId,
      }));

      const { error: pledgeError } = await supabase
        .from("pledges")
        .upsert(pledgeRows, { onConflict: "id" });

      if (pledgeError) {
        console.error("Team pledge upsert error:", pledgeError);
        return new Response(
          JSON.stringify({ error: "Failed to upsert pledges" }),
          { status: 500, headers: jsonHeaders }
        );
      }

      // Gelöschte Pledges entfernen
      const deletedPledgeIds = body.deleted_pledge_ids || [];
      if (deletedPledgeIds.length > 0) {
        await supabase
          .from("pledges")
          .delete()
          .in("id", deletedPledgeIds)
          .eq("call_id", callId)
          .eq("user_id", userId);
      }

      // Call updated_at aktualisieren
      await supabase
        .from("calls")
        .update({ updated_at: new Date().toISOString() })
        .eq("id", callId);

      return new Response(
        JSON.stringify({ success: true, upserted: pledgeRows.length }),
        { status: 200, headers: jsonHeaders }
      );
    }

    // --- DELETE: Remove calls ---
    if (action === "delete") {
      const callIds = body.call_ids || [];
      if (callIds.length === 0) {
        return new Response(
          JSON.stringify({ success: true, deleted: 0 }),
          { status: 200, headers: jsonHeaders }
        );
      }

      // Tombstones schreiben (für Multi-Device Sync)
      const tombstones = callIds.map((cid: string) => ({
        call_id: cid,
        user_id: userId,
      }));
      await supabase.from("deleted_calls").insert(tombstones);

      // Nur eigene Calls löschen (user_id check)
      const { error, count } = await supabase
        .from("calls")
        .delete({ count: "exact" })
        .in("id", callIds)
        .eq("user_id", userId);

      if (error) {
        console.error("Delete error:", error);
        return new Response(
          JSON.stringify({ error: "Failed to delete calls" }),
          { status: 500, headers: jsonHeaders }
        );
      }

      return new Response(
        JSON.stringify({ success: true, deleted: count || 0 }),
        { status: 200, headers: jsonHeaders }
      );
    }

    return new Response(
      JSON.stringify({ error: "Unknown action. Use: push, pull, delete, pledge" }),
      { status: 400, headers: jsonHeaders }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: jsonHeaders }
    );
  }
});
