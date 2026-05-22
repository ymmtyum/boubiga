"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { fetchIOSVersionDraft, fetchThresholdDrafts, updateIOSVersionDraft, updateThresholdDraft } from "@/lib/cms";
import { fetchPublishedConfig, previewRules, publishConfig } from "@/lib/functions";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import type {
  DeviceSnapshot,
  IOSVersionDraft,
  PublishedConfig,
  RuleDefinition,
  RulePreviewResult,
  ThresholdDraft,
} from "@/lib/types";

const initialSnapshot: DeviceSnapshot = {
  marketingName: "iPhone 16 Pro",
  iosVersion: "26.4",
  storageFreeGB: 8,
  storageTotalGB: 256,
  batteryCapacityPercent: 82,
  firstUseMonths: 18,
  isPro: false,
};

export function AdminClient() {
  const [session, setSession] = useState<Session | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isSigningIn, setIsSigningIn] = useState(false);
  const [isSendingLink, setIsSendingLink] = useState(false);
  const [isLoadingConfig, setIsLoadingConfig] = useState(false);
  const [isSavingDraft, setIsSavingDraft] = useState(false);
  const [isPreviewing, setIsPreviewing] = useState(false);
  const [isPublishing, setIsPublishing] = useState(false);
  const [useDraft, setUseDraft] = useState(true);
  const [snapshot, setSnapshot] = useState<DeviceSnapshot>(initialSnapshot);
  const [publishedConfig, setPublishedConfig] = useState<PublishedConfig | null>(null);
  const [iosDraft, setIOSDraft] = useState<IOSVersionDraft | null>(null);
  const [thresholdDrafts, setThresholdDrafts] = useState<ThresholdDraft[]>([]);
  const [previewResult, setPreviewResult] = useState<RulePreviewResult | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const accessToken = session?.access_token ?? "";
  const signedInEmail = session?.user.email ?? "";
  const canUseAdminActions = Boolean(accessToken);

  useEffect(() => {
    if (!hasSupabaseConfig) return;

    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
    });

    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
    });

    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!hasSupabaseConfig) return;
    void loadPublishedConfig();
  }, []);

  useEffect(() => {
    if (!session) return;
    void loadDraftSettings();
  }, [session]);

  const previewCounts = useMemo(() => {
    if (!previewResult) return null;
    return {
      todo: previewResult.todoItems.length,
      caution: previewResult.cautionItems.length,
      solve: previewResult.solveItems.length,
      diagnosis: previewResult.diagnosisHints.length,
    };
  }, [previewResult]);

  async function loadPublishedConfig() {
    setIsLoadingConfig(true);
    setError(null);
    try {
      const config = await fetchPublishedConfig();
      setPublishedConfig(config);
    } catch (nextError) {
      setError(errorMessage(nextError));
    } finally {
      setIsLoadingConfig(false);
    }
  }

  async function loadDraftSettings() {
    setError(null);
    try {
      const [nextIOSDraft, nextThresholds] = await Promise.all([
        fetchIOSVersionDraft(),
        fetchThresholdDrafts(),
      ]);
      setIOSDraft(nextIOSDraft);
      setThresholdDrafts(nextThresholds);
    } catch (nextError) {
      setError(errorMessage(nextError));
    }
  }

  async function handleSaveDraftSettings() {
    if (!iosDraft) return;
    setIsSavingDraft(true);
    setError(null);
    setMessage(null);
    try {
      const [savedIOSDraft, savedThresholds] = await Promise.all([
        updateIOSVersionDraft(iosDraft),
        Promise.all(thresholdDrafts.map((threshold) => updateThresholdDraft(threshold))),
      ]);
      setIOSDraft(savedIOSDraft);
      setThresholdDrafts(savedThresholds);
      setMessage("下書きを保存しました。公開するまではアプリには反映されません。");
    } catch (nextError) {
      setError(errorMessage(nextError));
    } finally {
      setIsSavingDraft(false);
    }
  }

  async function handleSignIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSigningIn(true);
    setError(null);
    setMessage(null);
    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
      if (signInError) throw signInError;
      setPassword("");
      setMessage("ログインしました。");
    } catch (nextError) {
      setError(errorMessage(nextError));
    } finally {
      setIsSigningIn(false);
    }
  }

  async function handleSendLoginLink() {
    if (!email) {
      setError("メールアドレスを入力してください。");
      return;
    }

    setIsSendingLink(true);
    setError(null);
    setMessage(null);
    try {
      const { error: otpError } = await supabase.auth.signInWithOtp({
        email,
        options: {
          emailRedirectTo: window.location.origin,
        },
      });
      if (otpError) throw otpError;
      setMessage("ログインリンクを送信しました。メール内のリンクから開いてください。");
    } catch (nextError) {
      setError(errorMessage(nextError));
    } finally {
      setIsSendingLink(false);
    }
  }

  async function handleSignOut() {
    await supabase.auth.signOut();
    setPreviewResult(null);
    setMessage("ログアウトしました。");
  }

  async function handlePreview() {
    if (!accessToken) return;
    setIsPreviewing(true);
    setError(null);
    setMessage(null);
    try {
      const result = await previewRules(accessToken, snapshot, useDraft);
      setPreviewResult(result);
      setMessage("プレビューを更新しました。");
    } catch (nextError) {
      setError(errorMessage(nextError));
    } finally {
      setIsPreviewing(false);
    }
  }

  async function handlePublish() {
    if (!accessToken) return;
    setIsPublishing(true);
    setError(null);
    setMessage(null);
    try {
      const config = await publishConfig(accessToken);
      setPublishedConfig(config);
      setMessage(`version ${config.version} を公開しました。`);
    } catch (nextError) {
      setError(errorMessage(nextError));
    } finally {
      setIsPublishing(false);
    }
  }

  function updateSnapshotNumber(key: keyof DeviceSnapshot, value: string) {
    const parsed = value === "" ? null : Number(value);
    setSnapshot((current) => ({ ...current, [key]: parsed }));
  }

  function updateThreshold(metric: string, patch: Partial<ThresholdDraft>) {
    setThresholdDrafts((current) =>
      current.map((threshold) => (threshold.metric === metric ? { ...threshold, ...patch } : threshold)),
    );
  }

  function updateThresholdNumber(metric: string, key: keyof ThresholdDraft, value: string) {
    updateThreshold(metric, { [key]: value === "" ? null : Number(value) });
  }

  if (!hasSupabaseConfig) {
    return (
      <main className="page-shell">
        <section className="setup-panel">
          <p className="eyebrow">boubiga Admin</p>
          <h1>Supabase接続設定が必要です</h1>
          <p>
            `admin/.env.local` に `NEXT_PUBLIC_SUPABASE_URL` と
            `NEXT_PUBLIC_SUPABASE_ANON_KEY` を設定してから起動してください。
          </p>
        </section>
      </main>
    );
  }

  return (
    <main className="page-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">boubiga Admin</p>
          <h1>配信設定</h1>
        </div>
        {session ? (
          <div className="account-box">
            <span>{signedInEmail}</span>
            <button className="button secondary" type="button" onClick={handleSignOut}>
              ログアウト
            </button>
          </div>
        ) : null}
      </header>

      <StatusMessage message={message} error={error} />

      {!session ? (
        <section className="panel narrow-panel">
          <h2>管理者ログイン</h2>
          <form className="form-grid" onSubmit={handleSignIn}>
            <label>
              メール
              <input
                autoComplete="email"
                inputMode="email"
                onChange={(event) => setEmail(event.target.value)}
                required
                type="email"
                value={email}
              />
            </label>
            <label>
              パスワード
              <input
                autoComplete="current-password"
                onChange={(event) => setPassword(event.target.value)}
                required
                type="password"
                value={password}
              />
            </label>
            <button className="button" disabled={isSigningIn} type="submit">
              {isSigningIn ? "ログイン中" : "ログイン"}
            </button>
            <button
              className="button secondary"
              disabled={isSendingLink}
              type="button"
              onClick={handleSendLoginLink}
            >
              {isSendingLink ? "送信中" : "メールでログインリンクを送る"}
            </button>
          </form>
        </section>
      ) : (
        <div className="workspace">
          <section className="panel">
            <div className="section-heading">
              <div>
                <h2>公開中の設定</h2>
                <p>アプリが取得するJSONの現在値です。</p>
              </div>
              <button className="button secondary" disabled={isLoadingConfig} type="button" onClick={loadPublishedConfig}>
                {isLoadingConfig ? "更新中" : "再読み込み"}
              </button>
            </div>
            {publishedConfig ? <PublishedConfigSummary config={publishedConfig} /> : <p className="muted">未取得です。</p>}
          </section>

          <section className="panel">
            <div className="section-heading">
              <div>
                <h2>下書き設定</h2>
                <p>最新iOSと判定しきい値を編集します。保存後に公開するとアプリへ反映されます。</p>
              </div>
              <button
                className="button"
                disabled={!iosDraft || isSavingDraft}
                type="button"
                onClick={handleSaveDraftSettings}
              >
                {isSavingDraft ? "保存中" : "下書きを保存"}
              </button>
            </div>

            {iosDraft ? (
              <div className="draft-grid">
                <label>
                  最新iOS
                  <input
                    onChange={(event) =>
                      setIOSDraft((current) =>
                        current ? { ...current, latest_version: event.target.value } : current,
                      )
                    }
                    value={iosDraft.latest_version}
                  />
                </label>
                <label>
                  リリース日
                  <input
                    onChange={(event) =>
                      setIOSDraft((current) =>
                        current ? { ...current, release_date: event.target.value || null } : current,
                      )
                    }
                    type="date"
                    value={iosDraft.release_date ?? ""}
                  />
                </label>
                <label>
                  重要度
                  <select
                    onChange={(event) =>
                      setIOSDraft((current) =>
                        current
                          ? { ...current, severity: event.target.value as IOSVersionDraft["severity"] }
                          : current,
                      )
                    }
                    value={iosDraft.severity}
                  >
                    <option value="normal">normal</option>
                    <option value="security">security</option>
                    <option value="major">major</option>
                  </select>
                </label>
                <label className="wide-field">
                  メッセージ
                  <textarea
                    onChange={(event) =>
                      setIOSDraft((current) => (current ? { ...current, message: event.target.value } : current))
                    }
                    rows={3}
                    value={iosDraft.message}
                  />
                </label>
                <label className="wide-field">
                  出典URL
                  <input
                    onChange={(event) =>
                      setIOSDraft((current) =>
                        current ? { ...current, source_url: event.target.value || null } : current,
                      )
                    }
                    type="url"
                    value={iosDraft.source_url ?? ""}
                  />
                </label>
              </div>
            ) : (
              <p className="muted">下書き設定を取得できませんでした。</p>
            )}

            {thresholdDrafts.length ? (
              <div className="threshold-table">
                <div className="threshold-row header">
                  <span>項目</span>
                  <span>良好</span>
                  <span>警告</span>
                  <span>危険</span>
                  <span>単位</span>
                </div>
                {thresholdDrafts.map((threshold) => (
                  <div className="threshold-row" key={threshold.id}>
                    <strong>{threshold.label}</strong>
                    <input
                      onChange={(event) => updateThresholdNumber(threshold.metric, "good_min", event.target.value)}
                      type="number"
                      value={threshold.good_min ?? ""}
                    />
                    <input
                      onChange={(event) => updateThresholdNumber(threshold.metric, "warning_min", event.target.value)}
                      type="number"
                      value={threshold.warning_min ?? ""}
                    />
                    <input
                      onChange={(event) =>
                        updateThresholdNumber(threshold.metric, "critical_below", event.target.value)
                      }
                      type="number"
                      value={threshold.critical_below ?? ""}
                    />
                    <input
                      onChange={(event) => updateThreshold(threshold.metric, { unit: event.target.value || null })}
                      value={threshold.unit ?? ""}
                    />
                  </div>
                ))}
              </div>
            ) : null}
          </section>

          <section className="panel">
            <div className="section-heading">
              <div>
                <h2>ルールプレビュー</h2>
                <p>端末状態を変えて、やることリストや注意表示を確認します。</p>
              </div>
              <label className="toggle">
                <input checked={useDraft} onChange={(event) => setUseDraft(event.target.checked)} type="checkbox" />
                下書きを使う
              </label>
            </div>

            <div className="snapshot-grid">
              <label>
                機種名
                <input
                  onChange={(event) => setSnapshot((current) => ({ ...current, marketingName: event.target.value }))}
                  value={snapshot.marketingName}
                />
              </label>
              <label>
                iOS
                <input
                  onChange={(event) => setSnapshot((current) => ({ ...current, iosVersion: event.target.value }))}
                  value={snapshot.iosVersion}
                />
              </label>
              <label>
                空き容量 GB
                <input
                  min="0"
                  onChange={(event) => updateSnapshotNumber("storageFreeGB", event.target.value)}
                  type="number"
                  value={snapshot.storageFreeGB}
                />
              </label>
              <label>
                全容量 GB
                <input
                  min="0"
                  onChange={(event) => updateSnapshotNumber("storageTotalGB", event.target.value)}
                  type="number"
                  value={snapshot.storageTotalGB}
                />
              </label>
              <label>
                バッテリー %
                <input
                  min="0"
                  max="100"
                  onChange={(event) => updateSnapshotNumber("batteryCapacityPercent", event.target.value)}
                  type="number"
                  value={snapshot.batteryCapacityPercent ?? ""}
                />
              </label>
              <label>
                使用月数
                <input
                  min="0"
                  onChange={(event) => updateSnapshotNumber("firstUseMonths", event.target.value)}
                  type="number"
                  value={snapshot.firstUseMonths ?? ""}
                />
              </label>
            </div>

            <div className="actions">
              <button className="button" disabled={!canUseAdminActions || isPreviewing} type="button" onClick={handlePreview}>
                {isPreviewing ? "確認中" : "プレビュー"}
              </button>
            </div>

            {previewCounts ? (
              <div className="result-strip">
                <span>やること {previewCounts.todo}</span>
                <span>注意 {previewCounts.caution}</span>
                <span>解決 {previewCounts.solve}</span>
                <span>診断 {previewCounts.diagnosis}</span>
              </div>
            ) : null}

            {previewResult ? <PreviewResult result={previewResult} /> : null}
          </section>

          <section className="panel publish-panel">
            <div>
              <h2>公開</h2>
              <p>現在のDB内容から新しい公開JSONを作成します。</p>
            </div>
            <button className="button danger" disabled={!canUseAdminActions || isPublishing} type="button" onClick={handlePublish}>
              {isPublishing ? "公開中" : "公開する"}
            </button>
          </section>
        </div>
      )}
    </main>
  );
}

