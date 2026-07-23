import { NextResponse } from "next/server";
import { recordLoanDisbursement } from "@/lib/modules/loans";

export async function POST(
  request: Request,
  ctx: { params: Promise<{ id: string }> }
) {
  const { id } = await ctx.params;
  const body = await request.json();
  const { bankAccountId, date } = body ?? {};

  if (typeof bankAccountId !== "string" || !bankAccountId) {
    return NextResponse.json({ error: "Choose a bank account" }, { status: 400 });
  }
  if (typeof date !== "string" || !date) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }

  try {
    const loan = await recordLoanDisbursement({
      loanId: id,
      bankAccountId,
      date: new Date(`${date}T00:00:00Z`),
    });
    return NextResponse.json({ loan });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record disbursement" },
      { status: 400 }
    );
  }
}
