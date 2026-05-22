"use client";

import { getFunctionsBaseUrl } from "@/lib/supabase";
import type { DeviceSnapshot, PublishedConfig, RulePreviewResult } from "@/lib/types";

async function parseJsonResponse<T>(response: Response): Promise<T> {
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    const message = typeof body?.error === "string" ? body.error : `Request failed: ${response.status}`;
    throw new Error(message);
  }

  return body as T;
}

export async function fetchPublishedConfig(): Promise<PublishedConfig> {
  const response = await fetch(`${getFunctionsBaseUrl()}/get-published-config`, {
    method: "GET",
    cache: "no-store",
  });

  return parseJsonResponse<PublishedConfig>(response);
}

export async function previewRules(
  accessToken: string,
  snapshot: DeviceSnapshot,
  useDraft: boolean,
): Promise<RulePreviewResult> {
  const response = await fetch(`${getFunctionsBaseUrl()}/preview-rules`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ snapshot, useDraft }),
  });

  return parseJsonResponse<RulePreviewResult>(response);
}

export async function publishConfig(accessToken: string): Promise<PublishedConfig> {
  const response = await fetch(`${getFunctionsBaseUrl()}/publish-config`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });

  return parseJsonResponse<PublishedConfig>(response);
}
