import { NextResponse } from "next/server";
import { recordLoanRepayment } from "@/lib/modules/loans";

export async function POST(
  request: Request,
  ctx: { params: Promise<{ id: string }> }
) {
  const { id } = await ctx.params;
  const body = await request.json();
  const { principalAmount, interestAmount, date, bankAccountId, notes } = body ?? {};

  const numericPrincipal = Number(principalAmount);
  if (!Number.isFinite(numericPrincipal) || numericPrincipal <= 0) {
    return NextResponse.json({ error: "Invalid principal amount" }, { status: 400 });
  }
  const numericInterest = interestAmount === "" || interestAmount == null ? 0 : Number(interestAmount);
  if (!Number.isFinite(numericInterest) || numericInterest < 0) {
    return NextResponse.json({ error: "Invalid interest amount" }, { status: 400 });
  }
  if (typeof date !== "string" || !date) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }
  if (typeof bankAccountId !== "string" || !bankAccountId) {
    return NextResponse.json({ error: "Choose a bank account" }, { status: 400 });
  }

  try {
    const payment = await recordLoanRepayment({
      loanId: id,
      principalAmount: numericPrincipal,
      interestAmount: numericInterest,
      date: new Date(`${date}T00:00:00Z`),
      bankAccountId,
      notes: typeof notes === "string" ? notes : undefined,
    });
    return NextResponse.json({ payment }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record repayment" },
      { status: 400 }
    );
  }
}
