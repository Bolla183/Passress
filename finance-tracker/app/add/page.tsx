"use client";

import { useState } from "react";
import { INCOME_CATEGORIES, EXPENSE_CATEGORIES } from "@/lib/categories";
import { dateInputValue } from "@/lib/dates";
import { formatEGP } from "@/lib/currency";

type TxType = "INCOME" | "EXPENSE";

type AddedEntry = {
  id: string;
  type: TxType;
  category: string;
  amount: number;
  note: string | null;
};

export default function AddPage() {
  const [type, setType] = useState<TxType>("EXPENSE");
  const [category, setCategory] = useState<string>(EXPENSE_CATEGORIES[0]);
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  const [date, setDate] = useState(dateInputValue(new Date()));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [added, setAdded] = useState<AddedEntry[]>([]);

  const categories = type === "INCOME" ? INCOME_CATEGORIES : EXPENSE_CATEGORIES;

  function switchType(next: TxType) {
    setType(next);
    setCategory((next === "INCOME" ? INCOME_CATEGORIES : EXPENSE_CATEGORIES)[0]);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const numericAmount = Number(amount);
    if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
      setError("Enter a valid amount");
      return;
    }

    setSaving(true);
    const res = await fetch("/api/transactions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type, category, amount: numericAmount, date, note }),
    });
    setSaving(false);

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }

    const { transaction } = await res.json();
    setAdded((prev) => [
      {
        id: transaction.id,
        type: transaction.type,
        category: transaction.category,
        amount: transaction.amount,
        note: transaction.note,
      },
      ...prev,
    ]);
    setAmount("");
    setNote("");
  }

  async function handleDelete(id: string) {
    setAdded((prev) => prev.filter((entry) => entry.id !== id));
    await fetch(`/api/transactions/${id}`, { method: "DELETE" });
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Add entry</h1>

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
        </div>

        <div className="mb-6 grid grid-cols-2 gap-2">
          {categories.map((c) => (
            <button
              key={c}
              type="button"
              onClick={() => setCategory(c)}
              className={`border px-3 py-2 text-left text-sm ${
                category === c
                  ? "border-ink bg-ink text-paper"
                  : "border-hairline text-ink"
              }`}
            >
              {c}
            </button>
          ))}
        </div>

        <label className="mb-4 block">
          <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
            Amount (EGP)
          </span>
          <input
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
                      entry.type === "INCOME" ? "text-income" : "text-expense"
                    }`}
                  >
                    {entry.type === "INCOME" ? "+" : "-"}
                    {formatEGP(entry.amount)}
                  </span>
                  <button
                    onClick={() => handleDelete(entry.id)}
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
