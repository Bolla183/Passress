"use client";

import { useCallback, useEffect, useState } from "react";
import { formatEGP } from "@/lib/currency";
import { dateInputValue } from "@/lib/dates";

type Option = { id: string; name: string };

type Bill = {
  id: string;
  billNumber: string | null;
  billDate: string;
  dueDate: string | null;
  amount: number;
  amountPaid: number;
  status: string;
  notes: string | null;
  supplier: { name: string };
  account: { name: string };
};

export default function BillsScreen({
  suppliers,
  accounts,
  bankAccounts,
}: {
  suppliers: Option[];
  accounts: Option[];
  bankAccounts: Option[];
}) {
  const [bills, setBills] = useState<Bill[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [payingBillId, setPayingBillId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [form, setForm] = useState({
    supplierId: suppliers[0]?.id ?? "",
    accountId: accounts[0]?.id ?? "",
    amount: "",
    billDate: dateInputValue(new Date()),
    dueDate: "",
    billNumber: "",
    notes: "",
  });

  const [payForm, setPayForm] = useState({
    amount: "",
    date: dateInputValue(new Date()),
    bankAccountId: bankAccounts[0]?.id ?? "",
  });

  const load = useCallback(async () => {
    setLoading(true);
    const res = await fetch("/api/bills");
    const body = await res.json();
    setBills(body.bills ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-mount
    load();
  }, [load]);

  async function handleAddBill(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const res = await fetch("/api/bills", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(form),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }
    setShowForm(false);
    setForm((f) => ({ ...f, amount: "", billNumber: "", notes: "", dueDate: "" }));
    load();
  }

  async function handlePay(billId: string, e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const res = await fetch(`/api/bills/${billId}/pay`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payForm),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not record payment");
      return;
    }
    setPayingBillId(null);
    setPayForm({ amount: "", date: dateInputValue(new Date()), bankAccountId: bankAccounts[0]?.id ?? "" });
    load();
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-lg tracking-widest uppercase">Bills</h1>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper"
        >
          {showForm ? "Cancel" : "Add Bill"}
        </button>
      </div>

      {suppliers.length === 0 && (
        <p className="mb-4 text-sm text-muted">Add a supplier first in Data → Suppliers.</p>
      )}

      {showForm && (
        <form onSubmit={handleAddBill} className="mb-6 border border-hairline p-4">
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Supplier</span>
            <select
              value={form.supplierId}
              onChange={(e) => setForm({ ...form, supplierId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Category</span>
            <select
              value={form.accountId}
              onChange={(e) => setForm({ ...form, accountId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {accounts.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name}
                </option>
              ))}
            </select>
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
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Bill date</span>
            <input
              type="date"
              value={form.billDate}
              onChange={(e) => setForm({ ...form, billDate: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Due date (optional)</span>
            <input
              type="date"
              value={form.dueDate}
              onChange={(e) => setForm({ ...form, dueDate: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Bill number (optional)</span>
            <input
              type="text"
              value={form.billNumber}
              onChange={(e) => setForm({ ...form, billNumber: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-4 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Notes (optional)</span>
            <input
              type="text"
              value={form.notes}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          {error && <p className="mb-3 text-sm text-expense">{error}</p>}
          <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
            Save Bill
          </button>
        </form>
      )}

      {loading ? (
        <p className="py-6 text-sm text-muted">Loading...</p>
      ) : bills.length === 0 ? (
        <p className="py-6 text-sm text-muted">No bills yet.</p>
      ) : (
        <ul>
          {bills.map((bill) => (
            <li key={bill.id} className="border-b border-hairline py-3">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm">
                    {bill.supplier.name} · {bill.account.name}
                  </p>
                  <p className="text-xs text-muted">
                    {new Date(bill.billDate).toLocaleDateString("en-GB", { timeZone: "UTC" })}
                    {bill.billNumber ? ` · ${bill.billNumber}` : ""} ·{" "}
                    <span
                      className={
                        bill.status === "PAID"
                          ? "text-income"
                          : bill.status === "PARTIALLY_PAID"
                            ? "text-ink"
                            : "text-expense"
                      }
                    >
                      {bill.status.replace("_", " ")}
                    </span>
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-sm">{formatEGP(bill.amount)}</p>
                  {bill.amountPaid > 0 && (
                    <p className="text-xs text-muted">{formatEGP(bill.amountPaid)} paid</p>
                  )}
                </div>
              </div>

              {bill.status !== "PAID" && bill.status !== "VOID" && (
                <div className="mt-2">
                  {payingBillId === bill.id ? (
                    <form onSubmit={(e) => handlePay(bill.id, e)} className="border border-hairline p-3">
                      <label className="mb-2 block">
                        <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
                          Payment amount (EGP)
                        </span>
                        <input
                          type="number"
                          min="0"
                          step="0.01"
                          value={payForm.amount}
                          onChange={(e) => setPayForm({ ...payForm, amount: e.target.value })}
                          className="w-full border-b border-hairline bg-transparent py-1.5 text-sm outline-none focus:border-ink"
                        />
                      </label>
                      <label className="mb-2 block">
                        <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Date</span>
                        <input
                          type="date"
                          value={payForm.date}
                          onChange={(e) => setPayForm({ ...payForm, date: e.target.value })}
                          className="w-full border-b border-hairline bg-transparent py-1.5 text-sm outline-none focus:border-ink"
                        />
                      </label>
                      <label className="mb-3 block">
                        <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
                          From account
                        </span>
                        <select
                          value={payForm.bankAccountId}
                          onChange={(e) => setPayForm({ ...payForm, bankAccountId: e.target.value })}
                          className="w-full border-b border-hairline bg-transparent py-1.5 text-sm outline-none focus:border-ink"
                        >
                          {bankAccounts.map((b) => (
                            <option key={b.id} value={b.id}>
                              {b.name}
                            </option>
                          ))}
                        </select>
                      </label>
                      {error && <p className="mb-2 text-sm text-expense">{error}</p>}
                      <div className="flex gap-3">
                        <button
                          type="submit"
                          className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper"
                        >
                          Confirm
                        </button>
                        <button
                          type="button"
                          onClick={() => setPayingBillId(null)}
                          className="text-xs uppercase text-muted"
                        >
                          Cancel
                        </button>
                      </div>
                    </form>
                  ) : (
                    <button
                      onClick={() => {
                        setPayingBillId(bill.id);
                        setPayForm((f) => ({ ...f, amount: String(bill.amount - bill.amountPaid) }));
                        setError(null);
                      }}
                      className="text-xs uppercase text-muted underline"
                    >
                      Record Payment
                    </button>
                  )}
                </div>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
