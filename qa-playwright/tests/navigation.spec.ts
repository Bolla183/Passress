import { test, expect } from "@playwright/test";
import { findBrokenLinks } from "./utils/network";

test.describe("Header & navigation", () => {
  test("desktop/tablet: primary nav links are visible and not broken", async ({ page, request }, testInfo) => {
    test.skip(testInfo.project.name === "Mobile", "Mobile uses the hamburger menu — covered separately");

    await page.goto("/", { waitUntil: "load" });
    const nav = page.locator("header nav, header [role='navigation'], .site-header").first();
    await expect(nav).toBeVisible();

    const links = await nav.locator("a[href]").evaluateAll((as) =>
      (as as HTMLAnchorElement[]).map((a) => a.href)
    );
    const unique = Array.from(new Set(links)).filter((h) => h && !h.startsWith("javascript:"));
    expect(unique.length, "Expected the header to contain navigation links").toBeGreaterThan(0);

    const broken = await findBrokenLinks(request, unique);
    expect(broken, `Broken nav links:\n${JSON.stringify(broken, null, 2)}`).toEqual([]);
  });

  test("mobile: hamburger menu opens and closes the nav drawer", async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== "Mobile", "Only relevant on the mobile project");

    await page.goto("/", { waitUntil: "load" });

    const menuButton = page.getByRole("button", { name: /menu|open navigation/i }).first();
    await expect(menuButton, "Expected a mobile menu/hamburger button").toBeVisible();
    await menuButton.click();

    const drawer = page.locator(
      '[id*="nav-drawer" i], [class*="nav-drawer" i], [class*="mobile-nav" i], [role="dialog"]'
    );
    await expect(drawer.first(), "Expected the mobile nav drawer to open").toBeVisible({ timeout: 5000 });

    const links = drawer.first().locator("a[href]");
    expect(await links.count(), "Expected links inside the mobile nav drawer").toBeGreaterThan(0);

    const closeButton = page.getByRole("button", { name: /close|dismiss/i }).first();
    if (await closeButton.count()) {
      await closeButton.click();
      await expect(drawer.first()).toBeHidden({ timeout: 5000 });
    }
  });

  test("logo links back to the homepage", async ({ page }) => {
    await page.goto("/collections/all", { waitUntil: "load" }).catch(() => {});
    const logo = page.locator("header a[href='/'], .site-header a[href='/'], a.logo, [class*='logo'] a").first();
    if (!(await logo.count())) {
      test.skip(true, "No dedicated logo link detected with common selectors");
    }
    await logo.click();
    await expect(page).toHaveURL(/\/$|\/(index)?$/);
  });
});
