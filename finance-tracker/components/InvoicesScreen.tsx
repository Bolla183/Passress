"use client";

import { useCallback, useEffect, useState } from "react";
import { formatEGP } from "@/lib/currency";
import { dateInputValue } from "@/lib/dates";

type Option = { id: string; name: string };

type Invoice = {
  id: string;
  invoiceNumber: string | null;
  invoiceDate: string;
  dueDate: string | null;
  amount: number;
  amountPaid: number;
  status: string;
  notes: string | null;
  customer: { name: string };
  account: { name: string };
};

export default function InvoicesScreen({
  customers,
  accounts,
  bankAccounts,
}: {
  customers: Option[];
  accounts: Option[];
  bankAccounts: Option[];
}) {
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [payingInvoiceId, setPayingInvoiceId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [form, setForm] = useState({
    customerId: customers[0]?.id ?? "",
    accountId: accounts[0]?.id ?? "",
    amount: "",
    invoiceDate: dateInputValue(new Date()),
    dueDate: "",
    invoiceNumber: "",
    notes: "",
  });

  const [payForm, setPayForm] = useState({
    amount: "",
    date: dateInputValue(new Date()),
    bankAccountId: bankAccounts[0]?.id ?? "",
  });

  const load = useCallback(async () => {
    setLoading(true);
    const res = await fetch("/api/invoices");
    const body = await res.json();
    setInvoices(body.invoices ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-mount
    load();
  }, [load]);

  async function handleAddInvoice(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const res = await fetch("/api/invoices", {
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
    setForm((f) => ({ ...f, amount: "", invoiceNumber: "", notes: "", dueDate: "" }));
    load();
  }

  async function handlePay(invoiceId: string, e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const res = await fetch(`/api/invoices/${invoiceId}/pay`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payForm),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not record payment");
      return;
    }
    setPayingInvoiceId(null);
    setPayForm({ amount: "", date: dateInputValue(new Date()), bankAccountId: bankAccounts[0]?.id ?? "" });
    load();
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-lg tracking-widest uppercase">Invoices</h1>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper"
        >
          {showForm ? "Cancel" : "Add Invoice"}
        </button>
      </div>

      {customers.length === 0 && (
        <p className="mb-4 text-sm text-muted">Add a customer first in Data → Customers.</p>
      )}

      {showForm && (
        <form onSubmit={handleAddInvoice} className="mb-6 border border-hairline p-4">
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Customer</span>
            <select
              value={form.customerId}
              onChange={(e) => setForm({ ...form, customerId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {customers.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Revenue category</span>
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
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Invoice date</span>
            <input
              type="date"
              value={form.invoiceDate}
              onChange={(e) => setForm({ ...form, invoiceDate: e.target.value })}
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
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
              Invoice number (optional)
            </span>
            <input
              type="text"
              value={form.invoiceNumber}
              onChange={(e) => setForm({ ...form, invoiceNumber: e.target.value })}
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
            Save Invoice
          </button>
        </form>
      )}

      {loading ? (
        <p className="py-6 text-sm text-muted">Loading...</p>
      ) : invoices.length === 0 ? (
        <p className="py-6 text-sm text-muted">No invoices yet.</p>
      ) : (
        <ul>
          {invoices.map((invoice) => (
            <li key={invoice.id} className="border-b border-hairline py-3">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm">
                    {invoice.customer.name} · {invoice.account.name}
                  </p>
                  <p className="text-xs text-muted">
                    {new Date(invoice.invoiceDate).toLocaleDateString("en-GB", { timeZone: "UTC" })}
                    {invoice.invoiceNumber ? ` · ${invoice.invoiceNumber}` : ""} ·{" "}
                    <span
                      className={
                        invoice.status === "PAID"
                          ? "text-income"
                          : invoice.status === "PARTIALLY_PAID"
                            ? "text-ink"
                            : "text-expense"
                      }
                    >
                      {invoice.status.replace("_", " ")}
                    </span>
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-sm">{formatEGP(invoice.amount)}</p>
                  {invoice.amountPaid > 0 && (
                    <p className="text-xs text-muted">{formatEGP(invoice.amountPaid)} collected</p>
                  )}
                </div>
              </div>

              {invoice.status !== "PAID" && invoice.status !== "VOID" && (
                <div className="mt-2">
                  {payingInvoiceId === invoice.id ? (
                    <form onSubmit={(e) => handlePay(invoice.id, e)} className="border border-hairline p-3">
                      <label className="mb-2 block">
                        <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
                          Amount collected (EGP)
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
                          Into account
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
                          onClick={() => setPayingInvoiceId(null)}
                          className="text-xs uppercase text-muted"
                        >
                          Cancel
                        </button>
                      </div>
                    </form>
                  ) : (
                    <button
                      onClick={() => {
                        setPayingInvoiceId(invoice.id);
                        setPayForm((f) => ({ ...f, amount: String(invoice.amount - invoice.amountPaid) }));
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
