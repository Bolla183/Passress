"use client";

import { useCallback, useEffect, useState } from "react";
import { formatEGP } from "@/lib/currency";
import { dateInputValue } from "@/lib/dates";

type Option = { id: string; name: string };

type Loan = {
  id: string;
  lender: string;
  principal: number;
  interestRate: number;
  remainingPrincipal: number | null;
  disbursementJournalEntryId: string | null;
};

export default function LoansScreen({
  liabilityAccounts,
  bankAccounts,
}: {
  liabilityAccounts: Option[];
  bankAccounts: Option[];
}) {
  const [loans, setLoans] = useState<Loan[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [actionLoanId, setActionLoanId] = useState<string | null>(null);
  const [actionType, setActionType] = useState<"disburse" | "repay" | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [form, setForm] = useState({
    lender: "",
    principal: "",
    interestRate: "",
    startDate: dateInputValue(new Date()),
    termMonths: "12",
    glAccountId: liabilityAccounts[0]?.id ?? "",
  });

  const [disburseForm, setDisburseForm] = useState({
    date: dateInputValue(new Date()),
    bankAccountId: bankAccounts[0]?.id ?? "",
  });

  const [repayForm, setRepayForm] = useState({
    principalAmount: "",
    interestAmount: "",
    date: dateInputValue(new Date()),
    bankAccountId: bankAccounts[0]?.id ?? "",
  });

  const load = useCallback(async () => {
    setLoading(true);
    const res = await fetch("/api/loans");
    const body = await res.json();
    setLoans(body.loans ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- fetch-on-mount
    load();
  }, [load]);

  async function handleAddLoan(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const res = await fetch("/api/masterdata/loans", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        lender: form.lender,
        principal: Number(form.principal),
        interestRate: Number(form.interestRate),
        startDate: new Date(`${form.startDate}T00:00:00Z`).toISOString(),
        termMonths: Number(form.termMonths),
        glAccountId: form.glAccountId,
      }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not save");
      return;
    }
    setShowForm(false);
    setForm((f) => ({ ...f, lender: "", principal: "", interestRate: "" }));
    load();
  }

  async function handleDisburse(loanId: string, e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const res = await fetch(`/api/loans/${loanId}/disburse`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(disburseForm),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not record");
      return;
    }
    setActionLoanId(null);
    load();
  }

  async function handleRepay(loanId: string, e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const res = await fetch(`/api/loans/${loanId}/repay`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(repayForm),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error || "Could not record");
      return;
    }
    setActionLoanId(null);
    setRepayForm({ principalAmount: "", interestAmount: "", date: dateInputValue(new Date()), bankAccountId: bankAccounts[0]?.id ?? "" });
    load();
  }

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-lg tracking-widest uppercase">Loans</h1>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper"
        >
          {showForm ? "Cancel" : "Add Loan"}
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleAddLoan} className="mb-6 border border-hairline p-4">
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Lender</span>
            <input
              type="text"
              value={form.lender}
              required
              onChange={(e) => setForm({ ...form, lender: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Principal (EGP)</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={form.principal}
              required
              onChange={(e) => setForm({ ...form, principal: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Interest rate (% per year)</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={form.interestRate}
              required
              onChange={(e) => setForm({ ...form, interestRate: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Start date</span>
            <input
              type="date"
              value={form.startDate}
              onChange={(e) => setForm({ ...form, startDate: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-3 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Term (months)</span>
            <input
              type="number"
              min="1"
              value={form.termMonths}
              onChange={(e) => setForm({ ...form, termMonths: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            />
          </label>
          <label className="mb-4 block">
            <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Liability account</span>
            <select
              value={form.glAccountId}
              onChange={(e) => setForm({ ...form, glAccountId: e.target.value })}
              className="w-full border-b border-hairline bg-transparent py-2 text-sm outline-none focus:border-ink"
            >
              {liabilityAccounts.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name}
                </option>
              ))}
            </select>
          </label>
          {error && <p className="mb-3 text-sm text-expense">{error}</p>}
          <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
            Save Loan
          </button>
        </form>
      )}

      {loading ? (
        <p className="py-6 text-sm text-muted">Loading...</p>
      ) : loans.length === 0 ? (
        <p className="py-6 text-sm text-muted">No loans yet.</p>
      ) : (
        <ul>
          {loans.map((loan) => (
            <li key={loan.id} className="border-b border-hairline py-3">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm">{loan.lender}</p>
                  <p className="text-xs text-muted">
                    {formatEGP(loan.principal)} at {loan.interestRate}%
                    {!loan.disbursementJournalEntryId && " · Not yet received"}
                  </p>
                </div>
                {loan.disbursementJournalEntryId && (
                  <p className="text-sm">
                    {loan.remainingPrincipal !== null && loan.remainingPrincipal <= 0.005
                      ? "Paid off"
                      : `${formatEGP(loan.remainingPrincipal ?? loan.principal)} remaining`}
                  </p>
                )}
              </div>

              {!loan.disbursementJournalEntryId ? (
                actionLoanId === loan.id && actionType === "disburse" ? (
                  <form onSubmit={(e) => handleDisburse(loan.id, e)} className="mt-2 border border-hairline p-3">
                    <label className="mb-2 block">
                      <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Received into</span>
                      <select
                        value={disburseForm.bankAccountId}
                        onChange={(e) => setDisburseForm({ ...disburseForm, bankAccountId: e.target.value })}
                        className="w-full border-b border-hairline bg-transparent py-1.5 text-sm outline-none focus:border-ink"
                      >
                        {bankAccounts.map((b) => (
                          <option key={b.id} value={b.id}>
                            {b.name}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="mb-3 block">
                      <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Date</span>
                      <input
                        type="date"
                        value={disburseForm.date}
                        onChange={(e) => setDisburseForm({ ...disburseForm, date: e.target.value })}
                        className="w-full border-b border-hairline bg-transparent py-1.5 text-sm outline-none focus:border-ink"
                      />
                    </label>
                    {error && <p className="mb-2 text-sm text-expense">{error}</p>}
                    <div className="flex gap-3">
                      <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
                        Confirm
                      </button>
                      <button type="button" onClick={() => setActionLoanId(null)} className="text-xs uppercase text-muted">
                        Cancel
                      </button>
                    </div>
                  </form>
                ) : (
                  <button
                    onClick={() => {
                      setActionLoanId(loan.id);
                      setActionType("disburse");
                      setError(null);
                    }}
                    className="mt-2 text-xs uppercase text-muted underline"
                  >
                    Record as Received
                  </button>
                )
              ) : loan.remainingPrincipal !== null && loan.remainingPrincipal > 0.005 ? (
                actionLoanId === loan.id && actionType === "repay" ? (
                  <form onSubmit={(e) => handleRepay(loan.id, e)} className="mt-2 border border-hairline p-3">
                    <label className="mb-2 block">
                      <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
                        Principal amount (EGP)
                      </span>
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={repayForm.principalAmount}
                        onChange={(e) => setRepayForm({ ...repayForm, principalAmount: e.target.value })}
                        className="w-full border-b border-hairline bg-transparent py-1.5 text-sm outline-none focus:border-ink"
                      />
                    </label>
                    <label className="mb-2 block">
                      <span className="mb-1 block text-xs uppercase tracking-widest text-muted">
                        Interest amount (optional, EGP)
                      </span>
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={repayForm.interestAmount}
                        onChange={(e) => setRepayForm({ ...repayForm, interestAmount: e.target.value })}
                        className="w-full border-b border-hairline bg-transparent py-1.5 text-sm outline-none focus:border-ink"
                      />
                    </label>
                    <label className="mb-2 block">
                      <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Date</span>
                      <input
                        type="date"
                        value={repayForm.date}
                        onChange={(e) => setRepayForm({ ...repayForm, date: e.target.value })}
                        className="w-full border-b border-hairline bg-transparent py-1.5 text-sm outline-none focus:border-ink"
                      />
                    </label>
                    <label className="mb-3 block">
                      <span className="mb-1 block text-xs uppercase tracking-widest text-muted">Paid from</span>
                      <select
                        value={repayForm.bankAccountId}
                        onChange={(e) => setRepayForm({ ...repayForm, bankAccountId: e.target.value })}
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
                      <button type="submit" className="bg-ink px-3 py-1.5 text-xs uppercase tracking-widest text-paper">
                        Confirm
                      </button>
                      <button type="button" onClick={() => setActionLoanId(null)} className="text-xs uppercase text-muted">
                        Cancel
                      </button>
                    </div>
                  </form>
                ) : (
                  <button
                    onClick={() => {
                      setActionLoanId(loan.id);
                      setActionType("repay");
                      setError(null);
                    }}
                    className="mt-2 text-xs uppercase text-muted underline"
                  >
                    Record Repayment
                  </button>
                )
              ) : null}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
