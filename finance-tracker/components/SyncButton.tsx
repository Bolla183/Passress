"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function SyncButton() {
  const router = useRouter();
  const [syncing, setSyncing] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

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
      {message && <p className="mt-1 text-xs text-muted">{message}</p>}
    </div>
  );
}
