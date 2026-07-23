"use client";

import { useRouter } from "next/navigation";
import { formatEGP } from "@/lib/currency";

export type TransactionListItem = {
  id: string;
  type: "INCOME" | "EXPENSE";
  category: string;
  amount: number;
  note: string | null;
  date: string;
  source: "MANUAL" | "SHOPIFY";
};

export default function TransactionList({
  transactions,
}: {
  transactions: TransactionListItem[];
}) {
  const router = useRouter();

  async function handleDelete(id: string) {
    await fetch(`/api/transactions/${id}`, { method: "DELETE" });
    router.refresh();
  }

  if (transactions.length === 0) {
    return <p className="py-6 text-sm text-muted">No entries yet.</p>;
  }

  return (
    <ul>
      {transactions.map((t) => (
        <li
          key={t.id}
          className="flex items-center justify-between border-b border-hairline py-3"
        >
          <div>
            <p className="text-sm">{t.category}</p>
            <p className="text-xs text-muted">
              {t.note ? `${t.note} · ` : ""}
              {new Date(t.date).toLocaleDateString("en-GB", { timeZone: "UTC" })}
              {t.source === "SHOPIFY" ? " · Shopify" : ""}
            </p>
          </div>
          <div className="flex items-center gap-3">
            <span
              className={`text-sm ${t.type === "INCOME" ? "text-income" : "text-expense"}`}
            >
              {t.type === "INCOME" ? "+" : "-"}
              {formatEGP(t.amount)}
            </span>
            <button
              onClick={() => handleDelete(t.id)}
              aria-label="Delete entry"
              className="text-xs uppercase text-muted underline"
            >
              Delete
            </button>
          </div>
        </li>
      ))}
    </ul>
  );
}
