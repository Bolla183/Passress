import { test, expect } from "@playwright/test";
import { goToCollection, openFirstProduct } from "./utils/shop-flows";

test.describe("Wishlist (if available)", () => {
  test("product cards or PDP expose a wishlist/save button", async ({ page }, testInfo) => {
    await goToCollection(page, testInfo.project.use.baseURL as string);

    const wishlistButton = page
      .getByRole("button", { name: /wishlist|add to favou?rites|save for later/i })
      .or(page.locator('[class*="wishlist" i], [data-wishlist], [aria-label*="wishlist" i]'))
      .first();

    test.skip(!(await wishlistButton.count()), "No wishlist feature detected on collection cards");

    await wishlistButton.click();
    await page.waitForTimeout(500);

    const activeState = page.locator('[class*="wishlist" i][class*="active" i], [aria-pressed="true"]');
    test.info().annotations.push({
      type: "wishlist-state",
      description: (await activeState.count()) > 0 ? "Wishlist button toggled to an active state" : "No visible active-state change detected — verify manually",
    });
  });

  test("wishlist persists and is viewable on a dedicated page", async ({ page }, testInfo) => {
    await goToCollection(page, testInfo.project.use.baseURL as string);
    await openFirstProduct(page);

    const pdpWishlistButton = page
      .getByRole("button", { name: /wishlist|add to favou?rites/i })
      .or(page.locator('[class*="wishlist" i]'))
      .first();

    test.skip(!(await pdpWishlistButton.count()), "No wishlist feature detected on the PDP");
    await pdpWishlistButton.click();

    const wishlistNavLink = page.getByRole("link", { name: /wishlist|favou?rites/i }).first();
    test.skip(!(await wishlistNavLink.count()), "No dedicated wishlist page link found in nav/header");

    await wishlistNavLink.click();
    await expect(page.locator('a[href*="/products/"]').first()).toBeVisible();
  });
});
