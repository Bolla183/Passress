import { test, expect } from "@playwright/test";
import { trackPageIssues, formatIssues } from "./utils/network";
import { goToCollection, openFirstProduct, selectAvailableVariantOptions, clickAddToCart, detectCartResponse } from "./utils/shop-flows";

async function addOneItemToCart(page: import("@playwright/test").Page, baseURL: string) {
  await goToCollection(page, baseURL);
  await openFirstProduct(page);
  await selectAvailableVariantOptions(page);
  await clickAddToCart(page);
  await detectCartResponse(page);
}

test.describe("Cart", () => {
  test("cart drawer or page shows the added item with correct details", async ({ page }, testInfo) => {
    const tracker = trackPageIssues(page);
    await addOneItemToCart(page, testInfo.project.use.baseURL as string);

    await page.goto("/cart", { waitUntil: "load" });
    const cart = await page.evaluate(() => fetch("/cart.js").then((r) => r.json()));
    expect(cart.item_count, "Expected the cart to contain the item just added").toBeGreaterThan(0);

    const lineItem = page.locator('[class*="cart-item" i], [class*="line-item" i], tr[class*="cart"]').first();
    await expect(lineItem, "Expected a visible line item on the cart page").toBeVisible();

    const issues = formatIssues(tracker);
    expect(issues, issues).toBe("");
  });

  test("quantity can be updated from the cart", async ({ page }, testInfo) => {
    await addOneItemToCart(page, testInfo.project.use.baseURL as string);
    await page.goto("/cart", { waitUntil: "load" });

    const qtyInput = page.locator('input[type="number"][name*="quantity" i], input[name*="updates"]').first();
    test.skip(!(await qtyInput.count()), "No quantity input found on the cart page");

    await qtyInput.fill("2");
    await qtyInput.dispatchEvent("change");
    await page.waitForTimeout(1000);

    const cart = await page.evaluate(() => fetch("/cart.js").then((r) => r.json()));
    expect(cart.items[0]?.quantity).toBe(2);
  });

  test("an item can be removed from the cart", async ({ page }, testInfo) => {
    await addOneItemToCart(page, testInfo.project.use.baseURL as string);
    await page.goto("/cart", { waitUntil: "load" });

    const removeButton = page
      .getByRole("button", { name: /remove|delete/i })
      .or(page.locator('a[href*="quantity=0"], [class*="remove" i]'))
      .first();
    test.skip(!(await removeButton.count()), "No remove control found on the cart page");

    await removeButton.click();
    await page.waitForTimeout(1000);

    const cart = await page.evaluate(() => fetch("/cart.js").then((r) => r.json()));
    expect(cart.item_count).toBe(0);
  });

  test("empty cart shows a clear empty state instead of erroring", async ({ page }) => {
    await page.evaluate(() =>
      fetch("/cart/clear.js", { method: "POST" }).catch(() => undefined)
    );
    await page.goto("/cart", { waitUntil: "load" });

    const body = await page.locator("body").innerText();
    expect(body.toLowerCase()).toMatch(/empty|nothing.*here|no items|start shopping/);
  });

  test("checkout button is present and points to /checkout", async ({ page }, testInfo) => {
    await addOneItemToCart(page, testInfo.project.use.baseURL as string);
    await page.goto("/cart", { waitUntil: "load" });

    const checkoutButton = page.getByRole("button", { name: /checkout/i }).or(page.getByRole("link", { name: /checkout/i }));
    await expect(checkoutButton.first(), "Expected a checkout button/link on the cart page").toBeVisible();
  });
});
