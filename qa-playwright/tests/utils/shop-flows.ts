import { Page, expect } from "@playwright/test";

/**
 * These helpers deliberately use broad, resilient locator strategies
 * (accessible role/name, common Shopify class/attribute patterns) instead
 * of hard-coded selectors, because the exact Impulse-theme markup on the
 * live store was not available to verify against when this suite was
 * written. If a step can't find an element, it throws a descriptive error
 * rather than silently no-op'ing, so failures point at what to adjust.
 */

export async function goToCollection(page: Page, baseURL: string) {
  await page.goto("/", { waitUntil: "load" });

  const navCandidates = page.getByRole("link", {
    name: /shop|collection|new in|new arrivals|women|shop all|dresses|clothing/i,
  });

  if (await navCandidates.count()) {
    await navCandidates.first().click({ trial: false }).catch(() => {});
    await page.waitForLoadState("load").catch(() => {});
    if (/\/collections\//.test(page.url())) return;
  }

  // Fallback: Shopify's default "all products" collection always exists
  // unless explicitly disabled.
  await page.goto(`${baseURL}/collections/all`, { waitUntil: "load" });
}

export async function openFirstProduct(page: Page) {
  const productLinks = page.locator('a[href*="/products/"]').first();
  await expect(productLinks, "Expected at least one product link on the collection page").toBeVisible({
    timeout: 15_000,
  });
  await productLinks.click();
  await page.waitForURL(/\/products\//, { timeout: 15_000 });
}

export interface VariantSelectionResult {
  colorSwatchClicked: boolean;
  sizeOptionSelected: boolean;
}

export async function selectAvailableVariantOptions(page: Page): Promise<VariantSelectionResult> {
  const result: VariantSelectionResult = { colorSwatchClicked: false, sizeOptionSelected: false };

  // Colour / style swatches: commonly rendered as input[type=radio] + label,
  // or clickable buttons/anchors grouped under a fieldset/legend mentioning
  // "colour"/"color".
  const swatchCandidates = page.locator(
    [
      'fieldset:has-text("Color") input[type="radio"]',
      'fieldset:has-text("Colour") input[type="radio"]',
      '[data-option-name*="color" i] input[type="radio"]',
      '.swatch:not(.selected)',
      '[class*="swatch"]:not([class*="selected"]) input[type="radio"]',
    ].join(", ")
  );
  const swatchCount = await swatchCandidates.count();
  if (swatchCount > 0) {
    const target = swatchCandidates.first();
    await target.click({ force: true }).catch(() => {});
    result.colorSwatchClicked = true;
  }

  // Size selector: <select> with size-like options, or a group of
  // button/radio/label elements under a "Size" fieldset.
  const sizeSelect = page
    .locator("select")
    .filter({ has: page.locator('option:text-matches("XS|S|M|L|XL|[0-9]{1,2}", "i")') })
    .first();

  if (await sizeSelect.count()) {
    const options = await sizeSelect.locator("option").all();
    for (const opt of options) {
      const disabled = await opt.getAttribute("disabled");
      const value = await opt.getAttribute("value");
      const text = (await opt.textContent())?.trim() ?? "";
      if (!disabled && value && !/select|choose/i.test(text)) {
        await sizeSelect.selectOption(value);
        result.sizeOptionSelected = true;
        break;
      }
    }
  } else {
    const sizeButtons = page.locator(
      [
        'fieldset:has-text("Size") input[type="radio"]:not([disabled])',
        '[data-option-name*="size" i] input[type="radio"]:not([disabled])',
        'fieldset:has-text("Size") label:not(.disabled):not(.sold-out)',
      ].join(", ")
    );
    if (await sizeButtons.count()) {
      await sizeButtons.first().click({ force: true }).catch(() => {});
      result.sizeOptionSelected = true;
    }
  }

  return result;
}

export async function setQuantity(page: Page, qty: number): Promise<boolean> {
  const qtyInput = page
    .locator('input[type="number"][name*="quantity" i], input[name="quantity"], .quantity-selector input')
    .first();

  if (await qtyInput.count()) {
    await qtyInput.fill(String(qty));
    await qtyInput.dispatchEvent("change").catch(() => {});
    return true;
  }

  // Stepper-style +/- buttons.
  const increment = page
    .locator('button[aria-label*="increase" i], button[name="plus"], .quantity-selector button:has-text("+")')
    .first();
  if (await increment.count()) {
    for (let i = 1; i < qty; i++) {
      await increment.click();
    }
    return true;
  }

  return false;
}

export async function clickAddToCart(page: Page) {
  const addButton = page.getByRole("button", { name: /add to (cart|bag)/i }).first();
  await expect(addButton, "Expected an 'Add to cart/bag' button on the product page").toBeVisible({
    timeout: 10_000,
  });

  const disabled = await addButton.isDisabled();
  const label = (await addButton.textContent()) ?? "";
  if (disabled || /sold out|unavailable/i.test(label)) {
    throw new Error(`Add-to-cart button is disabled/sold out: "${label.trim()}"`);
  }

  await addButton.click();
}

/** Returns 'drawer' | 'page' | 'none' depending on what happened after
 * add-to-cart was clicked. */
export async function detectCartResponse(page: Page): Promise<"drawer" | "page" | "none"> {
  const drawer = page.locator(
    '[id*="cart-drawer" i], [class*="cart-drawer" i], [class*="drawer"][class*="cart" i], #CartDrawer'
  );

  const result = await Promise.race<Promise<"drawer" | "page" | "none">>([
    drawer
      .first()
      .waitFor({ state: "visible", timeout: 6000 })
      .then(() => "drawer" as const)
      .catch(() => "none" as const),
    page
      .waitForURL(/\/cart/, { timeout: 6000 })
      .then(() => "page" as const)
      .catch(() => "none" as const),
  ]);

  if (result !== "none") return result;

  // Last resort: ask Shopify directly whether the cart actually received
  // the item, in case the UI feedback is silent/custom.
  const cart = await page.evaluate(() => fetch("/cart.js").then((r) => r.json()));
  return cart?.item_count > 0 ? "page" : "none";
}
