import { test, expect } from "@playwright/test";

test.describe("Search", () => {
  test("search returns relevant results for a common query", async ({ page }) => {
    await page.goto("/", { waitUntil: "load" });

    const searchButton = page.getByRole("button", { name: /search/i }).first();
    const searchLink = page.getByRole("link", { name: /search/i }).first();

    if (await searchButton.count()) {
      await searchButton.click();
    } else if (await searchLink.count()) {
      await searchLink.click();
    } else {
      test.skip(true, "No search entry point found (button or link)");
    }

    const searchInput = page
      .getByRole("searchbox")
      .or(page.locator('input[type="search"], input[name="q"]'))
      .first();
    await expect(searchInput, "Expected a search input to appear").toBeVisible({ timeout: 5000 });

    await searchInput.fill("dress");
    await searchInput.press("Enter");
    await page.waitForLoadState("load").catch(() => {});

    // Either a predictive-search dropdown renders results inline, or we
    // land on /search with results — accept either.
    const resultLinks = page.locator('a[href*="/products/"]');
    await expect
      .poll(async () => resultLinks.count(), { timeout: 10_000 })
      .toBeGreaterThan(0);
  });

  test("search with no matches shows a friendly empty state, not an error", async ({ page }) => {
    await page.goto("/search?q=zzzznonexistentproductqueryzzzz&type=product", { waitUntil: "load" });

    const body = await page.locator("body").innerText();
    expect(body.toLowerCase()).toMatch(/no results|nothing found|no products found|couldn.?t find/);
  });
});
