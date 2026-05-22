export type RuleSurface = "todo" | "caution" | "solve" | "diagnosis";
export type RuleAccessLevel = "free" | "pro";
export type RuleOperator = "eq" | "neq" | "lt" | "lte" | "gt" | "gte" | "between" | "is_null" | "is_not_null" | "in";

export type DeviceSnapshot = Record<string, unknown> & {
  isPro?: boolean;
};

export type RuleCondition = {
  metric: string;
  operator_name?: RuleOperator;
  operator?: RuleOperator;
  value?: unknown;
};

export type RuleDefinition = {
  id: string;
  title: string;
  description: string;
  target_surface: RuleSurface;
  severity: string;
  cta_label?: string | null;
  action_type?: string | null;
  access_level: RuleAccessLevel;
  priority: number;
  is_active: boolean;
  conditions: RuleCondition[];
};

export type MatchedRules = {
  todoItems: RuleDefinition[];
  cautionItems: RuleDefinition[];
  solveItems: RuleDefinition[];
  diagnosisHints: RuleDefinition[];
};

export function evaluateRules(snapshot: DeviceSnapshot, rules: RuleDefinition[]): MatchedRules {
  const visibleRules = rules
    .filter((rule) => rule.is_active)
    .filter((rule) => rule.access_level === "free" || snapshot.isPro === true)
    .filter((rule) => rule.conditions.every((condition) => evaluateCondition(condition, snapshot)))
    .sort((left, right) => left.priority - right.priority);

  return {
    todoItems: visibleRules.filter((rule) => rule.target_surface === "todo"),
    cautionItems: visibleRules.filter((rule) => rule.target_surface === "caution"),
    solveItems: visibleRules.filter((rule) => rule.target_surface === "solve"),
    diagnosisHints: visibleRules.filter((rule) => rule.target_surface === "diagnosis"),
  };
}

function evaluateCondition(condition: RuleCondition, snapshot: DeviceSnapshot): boolean {
  const operator = condition.operator_name ?? condition.operator;
  const actual = snapshot[condition.metric];

  switch (operator) {
    case "is_null":
      return actual === null || actual === undefined;
    case "is_not_null":
      return actual !== null && actual !== undefined;
    case "eq":
      return actual === condition.value;
    case "neq":
      return actual !== condition.value;
    case "lt":
      return numeric(actual) < numeric(condition.value);
    case "lte":
      return numeric(actual) <= numeric(condition.value);
    case "gt":
      return numeric(actual) > numeric(condition.value);
    case "gte":
      return numeric(actual) >= numeric(condition.value);
    case "between": {
      const range = Array.isArray(condition.value) ? condition.value : [];
      return range.length >= 2 && numeric(actual) >= numeric(range[0]) && numeric(actual) <= numeric(range[1]);
    }
    case "in":
      return Array.isArray(condition.value) && condition.value.includes(actual);
    default:
      return false;
  }
}

function numeric(value: unknown): number {
  if (typeof value === "number") {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : Number.NaN;
  }

  return Number.NaN;
}
