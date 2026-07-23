import { formatEGP } from "@/lib/currency";

export default function SummaryCards({
  income,
  expense,
}: {
  income: number;
  expense: number;
}) {
  const net = income - expense;

  return (
    <div className="mb-8 grid grid-cols-3 divide-x divide-hairline border border-hairline">
      <div className="px-3 py-4 text-center">
        <p className="mb-1 text-xs uppercase tracking-widest text-muted">Income</p>
        <p className="text-income text-sm sm:text-base">{formatEGP(income)}</p>
      </div>
      <div className="px-3 py-4 text-center">
        <p className="mb-1 text-xs uppercase tracking-widest text-muted">Expense</p>
        <p className="text-expense text-sm sm:text-base">{formatEGP(expense)}</p>
      </div>
      <div className="px-3 py-4 text-center">
        <p className="mb-1 text-xs uppercase tracking-widest text-muted">Net</p>
        <p className={`text-sm sm:text-base ${net >= 0 ? "text-income" : "text-expense"}`}>
          {formatEGP(net)}
        </p>
      </div>
    </div>
  );
}
