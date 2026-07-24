"use client";

import { useEffect, useRef, useState } from "react";
import { dateInputValue } from "@/lib/dates";
import { formatEGP } from "@/lib/currency";
import SyncButton from "@/components/SyncButton";

type TxType = "INCOME" | "EXPENSE" | "CAPITAL";
type QuickAddAccount = { id: string; name: string; needsProduct?: boolean };
type Product = { id: string; name: string };

type AddedEntry = {
  id: string;
  type: TxType;
  category: string;
  amount: number;
  note: string | null;
};

type Snapshot = { income: number; expense: number; net: number };

const LAST_CATEGORY_KEY = (type: TxType) => `passress:lastCategory:${type}`;

export default function AddPage() {
  const [accounts, setAccounts] = useState<{ income: QuickAddAccount[]; expense: QuickAddAccount[] }>({
    income: [],
    expense: [],
  });
  const [products, setProducts] = useState<Product[]>([]);
  const [type, setType] = useState<TxType>("EXPENSE");
  const [accountId, setAccountId] = useState<string>("");
  const [productId, setProductId] = useState<string>("");
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  const [date, setDate] = useState(dateInputValue(new Date()));
  const [showDetails, setShowDetails] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [added, setAdded] = useState<AddedEntry[]>([]);
  const [snapshot, setSnapshot] = useState<{ today: Snapshot; month: Snapshot } | null>(null);
  const amountRef = useRef<HTMLInputElement>(null);

  function pickDefaultCategory(list: QuickAddAccount[], forType: TxType): string {
    const remembered = typeof window !== "undefined" ? localStorage.getItem(LAST_CATEGORY_KEY(forType)) : null;
    if (remembered && list.some((c) => c.id === remembered)) return remembered;
    return list[0]?.id ?? "";
  }

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const [accountsRes, snapshotRes] = await Promise.all([
        fetch("/api/accounts/quick-add"),
        fetch("/api/performance/snapshot"),
      ]);
      const accountsBody = await accountsRes.json();
      const snapshotBody = await snapshotRes.json();
      if (cancelled) return;
      setAccounts(accountsBody);
      setProducts(accountsBody.products ?? []);
      setAccountId(pickDefaultCategory(accountsBody.expense, "EXPENSE"));
      setSnapshot(snapshotBody);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, []);

  const categories = type === "INCOME" ? accounts.income : type === "EXPENSE" ? accounts.expense : [];
  const selectedCategory = categories.find((c) => c.id === accountId);
  const needsProduct = type === "EXPENSE" && Boolean(selectedCategory?.needsProduct);

  function switchType(next: TxType) {
    setType(next);
    setProductId("");
    if (next === "CAPITAL") {
      setAccountId("");
      return;
    }
    const list = next === "INCOME" ? accounts.income : accounts.expense;
    setAccountId(pickDefaultCategory(list, next));
  }

  function selectCategory(id: string) {
    setAccountId(id);
    setProductId("");
    localStorage.setItem(LAST_CATEGORY_KEY(type), id);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const numericAmount = Number(amount);
    if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
      setError("Enter a valid amount");
      return;
    }
    if (type !== "CAPITAL" && !accountId) {
      setError("Choose a category");
      return;
    }

    setSaving(true);
    const res =
      type === "CAPITAL"
        ? await fetch("/api/capital", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ amount: numericAmount, date, notes: note }),
          })
        : await fetch("/api/transactions", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ accountId, amount: numericAmount, date, note, productId: productId || undefined }),
          });
    setSaving(false);

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }

    const body = await res.json();
    const entry: AddedEntry =
      type === "CAPITAL"
        ? { id: body.entry.id, type: "CAPITAL", category: "Owner Capital", amount: numericAmount, note: note || null }
        : {
            id: body.transaction.id,
            type: body.transaction.type,
            category: body.transaction.category,
            amount: body.transaction.amount,
            note: body.transaction.note,
          };
    setAdded((prev) => [entry, ...prev]);
    setAmount("");
    setNote("");
    setProductId("");
    amountRef.current?.focus();

    fetch("/api/performance/snapshot")
      .then((r) => r.json())
      .then(setSnapshot)
      .catch(() => {});
  }

  async function handleDelete(entry: AddedEntry) {
    setAdded((prev) => prev.filter((e) => e.id !== entry.id));
    const url = entry.type === "CAPITAL" ? `/api/capital/${entry.id}` : `/api/transactions/${entry.id}`;
    await fetch(url, { method: "DELETE" });
    fetch("/api/performance/snapshot")
      .then((r) => r.json())
      .then(setSnapshot)
      .catch(() => {});
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-4 text-lg tracking-widest uppercase">Add entry</h1>

      {snapshot && (
        <div className="mb-6 flex border border-hairline text-center">
          <div className="flex-1 border-r border-hairline px-3 py-3">
            <p className="mb-1 text-xs uppercase tracking-widest text-muted">Today</p>
            <p className={`text-sm ${snapshot.today.net >= 0 ? "text-income" : "text-expense"}`}>
              {formatEGP(snapshot.today.net)}
            </p>
          </div>
          <div className="flex-1 px-3 py-3">
            <p className="mb-1 text-xs uppercase tracking-widest text-muted">This month</p>
            <p className={`text-sm ${snapshot.month.net >= 0 ? "text-income" : "text-expense"}`}>
              {formatEGP(snapshot.month.net)}
            </p>
          </div>
        </div>
      )}

      <div className="mb-6">
        <SyncButton />
      </div>

      <form onSubmit={handleSubmit}>
        <div className="mb-6 flex border border-hairline">
          <button
            type="button"
            onClick={() => switchType("EXPENSE")}
            className={`flex-1 py-3 text-sm uppercase tracking-widest ${
              type === "EXPENSE" ? "bg-ink text-paper" : "text-muted"
            }`}
          >
            Expense
          </button>
          <button
            type="button"
            onClick={() => switchType("INCOME")}
            className={`flex-1 py-3 text-sm uppercase tracking-widest ${
              type === "INCOME" ? "bg-ink text-paper" : "text-muted"
            }`}
          >
            Income
          </button>
          <button
            type="button"
            onClick={() => switchType("CAPITAL")}
            className={`flex-1 py-3 text-sm uppercase tracking-widest ${
              type === "CAPITAL" ? "bg-ink text-paper" : "text-muted"
            }`}
          >
            Capital
          </button>
        </div>

        {type === "CAPITAL" ? (
          <p className="mb-6 text-sm text-muted">
            Money you&apos;re putting into the business personally — this grows Capital Invested and Owner Equity on the Dashboard.
          </p>
        ) : (
          <div className="mb-6 grid grid-cols-2 gap-2">
            {categories.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => selectCategory(c.id)}
                className={`border px-3 py-2 text-left text-sm ${
                  accountId === c.id
                    ? "border-ink bg-ink text-paper"
                    : "border-hairline text-ink"
                }`}
              >
                {c.name}
              </button>
            ))}
            {categories.length === 0 && (
              <p className="col-span-2 text-sm text-muted">
                No categories yet — add one in Data → Chart of Accounts.
              </p>
            )}
          </div>
        )}

        {needsProduct && (
          <label className="mb-6 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
              Product (optional)
            </span>
            <select
              value={productId}
              onChange={(e) => setProductId(e.target.value)}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              <option value="">Not tied to one product</option>
              {products.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </label>
        )}

        <label className="mb-4 block">
          <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
            Amount (EGP)
          </span>
          <input
            ref={amountRef}
            type="number"
            inputMode="decimal"
            min="0"
            step="0.01"
            autoFocus
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0"
            className="w-full border-b border-hairline bg-transparent py-3 text-2xl outline-none focus:border-ink"
          />
        </label>

        {showDetails ? (
          <>
            <label className="mb-4 block">
              <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
                Date
              </span>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
              />
            </label>

            <label className="mb-6 block">
              <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
                Note (optional)
              </span>
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="e.g. Meta ads - July campaign"
                className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
              />
            </label>
          </>
        ) : (
          <button
            type="button"
            onClick={() => setShowDetails(true)}
            className="mb-6 text-xs uppercase tracking-widest text-muted underline"
          >
            + Date / note (today by default)
          </button>
        )}

        {error && <p className="mb-4 text-sm text-expense">{error}</p>}

        <button
          type="submit"
          disabled={saving}
          className="w-full bg-ink py-3 text-sm uppercase tracking-widest text-paper disabled:opacity-50"
        >
          {saving ? "Saving..." : "Save entry"}
        </button>
      </form>

      {added.length > 0 && (
        <div className="mt-10">
          <p className="mb-2 text-xs uppercase tracking-widest text-muted">
            Added just now
          </p>
          <ul>
            {added.map((entry) => (
              <li
                key={entry.id}
                className="flex items-center justify-between border-b border-hairline py-3"
              >
                <div>
                  <p className="text-sm">{entry.category}</p>
                  {entry.note && <p className="text-xs text-muted">{entry.note}</p>}
                </div>
                <div className="flex items-center gap-3">
                  <span
                    className={`text-sm ${
                      entry.type === "EXPENSE" ? "text-expense" : "text-income"
                    }`}
                  >
                    {entry.type === "EXPENSE" ? "-" : "+"}
                    {formatEGP(entry.amount)}
                  </span>
                  <button
                    onClick={() => handleDelete(entry)}
                    className="text-xs uppercase text-muted underline"
                  >
                    Undo
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
