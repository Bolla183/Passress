"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/dashboard", label: "Dashboard", exact: true },
  { href: "/timeline", label: "Timeline" },
  { href: "/reports", label: "Reports" },
  {
    href: "/more",
    label: "More",
    extraMatch: ["/dashboard/daily", "/dashboard/monthly", "/dashboard/trends", "/workflows", "/data", "/payroll"],
  },
];

export default function BottomNav() {
  const pathname = usePathname();

  if (pathname === "/login") return null;

  return (
    <>
      {!pathname.startsWith("/add") && (
        <Link
          href="/add"
          aria-label="Add entry"
          className="fixed right-5 z-10 flex h-14 w-14 items-center justify-center rounded-full bg-ink text-2xl leading-none text-paper shadow-lg"
          style={{ bottom: "calc(5rem + env(safe-area-inset-bottom))" }}
        >
          +
        </Link>
      )}
      <nav className="fixed bottom-0 left-0 right-0 border-t border-hairline bg-paper pb-[env(safe-area-inset-bottom)]">
        <div className="mx-auto flex max-w-lg overflow-x-auto px-5">
          {TABS.map((tab) => {
            const active = tab.exact
              ? pathname === tab.href
              : pathname.startsWith(tab.href) || (tab.extraMatch?.some((p) => pathname.startsWith(p)) ?? false);
            return (
              <Link
                key={tab.href}
                href={tab.href}
                className={`shrink-0 basis-1/4 px-0.5 py-3 text-center text-[11px] uppercase tracking-widest ${
                  active ? "text-ink font-medium" : "text-muted"
                }`}
              >
                {tab.label}
              </Link>
            );
          })}
        </div>
      </nav>
    </>
  );
}
