import { formatEGP } from "@/lib/currency";

export default function MonthCard({
  revenue,
  expense,
  profit,
}: {
  revenue: number;
  expense: number;
  profit: number;
}) {
  return (
    <div className="mb-6 rounded-2xl border border-hairline bg-paper p-5 shadow-sm">
      <p className="mb-3 text-xs uppercase tracking-widest text-muted">This Month</p>
      <div className="mb-1.5 flex items-center justify-between text-sm">
        <span className="text-muted">Revenue</span>
        <span className="font-medium text-income">{formatEGP(revenue)}</span>
      </div>
      <div className="mb-1.5 flex items-center justify-between text-sm">
        <span className="text-muted">Expenses</span>
        <span className="font-medium text-expense">{formatEGP(expense)}</span>
      </div>
      <div className={`flex items-center justify-between border-t border-hairline pt-2 text-sm font-semibold`}>
        <span>Profit so far</span>
        <span className={profit >= 0 ? "text-income" : "text-expense"}>{formatEGP(profit)}</span>
      </div>
    </div>
  );
}
