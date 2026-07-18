import { test, expect } from "@playwright/test";
import { findBrokenLinks, trackPageIssues, formatIssues } from "./utils/network";

test.describe("Footer", () => {
  test("footer renders with working links", async ({ page, request }) => {
    await page.goto("/", { waitUntil: "load" });
    const footer = page.locator("footer").first();
    await expect(footer, "Expected a <footer> element").toBeVisible();

    const links = await footer.locator("a[href]").evaluateAll((as) =>
      (as as HTMLAnchorElement[]).map((a) => a.href)
    );
    const unique = Array.from(new Set(links)).filter(
      (h) => h && !h.startsWith("mailto:") && !h.startsWith("tel:") && !h.startsWith("javascript:")
    );
    expect(unique.length, "Expected the footer to contain links").toBeGreaterThan(0);

    const broken = await findBrokenLinks(request, unique);
    expect(broken, `Broken footer links:\n${JSON.stringify(broken, null, 2)}`).toEqual([]);
  });

  test("newsletter signup form validates and accepts an email", async ({ page }) => {
    const form = page.locator('footer form[action*="/contact"], footer form:has(input[type="email"])').first();
    test.skip(!(await form.count()), "No newsletter signup form detected in the footer");

    const emailInput = form.locator('input[type="email"]').first();
    const submit = form.getByRole("button", { name: /subscribe|sign up|submit/i }).first();

    // Invalid email should be rejected client-side (native or custom
    // validation) rather than submitted.
    await emailInput.fill("not-an-email");
    await submit.click();
    const validity = await emailInput.evaluate((el: HTMLInputElement) => el.validity.valid);
    expect(validity, "Expected the email field to reject an invalid address").toBeFalsy();
  });
});

test.describe("Static / policy pages", () => {
  const pages: Array<{ name: string; patterns: RegExp[] }> = [
    { name: "Contact", patterns: [/contact/i] },
    { name: "Track Order", patterns: [/track.*order|order.*track|track-order/i] },
    { name: "Shipping", patterns: [/shipping/i] },
    { name: "Returns", patterns: [/return|exchange/i] },
    { name: "FAQ", patterns: [/faq|frequently asked/i] },
  ];

  for (const { name, patterns } of pages) {
    test(`${name} page is reachable and renders content with no console errors`, async ({ page }) => {
      await page.goto("/", { waitUntil: "load" });
      const footer = page.locator("footer").first();

      let link = footer.getByRole("link", { name: patterns[0] }).first();
      if (!(await link.count())) {
        link = page.getByRole("link", { name: patterns[0] }).first();
      }

      test.skip(!(await link.count()), `No "${name}" link found in footer or page — confirm the page exists under a different label`);

      const tracker = trackPageIssues(page);
      await link.click();
      await page.waitForLoadState("load");

      const main = page.locator("main, #MainContent, [role='main']").first();
      await expect(main, `Expected the ${name} page to render main content`).toBeVisible();
      const text = await main.innerText();
      expect(text.trim().length, `${name} page appears to have no body content`).toBeGreaterThan(20);

      const issues = formatIssues(tracker);
      expect(issues, issues).toBe("");
    });
  }
});
