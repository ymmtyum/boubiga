-- Initial boubiga content matching boubiga/bundled_app_config.json.

insert into public.os_versions (
  platform,
  latest_version,
  release_date,
  severity,
  message,
  status
) values (
  'ios',
  '26.5',
  '2026-05-11',
  'normal',
  '利用できるアップデートがある可能性があります。設定アプリから確認しましょう。',
  'published'
) on conflict do nothing;

insert into public.condition_thresholds (metric, label, good_min, warning_min, critical_below, unit, status)
values
  ('battery_capacity_percent', 'バッテリー最大容量', 85, 80, 80, '%', 'published'),
  ('storage_free_gb', '空き容量', 20, 20, 10, 'GB', 'published')
on conflict (metric) do update set
  label = excluded.label,
  good_min = excluded.good_min,
  warning_min = excluded.warning_min,
  critical_below = excluded.critical_below,
  unit = excluded.unit,
  status = excluded.status,
  updated_at = now();

insert into public.content_guides (slug, category, title, summary, body, access_level, priority, status)
values
  (
    'battery_condition_screenshot',
    'battery',
    'バッテリー状態のスクショを追加する',
    '設定アプリのバッテリー画面から最大容量を確認します。',
    '設定アプリを開き、バッテリー > バッテリーの状態へ進み、スクリーンショットを追加します。',
    'free',
    10,
    'published'
  ),
  (
    'storage_cleanup_basic',
    'storage',
    '容量を減らす基本チェック',
    '写真・動画・アプリデータから確認します。',
    '写真や動画、使っていないアプリ、大きな添付ファイルを順番に確認します。',
    'free',
    20,
    'published'
  ),
  (
    'battery_replacement_compare',
    'battery',
    'バッテリー交換と買い替えを比較する',
    '最大容量が低い場合は、交換費用と買い替えを並べて見ます。',
    '最大容量、使用期間、参考買取価格を見ながら、交換する場合と買い替える場合を比較します。',
    'free',
    30,
    'published'
  )
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  summary = excluded.summary,
  body = excluded.body,
  access_level = excluded.access_level,
  priority = excluded.priority,
  status = excluded.status,
  updated_at = now();

insert into public.action_items (
  slug,
  title,
  description,
  category,
  target_surface,
  severity,
  cta_label,
  action_type,
  guide_slug,
  access_level,
  priority,
  status
) values
  (
    'battery-unchecked',
    'バッテリー最大容量を確認する',
    '設定アプリのバッテリー画面スクショを追加すると、より正確に状態を見られます。',
    'battery',
    'todo',
    'info',
    'スクショを追加',
    'battery_ocr',
    'battery_condition_screenshot',
    'free',
    10,
    'published'
  ),
  (
    'storage-low',
    '空き容量を少し整理する',
    '空き容量が少ないため、写真や動画の整理が買い替え判断の材料になります。',
    'storage',
    'caution',
    'warning',
    '容量を確認',
    'storage_guide',
    'storage_cleanup_basic',
    'free',
    20,
    'published'
  ),
  (
    'battery-replacement-candidate',
    'バッテリー交換も比較する',
    '最大容量が80%未満なら、買い替えだけでなく交換費用も並べて見ましょう。',
    'battery',
    'solve',
    'warning',
    '交換と買い替えを比較',
    'battery_compare',
    'battery_replacement_compare',
    'free',
    30,
    'published'
  )
on conflict (slug) do update set
  title = excluded.title,
  description = excluded.description,
  category = excluded.category,
  target_surface = excluded.target_surface,
  severity = excluded.severity,
  cta_label = excluded.cta_label,
  action_type = excluded.action_type,
  guide_slug = excluded.guide_slug,
  access_level = excluded.access_level,
  priority = excluded.priority,
  status = excluded.status,
  updated_at = now();

insert into public.rules (slug, name, action_item_id, match_type, is_active, status)
select
  ai.slug,
  ai.title,
  ai.id,
  'all',
  true,
  'published'
from public.action_items ai
where ai.slug in ('battery-unchecked', 'storage-low', 'battery-replacement-candidate')
on conflict (slug) do update set
  name = excluded.name,
  action_item_id = excluded.action_item_id,
  match_type = excluded.match_type,
  is_active = excluded.is_active,
  status = excluded.status,
  updated_at = now();

delete from public.rule_conditions
where rule_id in (
  select id from public.rules
  where slug in ('battery-unchecked', 'storage-low', 'battery-replacement-candidate')
);

insert into public.rule_conditions (rule_id, metric, operator, value_json)
select id, 'battery_capacity_percent', 'is_null', null
from public.rules
where slug = 'battery-unchecked';

insert into public.rule_conditions (rule_id, metric, operator, value_json)
select id, 'storage_free_gb', 'lte', '{"value":10}'::jsonb
from public.rules
where slug = 'storage-low';

insert into public.rule_conditions (rule_id, metric, operator, value_json)
select id, 'battery_capacity_percent', 'lt', '{"value":80}'::jsonb
from public.rules
where slug = 'battery-replacement-candidate';

insert into public.published_configs (version_number, config_json, is_current)
values (
  1,
  '{
    "version": 1,
    "published_at": "2026-05-22T00:00:00Z",
    "ios": {
      "latest_global_version": "26.5",
      "release_date": "2026-05-11",
      "severity": "normal",
      "message": "利用できるアップデートがある可能性があります。設定アプリから確認しましょう。"
    },
    "thresholds": {
      "battery_warning_percent": 85,
      "battery_critical_percent": 80,
      "storage_warning_gb": 20,
      "storage_critical_gb": 10
    },
    "rules": [
      {
        "id": "battery-unchecked",
        "title": "バッテリー最大容量を確認する",
        "description": "設定アプリのバッテリー画面スクショを追加すると、より正確に状態を見られます。",
        "target_surface": "todo",
        "severity": "info",
        "cta_label": "スクショを追加",
        "action_type": "battery_ocr",
        "access_level": "free",
        "priority": 10,
        "is_active": true,
        "conditions": [
          { "metric": "battery_capacity_percent", "operator_name": "is_null", "value": null }
        ]
      },
      {
        "id": "storage-low",
        "title": "空き容量を少し整理する",
        "description": "空き容量が少ないため、写真や動画の整理が買い替え判断の材料になります。",
        "target_surface": "caution",
        "severity": "warning",
        "cta_label": "容量を確認",
        "action_type": "storage_guide",
        "access_level": "free",
        "priority": 20,
        "is_active": true,
        "conditions": [
          { "metric": "storage_free_gb", "operator_name": "lte", "value": 10 }
        ]
      },
      {
        "id": "battery-replacement-candidate",
        "title": "バッテリー交換も比較する",
        "description": "最大容量が80%未満なら、買い替えだけでなく交換費用も並べて見ましょう。",
        "target_surface": "solve",
        "severity": "warning",
        "cta_label": "交換と買い替えを比較",
        "action_type": "battery_compare",
        "access_level": "free",
        "priority": 30,
        "is_active": true,
        "conditions": [
          { "metric": "battery_capacity_percent", "operator_name": "lt", "value": 80 }
        ]
      }
    ]
  }'::jsonb,
  true
)
on conflict (version_number) do update set
  config_json = excluded.config_json,
  is_current = excluded.is_current,
  published_at = now();
