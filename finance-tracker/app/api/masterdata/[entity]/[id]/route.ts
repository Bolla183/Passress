import { NextResponse } from "next/server";
import { MASTER_DATA_SERVICES, isMasterDataEntity } from "@/lib/masterdata/registry";

export async function PATCH(
  request: Request,
  ctx: { params: Promise<{ entity: string; id: string }> }
) {
  const { entity, id } = await ctx.params;
  if (!isMasterDataEntity(entity)) {
    return NextResponse.json({ error: "Unknown entity" }, { status: 404 });
  }

  const data = await request.json();
  try {
    const item = await MASTER_DATA_SERVICES[entity].update(id, data);
    return NextResponse.json({ item });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not update" },
      { status: 400 }
    );
  }
}

export async function DELETE(
  _request: Request,
  ctx: { params: Promise<{ entity: string; id: string }> }
) {
  const { entity, id } = await ctx.params;
  if (!isMasterDataEntity(entity)) {
    return NextResponse.json({ error: "Unknown entity" }, { status: 404 });
  }

  try {
    await MASTER_DATA_SERVICES[entity].remove(id);
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not delete" },
      { status: 400 }
    );
  }
  return NextResponse.json({ ok: true });
}
