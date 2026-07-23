import Link from "next/link";

const ENTITIES = [
  { href: "/data/chart-of-accounts", label: "Chart of Accounts", ready: true },
  { href: "/data/suppliers", label: "Suppliers", ready: true },
  { href: "/data/bank-accounts", label: "Bank Accounts", ready: true },
  { href: "/data/employees", label: "Employees", ready: true },
  { href: "/data/customers", label: "Customers", ready: true },
  { href: "/data/products", label: "Products", ready: true },
  { href: "#", label: "Categories", ready: false },
  { href: "#", label: "Brands", ready: false },
  { href: "#", label: "Collections", ready: false },
  { href: "#", label: "Warehouses", ready: false },
  { href: "#", label: "Locations", ready: false },
  { href: "#", label: "Departments", ready: false },
  { href: "#", label: "Cost Centers", ready: false },
  { href: "#", label: "Payment Methods", ready: false },
  { href: "#", label: "Loans", ready: false },
  { href: "#", label: "Fixed Assets", ready: false },
  { href: "#", label: "Budgets", ready: false },
  { href: "#", label: "Tax Rates", ready: false },
];

export default function DataIndex() {
  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Master Data</h1>
      <ul>
        {ENTITIES.map((entity) => (
          <li key={entity.label} className="border-b border-hairline">
            {entity.ready ? (
              <Link href={entity.href} className="flex items-center justify-between py-4 text-sm">
                {entity.label}
                <span className="text-muted">→</span>
              </Link>
            ) : (
              <div className="flex items-center justify-between py-4 text-sm text-muted">
                {entity.label}
                <span className="text-xs uppercase tracking-widest">Coming soon</span>
              </div>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
