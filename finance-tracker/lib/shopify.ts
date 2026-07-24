export type ShopifyOrder = {
  id: number;
  name: string;
  created_at: string;
  total_price: string;
  financial_status: string;
};

function parseNextPageInfo(linkHeader: string | null): string | null {
  if (!linkHeader) return null;
  const match = linkHeader
    .split(",")
    .map((part) => part.trim())
    .find((part) => part.endsWith('rel="next"'));
  if (!match) return null;
  const urlMatch = match.match(/<([^>]+)>/);
  if (!urlMatch) return null;
  return new URL(urlMatch[1]).searchParams.get("page_info");
}

export async function fetchAllOrders(
  { maxPages = 10, updatedAtMin }: { maxPages?: number; updatedAtMin?: Date } = {}
): Promise<ShopifyOrder[]> {
  const domain = process.env.SHOPIFY_STORE_DOMAIN;
  const token = process.env.SHOPIFY_ADMIN_ACCESS_TOKEN;

  if (!domain || !token) {
    throw new Error(
      "Missing SHOPIFY_STORE_DOMAIN or SHOPIFY_ADMIN_ACCESS_TOKEN env vars"
    );
  }

  const orders: ShopifyOrder[] = [];
  let pageInfo: string | null = null;
  let page = 0;

  do {
    const url = new URL(`https://${domain}/admin/api/2024-10/orders.json`);
    url.searchParams.set("status", "any");
    url.searchParams.set("limit", "250");
    url.searchParams.set(
      "fields",
      "id,name,created_at,total_price,financial_status"
    );
    if (updatedAtMin) url.searchParams.set("updated_at_min", updatedAtMin.toISOString());
    if (pageInfo) url.searchParams.set("page_info", pageInfo);

    const res = await fetch(url, {
      headers: { "X-Shopify-Access-Token": token },
    });

    if (!res.ok) {
      throw new Error(`Shopify API error: ${res.status} ${await res.text()}`);
    }

    const json = await res.json();
    orders.push(...(json.orders ?? []));
    pageInfo = parseNextPageInfo(res.headers.get("link"));
    page += 1;
  } while (pageInfo && page < maxPages);

  return orders;
}
