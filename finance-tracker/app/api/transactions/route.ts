import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { categoriesFor } from "@/lib/categories";
import { parseDateInputValue } from "@/lib/dates";

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

  const transaction = await prisma.transaction.create({
    data: {
      type,
      category,
      amount: numericAmount,
      date: parseDateInputValue(date),
      note: typeof note === "string" && note.trim() ? note.trim().slice(0, 200) : null,
    },
  });

  return NextResponse.json(
    { transaction: { ...transaction, amount: Number(transaction.amount) } },
    { status: 201 }
  );
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const from = searchParams.get("from");
  const to = searchParams.get("to");

  const transactions = await prisma.transaction.findMany({
    where: {
      ...(from || to
        ? {
            date: {
              ...(from ? { gte: new Date(from) } : {}),
              ...(to ? { lt: new Date(to) } : {}),
            },
          }
        : {}),
    },
    orderBy: { date: "desc" },
  });

  return NextResponse.json({
    transactions: transactions.map((t) => ({ ...t, amount: Number(t.amount) })),
  });
}
