import Link from "next/link";
import LogoutButton from "@/components/LogoutButton";

const SECTIONS: { title: string; links: { href: string; label: string }[] }[] = [
  {
    title: "Older dashboards",
    links: [
      { href: "/dashboard/daily", label: "Daily" },
      { href: "/dashboard/monthly", label: "Monthly" },
      { href: "/dashboard/trends", label: "Trends" },
    ],
  },
  {
    title: "Business workflows",
    links: [
      { href: "/payroll", label: "Payroll" },
      { href: "/workflows", label: "Bills, Invoices, Loans, Inventory" },
    ],
  },
  {
    title: "Master data",
    links: [{ href: "/data", label: "Suppliers, Bank Accounts, Employees, Products, Chart of Accounts..." }],
  },
  {
    title: "Advanced",
    links: [
      { href: "/reports/trial-balance", label: "Trial Balance" },
      { href: "/reports/general-ledger", label: "General Ledger" },
    ],
  },
];

export default function MoreIndex() {
  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">More</h1>
      {SECTIONS.map((section) => (
        <div key={section.title} className="mb-8">
          <p className="mb-2 text-xs uppercase tracking-widest text-muted">{section.title}</p>
          <ul>
            {section.links.map((link) => (
              <li key={link.href} className="border-b border-hairline">
                <Link href={link.href} className="flex items-center justify-between py-4 text-sm">
                  {link.label}
                  <span className="text-muted">→</span>
                </Link>
              </li>
            ))}
          </ul>
        </div>
      ))}
      <div className="mb-8 border-t border-hairline">
        <LogoutButton />
      </div>
    </div>
  );
}
