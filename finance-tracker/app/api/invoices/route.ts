import { NextResponse } from "next/server";
import { listInvoices, recordInvoice } from "@/lib/modules/invoices";

export async function GET() {
  const invoices = await listInvoices();
  return NextResponse.json({
    invoices: invoices.map((i) => ({
      ...i,
      amount: Number(i.amount),
      amountPaid: Number(i.amountPaid),
      payments: i.payments.map((p) => ({ ...p, amount: Number(p.amount) })),
    })),
  });
}

export async function POST(request: Request) {
  const body = await request.json();
  const { customerId, accountId, amount, invoiceDate, dueDate, invoiceNumber, notes } = body ?? {};

  if (typeof customerId !== "string" || !customerId) {
    return NextResponse.json({ error: "Choose a customer" }, { status: 400 });
  }
  if (typeof accountId !== "string" || !accountId) {
    return NextResponse.json({ error: "Choose a category" }, { status: 400 });
  }
  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
  }
  if (typeof invoiceDate !== "string" || !invoiceDate) {
    return NextResponse.json({ error: "Invalid invoice date" }, { status: 400 });
  }

  try {
    const invoice = await recordInvoice({
      customerId,
      accountId,
      amount: numericAmount,
      invoiceDate: new Date(`${invoiceDate}T00:00:00Z`),
      dueDate: dueDate ? new Date(`${dueDate}T00:00:00Z`) : undefined,
      invoiceNumber: typeof invoiceNumber === "string" ? invoiceNumber : undefined,
      notes: typeof notes === "string" ? notes : undefined,
    });
    return NextResponse.json({ invoice }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record invoice" },
      { status: 400 }
    );
  }
}
