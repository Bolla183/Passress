import { NextResponse } from "next/server";
import { listSalaryPayments, recordSalaryPayment } from "@/lib/modules/payroll";
import { startOfCairoMonth, endOfCairoMonth } from "@/lib/dates";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const month = searchParams.get("month");
  const selected = month ? new Date(`${month}-01T00:00:00Z`) : new Date();

  const payments = await listSalaryPayments({
    from: startOfCairoMonth(selected),
    to: endOfCairoMonth(selected),
  });
  return NextResponse.json({
    payments: payments.map((p) => ({
      id: p.id,
      employeeName: p.employee.name,
      amount: Number(p.amount),
      date: p.date,
      notes: p.notes,
    })),
  });
}

export async function POST(request: Request) {
  const body = await request.json();
  const { employeeName, amount, date, notes } = body ?? {};

  if (typeof employeeName !== "string" || !employeeName.trim()) {
    return NextResponse.json({ error: "Enter an employee name" }, { status: 400 });
  }
  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
  }
  if (typeof date !== "string" || !date) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }

  try {
    const payment = await recordSalaryPayment({
      employeeName,
      amount: numericAmount,
      date: new Date(`${date}T00:00:00Z`),
      notes: typeof notes === "string" && notes ? notes : undefined,
    });
    return NextResponse.json({ payment }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record payment" },
      { status: 400 }
    );
  }
}
