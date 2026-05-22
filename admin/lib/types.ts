export type PublishedConfig = {
  version: number;
  published_at: string;
  ios: {
    latest_global_version: string;
    release_date: string | null;
    severity: "normal" | "warning" | "critical";
    message: string;
  };
  thresholds: {
    battery_warning_percent: number;
    battery_critical_percent: number;
    storage_warning_gb: number;
    storage_critical_gb: number;
  };
  rules: RuleDefinition[];
  guides: unknown[];
};

export type RuleDefinition = {
  id: string;
  title: string;
  description: string;
  target_surface: "todo" | "caution" | "solve" | "diagnosis";
  severity: string;
  cta_label?: string | null;
  action_type?: string | null;
  access_level: "free" | "pro";
  priority: number;
  is_active: boolean;
};

export type RulePreviewResult = {
  todoItems: RuleDefinition[];
  cautionItems: RuleDefinition[];
  solveItems: RuleDefinition[];
  diagnosisHints: RuleDefinition[];
};

export type DeviceSnapshot = {
  marketingName: string;
  iosVersion: string;
  storageFreeGB: number;
  storageTotalGB: number;
  batteryCapacityPercent?: number | null;
  firstUseMonths?: number | null;
  isPro: boolean;
};

export type IOSVersionDraft = {
  id: string;
  latest_version: string;
  release_date: string | null;
  severity: "normal" | "security" | "major";
  message: string;
  source_url: string | null;
  status: "draft" | "published" | "archived";
};

export type ThresholdDraft = {
  id: string;
  metric: string;
  label: string;
  good_min: number | null;
  warning_min: number | null;
  critical_below: number | null;
  unit: string | null;
  status: "draft" | "published" | "archived";
};
