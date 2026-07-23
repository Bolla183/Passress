"use client";

import { useCallback, useEffect, useState } from "react";
import { formatEGP } from "@/lib/currency";
import { dateInputValue } from "@/lib/dates";

type Employee = { id: string; name: string; salaryAmount: number | null };
type BankAccountOption = { id: string; name: string };

type SalaryPayment = {
  id: string;
  period: string;
  amount: number;
  date: string;
  notes: string | null;
  employee: { name: string };
};

function currentPeriod(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
}

export default function PayrollScreen({
  employees,
  bankAccounts,
}: {
  employees: Employee[];
  bankAccounts: BankAccountOption[];
}) {
  const [payments, setPayments] = useState<SalaryPayment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({
    employeeId: employees[0]?.id ?? "",
    period: currentPeriod(),
    amount: employees[0]?.salaryAmount ? String(employees[0].salaryAmount) : "",
    date: dateInputValue(new Date()),
    bankAccountId: bankAccounts[0]?.id ?? "",
    notes: "",
  });

  const load = useCallback(async () => {
    setLoading(true);
    const res = await fetch("/api/payroll");
    const body = await res.json();
    setPayments(body.payments ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-mount
    load();
  }, [load]);

  function handleEmployeeChange(employeeId: string) {
    const employee = employees.find((e) => e.id === employeeId);
    setForm({
      ...form,
      employeeId,
      amount: employee?.salaryAmount ? String(employee.salaryAmount) : form.amount,
    });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const res = await fetch("/api/payroll", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(form),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }
    setForm((f) => ({ ...f, notes: "" }));
    load();
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Payroll</h1>

      {employees.length === 0 ? (
        <p className="mb-4 text-sm text-muted">Add an employee first in Data → Employees.</p>
      ) : (
        <form onSubmit={handleSubmit} className="mb-6 border border-hairline p-4">
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Employee</span>
            <select
              value={form.employeeId}
              onChange={(e) => handleEmployeeChange(e.target.value)}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {employees.map((e) => (
                <option key={e.id} value={e.id}>
                  {e.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Period (e.g. 2026-07)</span>
            <input
              type="text"
              value={form.period}
              onChange={(e) => setForm({ ...form, period: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Amount (EGP)</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Date</span>
            <input
              type="date"
              value={form.date}
              onChange={(e) => setForm({ ...form, date: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-4 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Paid from</span>
            <select
              value={form.bankAccountId}
              onChange={(e) => setForm({ ...form, bankAccountId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {bankAccounts.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name}
                </option>
              ))}
            </select>
          </label>
          {error && <p className="mb-3 text-sm text-expense">{error}</p>}
          <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
            Record Payment
          </button>
        </form>
      )}

      {loading ? (
        <p className="py-6 text-sm text-muted">Loading...</p>
      ) : payments.length === 0 ? (
        <p className="py-6 text-sm text-muted">No salary payments yet.</p>
      ) : (
        <ul>
          {payments.map((p) => (
            <li key={p.id} className="flex items-center justify-between border-b border-hairline py-3">
              <div>
                <p className="text-sm">{p.employee.name}</p>
                <p className="text-xs text-muted">
                  {p.period} · {new Date(p.date).toLocaleDateString("en-GB", { timeZone: "UTC" })}
                </p>
              </div>
              <p className="text-sm">{formatEGP(p.amount)}</p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