function PublishedConfigSummary({ config }: { config: PublishedConfig }) {
  return (
    <dl className="summary-grid">
      <div>
        <dt>version</dt>
        <dd>{config.version}</dd>
      </div>
      <div>
        <dt>公開日時</dt>
        <dd>{formatDate(config.published_at)}</dd>
      </div>
      <div>
        <dt>最新iOS</dt>
        <dd>{config.ios.latest_global_version}</dd>
      </div>
      <div>
        <dt>ルール</dt>
        <dd>{config.rules.length}</dd>
      </div>
      <div>
        <dt>バッテリー警告</dt>
        <dd>{config.thresholds.battery_warning_percent}%</dd>
      </div>
      <div>
        <dt>容量警告</dt>
        <dd>{config.thresholds.storage_warning_gb}GB</dd>
      </div>
    </dl>
  );
}

function PreviewResult({ result }: { result: RulePreviewResult }) {
  return (
    <div className="preview-grid">
      <RuleList title="やること" rules={result.todoItems} />
      <RuleList title="注意" rules={result.cautionItems} />
      <RuleList title="解決" rules={result.solveItems} />
      <RuleList title="診断" rules={result.diagnosisHints} />
    </div>
  );
}

function RuleList({ title, rules }: { title: string; rules: RuleDefinition[] }) {
  return (
    <section className="rule-list">
      <h3>{title}</h3>
      {rules.length === 0 ? (
        <p className="muted">該当なし</p>
      ) : (
        <ul>
          {rules.map((rule) => (
            <li key={rule.id}>
              <div>
                <strong>{rule.title}</strong>
                <p>{rule.description}</p>
              </div>
              <span>{rule.severity}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function StatusMessage({ message, error }: { message: string | null; error: string | null }) {
  if (!message && !error) return null;

  return (
    <div className={error ? "status error" : "status"}>
      {error ?? message}
    </div>
  );
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return "処理に失敗しました。";
}

function formatDate(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("ja-JP", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}
