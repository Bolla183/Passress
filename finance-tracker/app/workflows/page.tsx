import Link from "next/link";

const WORKFLOWS = [
  { href: "/workflows/bills", label: "Bills (Accounts Payable)" },
  { href: "/workflows/invoices", label: "Invoices (Accounts Receivable)" },
  { href: "/workflows/payroll", label: "Payroll" },
  { href: "/workflows/loans", label: "Loans" },
  { href: "/workflows/inventory", label: "Inventory" },
];

export default function WorkflowsIndex() {
  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Workflows</h1>
      <ul>
        {WORKFLOWS.map((w) => (
          <li key={w.href} className="border-b border-hairline">
            <Link href={w.href} className="flex items-center justify-between py-4 text-sm">
              {w.label}
              <span className="text-muted">→</span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
