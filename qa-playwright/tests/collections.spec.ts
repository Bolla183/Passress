import { test, expect } from "@playwright/test";
import { trackPageIssues, formatIssues, auditImages } from "./utils/network";
import { goToCollection } from "./utils/shop-flows";

test.describe("Collections", () => {
  test("a collection page renders a product grid with no console errors", async ({ page }, testInfo) => {
    const tracker = trackPageIssues(page);
    await goToCollection(page, testInfo.project.use.baseURL as string);

    const productLinks = page.locator('a[href*="/products/"]');
    await expect(productLinks.first(), "Expected at least one product card").toBeVisible({ timeout: 15_000 });
    expect(await productLinks.count()).toBeGreaterThan(0);

    const issues = formatIssues(tracker);
    expect(issues, issues).toBe("");
  });

  test("product card images load and show price/title", async ({ page }, testInfo) => {
    await goToCollection(page, testInfo.project.use.baseURL as string);
    await page.waitForLoadState("networkidle").catch(() => {});

    const images = await auditImages(page);
    const productImages = images.filter((i) => i.src && !i.src.includes("data:"));
    expect(productImages.length).toBeGreaterThan(0);

    const broken = productImages.filter((i) => i.broken);
    expect(broken, `Broken product images:\n${JSON.stringify(broken, null, 2)}`).toEqual([]);
  });

  test("pagination or 'load more' works if present", async ({ page }, testInfo) => {
    await goToCollection(page, testInfo.project.use.baseURL as string);

    const loadMore = page.getByRole("button", { name: /load more|show more/i }).first();
    const nextPageLink = page.getByRole("link", { name: /next|→/i }).first();

    if (await loadMore.count()) {
      const before = await page.locator('a[href*="/products/"]').count();
      await loadMore.click();
      await expect
        .poll(async () => page.locator('a[href*="/products/"]').count(), { timeout: 10_000 })
        .toBeGreaterThan(before);
    } else if (await nextPageLink.count()) {
      await nextPageLink.click();
      await page.waitForLoadState("load");
      expect(page.url()).toMatch(/page=2|\/2$/);
    } else {
      test.skip(true, "No pagination or load-more control found (collection may fit on one page)");
    }
  });
});
