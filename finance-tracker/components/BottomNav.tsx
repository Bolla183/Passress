"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

const TABS = [
  { href: "/add", label: "Add" },
  { href: "/dashboard/daily", label: "Daily" },
  { href: "/dashboard/monthly", label: "Monthly" },
  { href: "/dashboard/trends", label: "Trends" },
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
      <div className="mx-auto flex max-w-lg">
        {TABS.map((tab) => {
          const active = pathname.startsWith(tab.href);
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`flex-1 py-3 text-center text-[11px] uppercase tracking-widest ${
                active ? "text-ink font-medium" : "text-muted"
              }`}
            >
              {tab.label}
            </Link>
          );
        })}
        <button
          onClick={handleLogout}
          className="flex-1 py-3 text-center text-[11px] uppercase tracking-widest text-muted"
        >
          Logout
        </button>
      </div>
    </nav>
  );
}
