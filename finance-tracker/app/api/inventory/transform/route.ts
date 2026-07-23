import { NextResponse } from "next/server";
import { recordTransform } from "@/lib/modules/inventory";

export async function POST(request: Request) {
  const body = await request.json();
  const {
    rawProductId,
    rawWarehouseId,
    rawQuantity,
    finishedProductId,
    finishedWarehouseId,
    finishedQuantity,
    date,
    notes,
  } = body ?? {};

  if (typeof rawProductId !== "string" || !rawProductId) {
    return NextResponse.json({ error: "Choose a raw material" }, { status: 400 });
  }
  if (typeof rawWarehouseId !== "string" || !rawWarehouseId) {
    return NextResponse.json({ error: "Choose a raw material warehouse" }, { status: 400 });
  }
  if (typeof finishedProductId !== "string" || !finishedProductId) {
    return NextResponse.json({ error: "Choose a finished good" }, { status: 400 });
  }
  if (typeof finishedWarehouseId !== "string" || !finishedWarehouseId) {
    return NextResponse.json({ error: "Choose a finished good warehouse" }, { status: 400 });
  }
  const numericRawQuantity = Number(rawQuantity);
  const numericFinishedQuantity = Number(finishedQuantity);
  if (!Number.isFinite(numericRawQuantity) || numericRawQuantity <= 0) {
    return NextResponse.json({ error: "Invalid raw material quantity" }, { status: 400 });
  }
  if (!Number.isFinite(numericFinishedQuantity) || numericFinishedQuantity <= 0) {
    return NextResponse.json({ error: "Invalid finished good quantity" }, { status: 400 });
  }
  if (typeof date !== "string" || !date) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }

  try {
    const movement = await recordTransform({
      rawProductId,
      rawWarehouseId,
      rawQuantity: numericRawQuantity,
      finishedProductId,
      finishedWarehouseId,
      finishedQuantity: numericFinishedQuantity,
      date: new Date(`${date}T00:00:00Z`),
      notes: typeof notes === "string" ? notes : undefined,
    });
    return NextResponse.json({ movement }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record transform" },
      { status: 400 }
    );
  }
}
