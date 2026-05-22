import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (request) => {
  const optionsResponse = handleOptions(request);
  if (optionsResponse) return optionsResponse;

  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !anonKey) {
    return jsonResponse({ error: "Supabase environment variables are missing" }, 500);
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: request.headers.get("Authorization") ?? "" } },
  });

  const { data, error } = await supabase
    .from("published_configs")
    .select("version_number, config_json, published_at")
    .eq("is_current", true)
    .maybeSingle();

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  if (!data) {
    return jsonResponse({ error: "No published config" }, 404);
  }

  return jsonResponse({
    ...data.config_json,
    version: data.config_json.version ?? data.version_number,
    published_at: data.config_json.published_at ?? data.published_at,
  });
});
