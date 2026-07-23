import Link from "next/link";

const REPORTS = [
  { href: "/reports/trial-balance", label: "Trial Balance" },
  { href: "/reports/general-ledger", label: "General Ledger" },
  { href: "/reports/profit-loss", label: "Profit & Loss" },
  { href: "/reports/balance-sheet", label: "Balance Sheet" },
  { href: "/reports/cash-flow", label: "Cash Flow Statement" },
];

export default function ReportsIndex() {
  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Reports</h1>
      <ul>
        {REPORTS.map((report) => (
          <li key={report.href} className="border-b border-hairline">
            <Link href={report.href} className="flex items-center justify-between py-4 text-sm">
              {report.label}
              <span className="text-muted">→</span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
