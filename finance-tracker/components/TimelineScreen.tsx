"use client";

import { useState } from "react";
import Link from "next/link";
import { formatEGP } from "@/lib/currency";
import { dayLabel } from "@/lib/dates";
import type { ActivityCategory } from "@/lib/accounting/activityFeed";

type Item = {
  id: string;
  date: string;
  label: string;
  sublabel: string | null;
  amount: number;
  direction: "in" | "out";
  category: ActivityCategory;
  emoji: string;
};

const FILTERS: { id: ActivityCategory | "all"; label: string }[] = [
  { id: "all", label: "All" },
  { id: "expense", label: "Expenses" },
  { id: "revenue", label: "Revenue" },
  { id: "capital", label: "Capital" },
  { id: "payroll", label: "Payroll" },
];

export default function TimelineScreen({ items }: { items: Item[] }) {
  const [filter, setFilter] = useState<ActivityCategory | "all">("all");

  const filtered = filter === "all" ? items : items.filter((i) => i.category === filter);

  const groups: { label: string; items: Item[] }[] = [];
  for (const item of filtered) {
    const label = dayLabel(new Date(item.date));
    const lastGroup = groups[groups.length - 1];
    if (lastGroup && lastGroup.label === label) {
      lastGroup.items.push(item);
    } else {
      groups.push({ label, items: [item] });
    }
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-4 text-lg tracking-widest uppercase">Timeline</h1>

      <div className="mb-4 flex gap-2 overflow-x-auto pb-1">
        {FILTERS.map((f) => (
          <button
            key={f.id}
            onClick={() => setFilter(f.id)}
            className={`shrink-0 rounded-full border px-3 py-1.5 text-xs uppercase tracking-widest ${
              filter === f.id ? "border-ink bg-ink text-paper" : "border-hairline text-muted"
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {groups.length === 0 ? (
        <p className="py-10 text-center text-sm text-muted">Nothing here yet.</p>
      ) : (
        groups.map((group) => (
          <div key={group.label} className="mb-2">
            <p className="mb-1 mt-4 text-xs uppercase tracking-widest text-muted">{group.label}</p>
            <div className="rounded-2xl border border-hairline bg-paper shadow-sm">
              {group.items.map((item, i) => (
                <Link
                  key={item.id}
                  href={`/timeline/${item.id}`}
                  className={`flex items-center gap-3 px-4 py-3 ${
                    i !== group.items.length - 1 ? "border-b border-hairline" : ""
                  }`}
                >
                  <span className="w-7 shrink-0 text-center text-xl">{item.emoji}</span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm">{item.label}</p>
                    {item.sublabel && <p className="truncate text-xs text-muted">{item.sublabel}</p>}
                  </div>
                  <span
                    className={`shrink-0 text-sm font-medium ${item.direction === "in" ? "text-income" : "text-expense"}`}
                  >
                    {item.direction === "in" ? "+" : "-"}
                    {formatEGP(item.amount)}
                  </span>
                  <span className="shrink-0 text-hairline">›</span>
                </Link>
              ))}
            </div>
          </div>
        ))
      )}
    </div>
  );
}
