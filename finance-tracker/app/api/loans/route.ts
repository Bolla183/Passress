import { NextResponse } from "next/server";
import { listLoans } from "@/lib/modules/loans";

export async function GET() {
  const loans = await listLoans();
  return NextResponse.json({
    loans: loans.map((l) => ({
      ...l,
      principal: Number(l.principal),
      interestRate: Number(l.interestRate),
      remainingPrincipal: l.remainingPrincipal ? Number(l.remainingPrincipal) : null,
      payments: l.payments.map((p) => ({
        ...p,
        principalAmount: Number(p.principalAmount),
        interestAmount: Number(p.interestAmount),
      })),
    })),
  });
}
