"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { formatDistanceToNow } from "date-fns";

export default function SyncButton() {
  const router = useRouter();
  const [syncing, setSyncing] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [lastSyncedAt, setLastSyncedAt] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetch("/api/sync/shopify")
      .then((r) => r.json())
      .then((body) => {
        if (!cancelled) setLastSyncedAt(body.lastSyncedAt ?? null);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, []);

  async function handleSync() {
    setSyncing(true);
    setMessage(null);

    const res = await fetch("/api/sync/shopify", { method: "POST" });
    const body = await res.json().catch(() => ({}));

    setSyncing(false);

    if (!res.ok) {
      setMessage(body.error || "Sync failed");
      return;
    }

    setMessage(`Synced ${body.created} new, ${body.updated} updated`);
    setLastSyncedAt(new Date().toISOString());
    router.refresh();
  }

  return (
    <div className="text-right">
      <button
        onClick={handleSync}
        disabled={syncing}
        className="text-xs uppercase tracking-widest text-muted underline disabled:opacity-50"
      >
        {syncing ? "Syncing..." : "Sync Shopify"}
      </button>
      <p className="mt-1 text-xs text-muted">
        {message ?? (lastSyncedAt ? `Last synced ${formatDistanceToNow(new Date(lastSyncedAt), { addSuffix: true })}` : "Not synced yet")}
      </p>
    </div>
  );
}
