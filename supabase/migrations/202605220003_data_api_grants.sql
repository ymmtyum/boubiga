-- Explicit Data API grants. RLS still controls row access for anon/authenticated roles.
-- service_role is used only by Edge Functions and local admin deployment tasks.

grant usage on schema public to anon, authenticated, service_role;

grant select on public.published_configs to anon, authenticated;

grant select, insert, update, delete on table
  public.admin_profiles,
  public.app_config_versions,
  public.os_versions,
  public.os_release_candidates,
  public.condition_thresholds,
  public.content_guides,
  public.action_items,
  public.rules,
  public.rule_conditions,
  public.published_configs,
  public.audit_logs
to authenticated;

grant all privileges on table
  public.admin_profiles,
  public.app_config_versions,
  public.os_versions,
  public.os_release_candidates,
  public.condition_thresholds,
  public.content_guides,
  public.action_items,
  public.rules,
  public.rule_conditions,
  public.published_configs,
  public.audit_logs
to service_role;
