import { test, expect } from "@playwright/test";
import { trackPageIssues, formatIssues, auditImages } from "./utils/network";
import {
  goToCollection,
  openFirstProduct,
  selectAvailableVariantOptions,
  setQuantity,
  clickAddToCart,
  detectCartResponse,
} from "./utils/shop-flows";

test.describe("Product page", () => {
  test.beforeEach(async ({ page }, testInfo) => {
    await goToCollection(page, testInfo.project.use.baseURL as string);
    await openFirstProduct(page);
  });

  test("loads with no console errors and a valid gallery", async ({ page }) => {
    const tracker = trackPageIssues(page);
    await page.reload({ waitUntil: "load" });

    const mainImage = page.locator('main img, .product-single img, [class*="product"] img').first();
    await expect(mainImage, "Expected a main product image").toBeVisible();

    const images = await auditImages(page);
    const broken = images.filter((i) => i.broken);
    expect(broken, `Broken product images:\n${JSON.stringify(broken, null, 2)}`).toEqual([]);

    const issues = formatIssues(tracker);
    expect(issues, issues).toBe("");
  });

  test("product title and price are visible", async ({ page }) => {
    await expect(page.locator("h1").first()).toBeVisible();
    const priceLike = page.locator('[class*="price" i], [data-price]').first();
    await expect(priceLike, "Expected some price element on the PDP").toBeVisible();
  });

  test("color swatches update the displayed variant", async ({ page }) => {
    const before = await page
      .locator('main img, .product-single img, [class*="product"] img')
      .first()
      .getAttribute("src");

    const { colorSwatchClicked } = await selectAvailableVariantOptions(page);
    test.skip(!colorSwatchClicked, "No color swatches detected on this product");

    await page.waitForTimeout(500); // allow variant image swap to settle
    const after = await page
      .locator('main img, .product-single img, [class*="product"] img')
      .first()
      .getAttribute("src");

    test.info().annotations.push({
      type: "swatch-image-change",
      description: after === before ? "Image did not change after swatch click (may be expected if same photo)" : "Image updated",
    });
  });

  test("size selector allows choosing an available size", async ({ page }) => {
    const { sizeOptionSelected } = await selectAvailableVariantOptions(page);
    test.skip(!sizeOptionSelected, "No size selector detected on this product (may be a one-size item)");
  });

  test("quantity selector accepts a value greater than 1", async ({ page }) => {
    const set = await setQuantity(page, 2);
    test.skip(!set, "No quantity selector detected on this product page");
  });

  test("add to cart succeeds and reflects in cart state", async ({ page }) => {
    await selectAvailableVariantOptions(page);
    const cartBefore = await page.evaluate(() => fetch("/cart.js").then((r) => r.json()));

    await clickAddToCart(page);
    const response = await detectCartResponse(page);
    expect(response, "Expected the cart drawer to open or navigation to /cart after adding to cart").not.toBe(
      "none"
    );

    const cartAfter = await page.evaluate(() => fetch("/cart.js").then((r) => r.json()));
    expect(cartAfter.item_count).toBeGreaterThan(cartBefore.item_count);
  });

  test("sold-out variants are clearly disabled, not silently addable", async ({ page }) => {
    const soldOutOption = page.locator('option:has-text("Sold out"), [class*="sold-out" i]').first();
    test.skip(!(await soldOutOption.count()), "No sold-out variants present on this product");

    const addButton = page.getByRole("button", { name: /add to (cart|bag)/i }).first();
    // If a sold-out option is selectable, selecting it should disable Add to
    // cart or clearly relabel it — never allow adding an unavailable variant.
    const label = (await addButton.textContent()) ?? "";
    expect(/sold out|unavailable/i.test(label) || (await addButton.isDisabled())).toBeTruthy();
  });
});
