import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function DELETE(
  _request: Request,
  ctx: { params: Promise<{ id: string }> }
) {
  const { id } = await ctx.params;

  await prisma.transaction.delete({ where: { id } }).catch(() => null);

  return NextResponse.json({ ok: true });
}
