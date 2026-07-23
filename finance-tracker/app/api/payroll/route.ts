import { NextResponse } from "next/server";
import { listSalaryPayments, recordSalaryPayment } from "@/lib/modules/payroll";

export async function GET() {
  const payments = await listSalaryPayments();
  return NextResponse.json({
    payments: payments.map((p) => ({ ...p, amount: Number(p.amount) })),
  });
}

export async function POST(request: Request) {
  const body = await request.json();
  const { employeeId, period, amount, date, bankAccountId, notes } = body ?? {};

  if (typeof employeeId !== "string" || !employeeId) {
    return NextResponse.json({ error: "Choose an employee" }, { status: 400 });
  }
  if (typeof period !== "string" || !period) {
    return NextResponse.json({ error: "Invalid period" }, { status: 400 });
  }
  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
  }
  if (typeof date !== "string" || !date) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }
  if (typeof bankAccountId !== "string" || !bankAccountId) {
    return NextResponse.json({ error: "Choose a bank account" }, { status: 400 });
  }

  try {
    const payment = await recordSalaryPayment({
      employeeId,
      period,
      amount: numericAmount,
      date: new Date(`${date}T00:00:00Z`),
      bankAccountId,
      notes: typeof notes === "string" ? notes : undefined,
    });
    return NextResponse.json({ payment }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record payment" },
      { status: 400 }
    );
  }
}
