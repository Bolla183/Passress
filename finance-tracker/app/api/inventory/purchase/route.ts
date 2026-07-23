import { NextResponse } from "next/server";
import { recordPurchase } from "@/lib/modules/inventory";

export async function POST(request: Request) {
  const body = await request.json();
  const { productId, warehouseId, supplierId, quantity, unitCost, date, paid, bankAccountId, notes } = body ?? {};

  if (typeof productId !== "string" || !productId) {
    return NextResponse.json({ error: "Choose a product" }, { status: 400 });
  }
  if (typeof warehouseId !== "string" || !warehouseId) {
    return NextResponse.json({ error: "Choose a warehouse" }, { status: 400 });
  }
  if (typeof supplierId !== "string" || !supplierId) {
    return NextResponse.json({ error: "Choose a supplier" }, { status: 400 });
  }
  const numericQuantity = Number(quantity);
  const numericUnitCost = Number(unitCost);
  if (!Number.isFinite(numericQuantity) || numericQuantity <= 0) {
    return NextResponse.json({ error: "Invalid quantity" }, { status: 400 });
  }
  if (!Number.isFinite(numericUnitCost) || numericUnitCost <= 0) {
    return NextResponse.json({ error: "Invalid unit cost" }, { status: 400 });
  }
  if (typeof date !== "string" || !date) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }
  if (paid && (typeof bankAccountId !== "string" || !bankAccountId)) {
    return NextResponse.json({ error: "Choose a bank account" }, { status: 400 });
  }

  try {
    const movement = await recordPurchase({
      productId,
      warehouseId,
      supplierId,
      quantity: numericQuantity,
      unitCost: numericUnitCost,
      date: new Date(`${date}T00:00:00Z`),
      settlement: paid ? { type: "CASH", bankAccountId } : { type: "CREDIT" },
      notes: typeof notes === "string" ? notes : undefined,
    });
    return NextResponse.json({ movement }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record purchase" },
      { status: 400 }
    );
  }
}
