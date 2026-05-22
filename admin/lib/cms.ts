"use client";

import { supabase } from "@/lib/supabase";
import type { IOSVersionDraft, ThresholdDraft } from "@/lib/types";

export async function fetchIOSVersionDraft(): Promise<IOSVersionDraft | null> {
  const { data, error } = await supabase
    .from("os_versions")
    .select("id, latest_version, release_date, severity, message, source_url, status")
    .eq("platform", "ios")
    .neq("status", "archived")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data as IOSVersionDraft | null;
}

export async function updateIOSVersionDraft(draft: IOSVersionDraft): Promise<IOSVersionDraft> {
  const { data, error } = await supabase
    .from("os_versions")
    .update({
      latest_version: draft.latest_version,
      release_date: draft.release_date || null,
      severity: draft.severity,
      message: draft.message,
      source_url: draft.source_url || null,
      status: draft.status,
    })
    .eq("id", draft.id)
    .select("id, latest_version, release_date, severity, message, source_url, status")
    .single();

  if (error) throw error;
  return data as IOSVersionDraft;
}

export async function fetchThresholdDrafts(): Promise<ThresholdDraft[]> {
  const { data, error } = await supabase
    .from("condition_thresholds")
    .select("id, metric, label, good_min, warning_min, critical_below, unit, status")
    .in("metric", ["battery_capacity_percent", "storage_free_gb"])
    .neq("status", "archived")
    .order("metric", { ascending: true });

  if (error) throw error;
  return (data ?? []) as ThresholdDraft[];
}

export async function updateThresholdDraft(draft: ThresholdDraft): Promise<ThresholdDraft> {
  const { data, error } = await supabase
    .from("condition_thresholds")
    .update({
      label: draft.label,
      good_min: draft.good_min,
      warning_min: draft.warning_min,
      critical_below: draft.critical_below,
      unit: draft.unit,
      status: draft.status,
    })
    .eq("id", draft.id)
    .select("id, metric, label, good_min, warning_min, critical_below, unit, status")
    .single();

  if (error) throw error;
  return data as ThresholdDraft;
}
