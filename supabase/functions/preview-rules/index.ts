import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { DeviceSnapshot, evaluateRules, RuleDefinition } from "../_shared/rule_engine.ts";

Deno.serve(async (request) => {
  const optionsResponse = handleOptions(request);
  if (optionsResponse) return optionsResponse;

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Supabase environment variables are missing" }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");

  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const { data: profile } = await supabase
    .from("admin_profiles")
    .select("role")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (!profile) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  const payload = await request.json().catch(() => null) as { snapshot?: DeviceSnapshot; useDraft?: boolean } | null;
  if (!payload?.snapshot) {
    return jsonResponse({ error: "snapshot is required" }, 400);
  }

  const rules = payload.useDraft ? await loadEditableRules(supabase) : await loadPublishedRules(supabase);
  return jsonResponse(evaluateRules(payload.snapshot, rules));
});

async function loadPublishedRules(supabase: ReturnType<typeof createClient>): Promise<RuleDefinition[]> {
  const { data, error } = await supabase
    .from("published_configs")
    .select("config_json")
    .eq("is_current", true)
    .maybeSingle();

  if (error || !data) {
    return [];
  }

  return data.config_json?.rules ?? [];
}

async function loadEditableRules(supabase: ReturnType<typeof createClient>): Promise<RuleDefinition[]> {
  const { data, error } = await supabase
    .from("rules")
    .select(`
      slug,
      is_active,
      action_items!inner (
        status,
        title,
        description,
        target_surface,
        severity,
        cta_label,
        action_type,
        access_level,
        priority
      ),
      rule_conditions (
        metric,
        operator,
        value_json
      )
    `)
    .neq("status", "archived")
    .neq("action_items.status", "archived");

  if (error || !data) {
    return [];
  }

  return data.map((row: any) => ({
    id: row.slug,
    title: row.action_items.title,
    description: row.action_items.description,
    target_surface: row.action_items.target_surface,
    severity: row.action_items.severity,
    cta_label: row.action_items.cta_label,
    action_type: row.action_items.action_type,
    access_level: row.action_items.access_level,
    priority: row.action_items.priority,
    is_active: row.is_active,
    conditions: (row.rule_conditions ?? []).map((condition: any) => ({
      metric: condition.metric,
      operator_name: condition.operator,
      value: condition.value_json?.value ?? condition.value_json,
    })),
  }));
}
