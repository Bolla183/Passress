import { chromium, FullConfig } from "@playwright/test";
import fs from "fs";
import path from "path";
import { BASE_URL, PREVIEW_THEME_ID, STOREFRONT_PASSWORD, STORAGE_STATE } from "../playwright.config";

/**
 * Runs once before the whole suite. Shopify unpublished-theme previews and
 * storefront-password gates are both cookie-based, so we do the one-time
 * handshake here and persist cookies to disk — every test project then
 * reuses that storage state instead of repeating the query param/password
 * flow on every navigation.
 */
export default async function globalSetup(_config: FullConfig) {
  fs.mkdirSync(path.dirname(STORAGE_STATE), { recursive: true });

  const browser = await chromium.launch({
    executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined,
  });
  const context = await browser.newContext();
  const page = await context.newPage();

  const target = PREVIEW_THEME_ID
    ? `${BASE_URL}/?preview_theme_id=${encodeURIComponent(PREVIEW_THEME_ID)}`
    : `${BASE_URL}/`;

  await page.goto(target, { waitUntil: "domcontentloaded" });

  if (/\/password/.test(page.url())) {
    if (!STOREFRONT_PASSWORD) {
      throw new Error(
        `Storefront is password-protected (redirected to ${page.url()}) but no STOREFRONT_PASSWORD was set. ` +
          `Copy .env.example to .env and set STOREFRONT_PASSWORD.`
      );
    }
    const pwInput = page.locator('input[type="password"], input[name="password"]').first();
    await pwInput.fill(STOREFRONT_PASSWORD);
    await Promise.all([
      page.waitForNavigation({ waitUntil: "domcontentloaded" }).catch(() => {}),
      pwInput.press("Enter"),
    ]);
    // Re-apply preview_theme_id after the password redirect, since the
    // password form may drop the original query string.
    if (PREVIEW_THEME_ID) {
      await page.goto(target, { waitUntil: "domcontentloaded" });
    }
  }

  await context.storageState({ path: STORAGE_STATE });
  await browser.close();
}
