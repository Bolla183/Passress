import { NextResponse } from "next/server";
import { deleteQuickEntry } from "@/lib/accounting/quickEntry";

export async function DELETE(
  _request: Request,
  ctx: { params: Promise<{ id: string }> }
) {
  const { id } = await ctx.params;

  await deleteQuickEntry(id);

  return NextResponse.json({ ok: true });
}
