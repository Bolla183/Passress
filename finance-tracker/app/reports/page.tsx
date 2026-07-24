import Link from "next/link";

const REPORTS = [
  { href: "/reports/profit-loss", label: "Profit & Loss", sublabel: "What you earned and spent this month" },
  { href: "/reports/balance-sheet", label: "Balance Sheet", sublabel: "What you own, owe, and are worth today" },
  { href: "/reports/cash-flow", label: "Cash Flow", sublabel: "Where your cash moved this month" },
];

export default function ReportsIndex() {
  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Reports</h1>
      <ul>
        {REPORTS.map((report) => (
          <li key={report.href} className="border-b border-hairline">
            <Link href={report.href} className="flex items-center justify-between py-4">
              <span>
                <span className="block text-sm">{report.label}</span>
                <span className="block text-xs text-muted">{report.sublabel}</span>
              </span>
              <span className="text-muted">→</span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
