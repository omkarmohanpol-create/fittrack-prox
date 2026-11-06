// delete-account: permanently deletes the signed-in user.
//
// The app calls this with the user's own access token. The function checks
// who the caller is, removes their profile pictures from Storage (not covered
// by the database cascade), then deletes the auth user, which cascades to
// public.users and every table that references it.
//
// Deploy: supabase functions deploy delete-account
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided
// to Edge Functions automatically; the service-role key never leaves the
// server.
import { createClient } from "npm:@supabase/supabase-js@2";

const AVATAR_BUCKET = "avatars";

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const authorization = req.headers.get("Authorization");
  if (!authorization) return json({ error: "Not signed in" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return json({ error: "Function is missing its environment" }, 500);
  }

  // Who is calling? Verified by Supabase Auth from the caller's own token.
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: { user }, error: userError } = await asCaller.auth.getUser();
  if (userError || !user) return json({ error: "Not signed in" }, 401);

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false },
  });

  const { data: files, error: listError } = await admin.storage
    .from(AVATAR_BUCKET)
    .list(user.id);
  if (listError) return json({ error: listError.message }, 500);
  if (files && files.length > 0) {
    const { error: removeError } = await admin.storage
      .from(AVATAR_BUCKET)
      .remove(files.map((f) => `${user.id}/${f.name}`));
    if (removeError) return json({ error: removeError.message }, 500);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return json({ error: deleteError.message }, 500);

  return json({ deleted: true }, 200);
});
