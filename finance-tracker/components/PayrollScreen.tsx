"use client";

import { useCallback, useEffect, useState } from "react";
import { formatEGP } from "@/lib/currency";
import { dateInputValue, addMonths, monthLabel } from "@/lib/dates";
import CategoryBarChart from "@/components/CategoryBarChart";

type Payment = {
  id: string;
  employeeName: string;
  amount: number;
  date: string;
  notes: string | null;
};

function monthParam(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

export default function PayrollScreen({ employeeNames }: { employeeNames: string[] }) {
  const [month, setMonth] = useState(() => new Date());
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({
    employeeName: "",
    amount: "",
    date: dateInputValue(new Date()),
    notes: "",
  });

  const load = useCallback(async (forMonth: Date) => {
    setLoading(true);
    const res = await fetch(`/api/payroll?month=${monthParam(forMonth)}`);
    const body = await res.json();
    setPayments(body.payments ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-mount / month change
    load(month);
  }, [load, month]);

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
    setForm((f) => ({ ...f, amount: "", notes: "" }));
    load(month);
  }

  const total = payments.reduce((s, p) => s + p.amount, 0);
  const byEmployee = new Map<string, number>();
  payments.forEach((p) => byEmployee.set(p.employeeName, (byEmployee.get(p.employeeName) ?? 0) + p.amount));
  const breakdown = Array.from(byEmployee, ([category, amount]) => ({ category, amount })).sort(
    (a, b) => b.amount - a.amount
  );

  const isCurrentMonth = monthParam(month) === monthParam(new Date());

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Payroll</h1>

      <form onSubmit={handleSubmit} className="mb-6 border border-hairline p-4">
        <label className="mb-3 block">
          <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Name</span>
          <input
            type="text"
            list="employee-names"
            value={form.employeeName}
            onChange={(e) => setForm({ ...form, employeeName: e.target.value })}
            placeholder="e.g. Ahmed"
            className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
          />
          <datalist id="employee-names">
            {employeeNames.map((name) => (
              <option key={name} value={name} />
            ))}
          </datalist>
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
        <label className="mb-4 block">
          <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Date</span>
          <input
            type="date"
            value={form.date}
            onChange={(e) => setForm({ ...form, date: e.target.value })}
            className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
          />
        </label>
        {error && <p className="mb-3 text-sm text-expense">{error}</p>}
        <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
          Pay
        </button>
      </form>

      <div className="mb-6 flex items-center justify-between">
        <button onClick={() => setMonth((m) => addMonths(m, -1))} className="text-sm text-muted">
          ←
        </button>
        <p className="text-xs uppercase tracking-widest text-muted">{monthLabel(month)}</p>
        {isCurrentMonth ? (
          <span className="w-4" />
        ) : (
          <button onClick={() => setMonth((m) => addMonths(m, 1))} className="text-sm text-muted">
            →
          </button>
        )}
      </div>

      <div className="mb-8 border border-hairline px-3 py-4 text-center">
        <p className="mb-1 text-xs uppercase tracking-widest text-muted">Total this month</p>
        <p className="text-base">{formatEGP(total)}</p>
      </div>

      {loading ? (
        <p className="py-6 text-sm text-muted">Loading...</p>
      ) : payments.length === 0 ? (
        <p className="py-6 text-sm text-muted">No payments this month.</p>
      ) : (
        <>
          <p className="mb-2 text-xs uppercase tracking-widest text-muted">By person</p>
          <div className="mb-8">
            <CategoryBarChart data={breakdown} />
          </div>

          <p className="mb-2 text-xs uppercase tracking-widest text-muted">Recent payments</p>
          <ul>
            {payments.map((p) => (
              <li key={p.id} className="flex items-center justify-between border-b border-hairline py-3">
                <div>
                  <p className="text-sm">{p.employeeName}</p>
                  <p className="text-xs text-muted">
                    {new Date(p.date).toLocaleDateString("en-GB", { timeZone: "UTC" })}
                    {p.notes ? ` · ${p.notes}` : ""}
                  </p>
                </div>
                <p className="text-sm">{formatEGP(p.amount)}</p>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
