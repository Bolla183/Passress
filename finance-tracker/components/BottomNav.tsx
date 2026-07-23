"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

const TABS = [
  { href: "/add", label: "Add" },
  { href: "/payroll", label: "Payroll" },
  { href: "/dashboard/performance", label: "Performance" },
  { href: "/reports", label: "Reports" },
  { href: "/more", label: "More", extraMatch: ["/dashboard/daily", "/dashboard/monthly", "/dashboard/trends", "/workflows", "/data"] },
];

export default function BottomNav() {
  const pathname = usePathname();
  const router = useRouter();

  if (pathname === "/login") return null;

  async function handleLogout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
  }

  return (
    <nav className="fixed bottom-0 left-0 right-0 border-t border-hairline bg-paper">
      <div className="mx-auto flex max-w-lg overflow-x-auto">
        {TABS.map((tab) => {
          const active = pathname.startsWith(tab.href) || (tab.extraMatch?.some((p) => pathname.startsWith(p)) ?? false);
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`shrink-0 basis-1/6 px-2 py-3 text-center text-[11px] uppercase tracking-widest ${
                active ? "text-ink font-medium" : "text-muted"
              }`}
            >
              {tab.label}
            </Link>
          );
        })}
        <button
          onClick={handleLogout}
          className="shrink-0 basis-1/6 px-2 py-3 text-center text-[11px] uppercase tracking-widest text-muted"
        >
          Logout
        </button>
      </div>
    </nav>
  );
}
