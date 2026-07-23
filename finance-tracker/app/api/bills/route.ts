import { NextResponse } from "next/server";
import { listBills, recordBill } from "@/lib/modules/bills";

export async function GET() {
  const bills = await listBills();
  return NextResponse.json({
    bills: bills.map((b) => ({
      ...b,
      amount: Number(b.amount),
      amountPaid: Number(b.amountPaid),
      payments: b.payments.map((p) => ({ ...p, amount: Number(p.amount) })),
    })),
  });
}

export async function POST(request: Request) {
  const body = await request.json();
  const { supplierId, accountId, amount, billDate, dueDate, billNumber, notes } = body ?? {};

  if (typeof supplierId !== "string" || !supplierId) {
    return NextResponse.json({ error: "Choose a supplier" }, { status: 400 });
  }
  if (typeof accountId !== "string" || !accountId) {
    return NextResponse.json({ error: "Choose a category" }, { status: 400 });
  }
  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
  }
  if (typeof billDate !== "string" || !billDate) {
    return NextResponse.json({ error: "Invalid bill date" }, { status: 400 });
  }

  try {
    const bill = await recordBill({
      supplierId,
      accountId,
      amount: numericAmount,
      billDate: new Date(`${billDate}T00:00:00Z`),
      dueDate: dueDate ? new Date(`${dueDate}T00:00:00Z`) : undefined,
      billNumber: typeof billNumber === "string" ? billNumber : undefined,
      notes: typeof notes === "string" ? notes : undefined,
    });
    return NextResponse.json({ bill }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record bill" },
      { status: 400 }
    );
  }
}
