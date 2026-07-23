import { NextResponse } from "next/server";
import { categoriesFor } from "@/lib/categories";
import { parseDateInputValue } from "@/lib/dates";
import { postQuickEntry, listSimpleEntries } from "@/lib/accounting/quickEntry";

export async function POST(request: Request) {
  const body = await request.json();
  const { type, category, amount, date, note } = body ?? {};

  if (type !== "INCOME" && type !== "EXPENSE") {
    return NextResponse.json({ error: "Invalid type" }, { status: 400 });
  }

  if (typeof category !== "string" || !categoriesFor(type).includes(category)) {
    return NextResponse.json({ error: "Invalid category" }, { status: 400 });
  }

  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
  }

  if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }

  const transaction = await postQuickEntry({
    type,
    category,
    amount: numericAmount,
    date: parseDateInputValue(date),
    note: typeof note === "string" && note.trim() ? note.trim().slice(0, 200) : undefined,
  });

  return NextResponse.json({ transaction }, { status: 201 });
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const from = searchParams.get("from");
  const to = searchParams.get("to");

  const transactions = await listSimpleEntries({
    from: from ? new Date(from) : undefined,
    to: to ? new Date(to) : undefined,
  });

  return NextResponse.json({ transactions });
}
