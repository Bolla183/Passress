import { NextResponse } from "next/server";
import { recordSale } from "@/lib/modules/inventory";

export async function POST(request: Request) {
  const body = await request.json();
  const {
    productId,
    warehouseId,
    quantity,
    salePrice,
    revenueAccountId,
    date,
    paid,
    bankAccountId,
    customerId,
    notes,
  } = body ?? {};

  if (typeof productId !== "string" || !productId) {
    return NextResponse.json({ error: "Choose a product" }, { status: 400 });
  }
  if (typeof warehouseId !== "string" || !warehouseId) {
    return NextResponse.json({ error: "Choose a warehouse" }, { status: 400 });
  }
  if (typeof revenueAccountId !== "string" || !revenueAccountId) {
    return NextResponse.json({ error: "Choose a revenue category" }, { status: 400 });
  }
  const numericQuantity = Number(quantity);
  const numericSalePrice = Number(salePrice);
  if (!Number.isFinite(numericQuantity) || numericQuantity <= 0) {
    return NextResponse.json({ error: "Invalid quantity" }, { status: 400 });
  }
  if (!Number.isFinite(numericSalePrice) || numericSalePrice <= 0) {
    return NextResponse.json({ error: "Invalid sale price" }, { status: 400 });
  }
  if (typeof date !== "string" || !date) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }
  if (paid && (typeof bankAccountId !== "string" || !bankAccountId)) {
    return NextResponse.json({ error: "Choose a bank account" }, { status: 400 });
  }
  if (!paid && (typeof customerId !== "string" || !customerId)) {
    return NextResponse.json({ error: "Choose a customer" }, { status: 400 });
  }

  try {
    const movement = await recordSale({
      productId,
      warehouseId,
      quantity: numericQuantity,
      salePrice: numericSalePrice,
      revenueAccountId,
      date: new Date(`${date}T00:00:00Z`),
      settlement: paid ? { type: "CASH", bankAccountId } : { type: "CREDIT", customerId },
      notes: typeof notes === "string" ? notes : undefined,
    });
    return NextResponse.json({ movement }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record sale" },
      { status: 400 }
    );
  }
}
