import { NextResponse } from "next/server";
import { parseDateInputValue } from "@/lib/dates";
import { recordCapitalContribution } from "@/lib/modules/capital";

export async function POST(request: Request) {
  const body = await request.json();
  const { amount, date, notes } = body ?? {};

  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
  }
  if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }

  try {
    const entry = await recordCapitalContribution({
      amount: numericAmount,
      date: parseDateInputValue(date),
      notes: typeof notes === "string" && notes.trim() ? notes.trim().slice(0, 200) : undefined,
    });
    return NextResponse.json({ entry }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not save" },
      { status: 400 }
    );
  }
}
