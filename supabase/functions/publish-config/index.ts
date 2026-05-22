import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { RuleDefinition } from "../_shared/rule_engine.ts";

type SupabaseClient = ReturnType<typeof createClient>;

type Thresholds = {
  battery_warning_percent: number;
  battery_critical_percent: number;
  storage_warning_gb: number;
  storage_critical_gb: number;
};

type PublishConfig = {
  version: number;
  published_at: string;
  ios: {
    latest_global_version: string;
    release_date: string | null;
    severity: "normal" | "warning" | "critical";
    message: string;
  };
  thresholds: Thresholds;
  rules: RuleDefinition[];
  guides: unknown[];
};

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
  const authResult = await requireEditor(supabase, request);
  if ("response" in authResult) return authResult.response;

  const publishedAt = new Date().toISOString();
  const versionNumber = await nextVersionNumber(supabase);
  const [ios, thresholds, rules, guides] = await Promise.all([
    loadIOSConfig(supabase),
    loadThresholds(supabase),
    loadRules(supabase),
    loadGuides(supabase),
  ]);

  const config: PublishConfig = {
    version: versionNumber,
    published_at: publishedAt,
    ios,
    thresholds,
    rules,
    guides,
  };

  const { data: publishedConfig, error: publishError } = await supabase
    .from("published_configs")
    .insert({
      version_number: versionNumber,
      config_json: config,
      published_by: authResult.userId,
      published_at: publishedAt,
      is_current: false,
    })
    .select("id")
    .single();

  if (publishError || !publishedConfig) {
    return jsonResponse({ error: publishError?.message ?? "Failed to publish config" }, 500);
  }

  const { error: clearError } = await supabase
    .from("published_configs")
    .update({ is_current: false })
    .eq("is_current", true);

  if (clearError) {
    return jsonResponse({ error: clearError.message }, 500);
  }

  const { error: currentError } = await supabase
    .from("published_configs")
    .update({ is_current: true })
    .eq("id", publishedConfig.id);

  if (currentError) {
    return jsonResponse({ error: currentError.message }, 500);
  }

  await supabase.from("app_config_versions").insert({
    version_number: versionNumber,
    status: "published",
    notes: "Published from Edge Function",
    created_by: authResult.userId,
    published_by: authResult.userId,
    published_at: publishedAt,
  });

  await supabase.from("audit_logs").insert({
    actor_id: authResult.userId,
    action: "publish_config",
    target_table: "published_configs",
    target_id: publishedConfig.id,
    after_json: config,
  });

  return jsonResponse(config, 201);
});

async function requireEditor(
  supabase: SupabaseClient,
  request: Request,
): Promise<{ userId: string } | { response: Response }> {
  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");

  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData.user) {
    return { response: jsonResponse({ error: "Unauthorized" }, 401) };
  }

  const { data: profile } = await supabase
    .from("admin_profiles")
    .select("role")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (!profile || !["owner", "editor"].includes(profile.role)) {
    return { response: jsonResponse({ error: "Forbidden" }, 403) };
  }

  return { userId: userData.user.id };
}

async function nextVersionNumber(supabase: SupabaseClient): Promise<number> {
  const { data } = await supabase
    .from("published_configs")
    .select("version_number")
    .order("version_number", { ascending: false })
    .limit(1)
    .maybeSingle();

  return (data?.version_number ?? 0) + 1;
}

async function loadIOSConfig(supabase: SupabaseClient): Promise<PublishConfig["ios"]> {
  const { data } = await supabase
    .from("os_versions")
    .select("latest_version, release_date, severity, message")
    .eq("platform", "ios")
    .neq("status", "archived")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  return {
    latest_global_version: data?.latest_version ?? "26.5",
    release_date: data?.release_date ?? null,
    severity: mapIOSSeverity(data?.severity),
    message: data?.message ?? "利用できるアップデートがある可能性があります。設定アプリから確認しましょう。",
  };
}

function mapIOSSeverity(severity: unknown): "normal" | "warning" | "critical" {
  switch (severity) {
    case "major":
    case "security":
      return "warning";
    default:
      return "normal";
  }
}

async function loadThresholds(supabase: SupabaseClient): Promise<Thresholds> {
  const { data } = await supabase
    .from("condition_thresholds")
    .select("metric, warning_min, critical_below")
    .neq("status", "archived");

  const byMetric = new Map((data ?? []).map((row: any) => [row.metric, row]));
  const battery = byMetric.get("battery_capacity_percent");
  const storage = byMetric.get("storage_free_gb");

  return {
    battery_warning_percent: Number(battery?.warning_min ?? 85),
    battery_critical_percent: Number(battery?.critical_below ?? 80),
    storage_warning_gb: Number(storage?.warning_min ?? 20),
    storage_critical_gb: Number(storage?.critical_below ?? 10),
  };
}

async function loadRules(supabase: SupabaseClient): Promise<RuleDefinition[]> {
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
    .neq("action_items.status", "archived")
    .order("updated_at", { ascending: false });

  if (error || !data) {
    return [];
  }

  return data
    .map((row: any) => ({
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
    }))
    .sort((left, right) => left.priority - right.priority);
}

async function loadGuides(supabase: SupabaseClient): Promise<unknown[]> {
  const { data } = await supabase
    .from("content_guides")
    .select("slug, category, title, summary, body, access_level, priority, min_ios_version, max_ios_version")
    .neq("status", "archived")
    .order("priority", { ascending: true });

  return data ?? [];
}
