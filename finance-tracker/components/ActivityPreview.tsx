import { formatEGP } from "@/lib/currency";
import type { ActivityItem } from "@/lib/accounting/activityFeed";

export default function ActivityPreview({ items }: { items: ActivityItem[] }) {
  return (
    <div className="mb-6">
      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Recent activity</p>
      {items.length === 0 ? (
        <p className="py-4 text-sm text-muted">Nothing recorded yet.</p>
      ) : (
        <div className="rounded-2xl border border-hairline bg-paper shadow-sm">
          {items.map((item, i) => (
            <div
              key={item.id}
              className={`flex items-center justify-between px-4 py-3 ${i !== items.length - 1 ? "border-b border-hairline" : ""}`}
            >
              <div className="min-w-0">
                <p className="truncate text-sm">{item.label}</p>
                {item.sublabel && <p className="truncate text-xs text-muted">{item.sublabel}</p>}
              </div>
              <span className={`ml-3 shrink-0 text-sm font-medium ${item.direction === "in" ? "text-income" : "text-expense"}`}>
                {item.direction === "in" ? "+" : "-"}
                {formatEGP(item.amount)}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
