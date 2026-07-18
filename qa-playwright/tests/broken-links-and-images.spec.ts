import { test, expect } from "@playwright/test";
import { collectLinks, findBrokenLinks, auditImages } from "./utils/network";
import { goToCollection, openFirstProduct } from "./utils/shop-flows";

/**
 * Site-wide crawl-lite: gathers every link/image from the key page types
 * and validates them in bulk. This runs once per project (desktop/tablet/
 * mobile) since link validity is layout-independent, but is included in
 * every project so a mobile-only broken link (e.g. a mobile-only menu
 * item) still gets caught.
 */
test.describe("Broken links & missing images (site-wide)", () => {
  test("no broken links across homepage, collection, product, and cart pages", async ({ page, request }) => {
    const allLinks = new Set<string>();

    await page.goto("/", { waitUntil: "load" });
    for (const l of await collectLinks(page)) allLinks.add(l);

    await goToCollection(page, test.info().project.use.baseURL as string);
    for (const l of await collectLinks(page)) allLinks.add(l);

    await openFirstProduct(page);
    for (const l of await collectLinks(page)) allLinks.add(l);

    await page.goto("/cart", { waitUntil: "load" });
    for (const l of await collectLinks(page)) allLinks.add(l);

    const broken = await findBrokenLinks(request, Array.from(allLinks));
    expect(broken, `Broken links found:\n${JSON.stringify(broken, null, 2)}`).toEqual([]);
  });

  test("no missing/broken images across homepage, collection, and product pages", async ({ page }) => {
    const allBroken: Array<{ page: string; src: string | null }> = [];

    await page.goto("/", { waitUntil: "networkidle" });
    for (const img of await auditImages(page)) {
      if (img.broken) allBroken.push({ page: "homepage", src: img.src });
    }

    await goToCollection(page, test.info().project.use.baseURL as string);
    await page.waitForLoadState("networkidle").catch(() => {});
    for (const img of await auditImages(page)) {
      if (img.broken) allBroken.push({ page: "collection", src: img.src });
    }

    await openFirstProduct(page);
    await page.waitForLoadState("networkidle").catch(() => {});
    for (const img of await auditImages(page)) {
      if (img.broken) allBroken.push({ page: "product", src: img.src });
    }

    expect(allBroken, `Broken images:\n${JSON.stringify(allBroken, null, 2)}`).toEqual([]);
  });
});
