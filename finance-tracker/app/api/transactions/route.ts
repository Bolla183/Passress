import { NextResponse } from "next/server";
import { parseDateInputValue } from "@/lib/dates";
import { postQuickEntry, listSimpleEntries, getQuickAddAccounts } from "@/lib/accounting/quickEntry";

export async function POST(request: Request) {
  const body = await request.json();
  const { accountId, amount, date, note } = body ?? {};

  if (typeof accountId !== "string" || !accountId) {
    return NextResponse.json({ error: "Invalid account" }, { status: 400 });
  }

  const { income, expense } = await getQuickAddAccounts();
  const isKnownAccount = [...income, ...expense].some((a) => a.id === accountId);
  if (!isKnownAccount) {
    return NextResponse.json({ error: "Invalid account" }, { status: 400 });
  }

  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
  }

  if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }

  try {
    const transaction = await postQuickEntry({
      accountId,
      amount: numericAmount,
      date: parseDateInputValue(date),
      note: typeof note === "string" && note.trim() ? note.trim().slice(0, 200) : undefined,
    });
    return NextResponse.json({ transaction }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not save" },
      { status: 400 }
    );
  }
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
