import Link from "next/link";
import { getActivityDetail } from "@/lib/accounting/activityFeed";
import { formatEGP } from "@/lib/currency";

export const dynamic = "force-dynamic";

export default async function TimelineDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const entry = await getActivityDetail(id);

  if (!entry) {
    return <div className="mx-auto max-w-lg px-6 pt-10 text-sm text-muted">Entry not found.</div>;
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <Link href="/timeline" className="mb-6 inline-block text-sm text-muted">
        ‹ Timeline
      </Link>

      <div className="mb-8 text-center">
        <p className="mb-2 text-3xl">{entry.emoji}</p>
        <p className={`text-3xl font-semibold tabular-nums ${entry.direction === "in" ? "text-income" : "text-expense"}`}>
          {entry.direction === "in" ? "+" : "-"}
          {formatEGP(entry.amount)}
        </p>
        <p className="mt-2 text-sm text-muted">{entry.label}</p>
      </div>

      <div className="border-t border-hairline">
        <Row label="Date" value={new Date(entry.date).toLocaleDateString("en-GB", { timeZone: "Africa/Cairo" })} />
        {entry.categoryName && <Row label="Category" value={entry.categoryName} />}
        {entry.supplier && <Row label="Supplier" value={entry.supplier} />}
        {entry.employee && <Row label="Employee" value={entry.employee} />}
        {entry.customer && <Row label="Customer" value={entry.customer} />}
        {entry.memo && <Row label="Note" value={entry.memo} />}
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between border-b border-hairline py-3 text-sm">
      <span className="text-muted">{label}</span>
      <span>{value}</span>
    </div>
  );
}
