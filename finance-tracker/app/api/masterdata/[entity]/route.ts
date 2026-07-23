import { NextResponse } from "next/server";
import { MASTER_DATA_SERVICES, isMasterDataEntity } from "@/lib/masterdata/registry";

export async function GET(
  request: Request,
  ctx: { params: Promise<{ entity: string }> }
) {
  const { entity } = await ctx.params;
  if (!isMasterDataEntity(entity)) {
    return NextResponse.json({ error: "Unknown entity" }, { status: 404 });
  }

  const { searchParams } = new URL(request.url);
  const page = Number(searchParams.get("page") ?? "1");
  const pageSize = Number(searchParams.get("pageSize") ?? "25");
  const search = searchParams.get("search") ?? undefined;
  const activeOnly = searchParams.get("activeOnly") === "true";

  const result = await MASTER_DATA_SERVICES[entity].list({ page, pageSize, search, activeOnly });
  return NextResponse.json(result);
}

export async function POST(
  request: Request,
  ctx: { params: Promise<{ entity: string }> }
) {
  const { entity } = await ctx.params;
  if (!isMasterDataEntity(entity)) {
    return NextResponse.json({ error: "Unknown entity" }, { status: 404 });
  }

  const data = await request.json();
  try {
    const item = await MASTER_DATA_SERVICES[entity].create(data);
    return NextResponse.json({ item }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not create" },
      { status: 400 }
    );
  }
}
