"use client";

import { useRouter } from "next/navigation";

export default function LogoutButton() {
  const router = useRouter();

  async function handleLogout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
  }

  return (
    <button onClick={handleLogout} className="flex w-full items-center justify-between py-4 text-left text-sm">
      Logout
      <span className="text-muted">→</span>
    </button>
  );
}
